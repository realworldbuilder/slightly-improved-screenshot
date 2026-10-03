import AVFoundation

enum Microphone {
    struct Device: Identifiable, Hashable {
        /// `AVCaptureDevice.uniqueID`.
        let id: String
        let name: String
    }

    /// Audio inputs currently connected.
    static var devices: [Device] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices.map { Device(id: $0.uniqueID, name: $0.localizedName) }
    }

    /// Shows the system prompt the first time; later calls return the stored answer.
    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
