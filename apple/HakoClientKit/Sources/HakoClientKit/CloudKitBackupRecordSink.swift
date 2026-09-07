import CloudKit
import Foundation

 
 
 
public final class CloudKitBackupRecordSink: BackupRecordSink, @unchecked Sendable {
    private let container: CKContainer
     
     
    public var diagnostics: (@Sendable (String) -> Void)?

    public init(containerIdentifier: String) {
        container = CKContainer(identifier: containerIdentifier)
    }

    public func upsert(_ payload: BackupRecordPayload) async throws {
        try await requireAccount()
        if let diagnostics {
             
             
             
            let user = (try? await container.userRecordID().recordName) ?? "unavailable"
            diagnostics("icloud auto backup: user record \(user), container \(container.containerIdentifier)")
        }
         
         
        let assetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hako-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: assetURL) }
        do {
            try payload.archive.write(to: assetURL, options: .atomic)
            let record = Self.record(for: payload, assetURL: assetURL)
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [record], deleting: [], savePolicy: .allKeys, atomically: true
            )
        } catch let error as BackupRecordSinkError {
            throw error
        } catch {
            throw Self.mapped(error)
        }
    }

    public func deleteOwn(installID: String) async throws {
        try await requireAccount()
        do {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [], deleting: [CKRecord.ID(recordName: installID)], savePolicy: .allKeys, atomically: true
            )
        } catch {
            if let ck = error as? CKError, ck.code == .unknownItem { return }
            throw Self.mapped(error)
        }
    }

     
     
     
    public static func record(for payload: BackupRecordPayload, assetURL: URL) -> CKRecord {
        let record = CKRecord(
            recordType: BackupRecordSchema.recordType,
            recordID: CKRecord.ID(recordName: payload.installID)
        )
        record[BackupRecordSchema.kindField] = BackupRecordSchema.kindAuto as NSString
        record[BackupRecordSchema.archiveField] = CKAsset(fileURL: assetURL)
        record[BackupRecordSchema.exportedAtField] = payload.exportedAt as NSDate
        record[BackupRecordSchema.sourceDeviceField] = payload.sourceDevice as NSString
        record[BackupRecordSchema.sourceInstallIDField] = payload.installID as NSString
        record[BackupRecordSchema.schemaVersionField] = payload.schemaVersion as NSNumber
        return record
    }

    private func requireAccount() async throws {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw BackupRecordSinkError.unavailable(error.localizedDescription)
        }
        switch status {
        case .available: return
        case .noAccount: throw BackupRecordSinkError.noAccount
        default:
            throw BackupRecordSinkError.unavailable(
                "iCloud account status: \(CloudKitBackupRecordSource.name(of: status))"
            )
        }
    }

     
    public static func mapped(_ error: Error) -> BackupRecordSinkError {
        guard let ck = error as? CKError else { return .unavailable(error.localizedDescription) }
        switch ck.code {
        case .notAuthenticated:
            return .noAccount
        case .networkUnavailable, .networkFailure, .serviceUnavailable:
            return .offline(ck.localizedDescription)
        case .quotaExceeded:
            return .quotaExceeded
        case .requestRateLimited, .zoneBusy:
            return .rateLimited(retryAfterSeconds: ck.retryAfterSeconds ?? 30)
        default:
            return .unavailable(ck.localizedDescription)
        }
    }
}
