import CloudKit
import Foundation

 
 
 
 
public final class CloudKitBackupRecordSource: BackupRecordSource, @unchecked Sendable {
    private let container: CKContainer

    public init(containerIdentifier: String) {
        container = CKContainer(identifier: containerIdentifier)
    }

    public func listBackups() async throws -> [BackupRecordSummary] {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw BackupRecordSourceError.unavailable(error.localizedDescription)
        }
        switch status {
        case .available:
            break
        case .noAccount:
            throw BackupRecordSourceError.noAccount
        default:
             
             
            throw BackupRecordSourceError.unavailable("iCloud account status: \(Self.name(of: status))")
        }
        let predicate = NSPredicate(format: "%K == %@", BackupRecordSchema.kindField, BackupRecordSchema.kindAuto)
        let query = CKQuery(recordType: BackupRecordSchema.recordType, predicate: predicate)
        do {
            let (matches, _) = try await container.privateCloudDatabase.records(
                matching: query, desiredKeys: BackupRecordSchema.summaryKeys, resultsLimit: 50
            )
            let summaries = matches.compactMap { _, result -> BackupRecordSummary? in
                guard case .success(let record) = result else { return nil }
                return Self.summary(from: record)
            }
            return summaries.sorted { ($0.exportedAt ?? .distantPast) > ($1.exportedAt ?? .distantPast) }
        } catch {
            throw Self.mapped(error)
        }
    }

    public func fetchArchive(installID: String) async throws -> Data {
        let record: CKRecord
        do {
            record = try await container.privateCloudDatabase.record(for: CKRecord.ID(recordName: installID))
        } catch {
            throw Self.mapped(error, notFound: installID)
        }
        guard let asset = record[BackupRecordSchema.archiveField] as? CKAsset, let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else {
            throw BackupRecordSourceError.notFound(installID)
        }
        return data
    }

    public static func name(of status: CKAccountStatus) -> String {
        switch status {
        case .available: "available"
        case .noAccount: "noAccount"
        case .restricted: "restricted"
        case .couldNotDetermine: "couldNotDetermine"
        case .temporarilyUnavailable: "temporarilyUnavailable"
        @unknown default: "unknown(\(status.rawValue))"
        }
    }

     
     
    public static func summary(from record: CKRecord) -> BackupRecordSummary {
        BackupRecordSummary(
            installID: record.recordID.recordName,
            sourceDevice: record[BackupRecordSchema.sourceDeviceField] as? String,
            exportedAt: record[BackupRecordSchema.exportedAtField] as? Date
        )
    }

    private static func mapped(_ error: Error, notFound installID: String? = nil) -> BackupRecordSourceError {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated: return .noAccount
            case .unknownItem: return .notFound(installID ?? "")
            default: break
            }
        }
        return .unavailable(error.localizedDescription)
    }
}
