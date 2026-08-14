import Foundation

/// Persists operation history to Application Support so it survives quitting.
///
/// History is capped: an unbounded log would grow without limit and each
/// record can carry a large captured console output.
actor HistoryStore {
    static let maximumEntries = 200

    /// Output beyond this is truncated before writing; full output is only
    /// needed while the console sheet is open.
    private static let maximumStoredOutputCharacters = 20_000

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        let directory = base.appendingPathComponent("BrewManager", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("history.json")
    }

    func load() -> [OperationRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stored = try decoder.decode([StoredRecord].self, from: data)
            return stored.map(\.record)
        } catch {
            AppLogger.app.error("Could not decode history: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func save(_ records: [OperationRecord]) {
        let capped = records.prefix(Self.maximumEntries).map { record in
            StoredRecord(record: record, maximumOutput: Self.maximumStoredOutputCharacters)
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(Array(capped))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.app.error("Could not save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear() {
        try? fileManager.removeItem(at: fileURL)
    }
}

/// `OperationRecord` uses `Duration`, which has no stable Codable form across
/// releases, so persistence goes through this explicit representation.
private struct StoredRecord: Codable {
    let id: UUID
    let title: String
    let command: String
    let output: String
    let exitCode: Int32
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Double

    init(record: OperationRecord, maximumOutput: Int) {
        self.id = record.id
        self.title = record.title
        self.command = record.command
        self.output = String(record.output.prefix(maximumOutput))
        self.exitCode = record.exitCode
        self.startedAt = record.startedAt
        self.endedAt = record.endedAt

        let components = record.duration.components
        self.durationSeconds = Double(components.seconds)
            + Double(components.attoseconds) / 1e18
    }

    var record: OperationRecord {
        OperationRecord(
            id: id,
            title: title,
            command: command,
            output: output,
            exitCode: exitCode,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: .seconds(durationSeconds)
        )
    }
}
