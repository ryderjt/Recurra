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
    var loopCount: Int
}

// Equatable conformance so arrays of RecordedMacro are Equatable for onChange(of:)
extension RecordedMacro: Equatable {
    static func == (lhs: RecordedMacro, rhs: RecordedMacro) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.createdAt == rhs.createdAt &&
        lhs.duration == rhs.duration &&
        lhs.events.count == rhs.events.count &&
        lhs.loopCount == rhs.loopCount
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
        macros.last
    }

    func add(_ macro: RecordedMacro) {
        // Validate macro before adding
        guard !macro.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSLog("Cannot add macro with empty name")
            return
        }

        guard macro.duration >= 0 else {
            NSLog("Cannot add macro with negative duration")
            return
        }

        let insert = {
            self.macros.append(macro)
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
        guard !trimmed.isEmpty else {
            NSLog("Cannot rename macro to empty name")
            return
        }

        guard trimmed.count <= 100 else {
            NSLog("Macro name too long (max 100 characters)")
            return
        }

        let update = {
            guard let index = self.macros.firstIndex(where: { $0.id == macro.id }) else { return }
            self.macros[index].name = trimmed
            self.persistCurrentState()
        }

        executeOnMain(update)
    }

    func update(_ macro: RecordedMacro) {
        let update = {
            guard let index = self.macros.firstIndex(where: { $0.id == macro.id }) else { return }
            self.macros[index] = macro
            self.persistCurrentState()
        }

        executeOnMain(update)
    }

    func updateLoopCount(_ macro: RecordedMacro, to loopCount: Int) {
        guard loopCount >= 0 else { return }
        guard loopCount != macro.loopCount else { return }

        let update = {
            if let index = self.macros.firstIndex(where: { $0.id == macro.id }) {
                self.macros[index].loopCount = loopCount
                self.persistCurrentState()
            }
        }

        executeOnMain(update)
    }

    @discardableResult
    func createCustomMacro(named name: String? = nil) -> RecordedMacro {
        let resolvedName: String
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            resolvedName = nextCustomMacroName()
        }

        let macro = RecordedMacro(id: UUID(),
                                  name: resolvedName,
                                  createdAt: Date(),
                                  events: [],
                                  duration: 0,
                                  loopCount: 1)
        add(macro)
        return macro
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

    private func nextCustomMacroName() -> String {
        let existing = macros.filter { $0.name.hasPrefix("Custom Macro") }.count + 1
        return "Custom Macro #\(existing)"
    }

    private func loadPersistedMacros() {
        persistenceQueue.async {
            do {
                let data = try Data(contentsOf: self.persistenceURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storedMacros = try decoder.decode([StoredMacro].self, from: data)
                let macros = storedMacros.compactMap { $0.makeRecordedMacro() }
                DispatchQueue.main.async {
                    self.macros = macros
                }
            } catch {
                // File doesn't exist or is corrupted - start with empty array
                if (error as NSError).code != NSFileReadNoSuchFileError {
                    NSLog("Failed to load persisted macros: %@", error.localizedDescription)
                }
                DispatchQueue.main.async {
                    self.macros = []
                }
            }
        }
    }

    private func persistCurrentState() {
        let snapshot = macros
        persistenceQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let stored = snapshot.compactMap { StoredMacro(macro: $0) }
                let data = try encoder.encode(stored)
                try self.ensurePersistenceDirectoryExists()
                try data.write(to: self.persistenceURL, options: .atomic)
            } catch {
                NSLog("Failed to persist macros: %@", error.localizedDescription)
                // Consider showing user notification for critical persistence failures
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
            baseDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
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
    let loopCount: Int

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
        self.loopCount = macro.loopCount
    }

    func makeRecordedMacro() -> RecordedMacro? {
        let events = events.compactMap { stored -> RecordedMacro.TimedEvent? in
            guard let event = CGEvent.fromArchivedData(stored.data) else { return nil }
            return RecordedMacro.TimedEvent(delay: stored.delay, event: event)
        }
        guard events.count == self.events.count else { return nil }
        return RecordedMacro(id: id, name: name, createdAt: createdAt, events: events, duration: duration, loopCount: loopCount)
    }
}

extension CGEvent {
    func archivedData() -> Data? {
        guard let cfData = self.data else { return nil }
        return cfData as Data
    }

    static func fromArchivedData(_ data: Data) -> CGEvent? {
        CGEvent(withDataAllocator: kCFAllocatorDefault, data: data as CFData)
    }
}
