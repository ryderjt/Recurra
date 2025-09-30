import Foundation
import ApplicationServices

// MARK: - Macro Timeline Extensions

extension CGEvent {
    func archivedData() -> Data? {
        guard let cfData = self.data else { return nil }
        return cfData as Data
    }

    static func fromArchivedData(_ data: Data) -> CGEvent? {
        CGEvent(withDataAllocator: kCFAllocatorDefault, data: data as CFData)
    }
}

extension MacroTimelineDraft {
    var maximumKeyframeTime: TimeInterval {
        keyframes.map(\.time).max() ?? 0
    }

    mutating func addKeyboardKeyframe(at time: TimeInterval) -> UUID {
        let keyframe = MacroTimelineKeyframe(
            id: UUID(),
            time: time,
            payload: .keyboard(KeyboardAction(phase: .down, keyCode: 0, flags: []))
        )
        keyframes.append(keyframe)
        return keyframe.id
    }

    mutating func addMouseKeyframe(at time: TimeInterval) -> UUID {
        let keyframe = MacroTimelineKeyframe(
            id: UUID(),
            time: time,
            payload: .mouse(MouseAction(phase: .down, button: .left, location: .zero, flags: []))
        )
        keyframes.append(keyframe)
        return keyframe.id
    }

    mutating func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }

    mutating func moveKeyframe(id: UUID, to time: TimeInterval) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        keyframes[index].time = time
    }

    mutating func updateKeyboardAction(id: UUID, update: (inout KeyboardAction) -> Void) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        if case .keyboard(var action) = keyframes[index].payload {
            update(&action)
            keyframes[index].payload = .keyboard(action)
        }
    }

    mutating func updateMouseAction(id: UUID, update: (inout MouseAction) -> Void) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        if case .mouse(var action) = keyframes[index].payload {
            update(&action)
            keyframes[index].payload = .mouse(action)
        }
    }

    mutating func clampDurationToKeyframes() {
        let maxKeyframeTime = maximumKeyframeTime
        if maxKeyframeTime > duration {
            duration = maxKeyframeTime + 0.5
        }
    }

    func buildMacro(from originalMacro: RecordedMacro) throws -> RecordedMacro {
        var events: [RecordedMacro.TimedEvent] = []
        var lastTime: TimeInterval = 0

        for keyframe in keyframes.sorted(by: { $0.time < $1.time }) {
            let delay = keyframe.time - lastTime
            lastTime = keyframe.time

            let event = try keyframe.payload.createCGEvent()
            let timedEvent = RecordedMacro.TimedEvent(delay: delay, event: event)
            events.append(timedEvent)
        }

        return RecordedMacro(
            id: originalMacro.id,
            name: originalMacro.name,
            createdAt: originalMacro.createdAt,
            events: events,
            duration: duration
        )
    }
}

extension MacroTimelineKeyframe.Payload {
    func createCGEvent() throws -> CGEvent {
        switch self {
        case .keyboard(let action):
            return try action.createCGEvent()
        case .mouse(let action):
            return try action.createCGEvent()
        case .unsupported:
            throw MacroTimelineError.unsupportedEventType
        }
    }
}

enum MacroTimelineError: Error {
    case unsupportedEventType
    case invalidEventData
}
