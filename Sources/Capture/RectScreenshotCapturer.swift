import CoreGraphics
import ScreenCaptureKit

/// macOS 26 path: display-agnostic global rect, exact pixel output size.
struct RectScreenshotCapturer: ScreenCapturing {
    let showsCursor: Bool

    nonisolated init(showsCursor: Bool = false) {
        self.showsCursor = showsCursor
    }

    nonisolated func capture(_ geometry: FrameGeometry, primaryHeight: CGFloat) async throws -> CGImage {
        let config = SCScreenshotConfiguration()
        config.width = Int(geometry.capturePixels.width)
        config.height = Int(geometry.capturePixels.height)
        config.showsCursor = showsCursor
        config.dynamicRange = .sdr
        config.displayIntent = .local
        config.includeChildWindows = true
        config.ignoreShadows = false

        let rect = geometry.cgGlobalRect(primaryHeight: primaryHeight)
        let output: SCScreenshotOutput
        do {
            output = try await SCScreenshotManager.captureScreenshot(rect: rect, configuration: config)
        } catch {
            throw ScreenCapturePermission.mapError(error)
        }
        guard let image = output.sdrImage else { throw CaptureError.noImage }
        return image
    }
}
