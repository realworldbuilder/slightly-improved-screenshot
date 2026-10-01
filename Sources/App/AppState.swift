import AppKit
import Observation

@Observable
final class AppState {
    static let shared = AppState()

    let store = PresetStore()

    var selectedPreset: Preset {
        didSet { store.selectedPreset = selectedPreset }
    }
    var fitPolicy: FitPolicy {
        didSet { store.fitPolicy = fitPolicy }
    }
    var copyToClipboard: Bool {
        didSet { store.copyToClipboard = copyToClipboard }
    }
    var saveToDownloads: Bool {
        didSet { store.saveToDownloads = saveToDownloads }
    }
    var useLegacyCapture: Bool {
        didSet { store.useLegacyCapture = useLegacyCapture }
    }
    private(set) var lastFileURL: URL? {
        didSet { store.lastFileURL = lastFileURL }
    }

    private(set) var isCapturing = false
    private(set) var statusSymbol = "camera.viewfinder"
    private(set) var hasScreenRecordingAccess = ScreenCapturePermission.preflight()

    private let overlay = OverlayController()
    private var feedbackTask: Task<Void, Never>?

    init() {
        selectedPreset = store.selectedPreset
        fitPolicy = store.fitPolicy
        copyToClipboard = store.copyToClipboard
        saveToDownloads = store.saveToDownloads
        useLegacyCapture = store.useLegacyCapture
        lastFileURL = store.lastFileURL
    }

    func refreshPermission() {
        hasScreenRecordingAccess = ScreenCapturePermission.preflight()
    }

    func requestPermission() {
        ScreenCapturePermission.request()
        refreshPermission()
    }

    /// Hotkey / menu entry point. Ignores re-entrant calls while a session is active.
    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        Task { await runCapture() }
    }

    func capture(preset: Preset) {
        selectedPreset = preset
        startCapture()
    }

    func revealLastScreenshot() {
        guard let lastFileURL, FileManager.default.fileExists(atPath: lastFileURL.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastFileURL])
    }

    // MARK: - Pipeline

    private func runCapture() async {
        defer { isCapturing = false }

        refreshPermission()
        if !hasScreenRecordingAccess {
            ScreenCapturePermission.request()
            refreshPermission()
            guard hasScreenRecordingAccess else {
                NSLog("Capture aborted: Screen Recording access not granted")
                presentError(CaptureError.permissionDenied)
                return
            }
        }

        NSLog("Capture session started: \(selectedPreset.rawValue), policy \(fitPolicy.rawValue)")
        guard let geometry = await overlay.run(state: self) else {
            NSLog("Capture session cancelled")
            return
        }
        NSLog("Frame chosen: \(geometry.pointRect) on display \(geometry.screen.displayID), capture \(geometry.capturePixels), scale \(geometry.frameScale)")

        // Hide the overlay and let the window server composite a frame without it.
        overlay.hideWindows()
        try? await Task.sleep(for: .milliseconds(80))

        let capturer: any ScreenCapturing = useLegacyCapture
            ? FilterScreenshotCapturer(excludedWindowIDs: overlay.windowIDs)
            : RectScreenshotCapturer()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let preset = selectedPreset
        let wantsClipboard = copyToClipboard
        let wantsFile = saveToDownloads

        do {
            let raw = try await capturer.capture(geometry, primaryHeight: primaryHeight)
            let expected = geometry.capturePixels
            if CGFloat(raw.width) != expected.width || CGFloat(raw.height) != expected.height {
                NSLog("Capture returned \(raw.width)x\(raw.height), expected \(Int(expected.width))x\(Int(expected.height)); normalizing")
            }

            let outputSize = geometry.outputPixels
            let (image, png) = try await Task.detached(priority: .userInitiated) {
                let image = try ImageNormalizer.normalize(raw, to: outputSize)
                let png = try OutputService.pngData(image)
                return (image, png)
            }.value

            overlay.tearDown()

            if wantsClipboard {
                OutputService.copyToPasteboard(png: png, image: image)
            }
            if wantsFile {
                let url = OutputService.downloadsURL(preset: preset)
                try OutputService.write(png: png, to: url)
                lastFileURL = url
            }
            NSLog("Capture finished: \(image.width)x\(image.height), file \(lastFileURL?.lastPathComponent ?? "none")")
            showFeedback("checkmark.circle")
        } catch {
            NSLog("Capture failed: \(error)")
            overlay.tearDown()
            presentError(error)
        }
    }

    private func showFeedback(_ symbol: String) {
        feedbackTask?.cancel()
        statusSymbol = symbol
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            statusSymbol = "camera.viewfinder"
        }
    }

    private func presentError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screenshot failed"
        alert.informativeText = error.localizedDescription
        if case CaptureError.permissionDenied = error {
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                ScreenCapturePermission.openSystemSettings()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
