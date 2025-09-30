import SwiftUI

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

    var body: some Scene {
        let _ = menuBarController
        WindowGroup {
            MainView()
                .environmentObject(macroManager)
                .environmentObject(recorder)
                .environmentObject(replayer)
                .environmentObject(menuBarController)
                .preferredColorScheme(.dark)
        }
        .commands {
            CommandMenu("Macro Controls") {
                Button(recorder.isRecording ? "Stop Recording" : "Start Recording") {
                    recorder.toggleRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(recorder.isReplaying)

                Button(replayer.isReplaying ? "Stop Playback" : "Replay Latest Macro") {
                    if replayer.isReplaying {
                        replayer.stop()
                    } else {
                        replayer.replayMostRecentMacro()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(!replayer.isReplaying && macroManager.mostRecentMacro == nil)
            }
        }
    }
}
