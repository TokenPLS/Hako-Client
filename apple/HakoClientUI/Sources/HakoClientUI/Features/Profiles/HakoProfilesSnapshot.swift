import Foundation
import HakoClientKit

public enum HakoProfileSourceKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case remote
    case file
    case clipboard
}

public struct HakoProfileSubscriptionSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let uploadBytes: Int64
    public let downloadBytes: Int64
    public let totalBytes: Int64
    public let expiration: Date?

    public init(
        uploadBytes: Int64,
        downloadBytes: Int64,
        totalBytes: Int64,
        expiration: Date? = nil
    ) {
        self.uploadBytes = max(0, uploadBytes)
        self.downloadBytes = max(0, downloadBytes)
        self.totalBytes = max(0, totalBytes)
        self.expiration = expiration
    }

    public var usedBytes: Int64 {
        let (sum, overflow) = uploadBytes.addingReportingOverflow(
            downloadBytes
        )
        return overflow ? Int64.max : sum
    }

    public var usageFraction: Double? {
        guard totalBytes > 0 else { return nil }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

 
 
 
public struct HakoProfileFeatureAvailabilitySnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let canRename: Bool
    public let canSync: Bool
    public let canConfigureSubscription: Bool
    public let canCopySubscriptionLink: Bool
    public let canDuplicate: Bool
    public let canExport: Bool
    public let canOpenRuntimePreview: Bool
    public let canRestoreLastKnownGood: Bool

    public init(
        canRename: Bool = true,
        canSync: Bool = true,
        canConfigureSubscription: Bool = true,
        canCopySubscriptionLink: Bool = true,
        canDuplicate: Bool = true,
        canExport: Bool = true,
        canOpenRuntimePreview: Bool = true,
        canRestoreLastKnownGood: Bool = false
    ) {
        self.canRename = canRename
        self.canSync = canSync
        self.canConfigureSubscription = canConfigureSubscription
        self.canCopySubscriptionLink = canCopySubscriptionLink
        self.canDuplicate = canDuplicate
        self.canExport = canExport
        self.canOpenRuntimePreview = canOpenRuntimePreview
        self.canRestoreLastKnownGood = canRestoreLastKnownGood
    }

    public static let full = HakoProfileFeatureAvailabilitySnapshot()
}

public struct HakoProfileSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: Profile.ID
    public let label: String
    public let source: HakoProfileSourceKind
    public let sourceSummary: HakoDisplayText
    public let subscription: HakoProfileSubscriptionSnapshot?
    public let lastUpdatedAt: Date?
    public let autoUpdate: Bool
    public let updateIntervalHours: Int
    public let isCurrent: Bool
    public let isBusy: Bool
    public let canEditSource: Bool
    public let canDelete: Bool
    public let deleteSubtitle: HakoDisplayText
    public let runtimeSummary: HakoDisplayText
    public let requiresPlaintextExportConfirmation: Bool
    public let featureAvailability:
        HakoProfileFeatureAvailabilitySnapshot?
     
     
    public let heldBackUpdates: [HakoProfileHeldBackUpdate]

    public init(
        id: Profile.ID,
        label: String,
        source: HakoProfileSourceKind,
        sourceSummary: HakoDisplayText,
        subscription: HakoProfileSubscriptionSnapshot? = nil,
        lastUpdatedAt: Date? = nil,
        autoUpdate: Bool = false,
        updateIntervalHours: Int = 12,
        isCurrent: Bool = false,
        isBusy: Bool = false,
        canEditSource: Bool = false,
        canDelete: Bool = true,
        deleteSubtitle: HakoDisplayText = "Remove this profile from Clash",
        runtimeSummary: HakoDisplayText = "Local cache · read-only",
        requiresPlaintextExportConfirmation: Bool = false,
        featureAvailability:
            HakoProfileFeatureAvailabilitySnapshot? = nil,
        heldBackUpdates: [HakoProfileHeldBackUpdate] = []
    ) {
        self.id = id
        self.heldBackUpdates = heldBackUpdates
        self.label = String(label.prefix(256))
        self.source = source
        self.sourceSummary = sourceSummary.bounded(to: 256)
        self.subscription = subscription
        self.lastUpdatedAt = lastUpdatedAt
        self.autoUpdate = autoUpdate
        self.updateIntervalHours = min(max(updateIntervalHours, 1), 168)
        self.isCurrent = isCurrent
        self.isBusy = isBusy
        self.canEditSource = canEditSource
        self.canDelete = canDelete
        self.deleteSubtitle = deleteSubtitle.bounded(to: 256)
        self.runtimeSummary = runtimeSummary.bounded(to: 256)
        self.requiresPlaintextExportConfirmation =
            requiresPlaintextExportConfirmation
        self.featureAvailability = featureAvailability
    }

    public var canRename: Bool {
        featureAvailability?.canRename ?? true
    }

    public var canSync: Bool {
        featureAvailability?.canSync ?? true
    }

    public var canConfigureSubscription: Bool {
        featureAvailability?.canConfigureSubscription ?? true
    }

    public var canCopySubscriptionLink: Bool {
        featureAvailability?.canCopySubscriptionLink ?? true
    }

    public var canDuplicate: Bool {
        featureAvailability?.canDuplicate ?? true
    }

    public var canExport: Bool {
        featureAvailability?.canExport ?? true
    }

    public var canOpenRuntimePreview: Bool {
        featureAvailability?.canOpenRuntimePreview ?? true
    }

    public var canRestoreLastKnownGood: Bool {
        featureAvailability?.canRestoreLastKnownGood ?? false
    }
}

public struct HakoProfilesFailureSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let message: HakoDisplayText
    public let canRetry: Bool

    public init(message: HakoDisplayText, canRetry: Bool = false) {
        self.message = message
        self.canRetry = canRetry
    }
}

public enum HakoProfileBatchUpdateState:
    String,
    Codable,
    Equatable,
    Sendable
{
    case updated
    case unchanged
    case failed

    public var title: String {
        switch self {
        case .updated:
            "Updated"
        case .unchanged:
            "Up to Date"
        case .failed:
            "Failed"
        }
    }
}

public struct HakoProfileBatchItemSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: Profile.ID
    public let label: String
    public let state: HakoProfileBatchUpdateState
    public let message: String
    public let diagnosticCode: String?

    public init(
        id: Profile.ID,
        label: String,
        state: HakoProfileBatchUpdateState,
        message: String,
        diagnosticCode: String? = nil
    ) {
        self.id = id
        self.label = String(label.prefix(256))
        self.state = state
        self.message = String(message.prefix(512))
        self.diagnosticCode = diagnosticCode.map {
            String($0.prefix(128))
        }
    }
}

public struct HakoProfileBatchReportSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: UUID
    public let title: String
    public let expectedCount: Int
    public let items: [HakoProfileBatchItemSnapshot]
    public let wasCancelled: Bool
    public let isRunning: Bool

    public init(
        id: UUID,
        title: String,
        expectedCount: Int,
        items: [HakoProfileBatchItemSnapshot],
        wasCancelled: Bool = false,
        isRunning: Bool = false
    ) {
        self.id = id
        self.title = String(title.prefix(160))
        self.expectedCount = max(0, expectedCount)
        self.items = Array(items.prefix(512))
        self.wasCancelled = wasCancelled
        self.isRunning = isRunning
    }

    public var updatedCount: Int {
        items.filter { $0.state == .updated }.count
    }

    public var unchangedCount: Int {
        items.filter { $0.state == .unchanged }.count
    }

    public var failedCount: Int {
        items.filter { $0.state == .failed }.count
    }

     
     
     
     
     
     
    public var summaryParts: [HakoDisplayText] {
        var parts: [HakoDisplayText] = [
            .format("%@ updated", [String(updatedCount)]),
            .format("%@ unchanged", [String(unchangedCount)]),
        ]
        if failedCount > 0 {
            parts.append(.format("%@ failed", [String(failedCount)]))
        }
        if wasCancelled {
            parts.append("cancelled")
        }
        return parts
    }
}

public struct HakoProfilesFeatureAvailabilitySnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let canCreateEmpty: Bool
    public let canImport: Bool
    public let canBackup: Bool
    public let canReorder: Bool
    public let canSyncAll: Bool

    public init(
        canCreateEmpty: Bool = true,
        canImport: Bool = true,
        canBackup: Bool = true,
        canReorder: Bool = true,
        canSyncAll: Bool = true
    ) {
        self.canCreateEmpty = canCreateEmpty
        self.canImport = canImport
        self.canBackup = canBackup
        self.canReorder = canReorder
        self.canSyncAll = canSyncAll
    }

    public static let full = HakoProfilesFeatureAvailabilitySnapshot()
}

public struct HakoProfilesSnapshot: Codable, Equatable, Sendable {
    public let profiles: [HakoProfileSnapshot]
    public let failure: HakoProfilesFailureSnapshot?
    public let statusMessage: HakoDisplayText
    public let batchReport: HakoProfileBatchReportSnapshot?
    public let featureAvailability:
        HakoProfilesFeatureAvailabilitySnapshot?

    public init(
        profiles: [HakoProfileSnapshot] = [],
        failure: HakoProfilesFailureSnapshot? = nil,
        statusMessage: HakoDisplayText = .copy(""),
        batchReport: HakoProfileBatchReportSnapshot? = nil,
        featureAvailability:
            HakoProfilesFeatureAvailabilitySnapshot? = nil
    ) {
        self.profiles = Array(profiles.prefix(1_024))
        self.failure = failure
        self.statusMessage = statusMessage.bounded(to: 512)
        self.batchReport = batchReport
        self.featureAvailability = featureAvailability
    }

    public func profile(id: Profile.ID) -> HakoProfileSnapshot? {
        profiles.first { $0.id == id }
    }

    public var canCreateEmpty: Bool {
        featureAvailability?.canCreateEmpty ?? true
    }

    public var canImport: Bool {
        featureAvailability?.canImport ?? true
    }

    public var canBackup: Bool {
        featureAvailability?.canBackup ?? true
    }

    public var canReorder: Bool {
        featureAvailability?.canReorder ?? true
    }

    public var canSyncAll: Bool {
        featureAvailability?.canSyncAll ?? true
    }

    public static let empty = HakoProfilesSnapshot()
}


 
 
 
 
public struct HakoProfileHeldBackUpdate: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Change: String, Codable, Sendable { case changed, added, removed }
    public let keyPath: String
    public let change: Change
     
     
    public let newValue: String?
    public let appValue: String

    public var id: String { keyPath }
    public init(keyPath: String, change: Change, newValue: String?, appValue: String) {
        self.keyPath = keyPath
        self.change = change
        self.newValue = newValue
        self.appValue = appValue
    }
}
