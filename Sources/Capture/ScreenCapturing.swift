import CoreGraphics
import Foundation

nonisolated enum CaptureError: LocalizedError {
    case permissionDenied
    case microphoneDenied
    case noImage
    case displayNotFound
    case unexpectedSize(got: CGSize, expected: CGSize)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required. Enable it for Slightly Improved Screenshot in System Settings › Privacy & Security › Screen & System Audio Recording."
        case .microphoneDenied:
            "Microphone access is required to record the selected microphone. Enable it for Slightly Improved Screenshot in System Settings › Privacy & Security › Microphone, or set Microphone to None in Options."
        case .noImage:
            "The system returned no image."
        case .displayNotFound:
            "The display under the cursor could not be found."
        case let .unexpectedSize(got, expected):
            "Captured \(Int(got.width))×\(Int(got.height)) but expected \(Int(expected.width))×\(Int(expected.height))."
        }
    }
}

/// Captures the screen region described by a `FrameGeometry` at its native pixel size.
protocol ScreenCapturing: Sendable {
    func capture(_ geometry: FrameGeometry, primaryHeight: CGFloat) async throws -> CGImage
}
