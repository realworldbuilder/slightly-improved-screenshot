import AppKit

/// A click-through outline just outside the capture region, shown while the timer counts
/// down and while a recording is running. Recordings exclude this app's windows, so it never
/// appears in the result.
final class RegionIndicatorWindow: NSWindow {
    private static let outset: CGFloat = 3
    private let countdown = NSTextField(labelWithString: "")

    /// `rect` is the capture region in AppKit global points.
    init(rect: CGRect) {
        let frame = rect.insetBy(dx: -Self.outset, dy: -Self.outset)
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        isExcludedFromWindowsMenu = true

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.borderWidth = 2
        view.layer?.borderColor = NSColor.white.cgColor
        contentView = view

        countdown.font = .monospacedDigitSystemFont(ofSize: 96, weight: .bold)
        countdown.textColor = .white
        countdown.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
            shadow.shadowBlurRadius = 12
            return shadow
        }()
        countdown.isHidden = true
        countdown.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countdown)
        NSLayoutConstraint.activate([
            countdown.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdown.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// Shows the seconds remaining in the middle of the region, or hides the number with `nil`.
    func setCountdown(_ seconds: Int?) {
        countdown.isHidden = seconds == nil
        countdown.stringValue = seconds.map(String.init) ?? ""
    }

    /// Turns the outline red while recording.
    func setRecording(_ recording: Bool) {
        contentView?.layer?.borderColor = (recording ? NSColor.systemRed : NSColor.white).cgColor
    }
}
