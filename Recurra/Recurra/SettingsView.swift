import SwiftUI
import AppKit
import Carbon.HIToolbox

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettingsKey.defaultTimelineDuration) private var defaultTimelineDuration = 3.0
    @AppStorage(AppSettingsKey.keyframeSnapEnabled) private var isKeyframeSnappingEnabled = true
    @AppStorage(AppSettingsKey.keyframeSnapInterval) private var keyframeSnapInterval = 0.05

    // Hotkey settings
    @AppStorage(AppSettingsKey.recordingHotkeyKeyCode) private var recordingKeyCode = Int(kVK_ANSI_R)
    @AppStorage(AppSettingsKey.recordingHotkeyModifiers) private var recordingModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.recordingHotkeyKeyEquivalent) private var recordingKeyEquivalent = "r"
    @AppStorage(AppSettingsKey.playbackHotkeyKeyCode) private var playbackKeyCode = Int(kVK_ANSI_P)
    @AppStorage(AppSettingsKey.playbackHotkeyModifiers) private var playbackModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.playbackHotkeyKeyEquivalent) private var playbackKeyEquivalent = "p"
    @AppStorage(AppSettingsKey.playSelectedHotkeyKeyCode) private var playSelectedKeyCode = Int(kVK_ANSI_S)
    @AppStorage(AppSettingsKey.playSelectedHotkeyModifiers) private var playSelectedModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.playSelectedHotkeyKeyEquivalent) private var playSelectedKeyEquivalent = "s"
    @AppStorage(AppSettingsKey.stopMacroHotkeyKeyCode) private var stopMacroKeyCode = Int(kVK_ANSI_Escape)
    @AppStorage(AppSettingsKey.stopMacroHotkeyModifiers) private var stopMacroModifiers = Int(cmdKey | optionKey)
    @AppStorage(AppSettingsKey.stopMacroHotkeyKeyEquivalent) private var stopMacroKeyEquivalent = "escape"

    var body: some View {
        let palette = Palette(colorScheme: colorScheme)

        ZStack {
            palette.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    RecurraLogo()
                        .frame(width: 64, height: 64)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.blue)
                }

                Text("Settings")
                    .font(.title2.weight(.semibold))

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Timeline Defaults")
                            .font(.headline)
                        Text("Set the starting length used when editing a macro without keyframes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            TextField("Seconds",
                                      value: $defaultTimelineDuration,
                                      format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Stepper(value: $defaultTimelineDuration, in: 0.5...120, step: 0.25) {
                                Text("\(defaultTimelineDuration, format: .number.precision(.fractionLength(2))) s")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Keyframe Editing")
                            .font(.headline)
                        Toggle("Snap keyframes to interval", isOn: $isKeyframeSnappingEnabled)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Snap interval: \(keyframeSnapInterval, format: .number.precision(.fractionLength(2))) s")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Slider(value: $keyframeSnapInterval, in: 0.01...1.0, step: 0.01)
                                .disabled(!isKeyframeSnappingEnabled)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)

                        HotkeyPicker(
                            title: "Recording",
                            description: "Start or stop recording a macro",
                            keyCode: $recordingKeyCode,
                            modifiers: $recordingModifiers,
                            keyEquivalent: $recordingKeyEquivalent
                        )
                        .onChange(of: recordingKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: recordingModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: recordingKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }

                        HotkeyPicker(
                            title: "Playback",
                            description: "Play the most recent macro",
                            keyCode: $playbackKeyCode,
                            modifiers: $playbackModifiers,
                            keyEquivalent: $playbackKeyEquivalent
                        )
                        .onChange(of: playbackKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playbackModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playbackKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }

                        HotkeyPicker(
                            title: "Play Selected",
                            description: "Play the currently selected macro",
                            keyCode: $playSelectedKeyCode,
                            modifiers: $playSelectedModifiers,
                            keyEquivalent: $playSelectedKeyEquivalent
                        )
                        .onChange(of: playSelectedKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playSelectedModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: playSelectedKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }

                        HotkeyPicker(
                            title: "Stop Macro",
                            description: "Stop any currently playing macro",
                            keyCode: $stopMacroKeyCode,
                            modifiers: $stopMacroModifiers,
                            keyEquivalent: $stopMacroKeyEquivalent
                        )
                        .onChange(of: stopMacroKeyCode) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: stopMacroModifiers) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                        .onChange(of: stopMacroKeyEquivalent) { _ in
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(GradientButtonStyle(isDestructive: false))
                }
            }
            .padding(36)
            .frame(maxWidth: 480)
            .cardBackground(cornerRadius: 28)
        }
        .onChange(of: defaultTimelineDuration) { newValue in
            let clamped = Self.clampDuration(newValue)
            if clamped != newValue {
                defaultTimelineDuration = clamped
            }
        }
        .onChange(of: keyframeSnapInterval) { newValue in
            let clamped = Self.clampSnapInterval(newValue)
            if clamped != newValue {
                keyframeSnapInterval = clamped
            }
        }
    }

    private static func clampDuration(_ value: Double) -> Double {
        guard value.isFinite else { return 3 }
        return min(max(value, 0.5), 120)
    }

    private static func clampSnapInterval(_ value: Double) -> Double {
        guard value.isFinite else { return 0.05 }
        return min(max(value, 0.01), 1.0)
    }
}

private struct HotkeyPicker: View {
    let title: String
    let description: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var keyEquivalent: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayString: String {
        var result = ""
        let modFlags = UInt32(modifiers)
        if modFlags & UInt32(controlKey) != 0 { result += "⌃" }
        if modFlags & UInt32(optionKey) != 0 { result += "⌥" }
        if modFlags & UInt32(shiftKey) != 0 { result += "⇧" }
        if modFlags & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyEquivalent.uppercased()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button(action: startRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "keyboard")
                        Text(isRecording ? "Press keys..." : displayString)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(isRecording)

                if !isRecording {
                    Button("Reset") {
                        // Reset to appropriate defaults based on context
                        if title == "Recording" {
                            keyCode = Int(kVK_ANSI_R)
                            modifiers = Int(cmdKey | optionKey)
                            keyEquivalent = "r"
                        } else if title == "Playback" {
                            keyCode = Int(kVK_ANSI_P)
                            modifiers = Int(cmdKey | optionKey)
                            keyEquivalent = "p"
                        } else if title == "Play Selected" {
                            keyCode = Int(kVK_ANSI_S)
                            modifiers = Int(cmdKey | optionKey)
                            keyEquivalent = "s"
                        } else if title == "Stop Macro" {
                            keyCode = Int(kVK_ANSI_Escape)
                            modifiers = Int(cmdKey | optionKey)
                            keyEquivalent = "escape"
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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

            var carbonModifiers: UInt32 = 0
            if modifierSubset.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if modifierSubset.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if modifierSubset.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            if modifierSubset.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

            keyCode = Int(event.keyCode)
            modifiers = Int(carbonModifiers)
            keyEquivalent = uppercase.lowercased()

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
