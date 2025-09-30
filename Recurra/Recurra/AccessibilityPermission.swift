import ApplicationServices

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
}
