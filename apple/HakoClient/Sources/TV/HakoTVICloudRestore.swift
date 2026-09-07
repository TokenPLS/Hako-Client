import Foundation
import HakoClientKit

 
 
 
 
 
 
 
struct HakoTVICloudRestore: @unchecked Sendable {
     
    static let sourceInstallIDKey = "hako.tv.backup.sourceInstallID"

    enum Availability: Equatable {
         
        case unavailable
         
        case failed(String)
        case noBackups
        case ready([BackupRecordSummary])
    }

    struct Plan: Equatable {
        struct Item: Equatable, Identifiable {
            enum Disposition: Equatable {
                case restorable(overridesApplied: Bool)
                 
                 
                case skippedLocalResources(count: Int)
            }
            let id: String
            let label: String
            let sourceKind: String
            let disposition: Disposition
        }
        let summary: BackupRecordSummary
        let envelope: BackupEnvelope
        let items: [Item]

        var restorableCount: Int {
            items.filter { if case .restorable = $0.disposition { true } else { false } }.count
        }
    }

    struct Outcome: Equatable {
        let restored: [String]
        let skipped: [String]
         
        let activeSubscriptionID: HakoTVSubscription.ID?
    }

    let container: URL
    let defaults: UserDefaults
    let locator: @Sendable () -> BackupEnvelopeLocator?

    init(
        container: URL,
        defaults: UserDefaults = .standard,
        locator: @escaping @Sendable () -> BackupEnvelopeLocator? = HakoTVICloudRestore.cloudKitLocator
    ) {
        self.container = container
        self.defaults = defaults
        self.locator = locator
    }

     
    static func cloudKitLocator() -> BackupEnvelopeLocator? {
        BackupEnvelopeLocator(source: CloudKitBackupRecordSource(containerIdentifier: HakoAppIdentifiers.iCloudContainer))
    }

    static func availability(locator: BackupEnvelopeLocator?) async -> Availability {
        guard let locator else { return .unavailable }
        do {
            let backups = try await locator.backups()
            return backups.isEmpty ? .noBackups : .ready(backups)
        } catch BackupRecordSourceError.noAccount {
            return .unavailable
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func plan(summary: BackupRecordSummary, envelope: BackupEnvelope) -> Plan {
        let items = envelope.profiles.compactMap { profile -> Plan.Item? in
            let kind: String
            switch profile.source {
            case .url: kind = "url"
            case .file: kind = "file"
            case .clipboard: kind = "clipboard"
            case .unknown: kind = "unknown"
            }
            if envelope.publicResourceProfileIDs.contains(profile.id) {
                return Plan.Item(id: profile.id, label: profile.label, sourceKind: kind,
                                 disposition: .skippedLocalResources(count: 1))
            }
            guard let document = envelope.document(for: profile.id) else { return nil }
            return Plan.Item(id: profile.id, label: profile.label, sourceKind: kind,
                             disposition: .restorable(overridesApplied: document.overridesApplied))
        }
        return Plan(summary: summary, envelope: envelope, items: items)
    }

     
     
    func apply(_ plan: Plan, to store: inout HakoTVSubscriptionStore) throws -> Outcome {
        var restored: [String] = []
        var skipped: [String] = []
        var activeID: HakoTVSubscription.ID?
        let installID = plan.envelope.sourceInstallID ?? plan.summary.installID
        let device = plan.envelope.sourceDevice ?? plan.summary.sourceDevice ?? installID
        let exportedAt = plan.envelope.exportedAt ?? plan.summary.exportedAt ?? Date()
        for item in plan.items {
            guard case .restorable(let applied) = item.disposition,
                  let document = plan.envelope.document(for: item.id),
                  let profile = plan.envelope.profiles.first(where: { $0.id == item.id }) else {
                skipped.append(item.id)
                continue
            }
            let address: URL
            if case .url(let string) = profile.source, let url = URL(string: string), url.scheme != nil {
                address = url
            } else {
                address = HakoTVSubscription.placeholderURL(archiveProfileID: item.id)
            }
            let row = HakoTVSubscription(
                requestURL: address, name: profile.label, updatedAt: nil,
                restored: .init(
                    archiveProfileID: item.id,
                    sourceInstallID: installID,
                    sourceDevice: device,
                    exportedAt: exportedAt,
                    overridesApplied: applied,
                    sourceKind: item.sourceKind
                )
            )
            try HakoTVRestoredDocuments.write(
                document.yaml, container: container, profileID: HakoTVConfigPipeline.profileID(for: row)
            )
            store.restore(row)
            restored.append(item.id)
            if plan.envelope.activeProfileID == item.id { activeID = row.id }
        }
        if let activeID { store.use(activeID) }
        defaults.set(installID, forKey: Self.sourceInstallIDKey)
        return Outcome(restored: restored, skipped: skipped, activeSubscriptionID: activeID)
    }

     
     
     
     
    func refreshIfNewer(store: inout HakoTVSubscriptionStore) async throws -> Bool {
        guard let sourceID = defaults.string(forKey: Self.sourceInstallIDKey),
              let locator = locator() else { return false }
        let following = store.followingAutoBackup
        guard let newest = following.compactMap({ $0.restored?.exportedAt }).max() else { return false }
        guard let summary = try await locator.backups().first(where: { $0.installID == sourceID }),
              let listedAt = summary.exportedAt, listedAt > newest else { return false }
        let envelope = try await locator.read(summary)
        guard let exportedAt = envelope.exportedAt, exportedAt > newest else { return false }
        var changed = false
        for row in following {
            guard let origin = row.restored,
                  let document = envelope.document(for: origin.archiveProfileID), document.overridesApplied,
                  let profile = envelope.profiles.first(where: { $0.id == origin.archiveProfileID }) else { continue }
            try HakoTVRestoredDocuments.write(
                document.yaml, container: container, profileID: HakoTVConfigPipeline.profileID(for: row)
            )
            store.restore(HakoTVSubscription(
                requestURL: row.requestURL, name: profile.label, updatedAt: row.updatedAt,
                restored: .init(
                    archiveProfileID: origin.archiveProfileID,
                    sourceInstallID: origin.sourceInstallID,
                    sourceDevice: envelope.sourceDevice ?? origin.sourceDevice,
                    exportedAt: exportedAt,
                    overridesApplied: true,
                    sourceKind: origin.sourceKind
                )
            ))
            changed = true
        }
        return changed
    }
}
