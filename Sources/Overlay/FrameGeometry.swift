import AppKit

/// Minimal description of a display, so geometry math is testable without real `NSScreen`s.
nonisolated struct ScreenInfo: Sendable, Equatable {
    let displayID: CGDirectDisplayID
    /// AppKit global coordinates (origin bottom-left of the primary display), in points.
    let frame: CGRect
    let backingScale: CGFloat

    nonisolated init(displayID: CGDirectDisplayID, frame: CGRect, backingScale: CGFloat) {
        self.displayID = displayID
        self.frame = frame
        self.backingScale = backingScale
    }

    @MainActor init(screen: NSScreen) {
        self.init(displayID: screen.displayID, frame: screen.frame, backingScale: screen.backingScaleFactor)
    }

    nonisolated var pixelSize: CGSize {
        CGSize(width: frame.width * backingScale, height: frame.height * backingScale)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

/// The resolved capture frame for one preset on one display.
nonisolated struct FrameGeometry: Sendable, Equatable {
    let screen: ScreenInfo
    /// Pixels actually captured from the screen: `(W*k, H*k)`, integral.
    let capturePixels: CGSize
    /// Exact preset size the output must have.
    let outputPixels: CGSize
    /// `k`; 1 means pixel-exact.
    let frameScale: CGFloat
    /// AppKit global points, snapped to this display's pixel grid, inside `screen.frame`.
    let pointRect: CGRect

    nonisolated var isPixelExact: Bool { frameScale >= 1 }

    /// Largest scale `k <= 1` at which the preset fits on the screen, or `nil` when the
    /// policy forbids scaling and the preset does not fit.
    nonisolated static func fitScale(preset: Preset, screen: ScreenInfo, policy: FitPolicy) -> CGFloat? {
        let px = screen.pixelSize
        let k = min(1, px.width / CGFloat(preset.width), px.height / CGFloat(preset.height))
        switch policy {
        case .exactOnly: return k >= 1 ? 1 : nil
        case .autoFit: return floor(k * 100) / 100
        }
    }

    /// Centers a frame of `preset` scaled by `k` on `mouse` (plus a nudge in device pixels),
    /// snaps its origin to the pixel grid, and clamps it inside the screen.
    nonisolated static func make(
        preset: Preset,
        mouse: CGPoint,
        nudgePx: CGPoint,
        screen: ScreenInfo,
        frameScale k: CGFloat
    ) -> FrameGeometry {
        let s = screen.backingScale
        let f = screen.frame
        let px = CGSize(
            width: floor(CGFloat(preset.width) * k),
            height: floor(CGFloat(preset.height) * k)
        )
        let size = CGSize(width: px.width / s, height: px.height / s)
        func snap(_ v: CGFloat) -> CGFloat { (v * s).rounded() / s }
        var x = snap(mouse.x - size.width / 2 + nudgePx.x / s)
        var y = snap(mouse.y - size.height / 2 + nudgePx.y / s)
        x = min(max(x, f.minX), f.maxX - size.width)
        y = min(max(y, f.minY), f.maxY - size.height)
        return FrameGeometry(
            screen: screen,
            capturePixels: px,
            outputPixels: preset.pixelSize,
            frameScale: k,
            pointRect: CGRect(x: x, y: y, width: size.width, height: size.height)
        )
    }

    /// Rect in CoreGraphics global display space: origin at the top-left of the primary
    /// display, y down, points. Used by `SCScreenshotManager.captureScreenshot(rect:)`.
    nonisolated func cgGlobalRect(primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: pointRect.minX,
            y: primaryHeight - pointRect.maxY,
            width: pointRect.width,
            height: pointRect.height
        )
    }

    /// Rect in this display's own logical coordinates, top-left origin, points.
    /// Used by `SCStreamConfiguration.sourceRect`.
    nonisolated var displayLocalRect: CGRect {
        CGRect(
            x: pointRect.minX - screen.frame.minX,
            y: screen.frame.maxY - pointRect.maxY,
            width: pointRect.width,
            height: pointRect.height
        )
    }
}
