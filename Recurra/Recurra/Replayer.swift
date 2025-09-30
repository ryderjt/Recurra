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
    private var cancellables: Set<AnyCancellable> = []

    init(recorder: Recorder?, macroManager: MacroManager) {
        self.recorder = recorder
        self.macroManager = macroManager
        registerHotKey()
        observeHotkeySettings()
    }

    deinit {
        HotKeyCenter.shared.unregister(identifier: playbackHotKey)
    }

    func replay(_ macro: RecordedMacro) {
        guard !isReplaying else { return }
        guard recorder?.isRecording == false else { return }
        guard !macro.events.isEmpty else { return }
        guard AccessibilityPermission.ensureTrusted() else {
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

                // Clamp delay to reasonable bounds to prevent excessive delays
                let clampedDelay = max(0, min(event.delay, 10.0))
                if clampedDelay > 0 {
                    Thread.sleep(forTimeInterval: clampedDelay)
                }

                // Post the event and check for errors
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
        let defaults = UserDefaults.standard

        // Get hotkey configuration from UserDefaults or use defaults
        let keyCode = UInt32(defaults.integer(forKey: "settings.playbackHotkeyKeyCode"))
        let modifiers = UInt32(defaults.integer(forKey: "settings.playbackHotkeyModifiers"))

        // Use defaults if no values are stored
        let finalKeyCode = keyCode == 0 ? UInt32(kVK_ANSI_P) : keyCode
        let finalModifiers = modifiers == 0 ? UInt32(cmdKey | optionKey) : modifiers

        playbackHotKey = HotKeyCenter.shared.register(keyCode: finalKeyCode, modifiers: finalModifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.togglePlayback()
            }
        }
    }

    func updateHotkey() {
        // Unregister current hotkey
        HotKeyCenter.shared.unregister(identifier: playbackHotKey)
        // Register new hotkey
        registerHotKey()
    }

    private func observeHotkeySettings() {
        // Listen for hotkey settings changes
        NotificationCenter.default.publisher(for: .hotkeySettingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateHotkey()
            }
            .store(in: &cancellables)
    }
}
