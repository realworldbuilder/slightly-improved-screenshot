import Testing
import CoreGraphics
@testable import SlightlyImprovedScreenshot

struct FrameGeometryTests {
    // Built-in 14" MacBook Pro: 1512x982 pt @2x, primary.
    let laptop = ScreenInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), backingScale: 2)
    // External 1920x1080 @1x, placed to the left of and above the primary (negative origin).
    let external = ScreenInfo(displayID: 2, frame: CGRect(x: -1920, y: 300, width: 1920, height: 1080), backingScale: 1)

    @Test func scaleLimitsReachAboveOneWhenPresetFits() {
        // 3024x1964 px: 3024 / 1600 = 1.89, 1964 / 900 = 2.18 -> 1.89
        #expect(FrameGeometry.scaleLimits(preset: .x, screen: laptop, policy: .autoFit) == 0.1...1.89)
        // 1964 / 1920 = 1.0229 -> 1.02
        #expect(FrameGeometry.scaleLimits(preset: .instagramStory, screen: laptop, policy: .autoFit) == 0.1...1.02)
        #expect(FrameGeometry.scaleLimits(preset: .x, screen: external, policy: .exactOnly) == 1...1)
    }

    @Test func scaleLimitsShrinkTallPresetsOnOneXDisplay() {
        // 1080 / 1350 = 0.8, 1080 / 1920 = 0.5625 -> floored to 0.56
        #expect(FrameGeometry.scaleLimits(preset: .instagramPortrait, screen: external, policy: .autoFit) == 0.1...0.8)
        #expect(FrameGeometry.scaleLimits(preset: .instagramStory, screen: external, policy: .autoFit) == 0.1...0.56)
        #expect(FrameGeometry.scaleLimits(preset: .instagramStory, screen: external, policy: .exactOnly) == nil)
    }

    @Test func scaleAboveOneDownscales() {
        let g = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 700, y: 500), nudgePx: .zero, screen: laptop, frameScale: 1.5)
        #expect(g.capturePixels == CGSize(width: 2400, height: 1350))
        #expect(g.pointRect.size == CGSize(width: 1200, height: 675))
        #expect(g.outputPixels == CGSize(width: 1600, height: 900))
        #expect(!g.isPixelExact)
        #expect(!g.isUpscaled)
    }

    // MARK: - Handles

    let rect = CGRect(x: 100, y: 100, width: 800, height: 450)

    @Test func cornerHitWinsOverEdgeAndInteriorMissesHandles() {
        #expect(FrameHandle.hit(CGPoint(x: 100, y: 550), in: rect, tolerance: 8) == .topLeft)
        #expect(FrameHandle.hit(CGPoint(x: 905, y: 105), in: rect, tolerance: 8) == .bottomRight)
        #expect(FrameHandle.hit(CGPoint(x: 894, y: 544), in: rect, tolerance: 8) == .topRight)
        #expect(FrameHandle.hit(CGPoint(x: 500, y: 550), in: rect, tolerance: 8) == .top)
        #expect(FrameHandle.hit(CGPoint(x: 500, y: 97), in: rect, tolerance: 8) == .bottom)
        #expect(FrameHandle.hit(CGPoint(x: 104, y: 300), in: rect, tolerance: 8) == .left)
        #expect(FrameHandle.hit(CGPoint(x: 907, y: 300), in: rect, tolerance: 8) == .right)
        #expect(FrameHandle.hit(CGPoint(x: 500, y: 300), in: rect, tolerance: 8) == nil)
        #expect(FrameHandle.hit(CGPoint(x: 120, y: 120), in: rect, tolerance: 8) == nil)
        #expect(FrameHandle.hit(CGPoint(x: 950, y: 300), in: rect, tolerance: 8) == nil)
    }

    @Test func anchorIsOppositeCornerOrEdgeMidpoint() {
        #expect(FrameHandle.bottomRight.anchor(in: rect) == CGPoint(x: 100, y: 550))
        #expect(FrameHandle.topLeft.anchor(in: rect) == CGPoint(x: 900, y: 100))
        #expect(FrameHandle.right.anchor(in: rect) == CGPoint(x: 100, y: 325))
        #expect(FrameHandle.top.anchor(in: rect) == CGPoint(x: 500, y: 100))
        #expect(FrameHandle.bottomRight.position(in: rect) == CGPoint(x: 900, y: 100))
    }

    // MARK: - Resize

    let limits: ClosedRange<CGFloat> = 0.1...1.89

    @Test func cornerResizeKeepsAnchorAndAspectRatio() {
        // Frame at 1:1 is 800x450 pt; its top-left corner is held while the bottom-right is pulled.
        let anchor = CGPoint(x: 100, y: 900)
        let r = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .bottomRight,
            anchor: anchor, mouse: CGPoint(x: 100 + 400, y: 900 - 225), limits: limits
        )
        #expect(abs(r.scale - 0.5) < 0.001)
        let g = FrameGeometry.make(preset: .x, mouse: r.center, nudgePx: .zero, screen: laptop, frameScale: r.scale)
        #expect(abs(g.pointRect.minX - anchor.x) <= 0.5)
        #expect(abs(g.pointRect.maxY - anchor.y) <= 0.5)
        #expect(abs(g.capturePixels.width / g.capturePixels.height - 16.0 / 9.0) < 0.01)

        // Pulling further out grows the frame; the cursor's off-diagonal component is projected away.
        let bigger = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .bottomRight,
            anchor: anchor, mouse: CGPoint(x: 100 + 1000, y: 900 - 100), limits: limits
        )
        #expect(bigger.scale > r.scale)
        #expect(bigger.scale <= limits.upperBound)
    }

    @Test func edgeResizeStaysCenteredOnOtherAxis() {
        let anchor = CGPoint(x: 100, y: 500)
        let r = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .right,
            anchor: anchor, mouse: CGPoint(x: 100 + 600, y: 777), limits: limits
        )
        #expect(abs(r.scale - 0.75) < 0.001)
        #expect(r.center.y == anchor.y)
        #expect(abs(r.center.x - (anchor.x + 300)) <= 0.5)

        let top = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .top,
            anchor: CGPoint(x: 700, y: 100), mouse: CGPoint(x: 0, y: 100 + 225), limits: limits
        )
        #expect(abs(top.scale - 0.5) < 0.001)
        #expect(top.center.x == 700)
    }

    @Test func resizeIsClampedToLimitsAndScreenRoom() {
        // Past the anchor: smallest allowed scale.
        let tiny = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .bottomRight,
            anchor: CGPoint(x: 100, y: 900), mouse: CGPoint(x: 0, y: 982), limits: limits
        )
        #expect(tiny.scale == limits.lowerBound)

        // Past the screen edge: frame ends exactly at the edge, anchor unmoved.
        let anchor = CGPoint(x: 1000, y: 900)
        let edge = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .bottomRight,
            anchor: anchor, mouse: CGPoint(x: 5000, y: -5000), limits: limits
        )
        let g = FrameGeometry.make(preset: .x, mouse: edge.center, nudgePx: .zero, screen: laptop, frameScale: edge.scale)
        #expect(g.pointRect.minX == anchor.x)
        #expect(g.pointRect.maxY == anchor.y)
        #expect(g.pointRect.maxX <= laptop.frame.maxX)
        #expect(g.pointRect.maxX > laptop.frame.maxX - 1)

        // Edge drag near the top: room on the centered axis is twice the distance to the nearer edge.
        let nearTop = FrameGeometry.resize(
            preset: .x, screen: laptop, handle: .right,
            anchor: CGPoint(x: 0, y: 982 - 100), mouse: CGPoint(x: 1500, y: 0), limits: limits
        )
        let gTop = FrameGeometry.make(preset: .x, mouse: nearTop.center, nudgePx: .zero, screen: laptop, frameScale: nearTop.scale)
        #expect(gTop.pointRect.maxY <= laptop.frame.maxY)
        #expect(gTop.pointRect.height <= 200)
        #expect(gTop.pointRect.height > 198)
    }

    @Test func frameSizeInPointsIsPixelsOverScale() {
        let g = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 700, y: 500), nudgePx: .zero, screen: laptop, frameScale: 1)
        #expect(g.pointRect.size == CGSize(width: 800, height: 450))
        #expect(g.capturePixels == CGSize(width: 1600, height: 900))
        #expect(g.outputPixels == CGSize(width: 1600, height: 900))
        #expect(g.isPixelExact)
    }

    @Test func originSnapsToDevicePixelGrid() {
        let g = FrameGeometry.make(preset: .linkedIn, mouse: CGPoint(x: 700.37, y: 500.12), nudgePx: .zero, screen: laptop, frameScale: 1)
        // At 2x, every coordinate must be a multiple of 0.5 pt.
        #expect((g.pointRect.minX * 2).rounded() == g.pointRect.minX * 2)
        #expect((g.pointRect.minY * 2).rounded() == g.pointRect.minY * 2)
        #expect(g.pointRect.size == CGSize(width: 600, height: 313.5))
    }

    @Test func frameIsClampedInsideScreen() {
        let g = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 10, y: 5), nudgePx: .zero, screen: laptop, frameScale: 1)
        #expect(g.pointRect.origin == .zero)
        let far = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 5000, y: 5000), nudgePx: .zero, screen: laptop, frameScale: 1)
        #expect(far.pointRect.maxX == 1512)
        #expect(far.pointRect.maxY == 982)
    }

    @Test func nudgeMovesByDevicePixels() {
        let base = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 700, y: 500), nudgePx: .zero, screen: laptop, frameScale: 1)
        let nudged = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 700, y: 500), nudgePx: CGPoint(x: 3, y: -10), screen: laptop, frameScale: 1)
        #expect(nudged.pointRect.minX - base.pointRect.minX == 1.5)
        #expect(nudged.pointRect.minY - base.pointRect.minY == -5)
    }

    @Test func autoFitCapturesFewerPixelsButKeepsOutputSize() {
        let g = FrameGeometry.make(preset: .instagramStory, mouse: CGPoint(x: -960, y: 840), nudgePx: .zero, screen: external, frameScale: 0.56)
        #expect(g.capturePixels == CGSize(width: 604, height: 1075))
        #expect(g.outputPixels == CGSize(width: 1080, height: 1920))
        #expect(!g.isPixelExact)
        #expect(g.pointRect.minY >= external.frame.minY && g.pointRect.maxY <= external.frame.maxY)
    }

    @Test func cgGlobalRectFlipsAboutPrimaryHeight() {
        let g = FrameGeometry.make(preset: .x, mouse: CGPoint(x: 700, y: 500), nudgePx: .zero, screen: laptop, frameScale: 1)
        let cg = g.cgGlobalRect(primaryHeight: 982)
        #expect(cg.minX == g.pointRect.minX)
        #expect(cg.minY == 982 - g.pointRect.maxY)
        #expect(cg.size == g.pointRect.size)
    }

    @Test func displayLocalRectOnSecondaryScreenWithNegativeOrigin() {
        // Frame flush with the external display's top-left corner.
        let g = FrameGeometry.make(preset: .x, mouse: CGPoint(x: -1920, y: 1380), nudgePx: .zero, screen: external, frameScale: 1)
        #expect(g.pointRect.origin == CGPoint(x: -1920, y: 1380 - 900))
        #expect(g.displayLocalRect == CGRect(x: 0, y: 0, width: 1600, height: 900))

        // And the CG global rect for that same frame: primary height is 982.
        let cg = g.cgGlobalRect(primaryHeight: 982)
        #expect(cg.origin == CGPoint(x: -1920, y: 982 - 1380))
    }
}
