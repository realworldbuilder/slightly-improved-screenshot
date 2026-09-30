import AppKit

/// Runs one interactive frame-placement session across all displays.
///
/// Returns the chosen geometry on click/Return/Space, or `nil` on Esc / right-click / display change.
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var monitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var continuation: CheckedContinuation<FrameGeometry?, Never>?
    private var previousApp: NSRunningApplication?
    private var cursorHidden = false

    private var preset: Preset = .x
    private var policy: FitPolicy = .autoFit
    private var nudgePx: CGPoint = .zero
    private var lastMouse: CGPoint = .zero
    private(set) var geometry: FrameGeometry?

    /// Window numbers of the overlay windows, for the legacy capture path's exclusion list.
    var windowIDs: Set<CGWindowID> { Set(windows.map { CGWindowID($0.windowNumber) }) }

    var isRunning: Bool { continuation != nil }

    func run(preset: Preset, policy: FitPolicy) async -> FrameGeometry? {
        precondition(continuation == nil, "OverlayController session already running")
        self.preset = preset
        self.policy = policy
        nudgePx = .zero
        geometry = nil
        previousApp = NSWorkspace.shared.frontmostApplication

        windows = NSScreen.screens.map(OverlayWindow.init(screen:))
        lastMouse = NSEvent.mouseLocation
        relayout(mouse: lastMouse)

        for window in windows { window.orderFrontRegardless() }
        (windowUnder(lastMouse) ?? windows.first)?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSCursor.hide()
        cursorHidden = true

        installMonitor()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(nil) }
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Hides the overlay so it cannot appear in the capture. Called by the app before capturing.
    func hideWindows() {
        for window in windows { window.orderOut(nil) }
    }

    /// Releases windows and restores focus. Safe to call more than once.
    func tearDown() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }
        previousApp = nil
    }

    // MARK: - Session plumbing

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.isRunning else { return false }
                self.handle(event)
                return true
            }
            return consumed ? nil : event
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            lastMouse = NSEvent.mouseLocation
            relayout(mouse: lastMouse)
        case .leftMouseDown:
            finish(geometry)
        case .rightMouseDown:
            finish(nil)
        case .keyDown:
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            switch event.keyCode {
            case 53: finish(nil)                                   // Esc
            case 36, 49, 76: finish(geometry)                      // Return, Space, Enter
            case 123: nudgePx.x -= step; relayout(mouse: lastMouse) // Left
            case 124: nudgePx.x += step; relayout(mouse: lastMouse) // Right
            case 125: nudgePx.y -= step; relayout(mouse: lastMouse) // Down
            case 126: nudgePx.y += step; relayout(mouse: lastMouse) // Up
            default: break
            }
        default:
            break
        }
    }

    private func finish(_ result: FrameGeometry?) {
        guard let continuation else { return }
        self.continuation = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        if result == nil { tearDown() }
        continuation.resume(returning: result)
    }

    private func windowUnder(_ point: CGPoint) -> OverlayWindow? {
        windows.first { NSMouseInRect(point, $0.screenInfo.frame, false) }
    }

    private func relayout(mouse: CGPoint) {
        let active = windowUnder(mouse) ?? windows.first
        for window in windows {
            guard window === active else {
                window.overlayView.update(hole: nil, text: "", warning: false)
                window.overlayView.showHint(nil)
                continue
            }
            let screen = window.screenInfo
            guard let k = FrameGeometry.fitScale(preset: preset, screen: screen, policy: policy) else {
                geometry = nil
                window.overlayView.update(hole: nil, text: "", warning: false)
                window.overlayView.showHint(
                    "\(preset.displayName) (\(preset.dimensionsLabel) px) does not fit on this display at 1:1. Press Esc or move to another display."
                )
                continue
            }
            let g = FrameGeometry.make(preset: preset, mouse: mouse, nudgePx: nudgePx, screen: screen, frameScale: k)
            geometry = g
            let hole = g.pointRect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
            var text = "\(preset.displayName) · \(preset.dimensionsLabel) px"
            if !g.isPixelExact {
                text += " · frame \(String(format: "%.2f", k))× (upscaled)"
            }
            window.overlayView.showHint(nil)
            window.overlayView.update(hole: hole, text: text, warning: !g.isPixelExact)
            if !window.isKeyWindow { window.makeKey() }
        }
    }
}
