import CoreGraphics
import CoreVideo
import ScreenCaptureKit

/// macOS 14 path: content filter for one display plus a display-local `sourceRect`.
/// Kept as a fallback in case the newer rect API misbehaves on some configuration.
struct FilterScreenshotCapturer: ScreenCapturing {
    /// Window numbers of our own overlay windows, excluded from the capture.
    let excludedWindowIDs: Set<CGWindowID>

    nonisolated init(excludedWindowIDs: Set<CGWindowID>) {
        self.excludedWindowIDs = excludedWindowIDs
    }

    nonisolated func capture(_ geometry: FrameGeometry, primaryHeight: CGFloat) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCapturePermission.mapError(error)
        }
        guard let display = content.displays.first(where: { $0.displayID == geometry.screen.displayID }) else {
            throw CaptureError.displayNotFound
        }
        let excluded = content.windows.filter { excludedWindowIDs.contains($0.windowID) }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)

        let config = SCStreamConfiguration()
        config.sourceRect = geometry.displayLocalRect
        config.width = Int(geometry.capturePixels.width)
        config.height = Int(geometry.capturePixels.height)
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        config.captureDynamicRange = .SDR
        config.colorSpaceName = CGColorSpace.sRGB
        config.scalesToFit = false
        config.preservesAspectRatio = true

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw ScreenCapturePermission.mapError(error)
        }
    }
}
