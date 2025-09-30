import Foundation
import ApplicationServices
#if canImport(AppKit)
import AppKit
#endif

struct MacroTimelineKeyframe: Identifiable, Equatable {
    enum Payload: Equatable {
        case keyboard(KeyboardAction)
        case mouse(MouseAction)
        case unsupported(UnsupportedAction)
    }

    var id: UUID
    var time: TimeInterval
    var payload: Payload

    init(id: UUID = UUID(), time: TimeInterval, payload: Payload) {
        self.id = id
        self.time = time
        self.payload = payload
    }
}

struct KeyboardAction: Equatable {
    enum Phase: String, CaseIterable, Identifiable {
        case keyDown = "Key Down"
        case keyUp = "Key Up"
        case flagsChanged = "Flags Changed"

        var id: String { rawValue }

        init?(eventType: CGEventType) {
            switch eventType {
            case .keyDown:
                self = .keyDown
            case .keyUp:
                self = .keyUp
            case .flagsChanged:
                self = .flagsChanged
            default:
                return nil
            }
        }

        var correspondingEventType: CGEventType {
            switch self {
            case .keyDown:
                return .keyDown
            case .keyUp:
                return .keyUp
            case .flagsChanged:
                return .flagsChanged
            }
        }
    }

    var keyCode: CGKeyCode
    var phase: Phase
    var flags: CGEventFlags

    init?(event: CGEvent) {
        guard let phase = Phase(eventType: event.type) else { return nil }
        let keyCodeValue = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCodeValue >= 0 else { return nil }
        self.keyCode = CGKeyCode(UInt16(keyCodeValue))
        self.phase = phase
        self.flags = event.flags
    }

    init(keyCode: CGKeyCode, phase: Phase, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.phase = phase
        self.flags = flags
    }

    func makeEvent(source: CGEventSource? = CGEventSource(stateID: .combinedSessionState)) -> CGEvent? {
        let isKeyDown = phase != .keyUp
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown) else {
            NSLog("Failed to create keyboard event for keyCode: %d, phase: %@", keyCode, phase.rawValue)
            return nil
        }
        event.flags = flags
        if phase == .flagsChanged {
            event.type = .flagsChanged
        }
        return event
    }
}

struct MouseAction: Equatable {
    enum Phase: String, CaseIterable, Identifiable {
        case move = "Move"
        case buttonDown = "Button Down"
        case buttonUp = "Button Up"
        case dragged = "Dragged"

        var id: String { rawValue }

        init?(eventType: CGEventType) {
            switch eventType {
            case .mouseMoved:
                self = .move
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                self = .buttonDown
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                self = .buttonUp
            case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                self = .dragged
            default:
                return nil
            }
        }
    }

    var phase: Phase
    var button: CGMouseButton
    var location: CGPoint
    var flags: CGEventFlags

    init?(event: CGEvent) {
        guard let phase = Phase(eventType: event.type) else { return nil }
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let rawValue = UInt32(max(0, buttonNumber))
        let button = CGMouseButton(rawValue: rawValue) ?? .left
        self.phase = phase
        self.button = button
        self.location = event.location
        self.flags = event.flags
    }

    init(phase: Phase, button: CGMouseButton, location: CGPoint, flags: CGEventFlags) {
        self.phase = phase
        self.button = button
        self.location = location
        self.flags = flags
    }

    func makeEvent(source: CGEventSource? = CGEventSource(stateID: .combinedSessionState)) -> CGEvent? {
        let eventType = cgEventType
        guard let event = CGEvent(mouseEventSource: source,
                                   mouseType: eventType,
                                   mouseCursorPosition: location,
                                   mouseButton: button) else {
            NSLog("Failed to create mouse event for phase: %@, button: %d, location: %@", phase.rawValue, button.rawValue, NSStringFromPoint(location))
            return nil
        }
        event.flags = flags
        return event
    }

    private var cgEventType: CGEventType {
        switch phase {
        case .move:
            return .mouseMoved
        case .buttonDown:
            switch button {
            case .left:
                return .leftMouseDown
            case .right:
                return .rightMouseDown
            default:
                return .otherMouseDown
            }
        case .buttonUp:
            switch button {
            case .left:
                return .leftMouseUp
            case .right:
                return .rightMouseUp
            default:
                return .otherMouseUp
            }
        case .dragged:
            switch button {
            case .left:
                return .leftMouseDragged
            case .right:
                return .rightMouseDragged
            default:
                return .otherMouseDragged
            }
        }
    }
}

struct UnsupportedAction: Equatable {
    let eventType: CGEventType
    let archivedData: Data
    let description: String
}

enum MacroTimelineError: Error, LocalizedError {
    case unsupportedEventDecoding(CGEventType)
    case failedToCreateKeyboardEvent
    case failedToCreateMouseEvent

    var errorDescription: String? {
        switch self {
        case .unsupportedEventDecoding(let type):
            return "Failed to rebuild event of type \(type.timelineDescription)."
        case .failedToCreateKeyboardEvent:
            return "Unable to create keyboard event from the provided keyframe."
        case .failedToCreateMouseEvent:
            return "Unable to create mouse event from the provided keyframe."
        }
    }
}

struct MacroTimelineDraft: Equatable {
    var keyframes: [MacroTimelineKeyframe]
    var duration: TimeInterval

    init(macro: RecordedMacro, minimumDuration: TimeInterval = 3) {
        var accumulated: TimeInterval = 0
        var frames: [MacroTimelineKeyframe] = []

        for event in macro.events {
            accumulated += max(0, event.delay)
            if let frame = MacroTimelineKeyframe(timedEvent: event, absoluteTime: accumulated) {
                frames.append(frame)
            }
        }

        keyframes = frames
        let baseDuration = max(macro.duration, accumulated)
        let sanitizedMinimum = max(0.5, minimumDuration)
        duration = max(baseDuration, sanitizedMinimum)
    }

    init(keyframes: [MacroTimelineKeyframe] = [], duration: TimeInterval = 3) {
        self.keyframes = keyframes
        self.duration = max(duration, 0.5)
    }

    var maximumKeyframeTime: TimeInterval {
        keyframes.map(\.time).max() ?? 0
    }

    mutating func normalizeOrdering() {
        keyframes.sort { $0.time < $1.time }
    }

    mutating func moveKeyframe(id: UUID, to newTime: TimeInterval) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(0, min(newTime, duration))
        keyframes[index].time = clamped
        normalizeOrdering()
    }

    mutating func addKeyboardKeyframe(at time: TimeInterval) -> UUID {
        let newAction = KeyboardAction(keyCode: CGKeyCode(0), phase: .keyDown, flags: [])
        let frame = MacroTimelineKeyframe(time: clampedTime(time), payload: .keyboard(newAction))
        keyframes.append(frame)
        normalizeOrdering()
        return frame.id
    }

    mutating func addMouseKeyframe(at time: TimeInterval, usingCurrentPointer: Bool = true) -> UUID {
        let location: CGPoint
        #if os(macOS)
        if usingCurrentPointer {
            location = NSEvent.mouseLocation
        } else {
            location = CGPoint(x: 0, y: 0)
        }
        #else
        location = CGPoint(x: 0, y: 0)
        #endif
        let newAction = MouseAction(phase: .buttonDown, button: .left, location: location, flags: [])
        let frame = MacroTimelineKeyframe(time: clampedTime(time), payload: .mouse(newAction))
        keyframes.append(frame)
        normalizeOrdering()
        return frame.id
    }

    mutating func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }

    mutating func updateKeyboardAction(id: UUID, transform: (inout KeyboardAction) -> Void) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        guard case var .keyboard(action) = keyframes[index].payload else { return }
        transform(&action)
        keyframes[index].payload = .keyboard(action)
    }

    mutating func updateMouseAction(id: UUID, transform: (inout MouseAction) -> Void) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        guard case var .mouse(action) = keyframes[index].payload else { return }
        transform(&action)
        keyframes[index].payload = .mouse(action)
    }

    mutating func clampDurationToKeyframes() {
        let maximum = maximumKeyframeTime
        if duration < maximum {
            duration = maximum.rounded(toPlaces: 2) + 0.1
        }
    }

    func buildMacro(from base: RecordedMacro) throws -> RecordedMacro {
        let sorted = keyframes.sorted { $0.time < $1.time }
        var previous: TimeInterval = 0
        var events: [RecordedMacro.TimedEvent] = []

        for frame in sorted {
            let delay = max(0, frame.time - previous)
            previous = frame.time
            let cgEvent: CGEvent

            switch frame.payload {
            case .keyboard(let action):
                guard let event = action.makeEvent() else {
                    throw MacroTimelineError.failedToCreateKeyboardEvent
                }
                cgEvent = event
            case .mouse(let action):
                guard let event = action.makeEvent() else {
                    throw MacroTimelineError.failedToCreateMouseEvent
                }
                cgEvent = event
            case .unsupported(let info):
                guard let event = CGEvent.fromArchivedData(info.archivedData) else {
                    throw MacroTimelineError.unsupportedEventDecoding(info.eventType)
                }
                cgEvent = event
            }

            events.append(RecordedMacro.TimedEvent(delay: delay, event: cgEvent))
        }

        let computedDuration = max(duration, previous)
        return RecordedMacro(id: base.id,
                             name: base.name,
                             createdAt: base.createdAt,
                             events: events,
                             duration: computedDuration)
    }

    private func clampedTime(_ proposed: TimeInterval) -> TimeInterval {
        max(0, min(proposed, duration))
    }
}

private extension MacroTimelineKeyframe {
    init?(timedEvent: RecordedMacro.TimedEvent, absoluteTime: TimeInterval) {
        let event = timedEvent.event.copy() ?? timedEvent.event
        if let keyboard = KeyboardAction(event: event) {
            self.init(time: absoluteTime, payload: .keyboard(keyboard))
            return
        }
        if let mouse = MouseAction(event: event) {
            self.init(time: absoluteTime, payload: .mouse(mouse))
            return
        }
        guard let archived = event.archivedData() else { return nil }
        let unsupported = UnsupportedAction(eventType: event.type,
                                            archivedData: archived,
                                            description: event.type.timelineDescription)
        self.init(time: absoluteTime, payload: .unsupported(unsupported))
    }
}

private extension CGEventType {
    var timelineDescription: String {
        switch self {
        case .keyDown:
            return "Key Down"
        case .keyUp:
            return "Key Up"
        case .flagsChanged:
            return "Modifier Change"
        case .mouseMoved:
            return "Mouse Move"
        case .leftMouseDown:
            return "Left Mouse Down"
        case .leftMouseUp:
            return "Left Mouse Up"
        case .leftMouseDragged:
            return "Left Mouse Dragged"
        case .rightMouseDown:
            return "Right Mouse Down"
        case .rightMouseUp:
            return "Right Mouse Up"
        case .rightMouseDragged:
            return "Right Mouse Dragged"
        case .otherMouseDown:
            return "Other Mouse Down"
        case .otherMouseUp:
            return "Other Mouse Up"
        case .otherMouseDragged:
            return "Other Mouse Dragged"
        case .scrollWheel:
            return "Scroll Wheel"
        default:
            return "Event \(rawValue)"
        }
    }
}

private extension TimeInterval {
    func rounded(toPlaces places: Int) -> TimeInterval {
        guard places >= 0 else { return self }
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
