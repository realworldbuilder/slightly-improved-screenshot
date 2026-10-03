import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HotkeyManager.install {
            AppState.shared.startCapture()
        }
        if !ScreenCapturePermission.preflight() {
            ScreenCapturePermission.request()
        }
        AppState.shared.refreshPermission()
        // `-debugRecordSeconds N` on the command line records for N seconds with no UI.
        let debugSeconds = UserDefaults.standard.integer(forKey: "debugRecordSeconds")
        if debugSeconds > 0 {
            AppState.shared.debugRecord(seconds: debugSeconds)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.refreshPermission()
    }
}
