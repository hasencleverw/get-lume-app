import Foundation
import Darwin

@MainActor
final class SystemMonitor: ObservableObject {

    // MARK: - Published state
    @Published var cpuUsage: Double = 0          // 0–100
    @Published var ramUsed: UInt64 = 0
    @Published var ramFree: UInt64 = 0
    @Published var ramTotal: UInt64 = 0
    /// Real RAM breakdown (bytes). Used by the Memory page so we don't lie
    /// with synthetic 55/25/20 splits.
    @Published var ramActive: UInt64 = 0
    @Published var ramWired: UInt64 = 0
    @Published var ramCompressed: UInt64 = 0
    @Published var ramInactive: UInt64 = 0
    @Published var diskUsed: Int64 = 0
    @Published var diskFree: Int64 = 0
    @Published var diskTotal: Int64 = 0
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var ramHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var topProcesses: [ProcessInfo2] = []

    // MARK: - Private
    private var timer: Timer?
    private var prevCPUInfo: UnsafeMutablePointer<integer_t>?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0

    struct ProcessInfo2: Identifiable {
        let id: Int32
        let name: String
        let cpu: Double
        let ram: UInt64
    }

    init() {
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
        if let prev = prevCPUInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(prevCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        Task.detached(priority: .utility) {
            let ramData   = Self.fetchRAM()
            let diskData  = Self.fetchDisk()
            let procs     = Self.fetchTopProcesses()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.ramUsed       = ramData.used
                self.ramFree       = ramData.free
                self.ramTotal      = ramData.total
                self.ramActive     = ramData.active
                self.ramWired      = ramData.wired
                self.ramCompressed = ramData.compressed
                self.ramInactive   = ramData.inactive
                self.diskUsed  = diskData.used
                self.diskFree  = diskData.free
                self.diskTotal = diskData.total
                self.topProcesses = procs

                let ramPct = self.ramTotal > 0
                    ? Double(self.ramUsed) / Double(self.ramTotal) * 100
                    : 0
                self.ramHistory.append(ramPct)
                if self.ramHistory.count > 60 { self.ramHistory.removeFirst() }
            }
        }
        fetchCPU()
    }

    struct RAMSnapshot {
        let used: UInt64
        let free: UInt64
        let total: UInt64
        let active: UInt64
        let wired: UInt64
        let compressed: UInt64
        let inactive: UInt64
    }

    // MARK: - RAM
    private nonisolated static func fetchRAM() -> RAMSnapshot {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let page = UInt64(vm_kernel_page_size)
        let active     = UInt64(stats.active_count)            * page
        let wired      = UInt64(stats.wire_count)              * page
        let compressed = UInt64(stats.compressor_page_count)   * page
        let inactive   = UInt64(stats.inactive_count)          * page
        let free       = UInt64(stats.free_count)              * page
        let used       = active + wired + compressed
        let total      = Foundation.ProcessInfo.processInfo.physicalMemory
        return RAMSnapshot(
            used: used, free: free, total: total,
            active: active, wired: wired, compressed: compressed, inactive: inactive
        )
    }

    // MARK: - Disk
    private nonisolated static func fetchDisk() -> (used: Int64, free: Int64, total: Int64) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free  = attrs[.systemFreeSize] as? Int64
        else { return (0, 0, 0) }
        return (total - free, free, total)
    }

    // MARK: - CPU (requires main-actor context for mutating prevCPUInfo)
    private func fetchCPU() {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &cpuInfo, &numCPUInfo) == KERN_SUCCESS,
              let cpuInfo else { return }

        var usage = 0.0

        if let prev = prevCPUInfo {
            var userDelta = 0.0, sysDelta = 0.0, idleDelta = 0.0
            for i in 0..<Int(numCPUs) {
                let base = Int(CPU_STATE_MAX) * i
                let u = Double(cpuInfo[base + Int(CPU_STATE_USER)]   - prev[base + Int(CPU_STATE_USER)])
                let s = Double(cpuInfo[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)])
                let n = Double(cpuInfo[base + Int(CPU_STATE_NICE)]   - prev[base + Int(CPU_STATE_NICE)])
                let d = Double(cpuInfo[base + Int(CPU_STATE_IDLE)]   - prev[base + Int(CPU_STATE_IDLE)])
                userDelta += u + n
                sysDelta  += s
                idleDelta += d
            }
            let total = userDelta + sysDelta + idleDelta
            if total > 0 { usage = ((userDelta + sysDelta) / total) * 100 }
        }

        if let prev = prevCPUInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(prevCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        prevCPUInfo      = cpuInfo
        prevCPUInfoCount = numCPUInfo

        cpuUsage = usage
        cpuHistory.append(usage)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
    }

    // MARK: - Top Processes
    private nonisolated static func fetchTopProcesses() -> [ProcessInfo2] {
        var pids = [pid_t](repeating: 0, count: 1024)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }

        let nameBufSize = 4096
        var results: [ProcessInfo2] = []
        for i in 0..<Int(count) {
            let pid = pids[i]
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }

            var nameBuf = [CChar](repeating: 0, count: nameBufSize)
            proc_name(pid, &nameBuf, UInt32(nameBufSize))
            let name = String(cString: nameBuf).components(separatedBy: "/").last ?? "Unknown"
            if name.isEmpty { continue }

            results.append(ProcessInfo2(
                id: pid,
                name: name,
                cpu: 0,
                ram: info.pti_resident_size
            ))
        }
        return Array(results.sorted { $0.ram > $1.ram }.prefix(8))
    }

    // MARK: - Memory clean
    /// Frees inactive system memory by invoking `/usr/sbin/purge`. This is the
    /// only sanctioned way on macOS to reclaim file cache + inactive pages
    /// back to "Free" — `malloc_zone_pressure_relief` (which we used before)
    /// only affects this process's own allocator and is invisible to the user.
    ///
    /// `purge` requires root, so we wrap it in `osascript … with administrator
    /// privileges` and the user will see a single password prompt.
    func cleanMemory() {
        // Snapshot RAM-used BEFORE the purge so the view can show how much
        // was actually reclaimed once the refresh fires.
        let ramBefore = ramUsed
        // Trigger the AuthorizationServices prompt synchronously on the main
        // actor (it must run on the main thread to present its sheet).
        let granted = PrivilegedExecutor.shared.authorize()
        guard granted else { lastFreedBytes = 0; return }

        Task.detached(priority: .utility) {
            _ = await PrivilegedExecutor.shared.runShell("/usr/sbin/purge")
            // `purge` is async-ish — give the VM a moment to settle before
            // we re-read host statistics, otherwise the numbers won't reflect
            // the work it just did.
            try? await Task.sleep(nanoseconds: 800_000_000)
            let after = Self.fetchRAM()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.ramUsed       = after.used
                self.ramFree       = after.free
                self.ramTotal      = after.total
                self.ramActive     = after.active
                self.ramWired      = after.wired
                self.ramCompressed = after.compressed
                self.ramInactive   = after.inactive
                self.lastFreedBytes = max(0, Int64(ramBefore) - Int64(after.used))
                let ramPct = after.total > 0 ? Double(after.used) / Double(after.total) * 100 : 0
                self.ramHistory.append(ramPct)
                if self.ramHistory.count > 60 { self.ramHistory.removeFirst() }
            }
        }
    }

    /// Bytes reclaimed by the last successful `cleanMemory()` call. Views can
    /// use this to show the "+X freed" feedback after a click.
    @Published var lastFreedBytes: Int64 = 0
}

// MARK: - Formatters
extension SystemMonitor {
    static func formatBytes(_ bytes: UInt64) -> String { formatInt64(Int64(bytes)) }
    static func formatInt64(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
