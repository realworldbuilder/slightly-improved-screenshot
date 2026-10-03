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

/// One of the eight resize handles on the capture frame's border.
nonisolated enum FrameHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// How far from the border (in points) a press still counts as grabbing a handle.
    static let tolerance: CGFloat = 8

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        case .top, .right, .bottom, .left: false
        }
    }

    /// Direction this handle moves the frame edge along x: +1 right, -1 left, 0 fixed.
    var dx: CGFloat {
        switch self {
        case .topRight, .right, .bottomRight: 1
        case .topLeft, .left, .bottomLeft: -1
        case .top, .bottom: 0
        }
    }

    /// Direction this handle moves the frame edge along y (AppKit, y up): +1 up, -1 down, 0 fixed.
    var dy: CGFloat {
        switch self {
        case .topLeft, .top, .topRight: 1
        case .bottomLeft, .bottom, .bottomRight: -1
        case .left, .right: 0
        }
    }

    /// Where this handle sits on `rect`: a corner, or the midpoint of an edge.
    func position(in rect: CGRect) -> CGPoint {
        CGPoint(
            x: dx == 0 ? rect.midX : (dx > 0 ? rect.maxX : rect.minX),
            y: dy == 0 ? rect.midY : (dy > 0 ? rect.maxY : rect.minY)
        )
    }

    /// The point that stays fixed while dragging this handle: the opposite corner, or the
    /// midpoint of the opposite edge.
    func anchor(in rect: CGRect) -> CGPoint {
        CGPoint(
            x: dx == 0 ? rect.midX : (dx > 0 ? rect.minX : rect.maxX),
            y: dy == 0 ? rect.midY : (dy > 0 ? rect.minY : rect.maxY)
        )
    }

    /// The handle within `tolerance` points of `rect`'s border under `point`, if any.
    /// Corners win over edges; the interior and the far outside return `nil`.
    static func hit(_ point: CGPoint, in rect: CGRect, tolerance: CGFloat = tolerance) -> FrameHandle? {
        let outer = rect.insetBy(dx: -tolerance, dy: -tolerance)
        guard outer.contains(point) else { return nil }
        let nearLeft = abs(point.x - rect.minX) <= tolerance
        let nearRight = abs(point.x - rect.maxX) <= tolerance
        let nearBottom = abs(point.y - rect.minY) <= tolerance
        let nearTop = abs(point.y - rect.maxY) <= tolerance
        switch (nearLeft, nearRight, nearBottom, nearTop) {
        case (true, _, _, true): return .topLeft
        case (_, true, _, true): return .topRight
        case (true, _, true, _): return .bottomLeft
        case (_, true, true, _): return .bottomRight
        case (true, _, _, _): return .left
        case (_, true, _, _): return .right
        case (_, _, true, _): return .bottom
        case (_, _, _, true): return .top
        default: return nil
        }
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

    nonisolated var isPixelExact: Bool { abs(frameScale - 1) < 0.001 }
    /// The frame is smaller than the preset, so the output has to be enlarged.
    nonisolated var isUpscaled: Bool { frameScale < 1 && !isPixelExact }

    /// Output size for video: `outputPixels` rounded up to even numbers, which H.264 requires.
    nonisolated var videoPixels: CGSize {
        CGSize(width: (outputPixels.width / 2).rounded(.up) * 2, height: (outputPixels.height / 2).rounded(.up) * 2)
    }

    /// Smallest manual scale, so the frame never collapses to nothing.
    static let minimumScale: CGFloat = 0.1

    /// Scales at which the preset fits on the screen, or `nil` when the policy demands 1:1 and
    /// the preset does not fit. The range collapses to `1...1` under `.exactOnly`.
    nonisolated static func scaleLimits(preset: Preset, screen: ScreenInfo, policy: FitPolicy) -> ClosedRange<CGFloat>? {
        let px = screen.pixelSize
        let fit = min(px.width / CGFloat(preset.width), px.height / CGFloat(preset.height))
        let kMax = floor(fit * 100) / 100
        switch policy {
        case .exactOnly: return kMax >= 1 ? 1...1 : nil
        case .autoFit: return min(minimumScale, kMax)...kMax
        }
    }

    /// Device pixels captured for `preset` at scale `k`: `(W*k, H*k)`, floored to whole pixels.
    nonisolated static func capturePixels(preset: Preset, frameScale k: CGFloat) -> CGSize {
        CGSize(width: floor(CGFloat(preset.width) * k), height: floor(CGFloat(preset.height) * k))
    }

    /// Frame size in points for `preset` at scale `k`.
    nonisolated static func pointSize(preset: Preset, screen: ScreenInfo, frameScale k: CGFloat) -> CGSize {
        let px = capturePixels(preset: preset, frameScale: k)
        return CGSize(width: px.width / screen.backingScale, height: px.height / screen.backingScale)
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
        let px = capturePixels(preset: preset, frameScale: k)
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

    /// Scale and center for a frame being resized by `handle`, with `anchor` (the opposite
    /// corner or edge midpoint) held fixed and the preset's aspect ratio preserved.
    ///
    /// Corners project the cursor onto the preset's diagonal, so the frame follows the cursor
    /// smoothly; edges use the cursor's distance along their axis. The result is clamped to
    /// `limits` and to the room between `anchor` and the screen edges, so the anchor never has to move.
    nonisolated static func resize(
        preset: Preset,
        screen: ScreenInfo,
        handle: FrameHandle,
        anchor: CGPoint,
        mouse: CGPoint,
        limits: ClosedRange<CGFloat>
    ) -> (scale: CGFloat, center: CGPoint) {
        let f = screen.frame
        let unit = pointSize(preset: preset, screen: screen, frameScale: 1)
        let w = unit.width, h = unit.height

        let ex = max(0, (mouse.x - anchor.x) * handle.dx)
        let ey = max(0, (mouse.y - anchor.y) * handle.dy)
        var k: CGFloat
        if handle.isCorner {
            k = (ex * w + ey * h) / (w * w + h * h)
        } else if handle.dx != 0 {
            k = ex / w
        } else {
            k = ey / h
        }
        k = min(max(k, limits.lowerBound), limits.upperBound)

        // Room between the anchor and the screen edges, per axis. A fixed axis stays centered
        // on the anchor, so its room is twice the shorter distance to either edge.
        let roomX: CGFloat = switch handle.dx {
        case 1: f.maxX - anchor.x
        case -1: anchor.x - f.minX
        default: 2 * min(anchor.x - f.minX, f.maxX - anchor.x)
        }
        let roomY: CGFloat = switch handle.dy {
        case 1: f.maxY - anchor.y
        case -1: anchor.y - f.minY
        default: 2 * min(anchor.y - f.minY, f.maxY - anchor.y)
        }
        k = min(k, roomX / w, roomY / h)

        let size = pointSize(preset: preset, screen: screen, frameScale: k)
        let center = CGPoint(
            x: anchor.x + handle.dx * size.width / 2,
            y: anchor.y + handle.dy * size.height / 2
        )
        return (k, center)
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
