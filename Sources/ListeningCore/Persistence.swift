import Foundation

private struct StorageEnvelope<Value: Codable>: Codable {
    let schemaVersion: Int
    let value: Value
}

public struct RepositoryLoadResult<Value: Sendable>: Sendable {
    public let value: Value
    public let warnings: [String]

    public init(value: Value, warnings: [String] = []) {
        self.value = value
        self.warnings = warnings
    }
}

public protocol SessionRepository: Sendable {
    func loadSessions() async -> RepositoryLoadResult<[ListeningSession]>
    func loadSettings() async -> RepositoryLoadResult<AppSettings>
    func loadCheckpoint() async -> ActiveSessionCheckpoint?
    func saveSessions(_ sessions: [ListeningSession]) async throws
    func saveSettings(_ settings: AppSettings) async throws
    func saveCheckpoint(_ checkpoint: ActiveSessionCheckpoint?) async throws
    func clearSessions() async throws
}

public actor JSONSessionRepository: SessionRepository {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        if let overridePath = ProcessInfo.processInfo.environment[
            "LISTENING_TIMER_DATA_DIR"
        ], !overridePath.isEmpty {
            self.directory = URL(
                fileURLWithPath: overridePath,
                isDirectory: true
            )
        } else if let directory {
            self.directory = directory
        } else {
            let base = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.homeDirectoryForCurrentUser
            self.directory =
                base.appendingPathComponent(
                    "com.lazycanary.ListeningTimer",
                    isDirectory: true
                )
        }
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadSessions() async -> RepositoryLoadResult<[ListeningSession]> {
        let url = sessionsURL
        guard fileManager.fileExists(atPath: url.path) else {
            return RepositoryLoadResult(value: [])
        }
        do {
            let envelope: StorageEnvelope<[ListeningSession]> =
                try decode(from: url)
            return RepositoryLoadResult(value: envelope.value)
        } catch {
            preserveCorruptFile(at: url)
            return RepositoryLoadResult(
                value: [],
                warnings: ["历史数据无法读取，原文件已保留，未自动删除。"]
            )
        }
    }

    public func loadSettings() async -> RepositoryLoadResult<AppSettings> {
        let url = settingsURL
        guard fileManager.fileExists(atPath: url.path) else {
            return RepositoryLoadResult(value: .default)
        }
        do {
            let envelope: StorageEnvelope<AppSettings> = try decode(from: url)
            return RepositoryLoadResult(value: envelope.value)
        } catch {
            preserveCorruptFile(at: url)
            return RepositoryLoadResult(
                value: .default,
                warnings: ["设置文件无法读取，已暂时使用默认设置。"]
            )
        }
    }

    public func loadCheckpoint() async -> ActiveSessionCheckpoint? {
        guard fileManager.fileExists(atPath: checkpointURL.path) else {
            return nil
        }
        do {
            return try decode(from: checkpointURL)
        } catch {
            preserveCorruptFile(at: checkpointURL)
            return nil
        }
    }

    public func saveSessions(_ sessions: [ListeningSession]) async throws {
        try ensureDirectory()
        try backupIfPresent(sessionsURL)
        let envelope = StorageEnvelope(schemaVersion: 1, value: sessions)
        let data = try encoder.encode(envelope)
        try data.write(to: sessionsURL, options: .atomic)
    }

    public func saveSettings(_ settings: AppSettings) async throws {
        try ensureDirectory()
        let envelope = StorageEnvelope(schemaVersion: 1, value: settings)
        let data = try encoder.encode(envelope)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func saveCheckpoint(
        _ checkpoint: ActiveSessionCheckpoint?
    ) async throws {
        try ensureDirectory()
        guard let checkpoint else {
            if fileManager.fileExists(atPath: checkpointURL.path) {
                try fileManager.removeItem(at: checkpointURL)
            }
            return
        }
        let data = try encoder.encode(checkpoint)
        try data.write(to: checkpointURL, options: .atomic)
    }

    public func clearSessions() async throws {
        for url in [sessionsURL, sessionsURL.appendingPathExtension("bak"),
                    checkpointURL] where
            fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private var sessionsURL: URL {
        directory.appendingPathComponent("sessions.json")
    }

    private var settingsURL: URL {
        directory.appendingPathComponent("settings.json")
    }

    private var checkpointURL: URL {
        directory.appendingPathComponent("active-session.json")
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func decode<Value: Decodable>(from url: URL) throws -> Value {
        let data = try Data(contentsOf: url)
        return try decoder.decode(Value.self, from: data)
    }

    private func backupIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        let backup = url.appendingPathExtension("bak")
        if fileManager.fileExists(atPath: backup.path) {
            try fileManager.removeItem(at: backup)
        }
        try fileManager.copyItem(at: url, to: backup)
    }

    private func preserveCorruptFile(at url: URL) {
        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destination = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp).json")
        try? fileManager.copyItem(at: url, to: destination)
    }
}
