import AppKit

/// Dims the screen and cuts a clear, bordered hole where the capture frame is.
final class OverlayView: NSView {
    private let dim = CAShapeLayer()
    private let border = CAShapeLayer()
    private let cross = CAShapeLayer()
    private let label = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let scale: CGFloat

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

        cross.fillColor = nil
        cross.strokeColor = NSColor.white.withAlphaComponent(0.55).cgColor
        cross.lineWidth = 1 / backingScale

        for sublayer in [dim, border, cross] {
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

    /// `hole` is in this view's coordinates, which equal screen-relative points because the
    /// window frame is the screen frame. Pass `nil` to dim the whole screen with no frame.
    func update(hole: CGRect?, text: String, warning: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole { path.addRect(hole) }
        dim.path = path

        guard let hole else {
            border.path = nil
            cross.path = nil
            label.isHidden = true
            return
        }

        let half = 0.5 / scale
        border.path = CGPath(rect: hole.insetBy(dx: -half, dy: -half), transform: nil)
        border.strokeColor = (warning ? NSColor.systemOrange : NSColor.white).cgColor

        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: hole.midX, y: hole.minY))
        crossPath.addLine(to: CGPoint(x: hole.midX, y: hole.maxY))
        crossPath.move(to: CGPoint(x: hole.minX, y: hole.midY))
        crossPath.addLine(to: CGPoint(x: hole.maxX, y: hole.midY))
        cross.path = crossPath

        label.isHidden = false
        label.stringValue = text
        label.textColor = warning ? .systemOrange : .white
        label.sizeToFit()
        var frame = label.frame
        frame.size.width += 14
        frame.size.height += 6
        frame.origin.x = hole.midX - frame.width / 2
        frame.origin.y = hole.minY - frame.height - 8
        if frame.minY < 8 { frame.origin.y = hole.maxY + 8 }
        frame.origin.x = min(max(frame.minX, 8), bounds.maxX - frame.width - 8)
        label.frame = frame.integral
    }

    /// Shows a centered message (used when a preset cannot fit with the 1:1 policy).
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
