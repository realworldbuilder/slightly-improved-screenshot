import AVFoundation
import ScreenCaptureKit

/// Records the region described by a `FrameGeometry` to an H.264 MP4 at the preset's pixel
/// size, with optional system audio and microphone.
final class ScreenRecorder: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    struct Options: Sendable {
        var showsCursor: Bool
        var showsClicks: Bool
        var systemAudio: Bool
        /// `AVCaptureDevice.uniqueID` of the microphone, or `nil` for none.
        var microphoneID: String?
    }

    private var stream: SCStream?
    private var isStopping = false
    private var isFinished = false
    private var failure: Error?
    private var waiter: CheckedContinuation<Error?, Never>?

    /// Starts recording to `url`. This app's own windows are left out of the picture.
    func start(_ geometry: FrameGeometry, options: Options, to url: URL) async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCapturePermission.mapError(error)
        }
        guard let display = content.displays.first(where: { $0.displayID == geometry.screen.displayID }) else {
            throw CaptureError.displayNotFound
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == pid }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = geometry.displayLocalRect
        config.width = Int(geometry.videoPixels.width)
        config.height = Int(geometry.videoPixels.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = options.showsCursor
        config.showMouseClicks = options.showsClicks
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        config.captureDynamicRange = .SDR
        config.colorSpaceName = CGColorSpace.sRGB
        config.scalesToFit = true
        // The even-sized video frame can differ from the preset by a pixel; stretch rather than letterbox.
        config.preservesAspectRatio = false
        config.capturesAudio = options.systemAudio
        config.excludesCurrentProcessAudio = true
        if let microphoneID = options.microphoneID {
            config.captureMicrophone = true
            config.microphoneCaptureDeviceID = microphoneID
        }

        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.videoCodecType = .h264
        recording.outputFileType = .mp4

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        isStopping = false
        isFinished = false
        failure = nil
        do {
            try stream.addRecordingOutput(SCRecordingOutput(configuration: recording, delegate: self))
            try await stream.startCapture()
        } catch {
            throw ScreenCapturePermission.mapError(error)
        }
        self.stream = stream
    }

    /// Ends the recording. `waitUntilFinished` returns once the file is finalized.
    func stop() {
        guard let stream, !isStopping else { return }
        isStopping = true
        Task {
            do {
                try await stream.stopCapture()
            } catch {
                complete(error)
                return
            }
            // The recording output normally reports that it finished; do not hang if it never does.
            try? await Task.sleep(for: .seconds(5))
            complete(nil)
        }
    }

    /// Suspends until the recording has ended, by `stop()` or on its own. Returns the failure, if any.
    func waitUntilFinished() async -> Error? {
        if isFinished { return failure }
        return await withCheckedContinuation { waiter = $0 }
    }

    private func complete(_ error: Error?) {
        guard !isFinished else { return }
        isFinished = true
        failure = error
        if let stream, !isStopping {
            Task { try? await stream.stopCapture() }
        }
        stream = nil
        waiter?.resume(returning: error)
        waiter = nil
    }

    private func streamStopped(_ error: Error) {
        guard !isStopping, !isFinished else { return }
        isStopping = true
        let ns = error as NSError
        guard ns.domain == SCStreamErrorDomain, ns.code == SCStreamError.Code.userStopped.rawValue else {
            complete(error)
            return
        }
        // Stopped from the system's screen sharing menu: give the file a moment to finalize.
        Task {
            try? await Task.sleep(for: .seconds(1))
            complete(nil)
        }
    }

    // MARK: - Delegates

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.streamStopped(error) }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.complete(nil) }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.complete(error) }
    }
}
