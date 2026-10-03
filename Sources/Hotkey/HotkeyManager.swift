import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default ⌘⇧2, next to the system screenshot tools on ⌘⇧3/4/5/6.
    static let capture = Self("capture", default: .init(.two, modifiers: [.command, .shift]))
}

enum HotkeyManager {
    static func install(_ action: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .capture) {
            action()
        }
    }

    /// Human-readable current binding, e.g. "⇧⌘2".
    static var captureShortcutDescription: String {
        KeyboardShortcuts.getShortcut(for: .capture)?.description ?? ""
    }
}
