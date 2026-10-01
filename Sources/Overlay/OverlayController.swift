import AppKit
import SwiftUI

/// Runs one interactive capture session across all displays, in the style of the macOS
/// Screenshot app: a fixed-size frame the user drags into place, and a floating toolbar
/// for picking the preset, changing options, and capturing.
///
/// Returns the chosen geometry on Capture / Return / double-click, or `nil` on cancel.
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var continuation: CheckedContinuation<FrameGeometry?, Never>?
    private var previousApp: NSRunningApplication?
    private weak var state: AppState?
    private let session = OverlaySessionModel()

    private var activeDisplayID: CGDirectDisplayID = 0
    /// Frame center in AppKit global points. Remembered between sessions, like the Screenshot app.
    private var center: CGPoint?
    private var dragOffset: CGPoint = .zero
    private(set) var geometry: FrameGeometry?

    /// Window numbers of the overlay windows, for the legacy capture path's exclusion list.
    var windowIDs: Set<CGWindowID> { Set(windows.map { CGWindowID($0.windowNumber) }) }

    var isRunning: Bool { continuation != nil }

    func run(state: AppState) async -> FrameGeometry? {
        precondition(continuation == nil, "OverlayController session already running")
        self.state = state
        geometry = nil
        previousApp = NSWorkspace.shared.frontmostApplication

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            let view = window.overlayView
            let toolbar = CaptureToolbar(
                state: state,
                session: session,
                onChange: { [weak self] in self?.relayout() },
                onCapture: { [weak self] in self?.capture() },
                onCancel: { [weak self] in self?.finish(nil) }
            )
            // Sit a little above the Dock (or the screen edge when the Dock is elsewhere).
            let dockInset = screen.visibleFrame.minY - screen.frame.minY
            view.installToolbar(NSHostingView(rootView: toolbar), bottomInset: dockInset + 28)
            view.onMouseDown = { [weak self] event in self?.mouseDown(event) }
            view.onMouseDragged = { [weak self] _ in self?.mouseDragged() }
            view.onMouseUp = { [weak self] _ in self?.mouseUp() }
            view.onRightMouseDown = { [weak self] in self?.finish(nil) }
            return window
        }

        // Start where the frame was last time if that is on the display the user is working
        // on; otherwise in the middle of that display.
        let mouseWindow = windowUnder(NSEvent.mouseLocation) ?? windows.first
        if let center, let remembered = windowUnder(center), remembered === mouseWindow {
            activeDisplayID = remembered.screenInfo.displayID
        } else if let mouseWindow {
            activeDisplayID = mouseWindow.screenInfo.displayID
            center = CGPoint(x: mouseWindow.screenInfo.frame.midX, y: mouseWindow.screenInfo.frame.midY)
        }
        relayout()

        for window in windows { window.orderFrontRegardless() }
        activeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.isRunning else { return false }
                return self.handleKey(event)
            }
            return consumed ? nil : event
        }
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
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }
        previousApp = nil
    }

    // MARK: - Input

    private func mouseDown(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        guard let window = windowUnder(point) else { return }
        let onActiveDisplay = window.screenInfo.displayID == activeDisplayID

        if onActiveDisplay, let geometry, geometry.pointRect.contains(point), let center {
            if event.clickCount >= 2 {
                capture()
                return
            }
            dragOffset = CGPoint(x: center.x - point.x, y: center.y - point.y)
        } else {
            // Clicking outside the frame (or on another display) brings the frame there.
            activeDisplayID = window.screenInfo.displayID
            center = point
            dragOffset = .zero
            window.makeKey()
        }
        NSCursor.closedHand.set()
        relayout()
    }

    private func mouseDragged() {
        let point = NSEvent.mouseLocation
        if let window = windowUnder(point), window.screenInfo.displayID != activeDisplayID {
            activeDisplayID = window.screenInfo.displayID
            window.makeKey()
        }
        center = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
        relayout()
    }

    private func mouseUp() {
        if let view = activeWindow?.overlayView {
            view.window?.invalidateCursorRects(for: view)
        }
    }

    /// Returns true when the key was handled and should not reach the responder chain.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 53: finish(nil)                    // Esc
        case 36, 76: capture()                  // Return, Enter
        case 123: nudge(dx: -step, dy: 0)       // Left
        case 124: nudge(dx: step, dy: 0)        // Right
        case 125: nudge(dx: 0, dy: -step)       // Down
        case 126: nudge(dx: 0, dy: step)        // Up
        default:
            // 1...6 pick a preset.
            guard let characters = event.charactersIgnoringModifiers, let number = Int(characters),
                  Preset.allCases.indices.contains(number - 1)
            else { return false }
            state?.selectedPreset = Preset.allCases[number - 1]
            relayout()
        }
        return true
    }

    private func nudge(dx: CGFloat, dy: CGFloat) {
        guard let center, let scale = activeWindow?.screenInfo.backingScale else { return }
        self.center = CGPoint(x: center.x + dx / scale, y: center.y + dy / scale)
        relayout()
    }

    private func capture() {
        guard let geometry else {
            NSSound.beep()
            return
        }
        finish(geometry)
    }

    // MARK: - Session plumbing

    private func finish(_ result: FrameGeometry?) {
        guard let continuation else { return }
        self.continuation = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        if result == nil { tearDown() }
        continuation.resume(returning: result)
    }

    private var activeWindow: OverlayWindow? {
        windows.first { $0.screenInfo.displayID == activeDisplayID } ?? windows.first
    }

    private func windowUnder(_ point: CGPoint) -> OverlayWindow? {
        windows.first { NSMouseInRect(point, $0.screenInfo.frame, false) }
    }

    /// Recomputes the frame for the current preset, policy, and center, and redraws every display.
    private func relayout() {
        guard let state, let center else { return }
        let preset = state.selectedPreset
        let active = activeWindow

        for window in windows {
            let view = window.overlayView
            view.setToolbarVisible(window === active)
            guard window === active else {
                view.update(hole: nil, text: "", warning: false)
                view.showHint(nil)
                continue
            }

            let screen = window.screenInfo
            guard let k = FrameGeometry.fitScale(preset: preset, screen: screen, policy: state.fitPolicy) else {
                geometry = nil
                session.canCapture = false
                view.update(hole: nil, text: "", warning: false)
                view.showHint(
                    "\(preset.displayName) (\(preset.dimensionsLabel) px) is larger than this display. Pick another size, or choose Options › Scale frame to fit."
                )
                continue
            }

            let g = FrameGeometry.make(preset: preset, mouse: center, nudgePx: .zero, screen: screen, frameScale: k)
            geometry = g
            session.canCapture = true
            // Keep the clamped position so nudges at a screen edge do not accumulate.
            self.center = CGPoint(x: g.pointRect.midX, y: g.pointRect.midY)

            var text = "\(preset.displayName) · \(preset.dimensionsLabel) px"
            if !g.isPixelExact {
                text += " · frame \(String(format: "%.2f", k))× (upscaled)"
            }
            view.showHint(nil)
            view.update(
                hole: g.pointRect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY),
                text: text,
                warning: !g.isPixelExact
            )
        }
    }
}
