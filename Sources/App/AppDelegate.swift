import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HotkeyManager.install { [weak self] in
            self?.state?.startCapture()
        }
        if !ScreenCapturePermission.preflight() {
            ScreenCapturePermission.request()
        }
        state?.refreshPermission()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        state?.refreshPermission()
    }
}
