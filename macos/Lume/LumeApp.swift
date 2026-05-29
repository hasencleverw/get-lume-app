import SwiftUI
import AppKit

/// AppKit delegate to keep the process alive after the user closes the last
/// window. Without this, SwiftUI's default behaviour quits the app on the
/// final NSWindow close, which kills the MenuBarExtra too — so clicking the
/// menu bar icon afterwards does nothing because the app is already gone.
final class LumeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct LumeApp: App {
    @NSApplicationDelegateAdaptor(LumeAppDelegate.self) var appDelegate
    @StateObject private var monitor    = SystemMonitor()
    @StateObject private var scanner    = DiskScanner()
    @StateObject private var appManager = AppManager()
    @StateObject private var largeFiles = LargeFilesScanner()
    @StateObject private var malware    = MalwareScanner()
    @StateObject private var donation   = DonationManager()
    @StateObject private var localization = Localization()
    @StateObject private var appleSecurity = AppleSecurityInfo()
    @StateObject private var permissions   = PermissionsManager()
    @StateObject private var updater       = UpdaterService()

    init() {
        AnalyticsService.shared.recordLaunch()
        AnalyticsService.shared.printSummary()
    }

    var body: some Scene {
        WindowGroup("Lume", id: "main") {
            ContentView()
                .environmentObject(monitor)
                .environmentObject(scanner)
                .environmentObject(appManager)
                .environmentObject(largeFiles)
                .environmentObject(malware)
                .environmentObject(donation)
                .environmentObject(localization)
                .environmentObject(appleSecurity)
                .environmentObject(permissions)
                .environmentObject(updater)
                .frame(minWidth: 1000, minHeight: 660)
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "lume.hideFromDock") {
                        NSApp.setActivationPolicy(.accessory)
                    }
                    donation.checkShouldShow()
                    appleSecurity.refresh()
                    // Renders the cached banner immediately and kicks off a
                    // new network check if 7 days have passed since the last.
                    updater.bootstrap()
                }
                .sheet(isPresented: $donation.showPopup) {
                    // Sheets on macOS run in a separate window hierarchy and do
                    // not reliably inherit @EnvironmentObjects from the parent
                    // — every dependency must be injected explicitly here, or
                    // the first @EnvironmentObject access crashes the app.
                    DonationPopupView(manager: donation)
                        .interactiveDismissDisabled()
                        .environmentObject(localization)
                        .environmentObject(donation)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1160, height: 760)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra {
            MenuBarQuickView()
                .environmentObject(monitor)
                .environmentObject(scanner)
                .environmentObject(localization)
        } label: {
            Image(systemName: "sparkles")
        }
        .menuBarExtraStyle(.window)
    }
}
