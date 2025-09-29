import ApplicationServices

enum AccessibilityPermission {
    private static let promptOptionKey = kAXTrustedCheckOptionPrompt as String

    @discardableResult
    static func ensureTrusted(promptIfNeeded: Bool = true) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        guard promptIfNeeded else {
            return false
        }

        let options: NSDictionary = [promptOptionKey: true]
        return AXIsProcessTrustedWithOptions(options)
    }
}
