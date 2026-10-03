import AVFoundation

/// ScreenCaptureKit writes system audio and the microphone as separate tracks, and most
/// players and social sites only play the first. This folds them into one AAC track.
nonisolated enum AudioMixdown {
    /// Rewrites the movie at `url` in place with its audio tracks mixed into one. The video is
    /// copied without re-encoding. Does nothing when there are fewer than two audio tracks.
    static func mixIfNeeded(_ url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard audioTracks.count > 1,
              let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        else { return }

        let reader = try AVAssetReader(asset: asset)
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        reader.add(videoOutput)
        reader.add(audioOutput)

        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: try await videoTrack.load(.formatDescriptions).first
        )
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000,
        ])
        writer.add(videoInput)
        writer.add(audioInput)

        guard reader.startReading(), writer.startWriting() else {
            throw reader.error ?? writer.error ?? OutputError.encodeFailed
        }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "AudioMixdown")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for (output, input) in [(videoOutput as AVAssetReaderOutput, videoInput), (audioOutput, audioInput)] {
                nonisolated(unsafe) let output = output
                nonisolated(unsafe) let input = input
                group.enter()
                input.requestMediaDataWhenReady(on: queue) {
                    while input.isReadyForMoreMediaData {
                        guard let buffer = output.copyNextSampleBuffer(), input.append(buffer) else {
                            input.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            }
            group.notify(queue: queue) { continuation.resume() }
        }
        await writer.finishWriting()

        guard reader.status == .completed, writer.status == .completed else {
            try? FileManager.default.removeItem(at: temporary)
            throw reader.error ?? writer.error ?? OutputError.encodeFailed
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }
}
