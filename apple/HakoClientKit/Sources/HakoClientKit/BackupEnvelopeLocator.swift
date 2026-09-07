import Foundation

 
 
 
public struct BackupEnvelopeLocator: Sendable {
    public let source: any BackupRecordSource

    public init(source: any BackupRecordSource) {
        self.source = source
    }

     
    public func backups() async throws -> [BackupRecordSummary] {
        try await source.listBackups()
    }

    public func read(_ summary: BackupRecordSummary) async throws -> BackupEnvelope {
        try BackupEnvelope.decode(try await source.fetchArchive(installID: summary.installID))
    }
}
