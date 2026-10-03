import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section("Capture") {
                Picker("Default preset", selection: $state.selectedPreset) {
                    ForEach(Preset.allCases) { preset in
                        Text("\(preset.displayName)  (\(preset.dimensionsLabel))").tag(preset)
                    }
                }
                KeyboardShortcuts.Recorder("Capture shortcut", name: .capture)
                Picker("When a preset does not fit", selection: $state.fitPolicy) {
                    ForEach(FitPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Output") {
                Toggle("Copy to clipboard", isOn: $state.copyToClipboard)
                Toggle("Save to Downloads", isOn: $state.saveToDownloads)
            }

            Section("Recording") {
                Picker("Microphone", selection: $state.microphoneID) {
                    Text("None").tag("")
                    ForEach(Microphone.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                Toggle("Record system audio", isOn: $state.recordSystemAudio)
                Toggle("Show mouse pointer", isOn: $state.showPointerInVideos)
                Toggle("Show mouse clicks", isOn: $state.showMouseClicks)
            }

            Section("Permissions") {
                LabeledContent("Screen Recording") {
                    HStack {
                        Image(systemName: state.hasScreenRecordingAccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(state.hasScreenRecordingAccess ? .green : .red)
                        Text(state.hasScreenRecordingAccess ? "Granted" : "Not granted")
                        Button("Open System Settings") { ScreenCapturePermission.openSystemSettings() }
                    }
                }
            }

            Section("Advanced") {
                Toggle("Use legacy capture path (ScreenCaptureKit filter)", isOn: $state.useLegacyCapture)
                Text("Try this if captures come out offset or the wrong size.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NSApp.activate()
            state.refreshPermission()
        }
    }
}
