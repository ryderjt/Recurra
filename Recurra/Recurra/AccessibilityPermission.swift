import ApplicationServices

struct AccessibilityPermission {
    /// Checks if the app is trusted for Accessibility.
    /// If `prompt` is true, macOS will show the system dialog asking the user to grant access.
    static func ensureTrusted(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
