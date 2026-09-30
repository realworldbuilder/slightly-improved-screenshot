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
}
