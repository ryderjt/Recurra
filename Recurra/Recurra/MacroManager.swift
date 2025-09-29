import Foundation
import Combine
import ApplicationServices

struct RecordedMacro: Identifiable {
    struct TimedEvent {
        let delay: TimeInterval
        let event: CGEvent
    }

    let id: UUID
    var name: String
    let createdAt: Date
    let events: [TimedEvent]
    let duration: TimeInterval
}

final class MacroManager: ObservableObject {
    @Published private(set) var macros: [RecordedMacro] = []

    var mostRecentMacro: RecordedMacro? {
        macros.first
    }

    func add(_ macro: RecordedMacro) {
        if Thread.isMainThread {
            macros.insert(macro, at: 0)
        } else {
            DispatchQueue.main.async {
                self.macros.insert(macro, at: 0)
            }
        }
    }

    func remove(_ macro: RecordedMacro) {
        if Thread.isMainThread {
            macros.removeAll { $0.id == macro.id }
        } else {
            DispatchQueue.main.async {
                self.macros.removeAll { $0.id == macro.id }
            }
        }
    }

    func remove(at offsets: IndexSet) {
        if Thread.isMainThread {
            macros.remove(atOffsets: offsets)
        } else {
            DispatchQueue.main.async {
                self.macros.remove(atOffsets: offsets)
            }
        }
    }

    func rename(_ macro: RecordedMacro, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let update = {
            guard let index = self.macros.firstIndex(where: { $0.id == macro.id }) else { return }
            self.macros[index].name = trimmed
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func macro(with id: RecordedMacro.ID?) -> RecordedMacro? {
        guard let id else { return nil }
        return macros.first(where: { $0.id == id })
    }
}

private extension Array where Element == RecordedMacro {
    mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            if indices.contains(offset) {
                remove(at: offset)
            }
        }
    }
}
