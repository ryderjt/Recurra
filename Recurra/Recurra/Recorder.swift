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

        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler,
                            1, &eventSpec,
                            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                            &eventHandler)
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
        var hotKeyID = EventHotKeyID(signature: OSType("MCRO".fourCharCodeValue), id: identifier)
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

private func hotKeyEventHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
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

    init(macroManager: MacroManager) {
        self.macroManager = macroManager
        nextMacroName = Recorder.defaultName(for: 1)
        registerHotKey()
    }

    deinit {
        tearDownEventTap()
        HotKeyCenter.shared.unregister(identifier: hotKeyIdentifier)
    }

    func toggleRecording() {
        guard !isReplaying else { return }
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard !isRecording, !isReplaying else { return }
        guard ensureAccessibilityPermission() else {
            DispatchQueue.main.async {
                self.status = .permissionDenied
            }
            return
        }

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue)
                               | (1 << CGEventType.keyUp.rawValue)
                               | (1 << CGEventType.flagsChanged.rawValue)
                               | (1 << CGEventType.leftMouseDown.rawValue)
                               | (1 << CGEventType.leftMouseUp.rawValue)
                               | (1 << CGEventType.rightMouseDown.rawValue)
                               | (1 << CGEventType.rightMouseUp.rawValue)
                               | (1 << CGEventType.otherMouseDown.rawValue)
                               | (1 << CGEventType.otherMouseUp.rawValue)
                               | (1 << CGEventType.mouseMoved.rawValue)
                               | (1 << CGEventType.scrollWheel.rawValue)
                               | (1 << CGEventType.leftMouseDragged.rawValue)
                               | (1 << CGEventType.rightMouseDragged.rawValue)
                               | (1 << CGEventType.otherMouseDragged.rawValue))

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<Recorder>.fromOpaque(userInfo).takeUnretainedValue()
            return recorder.handleIncoming(event: event, type: type)
        }

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) else {
            DispatchQueue.main.async {
                self.status = .permissionDenied
            }
            return
        }

        recordingStartTime = CFAbsoluteTimeGetCurrent()
        lastEventTime = recordingStartTime
        currentRecording.removeAll(keepingCapacity: true)
        currentRecordingName = nextMacroName.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentRecordingName.isEmpty {
            currentRecordingName = Recorder.defaultName(for: recordingCount)
        }
        totalRecordingDuration = 0

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)

        DispatchQueue.main.async {
            self.status = .recording
        }
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
                                                                         duration: duration)

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

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let prompt: CFDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(prompt)
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
        let delay = now - lastEventTime
        lastEventTime = now
        totalRecordingDuration = now - recordingStartTime

        if let copiedEvent = event.copy() {
            let timedEvent = RecordedMacro.TimedEvent(delay: delay, event: copiedEvent)
            currentRecording.append(timedEvent)
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
        let modifiers = UInt32(cmdKey | optionKey)
        hotKeyIdentifier = HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_R), modifiers: modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleRecording()
            }
        }
    }

    private static func defaultName(for index: Int) -> String {
        "Macro #\(index)"
    }
}
