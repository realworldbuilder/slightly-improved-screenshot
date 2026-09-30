import SwiftUI

@main
struct SlightlyImprovedScreenshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.statusSymbol)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(state: state)
        }
    }
}

private struct MenuContent: View {
    @Bindable var state: AppState

    var body: some View {
        let shortcut = HotkeyManager.captureShortcutDescription
        Button(shortcut.isEmpty ? "Capture \(state.selectedPreset.displayName)" : "Capture \(state.selectedPreset.displayName)   \(shortcut)") {
            state.startCapture()
        }
        .disabled(state.isCapturing)

        Divider()

        Picker("Preset", selection: $state.selectedPreset) {
            ForEach(Preset.allCases) { preset in
                Text("\(preset.displayName)  \(preset.dimensionsLabel)").tag(preset)
            }
        }
        .pickerStyle(.inline)

        Divider()

        Button("Reveal Last Screenshot") { state.revealLastScreenshot() }
            .disabled(state.lastFileURL == nil)

        if !state.hasScreenRecordingAccess {
            Button("Grant Screen Recording Access…") {
                state.requestPermission()
                ScreenCapturePermission.openSystemSettings()
            }
        }

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Slightly Improved Screenshot") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
