import Foundation

/// Typed access to the app's persisted preferences.
struct PresetStore: Sendable {
    nonisolated(unsafe) private let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    nonisolated enum Key {
        static let selectedPreset = "selectedPreset"
        static let fitPolicy = "fitPolicy"
        static let copyToClipboard = "copyToClipboard"
        static let saveToDownloads = "saveToDownloads"
        static let useLegacyCapture = "useLegacyCapture"
        static let lastFileURL = "lastFileURL"
        static let captureMode = "captureMode"
        static let timerSeconds = "timerSeconds"
        static let showPointerInPhotos = "showPointerInPhotos"
        static let showPointerInVideos = "showPointerInVideos"
        static let showMouseClicks = "showMouseClicks"
        static let recordSystemAudio = "recordSystemAudio"
        static let microphoneID = "microphoneID"
    }

    nonisolated var selectedPreset: Preset {
        get { defaults.string(forKey: Key.selectedPreset).flatMap(Preset.init(rawValue:)) ?? .x }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.selectedPreset) }
    }

    nonisolated var fitPolicy: FitPolicy {
        get { defaults.string(forKey: Key.fitPolicy).flatMap(FitPolicy.init(rawValue:)) ?? .autoFit }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.fitPolicy) }
    }

    nonisolated var copyToClipboard: Bool {
        get { defaults.object(forKey: Key.copyToClipboard) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.copyToClipboard) }
    }

    nonisolated var saveToDownloads: Bool {
        get { defaults.object(forKey: Key.saveToDownloads) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.saveToDownloads) }
    }

    nonisolated var useLegacyCapture: Bool {
        get { defaults.bool(forKey: Key.useLegacyCapture) }
        nonmutating set { defaults.set(newValue, forKey: Key.useLegacyCapture) }
    }

    nonisolated var lastFileURL: URL? {
        get { defaults.url(forKey: Key.lastFileURL) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastFileURL) }
    }

    nonisolated var captureMode: CaptureMode {
        get { defaults.string(forKey: Key.captureMode).flatMap(CaptureMode.init(rawValue:)) ?? .photo }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.captureMode) }
    }

    /// Delay before capturing, in seconds. `0` is off.
    nonisolated var timerSeconds: Int {
        get { defaults.integer(forKey: Key.timerSeconds) }
        nonmutating set { defaults.set(newValue, forKey: Key.timerSeconds) }
    }

    nonisolated var showPointerInPhotos: Bool {
        get { defaults.bool(forKey: Key.showPointerInPhotos) }
        nonmutating set { defaults.set(newValue, forKey: Key.showPointerInPhotos) }
    }

    nonisolated var showPointerInVideos: Bool {
        get { defaults.object(forKey: Key.showPointerInVideos) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.showPointerInVideos) }
    }

    nonisolated var showMouseClicks: Bool {
        get { defaults.bool(forKey: Key.showMouseClicks) }
        nonmutating set { defaults.set(newValue, forKey: Key.showMouseClicks) }
    }

    nonisolated var recordSystemAudio: Bool {
        get { defaults.object(forKey: Key.recordSystemAudio) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.recordSystemAudio) }
    }

    /// `AVCaptureDevice.uniqueID` of the microphone to record, or empty for none.
    nonisolated var microphoneID: String {
        get { defaults.string(forKey: Key.microphoneID) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.microphoneID) }
    }
}
