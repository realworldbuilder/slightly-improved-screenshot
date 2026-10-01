import Observation
import SwiftUI

/// Per-session UI state shared by the toolbars on every display.
@Observable
final class OverlaySessionModel {
    var canCapture = true
}

/// Floating toolbar modeled on the macOS Screenshot app: close, preset buttons, Options, Capture.
struct CaptureToolbar: View {
    @Bindable var state: AppState
    var session: OverlaySessionModel
    var onChange: () -> Void
    var onCapture: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Cancel (Esc)")

            Divider().frame(height: 34)

            HStack(spacing: 2) {
                ForEach(Array(Preset.allCases.enumerated()), id: \.element) { index, preset in
                    PresetButton(preset: preset, isSelected: state.selectedPreset == preset) {
                        state.selectedPreset = preset
                    }
                    .help("\(preset.displayName), \(preset.dimensionsLabel) px (press \(index + 1))")
                }
            }

            Divider().frame(height: 34)

            Menu {
                Section("Save to") {
                    Toggle("Downloads", isOn: $state.saveToDownloads)
                    Toggle("Clipboard", isOn: $state.copyToClipboard)
                }
                Section("If a size doesn't fit this display") {
                    Picker("Fit", selection: $state.fitPolicy) {
                        Text("Scale frame to fit").tag(FitPolicy.autoFit)
                        Text("Exact pixels only").tag(FitPolicy.exactOnly)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Options")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 6)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()

            // Styled by hand so it looks the same whether or not the overlay window is key.
            Button(action: onCapture) {
                Text("Capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(Color.white, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(session.canCapture ? 1 : 0.4)
            .disabled(!session.canCapture)
            .help("Capture (Return)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        // Dark backing keeps the white labels legible over bright content; glass sits behind it.
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .environment(\.colorScheme, .dark)
        .onChange(of: state.selectedPreset) { onChange() }
        .onChange(of: state.fitPolicy) { onChange() }
        .fixedSize()
    }
}

private struct PresetButton: View {
    let preset: Preset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(lineWidth: 1.5)
                    .aspectRatio(CGFloat(preset.width) / CGFloat(preset.height), contentMode: .fit)
                    .frame(width: 26, height: 22)
                Text(preset.shortName)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(width: 56, height: 46)
            .background(
                isSelected ? Color.white.opacity(0.22) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
