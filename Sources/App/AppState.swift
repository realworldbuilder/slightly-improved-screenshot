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
    var captureMode: CaptureMode {
        didSet { store.captureMode = captureMode }
    }
    /// Delay before capturing, in seconds. `0` is off.
    var timerSeconds: Int {
        didSet { store.timerSeconds = timerSeconds }
    }
    var showPointerInPhotos: Bool {
        didSet { store.showPointerInPhotos = showPointerInPhotos }
    }
    var showPointerInVideos: Bool {
        didSet { store.showPointerInVideos = showPointerInVideos }
    }
    var showMouseClicks: Bool {
        didSet { store.showMouseClicks = showMouseClicks }
    }
    var recordSystemAudio: Bool {
        didSet { store.recordSystemAudio = recordSystemAudio }
    }
    /// `AVCaptureDevice.uniqueID` of the microphone to record, or empty for none.
    var microphoneID: String {
        didSet { store.microphoneID = microphoneID }
    }
    private(set) var lastFileURL: URL? {
        didSet { store.lastFileURL = lastFileURL }
    }

    private(set) var isCapturing = false
    private(set) var isRecording = false
    private(set) var recordingSeconds = 0
    private(set) var statusSymbol = "camera.viewfinder"
    private(set) var hasScreenRecordingAccess = ScreenCapturePermission.preflight()

    private let overlay = OverlayController()
    private let recorder = ScreenRecorder()
    private var feedbackTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var isCountingDown = false

    init() {
        selectedPreset = store.selectedPreset
        fitPolicy = store.fitPolicy
        copyToClipboard = store.copyToClipboard
        saveToDownloads = store.saveToDownloads
        useLegacyCapture = store.useLegacyCapture
        captureMode = store.captureMode
        timerSeconds = store.timerSeconds
        showPointerInPhotos = store.showPointerInPhotos
        showPointerInVideos = store.showPointerInVideos
        showMouseClicks = store.showMouseClicks
        recordSystemAudio = store.recordSystemAudio
        microphoneID = store.microphoneID
        lastFileURL = store.lastFileURL
    }

    /// Elapsed recording time as `m:ss`, for the menu bar.
    var recordingElapsedLabel: String {
        String(format: "%d:%02d", recordingSeconds / 60, recordingSeconds % 60)
    }

    func refreshPermission() {
        hasScreenRecordingAccess = ScreenCapturePermission.preflight()
    }

    func requestPermission() {
        ScreenCapturePermission.request()
        refreshPermission()
    }

    /// Hotkey / menu entry point. Stops a running recording, cancels a running timer, and
    /// otherwise ignores re-entrant calls while a session is active.
    func startCapture() {
        if isRecording {
            stopRecording()
            return
        }
        if isCountingDown {
            captureTask?.cancel()
            return
        }
        guard !isCapturing else { return }
        isCapturing = true
        captureTask = Task { await runCapture() }
    }

    func stopRecording() {
        recorder.stop()
    }

    /// Records the selected preset at the center of the main display for `seconds` into the
    /// temporary directory, with no UI. For checking the recording pipeline from the command line.
    func debugRecord(seconds: Int) {
        guard !isCapturing, let screen = NSScreen.main else { return }
        let info = ScreenInfo(screen: screen)
        guard let limits = FrameGeometry.scaleLimits(preset: selectedPreset, screen: info, policy: .autoFit) else { return }
        let geometry = FrameGeometry.make(
            preset: selectedPreset, mouse: CGPoint(x: info.frame.midX, y: info.frame.midY),
            nudgePx: .zero, screen: info, frameScale: min(1, limits.upperBound)
        )
        isCapturing = true
        Task {
            defer { isCapturing = false }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                stopRecording()
            }
            await record(geometry, indicator: nil, toDownloads: false, copy: false)
        }
    }

    func capture(preset: Preset) {
        selectedPreset = preset
        startCapture()
    }

    func revealLastCapture() {
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

        overlay.hideWindows()
        let mode = captureMode
        let timer = timerSeconds

        if mode == .video, activeMicrophoneID != nil, !(await Microphone.requestAccess()) {
            NSLog("Recording aborted: Microphone access not granted")
            overlay.tearDown()
            presentError(CaptureError.microphoneDenied)
            return
        }

        // The timer and recordings hand focus back to the previous app and outline the region.
        var indicator: RegionIndicatorWindow?
        defer { indicator?.orderOut(nil) }
        if timer > 0 || mode == .video {
            overlay.tearDown()
            let window = RegionIndicatorWindow(rect: geometry.pointRect)
            window.orderFrontRegardless()
            indicator = window
        }
        if timer > 0, let indicator {
            guard await countdown(timer, in: indicator) else {
                NSLog("Capture session cancelled during timer")
                return
            }
        }

        switch mode {
        case .photo:
            indicator?.orderOut(nil)
            await capturePhoto(geometry)
        case .video:
            await record(geometry, indicator: indicator, toDownloads: saveToDownloads, copy: copyToClipboard)
        }
    }

    /// The microphone to record: the selected one if it is still connected, else none.
    private var activeMicrophoneID: String? {
        guard !microphoneID.isEmpty else { return nil }
        guard Microphone.devices.contains(where: { $0.id == microphoneID }) else {
            NSLog("Selected microphone is not connected; recording without it")
            return nil
        }
        return microphoneID
    }

    /// Counts down in the middle of the region. Returns false when cancelled by the hotkey.
    private func countdown(_ seconds: Int, in indicator: RegionIndicatorWindow) async -> Bool {
        isCountingDown = true
        defer {
            isCountingDown = false
            indicator.setCountdown(nil)
        }
        for remaining in stride(from: seconds, to: 0, by: -1) {
            indicator.setCountdown(remaining)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return false
            }
        }
        return true
    }

    private func capturePhoto(_ geometry: FrameGeometry) async {
        // Let the window server composite a frame without the overlay.
        try? await Task.sleep(for: .milliseconds(80))

        let capturer: any ScreenCapturing = useLegacyCapture
            ? FilterScreenshotCapturer(excludedWindowIDs: overlay.windowIDs, showsCursor: showPointerInPhotos)
            : RectScreenshotCapturer(showsCursor: showPointerInPhotos)
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

    /// Records until `stopRecording()`. A recording always needs a file, so with Downloads
    /// switched off it goes to the temporary directory and is only reachable from the clipboard.
    private func record(_ geometry: FrameGeometry, indicator: RegionIndicatorWindow?, toDownloads: Bool, copy: Bool) async {
        let url = OutputService.fileURL(
            kind: "Recording", preset: selectedPreset, size: geometry.videoPixels, pathExtension: "mp4",
            directory: toDownloads ? nil : FileManager.default.temporaryDirectory
        )
        let options = ScreenRecorder.Options(
            showsCursor: showPointerInVideos,
            showsClicks: showMouseClicks,
            systemAudio: recordSystemAudio,
            microphoneID: activeMicrophoneID
        )
        var control: RecordingControlWindow?
        defer { control?.orderOut(nil) }

        do {
            try await recorder.start(geometry, options: options, to: url)
            NSLog("Recording started: \(url.path), system audio \(options.systemAudio), microphone \(options.microphoneID ?? "none")")
            indicator?.setRecording(true)
            if indicator != nil {
                let screen = NSScreen.screens.first { $0.displayID == geometry.screen.displayID }
                control = RecordingControlWindow(
                    region: geometry.pointRect,
                    visibleFrame: screen?.visibleFrame ?? geometry.screen.frame,
                    state: self,
                    onStop: { [weak self] in self?.stopRecording() }
                )
                control?.orderFrontRegardless()
            }
            feedbackTask?.cancel()
            statusSymbol = "stop.circle.fill"
            isRecording = true
            let started = Date.now
            let ticker = Task {
                while (try? await Task.sleep(for: .seconds(1))) != nil {
                    recordingSeconds = Int(Date.now.timeIntervalSince(started))
                }
            }

            let failure = await recorder.waitUntilFinished()
            ticker.cancel()
            isRecording = false
            recordingSeconds = 0
            indicator?.orderOut(nil)
            control?.orderOut(nil)
            if let failure { throw failure }

            try await AudioMixdown.mixIfNeeded(url)
            if copy {
                OutputService.copyFileToPasteboard(url)
            }
            if toDownloads {
                lastFileURL = url
            }
            NSLog("Recording finished: \(url.path)")
            showFeedback("checkmark.circle")
        } catch {
            NSLog("Recording failed: \(error)")
            statusSymbol = "camera.viewfinder"
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
        alert.messageText = "Capture failed"
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
