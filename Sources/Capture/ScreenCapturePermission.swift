import AppKit
import ScreenCaptureKit

enum ScreenCapturePermission {
    /// True when Screen Recording access has been granted.
    static func preflight() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system prompt once per (bundle, signature). Later calls are no-ops.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Converts ScreenCaptureKit errors into user-facing `CaptureError`s where possible.
    nonisolated static func mapError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain == SCStreamErrorDomain {
            switch SCStreamError.Code(rawValue: ns.code) {
            case .userDeclined, .failedApplicationConnectionInvalid, .missingEntitlements:
                return CaptureError.permissionDenied
            default:
                break
            }
        }
        return error
    }
}
