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
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.refreshPermission()
    }
}
