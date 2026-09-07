import Foundation

 
 
 
 
public struct BackupRecordPayload: Equatable, Sendable {
    public let installID: String
    public let archive: Data
    public let sourceDevice: String
    public let exportedAt: Date
    public let schemaVersion: Int

    public init(installID: String, archive: Data, sourceDevice: String, exportedAt: Date, schemaVersion: Int) {
        self.installID = installID
        self.archive = archive
        self.sourceDevice = sourceDevice
        self.exportedAt = exportedAt
        self.schemaVersion = schemaVersion
    }
}

public enum BackupRecordSinkError: Error, Equatable {
     
    case noAccount
     
     
    case offline(String)
     
    case quotaExceeded
     
    case rateLimited(retryAfterSeconds: Double)
     
    case unavailable(String)
}

 
 
 
 
public protocol BackupRecordSink: Sendable {
     
    func upsert(_ payload: BackupRecordPayload) async throws
     
     
    func deleteOwn(installID: String) async throws
}

public struct DirectoryBackupRecordSink: BackupRecordSink {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func upsert(_ payload: BackupRecordPayload) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try payload.archive.write(to: fileURL(installID: payload.installID), options: .atomic)
    }

    public func deleteOwn(installID: String) async throws {
        let url = fileURL(installID: installID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(installID: String) -> URL {
        directory.appendingPathComponent(
            DirectoryBackupRecordSource.autoFilePrefix + installID + DirectoryBackupRecordSource.fileSuffix
        )
    }
}
