import Foundation

 
 
 
public struct BackupRecordSummary: Equatable, Sendable, Identifiable {
    public let installID: String
    public let sourceDevice: String?
    public let exportedAt: Date?
    public var id: String { installID }

    public init(installID: String, sourceDevice: String?, exportedAt: Date?) {
        self.installID = installID
        self.sourceDevice = sourceDevice
        self.exportedAt = exportedAt
    }
}

public enum BackupRecordSourceError: Error, Equatable {
     
    case noAccount
     
     
    case unavailable(String)
    case notFound(String)
}

 
 
public protocol BackupRecordSource: Sendable {
     
    func listBackups() async throws -> [BackupRecordSummary]
     
    func fetchArchive(installID: String) async throws -> Data
}

 
 
public struct DirectoryBackupRecordSource: BackupRecordSource {
    public static let autoFilePrefix = "Hako-backup-auto-"
    public static let fileSuffix = ".json"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func listBackups() async throws -> [BackupRecordSummary] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        var out: [BackupRecordSummary] = []
        for name in names where name.hasPrefix(Self.autoFilePrefix) && name.hasSuffix(Self.fileSuffix) {
            let installID = String(name.dropFirst(Self.autoFilePrefix.count).dropLast(Self.fileSuffix.count))
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
                  let envelope = try? BackupEnvelope.decode(data) else { continue }
            out.append(BackupRecordSummary(installID: installID, sourceDevice: envelope.sourceDevice, exportedAt: envelope.exportedAt))
        }
        return out.sorted { ($0.exportedAt ?? .distantPast) > ($1.exportedAt ?? .distantPast) }
    }

    public func fetchArchive(installID: String) async throws -> Data {
        let url = directory.appendingPathComponent(Self.autoFilePrefix + installID + Self.fileSuffix)
        guard let data = try? Data(contentsOf: url) else { throw BackupRecordSourceError.notFound(installID) }
        return data
    }
}
