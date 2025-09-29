import ApplicationServices

struct AccessibilityPermission {
    private static let promptOptionKey = kAXTrustedCheckOptionPrompt as String

    @discardableResult
    static func ensureTrusted(prompt: Bool = true) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options: NSDictionary = [promptOptionKey: prompt]
        return AXIsProcessTrustedWithOptions(options)
    }
}
