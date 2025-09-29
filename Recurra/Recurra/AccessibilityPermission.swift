import ApplicationServices

enum AccessibilityPermission {
    private static let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

    @discardableResult
    static func ensureTrusted(promptsIfNeeded: Bool = true) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        guard promptsIfNeeded else {
            return false
        }
        let options: CFDictionary = [promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
