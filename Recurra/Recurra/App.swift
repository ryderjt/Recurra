import SwiftUI
import Carbon.HIToolbox

@main
struct RecurraApp: App {
    @StateObject private var macroManager: MacroManager
    @StateObject private var recorder: Recorder
    @StateObject private var replayer: Replayer
    @StateObject private var menuBarController: MenuBarController

    init() {
        let manager = MacroManager()
        _macroManager = StateObject(wrappedValue: manager)

        let recorder = Recorder(macroManager: manager)
        _recorder = StateObject(wrappedValue: recorder)

        let replayer = Replayer(recorder: recorder, macroManager: manager)
        _replayer = StateObject(wrappedValue: replayer)

        _menuBarController = StateObject(wrappedValue: MenuBarController(recorder: recorder, replayer: replayer, macroManager: manager))
    }

    private var recordingKeyboardShortcut: KeyboardShortcut {
        let defaults = UserDefaults.standard
        let keyEquivalent = defaults.string(forKey: "settings.recordingHotkeyKeyEquivalent") ?? "r"
        let modifiers = UInt32(defaults.integer(forKey: "settings.recordingHotkeyModifiers"))

        var eventModifiers: SwiftUI.EventModifiers = []
        if modifiers & UInt32(controlKey) != 0 { eventModifiers.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { eventModifiers.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { eventModifiers.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { eventModifiers.insert(.command) }

        guard let character = keyEquivalent.first else {
            return KeyboardShortcut("r", modifiers: [.command, .option])
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }

    private var playbackKeyboardShortcut: KeyboardShortcut {
        let defaults = UserDefaults.standard
        let keyEquivalent = defaults.string(forKey: "settings.playbackHotkeyKeyEquivalent") ?? "p"
        let modifiers = UInt32(defaults.integer(forKey: "settings.playbackHotkeyModifiers"))

        var eventModifiers: SwiftUI.EventModifiers = []
        if modifiers & UInt32(controlKey) != 0 { eventModifiers.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { eventModifiers.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { eventModifiers.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { eventModifiers.insert(.command) }

        guard let character = keyEquivalent.first else {
            return KeyboardShortcut("p", modifiers: [.command, .option])
        }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: eventModifiers)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(macroManager)
                .environmentObject(recorder)
                .environmentObject(replayer)
                .environmentObject(menuBarController)
        }
        .defaultSize(width: 960, height: 960)
        .commands {
            CommandMenu("Macro Controls") {
                Button(recorder.isRecording ? "Stop Recording" : "Start Recording") {
                    recorder.toggleRecording()
                }
                .keyboardShortcut(recordingKeyboardShortcut)
                .disabled(recorder.isReplaying)

                Button(replayer.isReplaying ? "Stop Playback" : "Replay Latest Macro") {
                    if replayer.isReplaying {
                        replayer.stop()
                    } else {
                        replayer.replayMostRecentMacro()
                    }
                }
                .keyboardShortcut(playbackKeyboardShortcut)
                .disabled(!replayer.isReplaying && macroManager.mostRecentMacro == nil)
            }
        }
    }
}
