import Cocoa
import Combine
import Carbon.HIToolbox
import ApplicationServices

/// Responsible for replaying previously recorded macros while respecting the
/// timing information captured during recording.
final class Replayer: ObservableObject {
    @Published private(set) var isReplaying: Bool = false
    private weak var recorder: Recorder?
    private let macroManager: MacroManager
    private let playbackQueue = DispatchQueue(label: "com.macroRecorder.playback")
    private var playbackHotKey: UInt32 = 0
    private var shouldCancelPlayback = false

    init(recorder: Recorder?, macroManager: MacroManager) {
        self.recorder = recorder
        self.macroManager = macroManager
        registerHotKey()
    }

    deinit {
        HotKeyCenter.shared.unregister(identifier: playbackHotKey)
    }

    func attach(recorder: Recorder) {
        self.recorder = recorder
    }

    func replay(_ macro: RecordedMacro) {
        guard !isReplaying else { return }
        guard recorder?.isRecording == false else { return }
        guard !macro.events.isEmpty else { return }
        let prompt: CFDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrusted() || AXIsProcessTrustedWithOptions(prompt) else {
            recorder?.markPermissionDenied()
            return
        }

        isReplaying = true
        shouldCancelPlayback = false
        recorder?.markReplaying()

        playbackQueue.async { [weak self] in
            guard let self else { return }
            for event in macro.events {
                if self.shouldCancelPlayback { break }
                if event.delay > 0 {
                    Thread.sleep(forTimeInterval: event.delay)
                }
                event.event.post(tap: .cghidEventTap)
            }

            DispatchQueue.main.async {
                self.shouldCancelPlayback = false
                self.isReplaying = false
                self.recorder?.markIdle()
            }
        }
    }

    func replayMostRecentMacro() {
        guard let macro = macroManager.mostRecentMacro else { return }
        replay(macro)
    }

    func togglePlayback() {
        if isReplaying {
            stop()
        } else {
            replayMostRecentMacro()
        }
    }

    func stop() {
        guard isReplaying else { return }
        shouldCancelPlayback = true
    }

    private func registerHotKey() {
        let modifiers = UInt32(cmdKey | optionKey)
        playbackHotKey = HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_P), modifiers: modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.togglePlayback()
            }
        }
    }
}
