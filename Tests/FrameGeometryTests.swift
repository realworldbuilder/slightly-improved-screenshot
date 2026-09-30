import Testing
import CoreGraphics
@testable import SlightlyImprovedScreenshot

struct FrameGeometryTests {
    // Built-in 14" MacBook Pro: 1512x982 pt @2x, primary.
    let laptop = ScreenInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), backingScale: 2)
    // External 1920x1080 @1x, placed to the left of and above the primary (negative origin).
    let external = ScreenInfo(displayID: 2, frame: CGRect(x: -1920, y: 300, width: 1920, height: 1080), backingScale: 1)

    @Test func fitScaleIsOneWhenPresetFits() {
        #expect(FrameGeometry.fitScale(preset: .x, screen: laptop, policy: .autoFit) == 1)
        #expect(FrameGeometry.fitScale(preset: .instagramStory, screen: laptop, policy: .autoFit) == 1)
        #expect(FrameGeometry.fitScale(preset: .x, screen: external, policy: .exactOnly) == 1)
    }

    @Test func fitScaleShrinksTallPresetsOnOneXDisplay() {
        // 1080 / 1350 = 0.8, 1080 / 1920 = 0.5625 -> floored to 0.56
        #expect(FrameGeometry.fitScale(preset: .instagramPortrait, screen: external, policy: .autoFit) == 0.8)
        #expect(FrameGeometry.fitScale(preset: .instagramStory, screen: external, policy: .autoFit) == 0.56)
        #expect(FrameGeometry.fitScale(preset: .instagramStory, screen: external, policy: .exactOnly) == nil)
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
