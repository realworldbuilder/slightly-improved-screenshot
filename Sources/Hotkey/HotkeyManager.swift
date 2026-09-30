import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default ⌃⌥⌘S. ⌘⇧3/4/5/6 are taken by the system screenshot tools.
    static let capture = Self("capture", default: .init(.s, modifiers: [.control, .option, .command]))
}

enum HotkeyManager {
    static func install(_ action: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .capture) {
            action()
        }
    }

    /// Human-readable current binding, e.g. "⌃⌥⌘S".
    static var captureShortcutDescription: String {
        KeyboardShortcuts.getShortcut(for: .capture)?.description ?? ""
    }
}
