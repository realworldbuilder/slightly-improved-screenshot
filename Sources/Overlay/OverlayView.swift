import AppKit

extension FrameHandle {
    /// System resize cursor for this handle.
    var cursor: NSCursor {
        let position: NSCursor.FrameResizePosition = switch self {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        }
        return .frameResize(position: position, directions: .all)
    }
}

/// Dims the screen, cuts a clear bordered hole where the capture frame is, and hosts the toolbar.
final class OverlayView: NSView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?
    var onRightMouseDown: (() -> Void)?

    private let dim = CAShapeLayer()
    private let border = CAShapeLayer()
    private let handles = CAShapeLayer()
    private let label = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private var toolbar: NSView?
    private var hole: CGRect?
    private var resizable = false
    private let scale: CGFloat

    private static let handleSize: CGFloat = 6

    init(frame: NSRect, backingScale: CGFloat) {
        scale = backingScale
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never

        dim.fillRule = .evenOdd
        dim.fillColor = NSColor.black.withAlphaComponent(0.45).cgColor

        border.fillColor = nil
        border.strokeColor = NSColor.white.cgColor
        border.lineWidth = 1 / backingScale

        handles.fillColor = NSColor.white.cgColor
        handles.strokeColor = NSColor.black.withAlphaComponent(0.6).cgColor
        handles.lineWidth = 1 / backingScale

        for sublayer in [dim, border, handles] {
            sublayer.contentsScale = backingScale
            layer?.addSublayer(sublayer)
        }

        for field in [label, hint] {
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            field.textColor = .white
            field.alignment = .center
            field.wantsLayer = true
            field.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
            field.layer?.cornerRadius = 6
            field.isHidden = true
            addSubview(field)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { onMouseDown?(event) }
    override func mouseDragged(with event: NSEvent) { onMouseDragged?(event) }
    override func mouseUp(with event: NSEvent) { onMouseUp?(event) }
    override func rightMouseDown(with event: NSEvent) { onRightMouseDown?() }

    /// Cursor rects must not overlap, so the frame is split into an interior, four edge bands
    /// (between the corners) and four corner squares.
    override func resetCursorRects() {
        guard let hole else { return }
        guard resizable else {
            addCursorRect(hole, cursor: .openHand)
            return
        }
        let t = FrameHandle.tolerance
        let outer = hole.insetBy(dx: -t, dy: -t)
        let corner = 2 * t

        func add(_ rect: CGRect, _ cursor: NSCursor) {
            let clipped = rect.intersection(bounds)
            guard !clipped.isEmpty else { return }
            addCursorRect(clipped, cursor: cursor)
        }

        add(hole.insetBy(dx: t, dy: t), .openHand)

        add(CGRect(x: outer.minX, y: outer.maxY - corner, width: corner, height: corner), FrameHandle.topLeft.cursor)
        add(CGRect(x: outer.maxX - corner, y: outer.maxY - corner, width: corner, height: corner), FrameHandle.topRight.cursor)
        add(CGRect(x: outer.minX, y: outer.minY, width: corner, height: corner), FrameHandle.bottomLeft.cursor)
        add(CGRect(x: outer.maxX - corner, y: outer.minY, width: corner, height: corner), FrameHandle.bottomRight.cursor)

        let bandW = outer.width - 2 * corner
        let bandH = outer.height - 2 * corner
        add(CGRect(x: outer.minX + corner, y: outer.maxY - corner, width: bandW, height: corner), FrameHandle.top.cursor)
        add(CGRect(x: outer.minX + corner, y: outer.minY, width: bandW, height: corner), FrameHandle.bottom.cursor)
        add(CGRect(x: outer.minX, y: outer.minY + corner, width: corner, height: bandH), FrameHandle.left.cursor)
        add(CGRect(x: outer.maxX - corner, y: outer.minY + corner, width: corner, height: bandH), FrameHandle.right.cursor)
    }

    /// Pins the toolbar to the bottom center of the screen, `bottomInset` points above the edge.
    func installToolbar(_ view: NSView, bottomInset: CGFloat) {
        toolbar = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: centerXAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset),
        ])
    }

    func setToolbarVisible(_ visible: Bool) {
        toolbar?.isHidden = !visible
    }

    /// `hole` is in this view's coordinates, which equal screen-relative points because the
    /// window frame is the screen frame. Pass `nil` to dim the whole screen with no frame.
    /// `resizable` draws the eight handles and enables the resize cursors.
    func update(hole: CGRect?, text: String, warning: Bool, resizable: Bool = false) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        self.hole = hole
        self.resizable = resizable
        window?.invalidateCursorRects(for: self)

        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole { path.addRect(hole) }
        dim.path = path

        guard let hole else {
            border.path = nil
            handles.path = nil
            label.isHidden = true
            return
        }

        let accent = warning ? NSColor.systemOrange : NSColor.white
        let half = 0.5 / scale
        border.path = CGPath(rect: hole.insetBy(dx: -half, dy: -half), transform: nil)
        border.strokeColor = accent.cgColor

        if resizable {
            let size = Self.handleSize
            let handlePath = CGMutablePath()
            for handle in FrameHandle.allCases {
                let p = handle.position(in: hole)
                let rect = CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
                handlePath.addRect(rect.insetBy(dx: half, dy: half))
            }
            handles.path = handlePath
            handles.fillColor = accent.cgColor
        } else {
            handles.path = nil
        }

        label.isHidden = false
        label.stringValue = text
        label.textColor = warning ? .systemOrange : .white
        label.sizeToFit()
        var frame = label.frame
        frame.size.width += 14
        frame.size.height += 6
        frame.origin.x = hole.midX - frame.width / 2
        // Prefer above the frame so the label stays clear of the toolbar at the bottom.
        frame.origin.y = hole.maxY + 8
        if frame.maxY > bounds.maxY - 30 { frame.origin.y = hole.maxY - frame.height - 8 }
        frame.origin.x = min(max(frame.minX, 8), bounds.maxX - frame.width - 8)
        label.frame = frame.integral
    }

    /// Shows a centered message (used when a preset cannot fit with the exact-pixels policy).
    func showHint(_ text: String?) {
        guard let text else {
            hint.isHidden = true
            return
        }
        hint.isHidden = false
        hint.stringValue = text
        hint.sizeToFit()
        var frame = hint.frame
        frame.size.width += 20
        frame.size.height += 10
        frame.origin.x = bounds.midX - frame.width / 2
        frame.origin.y = bounds.midY - frame.height / 2
        hint.frame = frame.integral
    }
}
