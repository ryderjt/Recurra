import SwiftUI
import AppKit
import Carbon.HIToolbox

public struct HotKeyConfiguration: Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let keyEquivalent: String

    public static let recordingDefault = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(cmdKey | optionKey),
        keyEquivalent: "r"
    )

    public init(keyCode: UInt32, modifiers: UInt32, keyEquivalent: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyEquivalent = keyEquivalent.lowercased()
    }

    public init?(event: NSEvent) {
        let deviceIndependent = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifierSubset = deviceIndependent.intersection([.command, .option, .control, .shift])
        let primaryModifiers = modifierSubset.intersection([.command, .option, .control])
        guard !primaryModifiers.isEmpty else { return nil }

        guard let characters = event.charactersIgnoringModifiers, let first = characters.first else {
            return nil
        }

        let uppercase = String(first).uppercased()
        guard let scalar = uppercase.unicodeScalars.first,
              CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) else {
            return nil
        }

        let carbonModifiers = HotKeyConfiguration.carbonModifiers(from: modifierSubset)
        let lowercased = uppercase.lowercased()
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers, keyEquivalent: lowercased)
    }

    public var displayString: String {
        let modifiers = HotKeyConfiguration.modifierSymbols(from: modifiers)
        let key = keyDisplayName
        return modifiers + key
    }

    public var keyDisplayName: String {
        if keyEquivalent == " " { return "Space" }
        if let character = keyEquivalent.first {
            return String(character).uppercased()
        }
        return ""
    }

    public var swiftUIModifiers: EventModifiers {
        var result: EventModifiers = []
        let flags = HotKeyConfiguration.modifierFlags(fromCarbon: modifiers)
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }

    public var keyboardShortcut: KeyboardShortcut? {
        guard let character = keyEquivalent.first else { return nil }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: swiftUIModifiers)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private static func modifierFlags(fromCarbon modifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    private static func modifierSymbols(from modifiers: UInt32) -> String {
        let flags = modifierFlags(fromCarbon: modifiers)
        var symbols = ""
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }
        return symbols
    }
}
