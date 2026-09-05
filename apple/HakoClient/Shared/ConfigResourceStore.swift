import CryptoKit
import Darwin
import Foundation

struct StoredConfiguration: Equatable {
    let profileID: String
    let revision: String
    let data: Data
    let recoveredFromLastKnownGood: Bool

    var text: String? { String(data: data, encoding: .utf8) }
}

struct InstalledConfiguration: Equatable {
    let profileID: String
    let revision: String
    let sha256: String
    let bytes: Int
    let reusedExistingRevision: Bool
    let activated: Bool
}

struct ActiveConfigurationPointer: Codable, Equatable {
    let profileID: String
    let revision: String
}

 
 
 
 
 
struct SuspensionShield {
    let begin: () -> Any?
    let end: (Any?) -> Void

    static let noop = SuspensionShield(begin: { nil }, end: { _ in })
}

 
 
 
struct ConfigurationCandidate: Equatable {
    let profileID: String
    let revision: String
    let stagingDirectory: URL
    let publishedDirectory: URL

    var stagingProvidersDirectory: URL {
        stagingDirectory.appendingPathComponent("providers", isDirectory: true)
    }

    var publishedProvidersDirectory: URL {
        publishedDirectory.appendingPathComponent("providers", isDirectory: true)
    }
}

enum ConfigResourceStoreError: LocalizedError {
    case invalidLimit
    case invalidProfileID
    case emptyConfiguration
    case configurationTooLarge(limit: Int)
    case configurationIsNotUTF8
    case configurationContainsNUL
    case unsafeFilesystemEntry(String)
    case lockTimedOut
    case noValidConfiguration
    case invalidRevision
    case corruptRevision
    case invalidActivation
    case activeConfigurationChanged
    case posix(operation: String, code: Int32)
    case simulatedCrash(ConfigResourceStoreFaultPoint)

    var errorDescription: String? {
        switch self {
        case .invalidLimit:
            return "Configuration store limits are invalid"
        case .invalidProfileID:
            return "Configuration profile ID is invalid"
        case .emptyConfiguration:
            return "Configuration is empty"
        case let .configurationTooLarge(limit):
            return "Configuration exceeds the \(limit)-byte limit"
         
         
         
        case .configurationIsNotUTF8, .configurationContainsNUL:
            return "That configuration is not a text file. Choose a different one."
        case let .unsafeFilesystemEntry(name):
            return "Configuration store entry is unsafe: \(name)"
        case .lockTimedOut:
            return "The configuration is in use. Try again in a moment."
        case .noValidConfiguration:
            return "No valid active or last-known-good configuration is available"
        case .invalidRevision:
            return "Configuration revision is invalid"
        case .corruptRevision:
            return "The saved configuration is damaged. Import it again."
        case .invalidActivation:
            return "The configuration could not be activated. Try again."
        case .activeConfigurationChanged:
            return "The active configuration changed while a replacement was being prepared"
        case let .posix(operation, code):
            return "Configuration store \(operation) failed (errno \(code))"
        case let .simulatedCrash(point):
            return "Simulated configuration store crash at \(point.rawValue)"
        }
    }
}

enum ConfigResourceStoreFaultPoint: String {
    case revisionDurable
    case revisionPublished
    case currentCommitted
}

 
 
 
 
 
final class ConfigResourceStore {
    static let defaultMaximumConfigurationBytes = 4 * 1024 * 1024
    static let defaultMaximumRevisions = 5
    static let defaultProfileID = "00000000-0000-0000-0000-000000000000"
    static let abandonedCandidateAge: TimeInterval = 24 * 60 * 60
    static let maximumCandidateResources = 256
    static let maximumCandidateResourceBytes = 16 * 1024 * 1024

    private struct Manifest: Codable, Equatable {
        let schemaVersion: Int
        let profileID: String
        let revision: String
        let configurationBytes: Int
        let configurationSHA256: String
        let createdAtUnixMilliseconds: Int64
        let resources: [ResourceDigest]?
    }

    private struct ResourceDigest: Codable, Equatable {
        let path: String
        let bytes: Int
        let sha256: String
    }

    private struct Pointer: Codable, Equatable {
        let schemaVersion: Int
        let profileID: String
        let revision: String
    }

    private enum Name {
        static let working = "working"
        static let store = "store"
        static let profiles = "profiles"
        static let revisions = "revisions"
        static let activeDirectory = "active"
        static let lock = ".configuration-store.lock"
        static let activePointer = "active.json"
        static let lastKnownGoodPointer = "last-known-good.json"
        static let profileCurrent = "current"
        static let resolvedConfiguration = "config.resolved.yaml"
        static let compatibilityConfiguration = "config.yaml"
        static let manifest = "manifest.json"
        static let temporaryPrefix = ".tmp-"
    }

    private let containerURL: URL
    private let workingURL: URL
    private let storeURL: URL
    private let profilesURL: URL
    private let activeDirectoryURL: URL
    private let lockURL: URL
    private let maximumConfigurationBytes: Int
    private let maximumRevisions: Int
    private let lockTimeout: TimeInterval
    private let faultInjector: ((ConfigResourceStoreFaultPoint) -> Bool)?
    private let fileManager: FileManager

    var activeConfigURL: URL {
        activeDirectoryURL.appendingPathComponent(Name.compatibilityConfiguration)
    }

    init(
        containerURL: URL,
        maximumConfigurationBytes: Int = ConfigResourceStore.defaultMaximumConfigurationBytes,
        maximumRevisions: Int = ConfigResourceStore.defaultMaximumRevisions,
        lockTimeout: TimeInterval = 2,
        fileManager: FileManager = .default,
        faultInjector: ((ConfigResourceStoreFaultPoint) -> Bool)? = nil
    ) throws {
        guard maximumConfigurationBytes > 0,
              maximumRevisions >= 2,
              lockTimeout > 0 else {
            throw ConfigResourceStoreError.invalidLimit
        }
        self.containerURL = containerURL.standardizedFileURL
        workingURL = self.containerURL.appendingPathComponent(Name.working, isDirectory: true)
        storeURL = workingURL.appendingPathComponent(Name.store, isDirectory: true)
        profilesURL = storeURL.appendingPathComponent(Name.profiles, isDirectory: true)
        activeDirectoryURL = workingURL.appendingPathComponent(
            Name.activeDirectory,
            isDirectory: true
        )
        lockURL = workingURL.appendingPathComponent(Name.lock)
        self.maximumConfigurationBytes = maximumConfigurationBytes
        self.maximumRevisions = maximumRevisions
        self.lockTimeout = lockTimeout
        self.fileManager = fileManager
        self.faultInjector = faultInjector
        try verifyContainerDirectory()
    }

     
     
    @discardableResult
    func install(
        _ data: Data,
        profileID: String = ConfigResourceStore.defaultProfileID,
        activate: Bool = true,
        markAsLastKnownGood: Bool = false
    ) throws -> InstalledConfiguration {
        try validateProfileID(profileID)
        try validateConfiguration(data)
        guard activate || !markAsLastKnownGood else {
            throw ConfigResourceStoreError.invalidActivation
        }
        return try withExclusiveLock {
            try prepareLayout()
            let profile = try prepareProfile(profileID)
            let digest = Self.sha256(data)
            let revision: String
            let reused: Bool

            if let currentRevision = try? readProfileCurrent(profile),
               let current = try? loadRevision(
                   Pointer(schemaVersion: 1, profileID: profileID, revision: currentRevision)
               ),
               Self.sha256(current.data) == digest {
                revision = currentRevision
                reused = true
            } else {
                revision = try publishRevision(
                    data,
                    digest: digest,
                    profileID: profileID,
                    profile: profile
                )
                reused = false
                try writeProfileCurrent(profile, revision: revision)
            }

            let pointer = Pointer(schemaVersion: 1, profileID: profileID, revision: revision)
            if activate {
                try commitActive(pointer, data: data)
                if markAsLastKnownGood {
                    try writePointer(Name.lastKnownGoodPointer, pointer: pointer)
                }
            }
            try pruneProfile(profileID)
            return InstalledConfiguration(
                profileID: profileID,
                revision: revision,
                sha256: digest,
                bytes: data.count,
                reusedExistingRevision: reused,
                activated: activate
            )
        }
    }

    @discardableResult
    func activate(
        profileID: String,
        revision: String,
        markAsLastKnownGood: Bool = false
    ) throws -> StoredConfiguration {
        try validateProfileID(profileID)
        guard Self.isValidRevision(revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        return try withExclusiveLock {
            try prepareLayout()
            let pointer = Pointer(schemaVersion: 1, profileID: profileID, revision: revision)
            let loaded = try loadRevision(pointer)
            try commitActive(pointer, data: loaded.data)
            if markAsLastKnownGood {
                try writePointer(Name.lastKnownGoodPointer, pointer: pointer)
            }
            return loaded
        }
    }

     
     
     
    func beginCandidate(profileID: String) throws -> ConfigurationCandidate {
        try validateProfileID(profileID)
        return try withExclusiveLock {
            try prepareLayout()
            let profile = try prepareProfile(profileID)
            let revision = UUID().uuidString.lowercased()
            let staging = profile.revisions.appendingPathComponent(
                Name.temporaryPrefix + revision,
                isDirectory: true
            )
            let published = profile.revisions.appendingPathComponent(revision, isDirectory: true)
            try ensureNewDirectory(staging)
            let providers = staging.appendingPathComponent("providers", isDirectory: true)
            try ensureNewDirectory(providers)
            try syncDirectory(staging)
            return ConfigurationCandidate(
                profileID: profileID,
                revision: revision,
                stagingDirectory: staging,
                publishedDirectory: published
            )
        }
    }

     
     
     
    @discardableResult
    func publishAndActivate(
        _ candidate: ConfigurationCandidate,
        finalData: Data
    ) throws -> ActiveConfigurationPointer? {
        try publishAndActivate(
            candidate,
            finalData: finalData,
            expectation: .unconstrained
        )
    }

     
     
     
     
    func publishAndActivateIfCurrentMatches(
        _ candidate: ConfigurationCandidate,
        finalData: Data,
        expectedActive: ActiveConfigurationPointer?
    ) throws -> ActiveConfigurationPointer? {
        try publishAndActivate(
            candidate,
            finalData: finalData,
            expectation: .matches(expectedActive)
        )
    }

    private enum ActiveExpectation {
        case unconstrained
        case matches(ActiveConfigurationPointer?)
    }

    private func publishAndActivate(
        _ candidate: ConfigurationCandidate,
        finalData: Data,
        expectation: ActiveExpectation
    ) throws -> ActiveConfigurationPointer? {
        try validateProfileID(candidate.profileID)
        guard Self.isValidRevision(candidate.revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        try validateConfiguration(finalData)
        return try withExclusiveLock {
            try prepareLayout()
            let previousPointer = try? readPointer(Name.activePointer)
            let previous = previousPointer.flatMap { pointer -> ActiveConfigurationPointer? in
                guard (try? loadRevision(pointer)) != nil else { return nil }
                return ActiveConfigurationPointer(
                    profileID: pointer.profileID,
                    revision: pointer.revision
                )
            }
            if case .matches(let expected) = expectation,
               previous != expected {
                throw ConfigResourceStoreError.activeConfigurationChanged
            }
            let expected = candidateFor(profileID: candidate.profileID, revision: candidate.revision)
            guard candidate == expected,
                  try entryType(at: candidate.stagingDirectory) == S_IFDIR,
                  !fileManager.fileExists(atPath: candidate.publishedDirectory.path) else {
                throw ConfigResourceStoreError.invalidRevision
            }
            try writeDurableFile(
                finalData,
                to: candidate.stagingDirectory.appendingPathComponent(Name.resolvedConfiguration)
            )
            let manifest = Manifest(
                schemaVersion: 1,
                profileID: candidate.profileID,
                revision: candidate.revision,
                configurationBytes: finalData.count,
                configurationSHA256: Self.sha256(finalData),
                createdAtUnixMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
                resources: try validateSyncAndDigestCandidateResources(candidate)
            )
            try writeDurableFile(
                try encode(manifest),
                to: candidate.stagingDirectory.appendingPathComponent(Name.manifest)
            )
            try syncDirectory(candidate.stagingDirectory)
            try renameItem(from: candidate.stagingDirectory, to: candidate.publishedDirectory)
            try syncDirectory(candidate.publishedDirectory.deletingLastPathComponent())

            let profile = profilePaths(candidate.profileID)
            try writeProfileCurrent(profile, revision: candidate.revision)
            let pointer = Pointer(
                schemaVersion: 1,
                profileID: candidate.profileID,
                revision: candidate.revision
            )
            try commitActive(pointer, data: finalData)
            try pruneProfile(candidate.profileID)
            return previous
        }
    }

    func discard(_ candidate: ConfigurationCandidate) throws {
        try withExclusiveLock {
            let expected = candidateFor(profileID: candidate.profileID, revision: candidate.revision)
            guard candidate == expected else { throw ConfigResourceStoreError.invalidRevision }
            if fileManager.fileExists(atPath: candidate.stagingDirectory.path) {
                try fileManager.removeItem(at: candidate.stagingDirectory)
                try syncDirectory(candidate.stagingDirectory.deletingLastPathComponent())
            }
        }
    }

    func activePointer() throws -> ActiveConfigurationPointer? {
        try withExclusiveLock {
            try prepareLayout()
            guard let pointer = try? readPointer(Name.activePointer),
                  (try? loadRevision(pointer)) != nil else { return nil }
            return ActiveConfigurationPointer(
                profileID: pointer.profileID,
                revision: pointer.revision
            )
        }
    }

     
     
     
     
     
     
     
     
    func activeIdentity() throws -> ActiveConfigurationPointer? {
        try withExclusiveLock {
            guard let pointer = try? readPointer(Name.activePointer) else {
                return nil
            }
            return ActiveConfigurationPointer(
                profileID: pointer.profileID,
                revision: pointer.revision
            )
        }
    }

    func lastKnownGoodPointer() throws -> ActiveConfigurationPointer? {
        try withExclusiveLock {
            try prepareLayout()
            guard let pointer = try? readPointer(Name.lastKnownGoodPointer),
                  (try? loadRevision(pointer)) != nil else { return nil }
            return ActiveConfigurationPointer(
                profileID: pointer.profileID,
                revision: pointer.revision
            )
        }
    }

     
     
     
     
    @discardableResult
    func activateIfCurrentMatches(
        _ expected: ActiveConfigurationPointer?,
        replacement: ActiveConfigurationPointer,
        markAsLastKnownGood: Bool = false
    ) throws -> Bool {
        try validateProfileID(replacement.profileID)
        guard Self.isValidRevision(replacement.revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        return try withExclusiveLock {
            try prepareLayout()
            let current: ActiveConfigurationPointer?
            if let pointer = try? readPointer(Name.activePointer),
               (try? loadRevision(pointer)) != nil {
                current = ActiveConfigurationPointer(
                    profileID: pointer.profileID,
                    revision: pointer.revision
                )
            } else {
                current = nil
            }
            guard current == expected else { return false }
            let pointer = Pointer(
                schemaVersion: 1,
                profileID: replacement.profileID,
                revision: replacement.revision
            )
            let loaded = try loadRevision(pointer)
            try commitActive(pointer, data: loaded.data)
            if markAsLastKnownGood {
                try writePointer(Name.lastKnownGoodPointer, pointer: pointer)
            }
            try pruneProfile(replacement.profileID)
            return true
        }
    }

    func rollback(to pointer: ActiveConfigurationPointer) throws {
        _ = try activate(profileID: pointer.profileID, revision: pointer.revision)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func activeProvidersDirectory() throws -> URL? {
        guard let pointer = try activeIdentity() else { return nil }
        return providersDirectory(profileID: pointer.profileID, revision: pointer.revision)
    }

     
     
     
     
     
     
     
     
    func newestProvidersDirectory(profileID: String) -> URL? {
        guard (try? validateProfileID(profileID)) != nil else { return nil }
        let revisions = profilePaths(profileID).revisions
        guard let entries = try? fileManager.contentsOfDirectory(
            at: revisions,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return entries
            .filter { Self.isValidRevision($0.lastPathComponent) }
            .map { ($0.appendingPathComponent("providers", isDirectory: true),
                    (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate ?? .distantPast) }
            .filter { fileManager.fileExists(atPath: $0.0.path) }
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

     
     
     
     
     
     
     
     
     
    func providersDirectory(profileID: String, revision: String) -> URL? {
        guard (try? validateProfileID(profileID)) != nil,
              Self.isValidRevision(revision) else { return nil }
        return profilePaths(profileID).revisions
            .appendingPathComponent(revision, isDirectory: true)
            .appendingPathComponent("providers", isDirectory: true)
    }

     
     
    func loadConfiguration(profileID: String, revision: String) throws -> StoredConfiguration {
        try validateProfileID(profileID)
        guard Self.isValidRevision(revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        return try withExclusiveLock {
            try prepareLayout()
            return try loadRevision(
                Pointer(schemaVersion: 1, profileID: profileID, revision: revision)
            )
        }
    }

     
     
     
    func restoreActive(_ pointer: ActiveConfigurationPointer?) throws {
        if let pointer {
            try rollback(to: pointer)
            return
        }
        try withExclusiveLock {
            try prepareLayout()
            for url in [
                storeURL.appendingPathComponent(Name.activePointer),
                activeDirectoryURL.appendingPathComponent(Name.compatibilityConfiguration),
                activeDirectoryURL.appendingPathComponent(Name.manifest),
                containerURL.appendingPathComponent(Name.compatibilityConfiguration),
            ] where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                try syncDirectory(url.deletingLastPathComponent())
            }
        }
    }

    func loadCurrent() throws -> StoredConfiguration {
        try withExclusiveLock {
            try prepareLayout()
            let hasVersionedPointer = fileManager.fileExists(
                atPath: storeURL.appendingPathComponent(Name.activePointer).path
            ) || fileManager.fileExists(
                atPath: storeURL.appendingPathComponent(Name.lastKnownGoodPointer).path
            )
            if let active = try? readPointer(Name.activePointer),
               let loaded = try? loadRevision(active) {
                return loaded
            }
            if let lastKnownGood = try? readPointer(Name.lastKnownGoodPointer),
               let loaded = try? loadRevision(lastKnownGood) {
                return StoredConfiguration(
                    profileID: loaded.profileID,
                    revision: loaded.revision,
                    data: loaded.data,
                    recoveredFromLastKnownGood: true
                )
            }
            if !hasVersionedPointer,
               let legacy = try loadLegacyConfigurationIfPresent() {
                return legacy
            }
            throw ConfigResourceStoreError.noValidConfiguration
        }
    }

     
     
    @discardableResult
    func recoverCurrentFromLastKnownGood() throws -> StoredConfiguration {
        try withExclusiveLock {
            try prepareLayout()
            if let active = try? readPointer(Name.activePointer),
               let loaded = try? loadRevision(active) {
                return loaded
            }
            let fallback = try readPointer(Name.lastKnownGoodPointer)
            let loaded = try loadRevision(fallback)
            try commitActive(fallback, data: loaded.data)
            return StoredConfiguration(
                profileID: loaded.profileID,
                revision: loaded.revision,
                data: loaded.data,
                recoveredFromLastKnownGood: true
            )
        }
    }

    func markLastKnownGood(profileID: String, revision: String) throws {
        try validateProfileID(profileID)
        guard Self.isValidRevision(revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        try withExclusiveLock {
            try prepareLayout()
            let pointer = Pointer(schemaVersion: 1, profileID: profileID, revision: revision)
            _ = try loadRevision(pointer)
            try writePointer(Name.lastKnownGoodPointer, pointer: pointer)
            try pruneProfile(profileID)
        }
    }

    func currentRevision() throws -> String? {
        try withExclusiveLock {
            try prepareLayout()
            return try? readPointer(Name.activePointer).revision
        }
    }

    func currentProfileID() throws -> String? {
        try withExclusiveLock {
            try prepareLayout()
            return try? readPointer(Name.activePointer).profileID
        }
    }

    private struct ProfilePaths {
        let root: URL
        let revisions: URL
    }

    private func profilePaths(_ profileID: String) -> ProfilePaths {
        let root = profilesURL.appendingPathComponent(profileID, isDirectory: true)
        return ProfilePaths(
            root: root,
            revisions: root.appendingPathComponent(Name.revisions, isDirectory: true)
        )
    }

    private func candidateFor(profileID: String, revision: String) -> ConfigurationCandidate {
        let revisions = profilePaths(profileID).revisions
        return ConfigurationCandidate(
            profileID: profileID,
            revision: revision,
            stagingDirectory: revisions.appendingPathComponent(
                Name.temporaryPrefix + revision,
                isDirectory: true
            ),
            publishedDirectory: revisions.appendingPathComponent(revision, isDirectory: true)
        )
    }

    private func prepareLayout() throws {
        try ensureDirectory(workingURL)
         
         
         
         
        var protectedWorkingURL = workingURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try protectedWorkingURL.setResourceValues(resourceValues)
        try ensureDirectory(storeURL)
        try ensureDirectory(profilesURL)
        try ensureDirectory(activeDirectoryURL)
        try removeAbandonedTemporaryEntries(in: storeURL)
        try removeAbandonedTemporaryEntries(in: activeDirectoryURL)
    }

    private func prepareProfile(_ profileID: String) throws -> ProfilePaths {
        let profile = profilePaths(profileID)
        try ensureDirectory(profile.root)
        try ensureDirectory(profile.revisions)
        try removeAbandonedTemporaryEntries(
            in: profile.root,
            olderThan: Self.abandonedCandidateAge
        )
        try removeAbandonedTemporaryEntries(
            in: profile.revisions,
            olderThan: Self.abandonedCandidateAge
        )
        return profile
    }

    private func publishRevision(
        _ data: Data,
        digest: String,
        profileID: String,
        profile: ProfilePaths
    ) throws -> String {
        let revision = UUID().uuidString.lowercased()
        let temporary = profile.revisions.appendingPathComponent(
            Name.temporaryPrefix + revision,
            isDirectory: true
        )
        let published = profile.revisions.appendingPathComponent(revision, isDirectory: true)
        try ensureNewDirectory(temporary)
        var removeTemporary = true
        defer {
            if removeTemporary { try? fileManager.removeItem(at: temporary) }
        }
        try writeDurableFile(
            data,
            to: temporary.appendingPathComponent(Name.resolvedConfiguration)
        )
        let manifest = Manifest(
            schemaVersion: 1,
            profileID: profileID,
            revision: revision,
            configurationBytes: data.count,
            configurationSHA256: digest,
            createdAtUnixMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
            resources: nil
        )
        try writeDurableFile(
            try encode(manifest),
            to: temporary.appendingPathComponent(Name.manifest)
        )
        try syncDirectory(temporary)
        try inject(.revisionDurable)
        try renameItem(from: temporary, to: published)
        removeTemporary = false
        try syncDirectory(profile.revisions)
        try inject(.revisionPublished)
        return revision
    }

    private func commitActive(_ pointer: Pointer, data: Data) throws {
        try writePointer(Name.activePointer, pointer: pointer)
        try inject(.currentCommitted)
         
         
         
         
         
        try? writeAtomicFile(
            data,
            to: activeDirectoryURL.appendingPathComponent(Name.compatibilityConfiguration)
        )
        try? writeAtomicFile(
            try encode(pointer),
            to: activeDirectoryURL.appendingPathComponent(Name.manifest)
        )
        try? writeAtomicFile(
            data,
            to: containerURL.appendingPathComponent(Name.compatibilityConfiguration)
        )
    }

    private func loadRevision(_ pointer: Pointer) throws -> StoredConfiguration {
        guard pointer.schemaVersion == 1 else { throw ConfigResourceStoreError.invalidRevision }
        try validateProfileID(pointer.profileID)
        guard Self.isValidRevision(pointer.revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        let revisionURL = profilePaths(pointer.profileID).revisions
            .appendingPathComponent(pointer.revision, isDirectory: true)
        guard try entryType(at: revisionURL) == S_IFDIR else {
            throw ConfigResourceStoreError.corruptRevision
        }
        let manifest = try JSONDecoder().decode(
            Manifest.self,
            from: readBoundedFile(
                revisionURL.appendingPathComponent(Name.manifest),
                maximumBytes: 64 * 1024
            )
        )
        guard manifest.schemaVersion == 1,
              manifest.profileID == pointer.profileID,
              manifest.revision == pointer.revision,
              manifest.configurationBytes > 0,
              manifest.configurationBytes <= maximumConfigurationBytes,
              manifest.configurationSHA256.count == 64 else {
            throw ConfigResourceStoreError.corruptRevision
        }
        let data = try readBoundedFile(
            revisionURL.appendingPathComponent(Name.resolvedConfiguration),
            maximumBytes: maximumConfigurationBytes
        )
        guard data.count == manifest.configurationBytes,
              Self.sha256(data) == manifest.configurationSHA256 else {
            throw ConfigResourceStoreError.corruptRevision
        }
        for resource in manifest.resources ?? [] {
             
             
             
             
             
             
             
             
            guard resource.bytes >= 0,
                  resource.bytes <= Self.maximumCandidateResourceBytes,
                  resource.sha256.count == 64,
                  isSafeResourcePath(resource.path) else {
                throw ConfigResourceStoreError.corruptRevision
            }
            let resourceData = try readBoundedFile(
                revisionURL.appendingPathComponent(resource.path),
                maximumBytes: Self.maximumCandidateResourceBytes
            )
            guard resourceData.count == resource.bytes,
                  Self.sha256(resourceData) == resource.sha256 else {
                throw ConfigResourceStoreError.corruptRevision
            }
        }
        try validateConfiguration(data)
        return StoredConfiguration(
            profileID: pointer.profileID,
            revision: pointer.revision,
            data: data,
            recoveredFromLastKnownGood: false
        )
    }

    private func loadLegacyConfigurationIfPresent() throws -> StoredConfiguration? {
        let url = containerURL.appendingPathComponent(Name.compatibilityConfiguration)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try readBoundedFile(url, maximumBytes: maximumConfigurationBytes)
        try validateConfiguration(data)
        return StoredConfiguration(
            profileID: ConfigResourceStore.defaultProfileID,
            revision: "legacy-unversioned",
            data: data,
            recoveredFromLastKnownGood: false
        )
    }

    private func writeProfileCurrent(_ profile: ProfilePaths, revision: String) throws {
        guard Self.isValidRevision(revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        try writeAtomicFile(
            Data((revision + "\n").utf8),
            to: profile.root.appendingPathComponent(Name.profileCurrent)
        )
    }

    private func readProfileCurrent(_ profile: ProfilePaths) throws -> String {
        let data = try readBoundedFile(
            profile.root.appendingPathComponent(Name.profileCurrent),
            maximumBytes: 64
        )
        guard let revision = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            Self.isValidRevision(revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        return revision
    }

    private func writePointer(_ name: String, pointer: Pointer) throws {
        try validateProfileID(pointer.profileID)
        guard pointer.schemaVersion == 1, Self.isValidRevision(pointer.revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        try writeAtomicFile(try encode(pointer), to: storeURL.appendingPathComponent(name))
    }

    private func readPointer(_ name: String) throws -> Pointer {
        let pointer = try JSONDecoder().decode(
            Pointer.self,
            from: readBoundedFile(storeURL.appendingPathComponent(name), maximumBytes: 512)
        )
        try validateProfileID(pointer.profileID)
        guard pointer.schemaVersion == 1, Self.isValidRevision(pointer.revision) else {
            throw ConfigResourceStoreError.invalidRevision
        }
        return pointer
    }

    private func pruneProfile(_ profileID: String) throws {
        let profile = profilePaths(profileID)
        let profileCurrent = try? readProfileCurrent(profile)
        let active = try? readPointer(Name.activePointer)
        let lastKnownGood = try? readPointer(Name.lastKnownGoodPointer)
        var protected = Set([profileCurrent].compactMap { $0 })
        if active?.profileID == profileID { protected.insert(active!.revision) }
        if lastKnownGood?.profileID == profileID { protected.insert(lastKnownGood!.revision) }
        let entries = try fileManager.contentsOfDirectory(
            at: profile.revisions,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let revisions = entries.filter { Self.isValidRevision($0.lastPathComponent) }
        guard revisions.count > maximumRevisions else { return }
        let dated = revisions.map { url -> (URL, Date) in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        for item in dated where protected.count < maximumRevisions {
            protected.insert(item.0.lastPathComponent)
        }
        for url in revisions where !protected.contains(url.lastPathComponent) {
            try fileManager.removeItem(at: url)
        }
        try syncDirectory(profile.revisions)
    }

    private func validateSyncAndDigestCandidateResources(
        _ candidate: ConfigurationCandidate
    ) throws -> [ResourceDigest] {
        let directory = candidate.stagingProvidersDirectory
        guard try entryType(at: directory) == S_IFDIR else {
            throw ConfigResourceStoreError.corruptRevision
        }
        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard entries.count <= Self.maximumCandidateResources else {
            throw ConfigResourceStoreError.configurationTooLarge(
                limit: Self.maximumCandidateResources
            )
        }
        var digests: [ResourceDigest] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = entry.lastPathComponent
            guard isSafeResourcePath("providers/" + name),
                  try entryType(at: entry) == S_IFREG else {
                throw ConfigResourceStoreError.unsafeFilesystemEntry(name)
            }
            let data = try readBoundedFile(
                entry,
                maximumBytes: Self.maximumCandidateResourceBytes
            )
             
             
             
             
             
             
            let descriptor = open(entry.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            guard descriptor >= 0 else { throw posixError("open candidate resource") }
            defer { close(descriptor) }
            guard fsync(descriptor) == 0 else { throw posixError("fsync candidate resource") }
            digests.append(ResourceDigest(
                path: "providers/" + name,
                bytes: data.count,
                sha256: Self.sha256(data)
            ))
        }
        try syncDirectory(directory)
        return digests
    }

    private func isSafeResourcePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2 &&
            components[0] == "providers" &&
            !components[1].isEmpty &&
            components[1] != "." &&
            components[1] != ".." &&
            !components[1].contains("\\")
    }

    private func validateProfileID(_ value: String) throws {
        guard value.count == 36,
              UUID(uuidString: value) != nil,
              value == value.lowercased() else {
            throw ConfigResourceStoreError.invalidProfileID
        }
    }

    private func validateConfiguration(_ data: Data) throws {
        guard !data.isEmpty else { throw ConfigResourceStoreError.emptyConfiguration }
        guard data.count <= maximumConfigurationBytes else {
            throw ConfigResourceStoreError.configurationTooLarge(limit: maximumConfigurationBytes)
        }
        guard String(data: data, encoding: .utf8) != nil else {
            throw ConfigResourceStoreError.configurationIsNotUTF8
        }
         
         
         
        let containsNUL = data.withUnsafeBytes { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            return memchr(base, 0, buffer.count) != nil
        }
        guard !containsNUL else { throw ConfigResourceStoreError.configurationContainsNUL }
    }

    private func verifyContainerDirectory() throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: containerURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              try entryType(at: containerURL) == S_IFDIR else {
            throw ConfigResourceStoreError.unsafeFilesystemEntry(containerURL.lastPathComponent)
        }
         
    }

    private func ensureDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue, try entryType(at: url) == S_IFDIR else {
                throw ConfigResourceStoreError.unsafeFilesystemEntry(url.lastPathComponent)
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        guard chmod(url.path, mode_t(0o700)) == 0 else { throw posixError("chmod directory") }
        try applyFileProtection(url)
    }

    private func ensureNewDirectory(_ url: URL) throws {
        guard mkdir(url.path, mode_t(0o700)) == 0 else { throw posixError("mkdir revision") }
        try applyFileProtection(url)
    }

    private func entryType(at url: URL) throws -> mode_t {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw posixError("lstat") }
        return info.st_mode & mode_t(S_IFMT)
    }

    static var suspensionShield: SuspensionShield = .noop

     
     
     
     
     
    static var lockObserver: ((_ operation: String, _ waitMilliseconds: Double, _ heldMilliseconds: Double) -> Void)?

    private func withExclusiveLock<T>(operation: String = #function, _ body: () throws -> T) throws -> T {
        let entered = DispatchTime.now()
        let shieldToken = Self.suspensionShield.begin()
        defer { Self.suspensionShield.end(shieldToken) }
        try verifyContainerDirectory()
        try ensureDirectory(workingURL)
        let descriptor = open(lockURL.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw posixError("open lock") }
        defer { close(descriptor) }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else { throw posixError("chmod lock") }
        try applyFileProtection(lockURL)
        let deadline = Date().addingTimeInterval(lockTimeout)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN else { throw posixError("flock") }
            guard Date() < deadline else { throw ConfigResourceStoreError.lockTimedOut }
            usleep(10_000)
        }
        defer { flock(descriptor, LOCK_UN) }
        let acquired = DispatchTime.now()
         
         
         
         
        defer {
            if let observer = Self.lockObserver {
                let finished = DispatchTime.now()
                observer(
                    operation,
                    Double(acquired.uptimeNanoseconds - entered.uptimeNanoseconds) / 1_000_000,
                    Double(finished.uptimeNanoseconds - acquired.uptimeNanoseconds) / 1_000_000
                )
            }
        }
        return try body()
    }

    private func writeAtomicFile(_ data: Data, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(
            Name.temporaryPrefix + UUID().uuidString.lowercased()
        )
        var removeTemporary = true
        defer { if removeTemporary { try? fileManager.removeItem(at: temporary) } }
        try writeDurableFile(data, to: temporary)
        try renameItem(from: temporary, to: destination)
        removeTemporary = false
        try syncDirectory(destination.deletingLastPathComponent())
    }

    private func writeDurableFile(_ data: Data, to url: URL) throws {
        let descriptor = open(
            url.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw posixError("open temporary file") }
        var descriptorIsOpen = true
        defer { if descriptorIsOpen { close(descriptor) } }
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    base.advanced(by: offset),
                    rawBuffer.count - offset
                )
                guard written >= 0 else {
                    if errno == EINTR { continue }
                    throw posixError("write")
                }
                offset += written
            }
        }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else { throw posixError("chmod file") }
        guard fsync(descriptor) == 0 else { throw posixError("fsync file") }
        guard close(descriptor) == 0 else { throw posixError("close file") }
        descriptorIsOpen = false
        try applyFileProtection(url)
    }

    private func readBoundedFile(_ url: URL, maximumBytes: Int) throws -> Data {
        guard try entryType(at: url) == S_IFREG else {
            throw ConfigResourceStoreError.unsafeFilesystemEntry(url.lastPathComponent)
        }
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw posixError("open file") }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw posixError("fstat") }
        guard info.st_mode & mode_t(S_IFMT) == S_IFREG else {
            throw ConfigResourceStoreError.unsafeFilesystemEntry(url.lastPathComponent)
        }
        guard info.st_size >= 0, info.st_size <= off_t(maximumBytes) else {
            throw ConfigResourceStoreError.configurationTooLarge(limit: maximumBytes)
        }
        var result = Data()
        result.reserveCapacity(Int(info.st_size))
        var buffer = [UInt8](repeating: 0, count: max(1, min(64 * 1024, maximumBytes)))
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw posixError("read")
            }
            if count == 0 { break }
            guard result.count + count <= maximumBytes else {
                throw ConfigResourceStoreError.configurationTooLarge(limit: maximumBytes)
            }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }

    private func removeAbandonedTemporaryEntries(
        in directory: URL,
        olderThan age: TimeInterval = 0
    ) throws {
        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        for entry in entries where entry.lastPathComponent.hasPrefix(Name.temporaryPrefix) {
            if age > 0 {
                let modified = try entry.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate ?? .distantPast
                guard Date().timeIntervalSince(modified) >= age else { continue }
            }
            try fileManager.removeItem(at: entry)
        }
        try syncDirectory(directory)
    }

    private func renameItem(from source: URL, to destination: URL) throws {
        guard rename(source.path, destination.path) == 0 else { throw posixError("rename") }
    }

    private func syncDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw posixError("open directory") }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw posixError("fsync directory") }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func applyFileProtection(_ url: URL) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private func inject(_ point: ConfigResourceStoreFaultPoint) throws {
        if faultInjector?(point) == true {
            throw ConfigResourceStoreError.simulatedCrash(point)
        }
    }

    private func posixError(_ operation: String) -> ConfigResourceStoreError {
        .posix(operation: operation, code: errno)
    }

    private static func isValidRevision(_ value: String) -> Bool {
        value.count == 36 && UUID(uuidString: value) != nil && value == value.lowercased()
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

 
 
 
 
 
 
 
 
 
 
 
enum TunnelIntentStamp {
    static let key = "HakoAppliedTunnelIntentJSON"

    static func write(_ intentJSON: String, to defaults: UserDefaults) {
        defaults.set(intentJSON, forKey: key)
    }

    static func readJSON(from defaults: UserDefaults) -> String? {
        defaults.string(forKey: key)
    }
}
