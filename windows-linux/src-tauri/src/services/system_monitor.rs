use serde::Serialize;
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, ProcessRefreshKind, ProcessesToUpdate, RefreshKind, System};

// Helper: build refresh kinds compatible with sysinfo 0.32 (`new()`).
fn empty_refresh() -> RefreshKind { RefreshKind::new() }
fn empty_cpu() -> CpuRefreshKind { CpuRefreshKind::new() }
fn empty_proc() -> ProcessRefreshKind { ProcessRefreshKind::new() }

#[derive(Debug, Clone, Serialize)]
pub struct SystemMetrics {
    pub cpu_usage: f32,
    pub cpu_cores: usize,
    pub ram_total: u64,
    pub ram_used: u64,
    pub ram_available: u64,
    pub swap_total: u64,
    pub swap_used: u64,
    pub disk_total: u64,
    pub disk_used: u64,
    pub disk_free: u64,
    pub uptime_seconds: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProcessSnapshot {
    pub pid: u32,
    pub name: String,
    pub cpu_usage: f32,
    pub memory: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct HostInfo {
    pub os_name: String,
    pub os_version: String,
    pub kernel: String,
    pub hostname: String,
    pub arch: String,
}

/// Snapshot of the system. Refreshes CPU/memory then reads from `sys`.
///
/// CPU usage requires two refreshes separated by ≥200ms (sysinfo measures the
/// delta between consecutive calls). Callers should poll on an interval — the
/// first reading on a fresh process will read 0% which is correct.
pub fn collect(sys: &mut System) -> SystemMetrics {
    sys.refresh_specifics(
        empty_refresh()
            .with_cpu(empty_cpu().with_cpu_usage())
            .with_memory(MemoryRefreshKind::everything()),
    );

    let cpu_usage = sys.global_cpu_usage();
    let cpu_cores = sys.cpus().len();

    let ram_total = sys.total_memory();
    let ram_available = sys.available_memory();
    let ram_used = ram_total.saturating_sub(ram_available);
    let swap_total = sys.total_swap();
    let swap_used = sys.used_swap();

    let (disk_total, disk_free) = root_disk_usage();
    let disk_used = disk_total.saturating_sub(disk_free);

    SystemMetrics {
        cpu_usage,
        cpu_cores,
        ram_total,
        ram_used,
        ram_available,
        swap_total,
        swap_used,
        disk_total,
        disk_used,
        disk_free,
        uptime_seconds: System::uptime(),
    }
}

pub fn top_processes(sys: &mut System, limit: usize) -> Vec<ProcessSnapshot> {
    sys.refresh_processes_specifics(
        ProcessesToUpdate::All,
        true,
        empty_proc().with_cpu().with_memory(),
    );

    let mut procs: Vec<ProcessSnapshot> = sys
        .processes()
        .iter()
        .map(|(pid, p)| ProcessSnapshot {
            pid: pid.as_u32(),
            name: p.name().to_string_lossy().into_owned(),
            cpu_usage: p.cpu_usage(),
            memory: p.memory(),
        })
        .collect();

    // Sort by composite signal: weighted CPU + memory, so a heavy idle process
    // still surfaces. Mirrors the macOS app's behaviour.
    procs.sort_by(|a, b| {
        let score_a = a.cpu_usage as f64 + (a.memory as f64 / 1_000_000.0);
        let score_b = b.cpu_usage as f64 + (b.memory as f64 / 1_000_000.0);
        score_b.partial_cmp(&score_a).unwrap_or(std::cmp::Ordering::Equal)
    });
    procs.truncate(limit);
    procs
}

pub fn host_info() -> HostInfo {
    HostInfo {
        os_name: System::name().unwrap_or_else(|| "Unknown".into()),
        os_version: System::os_version().unwrap_or_else(|| "—".into()),
        kernel: System::kernel_version().unwrap_or_else(|| "—".into()),
        hostname: System::host_name().unwrap_or_else(|| "—".into()),
        arch: std::env::consts::ARCH.into(),
    }
}

/// Total / free bytes for the volume containing the user's home directory
/// (root `/` on Linux, the system drive on Windows). Uses `sysinfo::Disks`.
fn root_disk_usage() -> (u64, u64) {
    use sysinfo::Disks;

    let target = preferred_root();
    let disks = Disks::new_with_refreshed_list();

    let mut best: Option<(usize, u64, u64)> = None;
    for d in disks.list() {
        let mount = d.mount_point();
        let mount_str = mount.to_string_lossy();
        let target_str = target.to_string_lossy();
        if target_str.starts_with(mount_str.as_ref()) {
            let depth = mount.components().count();
            let total = d.total_space();
            let free = d.available_space();
            match best {
                Some((d0, _, _)) if d0 >= depth => {}
                _ => best = Some((depth, total, free)),
            }
        }
    }
    best.map(|(_, t, f)| (t, f)).unwrap_or((0, 0))
}

#[cfg(target_os = "windows")]
fn preferred_root() -> std::path::PathBuf {
    std::env::var_os("SystemDrive")
        .map(|s| std::path::PathBuf::from(format!("{}\\", s.to_string_lossy())))
        .unwrap_or_else(|| std::path::PathBuf::from("C:\\"))
}

#[cfg(not(target_os = "windows"))]
fn preferred_root() -> std::path::PathBuf {
    std::path::PathBuf::from("/")
}
