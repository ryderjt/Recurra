import AppKit
import Combine

final class MenuBarController: NSObject, ObservableObject {
    private let statusItem: NSStatusItem
    private let recorder: Recorder
    private let replayer: Replayer
    private let macroManager: MacroManager
    private var cancellables: Set<AnyCancellable> = []

    init(recorder: Recorder, replayer: Replayer, macroManager: MacroManager) {
        self.recorder = recorder
        self.replayer = replayer
        self.macroManager = macroManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        bind()
        rebuildMenu()
    }

    deinit {
        if let button = statusItem.button {
            button.target = nil
            button.action = nil
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func bind() {
        recorder.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        replayer.$isReplaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAppearance()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        macroManager.$macros
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Macro Recorder")
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor.controlAccentColor
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let recordingTitle = recorder.isRecording ? "Stop Recording" : "Start Recording"
        let recordingItem = NSMenuItem(title: recordingTitle, action: #selector(toggleRecording), keyEquivalent: "")
        recordingItem.target = self
        recordingItem.isEnabled = !recorder.isReplaying
        menu.addItem(recordingItem)

        let playbackTitle = replayer.isReplaying ? "Stop Playback" : "Replay Latest Macro"
        let playbackItem = NSMenuItem(title: playbackTitle, action: #selector(togglePlayback), keyEquivalent: "")
        playbackItem.target = self
        playbackItem.isEnabled = replayer.isReplaying || macroManager.mostRecentMacro != nil
        menu.addItem(playbackItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Macro Recorder", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Macro Recorder", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshAppearance()
    }

    private func refreshAppearance() {
        guard let button = statusItem.button else { return }
        switch recorder.status {
        case .idle:
            button.contentTintColor = NSColor.controlAccentColor
        case .recording:
            button.contentTintColor = NSColor.systemRed
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        case .replaying:
            button.contentTintColor = NSColor.systemBlue
            button.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Replaying")
        case .permissionDenied:
            button.contentTintColor = NSColor.systemOrange
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Permission Required")
        }
        if recorder.status == .idle {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Macro Recorder")
        }
    }

    @objc private func toggleRecording() {
        recorder.toggleRecording()
    }

    @objc private func togglePlayback() {
        replayer.togglePlayback()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let visibleWindows = NSApp.windows.filter { $0.isVisible && $0.canBecomeKey }
        if visibleWindows.isEmpty {
            NSApp.arrangeInFront(nil)
        }
        let windowsToShow = visibleWindows.isEmpty ? NSApp.windows : visibleWindows
        for window in windowsToShow where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
