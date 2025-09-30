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

// Equatable conformance so arrays of RecordedMacro are Equatable for onChange(of:)
extension RecordedMacro: Equatable {
    static func == (lhs: RecordedMacro, rhs: RecordedMacro) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.createdAt == rhs.createdAt &&
        lhs.duration == rhs.duration &&
        lhs.events.count == rhs.events.count
    }
}

final class MacroManager: ObservableObject {
    @Published private(set) var macros: [RecordedMacro] = []

    private let fileManager: FileManager
    private let persistenceURL: URL
    private let persistenceQueue = DispatchQueue(label: "com.recurra.persistence", qos: .utility)

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.persistenceURL = MacroManager.makePersistenceURL(fileManager: fileManager)
        loadPersistedMacros()
    }

    var mostRecentMacro: RecordedMacro? {
        macros.first
    }

    func add(_ macro: RecordedMacro) {
        let insert = {
            self.macros.insert(macro, at: 0)
            self.persistCurrentState()
        }

        executeOnMain(insert)
    }

    func remove(_ macro: RecordedMacro) {
        let removal = {
            self.macros.removeAll { $0.id == macro.id }
            self.persistCurrentState()
        }

        executeOnMain(removal)
    }

    func remove(at offsets: IndexSet) {
        let removal = {
            for index in offsets.sorted(by: >) {
                self.macros.remove(at: index)
            }
            self.persistCurrentState()
        }

        executeOnMain(removal)
    }

    func rename(_ macro: RecordedMacro, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let update = {
            guard let index = self.macros.firstIndex(where: { $0.id == macro.id }) else { return }
            self.macros[index].name = trimmed
            self.persistCurrentState()
        }

        executeOnMain(update)
    }

    func macro(with id: RecordedMacro.ID?) -> RecordedMacro? {
        guard let id else { return nil }
        return macros.first(where: { $0.id == id })
    }

    private func executeOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func loadPersistedMacros() {
        persistenceQueue.async {
            guard let data = try? Data(contentsOf: self.persistenceURL) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let storedMacros = try decoder.decode([StoredMacro].self, from: data)
                let macros = storedMacros.compactMap { $0.makeRecordedMacro() }
                DispatchQueue.main.async {
                    self.macros = macros
                }
            } catch {
                NSLog("Failed to decode macros: %@", error.localizedDescription)
            }
        }
    }

    private func persistCurrentState() {
        let snapshot = macros
        persistenceQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let stored = snapshot.compactMap { StoredMacro(macro: $0) }
            do {
                let data = try encoder.encode(stored)
                try self.ensurePersistenceDirectoryExists()
                try data.write(to: self.persistenceURL, options: .atomic)
            } catch {
                NSLog("Failed to persist macros: %@", error.localizedDescription)
            }
        }
    }

    private func ensurePersistenceDirectoryExists() throws {
        let directory = persistenceURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func makePersistenceURL(fileManager: FileManager) -> URL {
        let baseDirectory: URL
        if let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDirectory = support
        } else {
            baseDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        }
        return baseDirectory
            .appendingPathComponent("Recurra", isDirectory: true)
            .appendingPathComponent("macros.json", isDirectory: false)
    }
}

// MARK: - Persistence Helpers

private struct StoredMacro: Codable {
    struct StoredEvent: Codable {
        let delay: TimeInterval
        let data: Data
    }

    let id: UUID
    let name: String
    let createdAt: Date
    let duration: TimeInterval
    let events: [StoredEvent]

    init?(macro: RecordedMacro) {
        let events = macro.events.compactMap { event -> StoredEvent? in
            guard let data = event.event.archivedData() else { return nil }
            return StoredEvent(delay: event.delay, data: data)
        }
        guard events.count == macro.events.count else { return nil }
        self.id = macro.id
        self.name = macro.name
        self.createdAt = macro.createdAt
        self.duration = macro.duration
        self.events = events
    }

    func makeRecordedMacro() -> RecordedMacro? {
        let events = events.compactMap { stored -> RecordedMacro.TimedEvent? in
            guard let event = CGEvent.fromArchivedData(stored.data) else { return nil }
            return RecordedMacro.TimedEvent(delay: stored.delay, event: event)
        }
        guard events.count == self.events.count else { return nil }
        return RecordedMacro(id: id, name: name, createdAt: createdAt, events: events, duration: duration)
    }
}

private extension CGEvent {
    func archivedData() -> Data? {
        guard let cfData = self.data else { return nil }
        return cfData as Data
    }

    static func fromArchivedData(_ data: Data) -> CGEvent? {
        CGEvent(withDataAllocator: kCFAllocatorDefault, data: data as CFData)
    }
}
