import AppKit
import SwiftUI

/// Floating Stop button with the elapsed time, shown next to the region while recording.
/// Recordings exclude this app's windows, so it never appears in the result.
final class RecordingControlWindow: NSPanel {
    /// `region` is the recorded rect in AppKit global points; `visibleFrame` is its screen's.
    init(region: CGRect, visibleFrame: CGRect, state: AppState, onStop: @escaping () -> Void) {
        let content = NSHostingView(rootView: RecordingControl(state: state, onStop: onStop))
        let size = content.fittingSize
        let gap: CGFloat = 10

        // Below the region when there is room, else above it, else inside its bottom edge.
        var y = region.minY - gap - size.height
        if y < visibleFrame.minY { y = region.maxY + gap }
        if y + size.height > visibleFrame.maxY { y = region.minY + gap }
        let x = min(max(region.midX - size.width / 2, visibleFrame.minX), visibleFrame.maxX - size.width)

        super.init(
            contentRect: CGRect(origin: CGPoint(x: x, y: y), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RecordingControl: View {
    var state: AppState
    var onStop: () -> Void

    var body: some View {
        Button(action: onStop) {
            HStack(spacing: 7) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.red)
                Text("Stop")
                    .font(.system(size: 13, weight: .semibold))
                Text(state.recordingElapsedLabel)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color.black.opacity(0.8), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Stop recording")
        .fixedSize()
    }
}
