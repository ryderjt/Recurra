import ApplicationServices
import AppKit

enum AccessibilityPermission {
    private static let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func ensureTrusted(promptsIfNeeded: Bool = true) -> Bool {
        guard !isTrusted() else { return true }
        guard promptsIfNeeded else { return false }
        return requestPermission()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        let options: CFDictionary = [promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func openSystemSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
