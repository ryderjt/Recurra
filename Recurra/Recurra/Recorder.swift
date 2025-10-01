import Cocoa
import Combine
import ApplicationServices
import Carbon.HIToolbox

/// Centralised helper that wraps Carbon hot-key registration so it can be shared
/// between recording and playback components.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var eventHandler: EventHandlerRef?
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var nextIdentifier: UInt32 = 1

    private init() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(GetApplicationEventTarget(),
                                        hotKeyEventHandler,
                                        1, &eventSpec,
                                        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                        &eventHandler)

        if status != noErr {
            NSLog("Failed to install hotkey event handler: %d", status)
        }
    }

    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        let identifier = nextIdentifier
        nextIdentifier += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("MCRO".fourCharCodeValue), id: identifier)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)

        guard status == noErr, let hotKeyRef else {
            NSLog("Failed to register hot key with keyCode: %u", keyCode)
            return 0
        }

        handlers[identifier] = handler
        hotKeyRefs[identifier] = hotKeyRef
        return identifier
    }

    func unregister(identifier: UInt32) {
        guard identifier != 0 else { return }
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: identifier) {
            UnregisterEventHotKey(hotKeyRef)
        }
        handlers.removeValue(forKey: identifier)
    }

    fileprivate func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(event,
                                       EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID),
                                       nil,
                                       MemoryLayout<EventHotKeyID>.size,
                                       nil,
                                       &hotKeyID)
        guard status == noErr else { return status }
        guard let handler = handlers[hotKeyID.id] else { return noErr }
        handler()
        return noErr
    }
}

private func hotKeyEventHandler(nextHandler: EventHandlerCallRef?, 
                                event: EventRef?, 
                                userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event = event, let userData = userData else { return noErr }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    return center.handle(event: event)
}

private extension String {
    /// Converts a string to a four character code for Carbon APIs.
    var fourCharCodeValue: OSType {
        var result: OSType = 0
        for character in utf16 {
            result = (result << 8) + OSType(character)
        }
        return result
    }
}

/// Manages recording of CGEvents using an event tap while tracking macro state.
final class Recorder: ObservableObject {
    enum Status: Equatable {
        case idle
        case recording
        case replaying
        case permissionDenied

        var description: String {
            switch self {
            case .idle:
                return "Idle"
            case .recording:
                return "Recording…"
            case .replaying:
                return "Replaying…"
            case .permissionDenied:
                return "Accessibility permission required"
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published var nextMacroName: String

    var isRecording: Bool { status == .recording }
    var isReplaying: Bool { status == .replaying }

    private let macroManager: MacroManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentRecording: [RecordedMacro.TimedEvent] = []
    private var recordingStartTime: CFAbsoluteTime = 0
    private var lastEventTime: CFAbsoluteTime = 0
    private var currentRecordingName: String = ""
    private var totalRecordingDuration: TimeInterval = 0
    private var hotKeyIdentifier: UInt32 = 0
    private var recordingCount = 1
    private var cancellables: Set<AnyCancellable> = []

    init(macroManager: MacroManager) {
        self.macroManager = macroManager
        let initialCount = max(macroManager.macros.count + 1, 1)
        recordingCount = initialCount
        nextMacroName = Recorder.defaultName(for: initialCount)
        registerHotKey()
        observeMacroLibrary()
    }

    deinit {
        tearDownEventTap()
        HotKeyCenter.shared.unregister(identifier: hotKeyIdentifier)
    }

    func toggleRecording() {
        guard !isReplaying else { return }
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard !isRecording, !isReplaying else { return }
        guard AccessibilityPermission.ensureTrusted() else {
            DispatchQueue.main.async {
                self.status = .permissionDenied
            }
            return
        }

        guard let tap = createEventTap() else {
            DispatchQueue.main.async {
                self.status = .permissionDenied
            }
            return
        }

        setupRecordingState()
        setupEventTap(tap)

        DispatchQueue.main.async {
            self.status = .recording
        }
    }

    private func createEventTap() -> CFMachPort? {
        let eventTypes: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved, .scrollWheel,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) { partialMask, eventType in
            partialMask | (CGEventMask(1) << CGEventMask(eventType.rawValue))
        }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else { return nil }
            let recorder = Unmanaged<Recorder>.fromOpaque(userInfo).takeUnretainedValue()
            return recorder.handleIncoming(event: event, type: type)
        }

        return CGEvent.tapCreate(tap: .cgSessionEventTap,
                                place: .headInsertEventTap,
                                options: .defaultTap,
                                eventsOfInterest: mask,
                                callback: callback,
                                userInfo: UnsafeMutableRawPointer(
                                    Unmanaged.passUnretained(self).toOpaque()))
    }

    private func setupRecordingState() {
        recordingStartTime = CFAbsoluteTimeGetCurrent()
        lastEventTime = recordingStartTime
        currentRecording.removeAll(keepingCapacity: true)
        currentRecordingName = nextMacroName.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentRecordingName.isEmpty {
            currentRecordingName = Recorder.defaultName(for: recordingCount)
        }
        totalRecordingDuration = 0
    }

    private func setupEventTap(_ tap: CFMachPort) {
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopRecording() {
        guard isRecording else { return }
        tearDownEventTap()

        let events = currentRecording
        let name = currentRecordingName
        let duration = totalRecordingDuration

        let macro: RecordedMacro? = events.isEmpty ? nil : RecordedMacro(id: UUID(),
                                                                         name: name,
                                                                         createdAt: Date(),
                                                                         events: events,
                                                                         duration: duration,
                                                                         loopCount: 1)

        DispatchQueue.main.async {
            if let macro {
                self.macroManager.add(macro)
                self.recordingCount += 1
                self.nextMacroName = Recorder.defaultName(for: self.recordingCount)
            }
            self.status = .idle
        }

        currentRecording.removeAll(keepingCapacity: true)
        totalRecordingDuration = 0
        currentRecordingName = ""
    }

    func markReplaying() {
        DispatchQueue.main.async {
            self.status = .replaying
        }
    }

    func markIdle() {
        DispatchQueue.main.async {
            self.status = .idle
        }
    }

    func markPermissionDenied() {
        DispatchQueue.main.async {
            self.status = .permissionDenied
        }
    }

    private func handleIncoming(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent> {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isRecording else {
            return Unmanaged.passUnretained(event)
        }

        let now = CFAbsoluteTimeGetCurrent()
        let delay = max(0, now - lastEventTime) // Ensure non-negative delay
        lastEventTime = now
        totalRecordingDuration = now - recordingStartTime

        // Limit the number of events to prevent memory issues
        guard currentRecording.count < 10000 else {
            NSLog("Recording stopped: too many events captured")
            stopRecording()
            return Unmanaged.passUnretained(event)
        }

        if let copiedEvent = event.copy() {
            let timedEvent = RecordedMacro.TimedEvent(delay: delay, event: copiedEvent)
            currentRecording.append(timedEvent)
        } else {
            NSLog("Failed to copy event during recording")
        }

        return Unmanaged.passUnretained(event)
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func registerHotKey() {
        let defaults = UserDefaults.standard

        // Get hotkey configuration from UserDefaults or use defaults
        let keyCode = UInt32(defaults.integer(forKey: "settings.recordingHotkeyKeyCode"))
        let modifiers = UInt32(defaults.integer(forKey: "settings.recordingHotkeyModifiers"))

        // Use defaults if no values are stored
        let finalKeyCode = keyCode == 0 ? UInt32(kVK_ANSI_R) : keyCode
        let finalModifiers = modifiers == 0 ? UInt32(cmdKey | optionKey) : modifiers

        hotKeyIdentifier = HotKeyCenter.shared.register(keyCode: finalKeyCode,
                                                        modifiers: finalModifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording()
            }
        }
    }

    func updateHotkey() {
        // Unregister current hotkey
        HotKeyCenter.shared.unregister(identifier: hotKeyIdentifier)
        // Register new hotkey
        registerHotKey()
    }

    private func observeMacroLibrary() {
        macroManager.$macros
            .receive(on: RunLoop.main)
            .sink { [weak self] macros in
                guard let self else { return }
                let suggestedIndex = max(macros.count + 1, 1)
                self.recordingCount = suggestedIndex
                let trimmedName = self.nextMacroName.trimmingCharacters(in: .whitespacesAndNewlines)
                let isUsingDefault = trimmedName.isEmpty || trimmedName.hasPrefix("Macro #")
                if !self.isRecording && isUsingDefault {
                    self.nextMacroName = Recorder.defaultName(for: suggestedIndex)
                }
            }
            .store(in: &cancellables)

        // Listen for hotkey settings changes
        NotificationCenter.default.publisher(for: .hotkeySettingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateHotkey()
            }
            .store(in: &cancellables)
    }

    private static func defaultName(for index: Int) -> String {
        "Macro #\(index)"
    }
}
