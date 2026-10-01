import AppKit

/// A borderless, transparent window covering one whole screen (including the menu bar strip).
final class OverlayWindow: NSWindow {
    let screenInfo: ScreenInfo
    let overlayView: OverlayView

    init(screen: NSScreen) {
        screenInfo = ScreenInfo(screen: screen)
        overlayView = OverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            backingScale: screen.backingScaleFactor
        )
        // `contentRect` is in AppKit global coordinates; do not pass `screen:` here.
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        // Above the menu bar and Dock, but one below pop-up menus so the toolbar's
        // Options menu can appear on top of the overlay.
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        hidesOnDeactivate = false
        isExcludedFromWindowsMenu = true
        isMovable = false
        // Hidden from other apps' captures. `-debugShareOverlay YES` on the command line
        // makes it visible to `screencapture` for UI checks.
        sharingType = UserDefaults.standard.bool(forKey: "debugShareOverlay") ? .readOnly : .none
        contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit otherwise shrinks borderless windows to `visibleFrame` (below the menu bar).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
