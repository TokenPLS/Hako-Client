import Foundation

public enum ProfileCatalogError: LocalizedError, Equatable, Sendable {
    case duplicateProfileID(Profile.ID)
    case activeProfileNotFound(Profile.ID)
    case profileAlreadyExists(Profile.ID)
    case profileNotFound(Profile.ID)
    case activeProfileCannotBeRemoved(Profile.ID)
    case invalidReorder
    case generationConflict(expected: UInt64, actual: UInt64)
    case unsupportedSchemaVersion(Int)
    case storeReadFailed
    case storeWriteFailed

    public var errorDescription: String? {
        switch self {
        case .duplicateProfileID:
            return "The profile catalog contains a duplicate identifier."
        case .activeProfileNotFound:
            return "The active profile is missing from the catalog."
        case .profileAlreadyExists:
            return "The profile already exists."
        case .profileNotFound:
            return "The profile does not exist."
        case .activeProfileCannotBeRemoved:
            return "Select another profile before removing the active profile."
        case .invalidReorder:
            return "The reordered profile list does not match the catalog."
        case let .generationConflict(expected, actual):
            return "Profile catalog generation changed (expected \(expected), actual \(actual))."
        case .unsupportedSchemaVersion:
            return "The profile catalog uses an unsupported schema version."
        case .storeReadFailed:
            return "The profile catalog could not be read."
        case .storeWriteFailed:
            return "The profile catalog could not be saved."
        }
    }
}

public struct ProfileCatalogSnapshot: Codable, Equatable, Sendable {
    public static let empty = ProfileCatalogSnapshot(
        generation: 0,
        normalizedProfiles: [],
        activeProfileID: nil
    )

    public let generation: UInt64
    public let profiles: [Profile]
    public let activeProfileID: Profile.ID?

    public init(
        generation: UInt64,
        profiles: [Profile],
        activeProfileID: Profile.ID?
    ) throws {
        var identifiers = Set<Profile.ID>()
        for profile in profiles where !identifiers.insert(profile.id).inserted {
            throw ProfileCatalogError.duplicateProfileID(profile.id)
        }
        if let activeProfileID, !identifiers.contains(activeProfileID) {
            throw ProfileCatalogError.activeProfileNotFound(activeProfileID)
        }

        let ordered = profiles.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.rawValue < rhs.id.rawValue
        }
        let normalized = ordered.enumerated().map { index, profile in
            var profile = profile
            profile.order = index
            return profile
        }
        self.init(
            generation: generation,
            normalizedProfiles: normalized,
            activeProfileID: activeProfileID
        )
    }

    private init(
        generation: UInt64,
        normalizedProfiles: [Profile],
        activeProfileID: Profile.ID?
    ) {
        self.generation = generation
        profiles = normalizedProfiles
        self.activeProfileID = activeProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case generation
        case profiles
        case activeProfileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                generation: container.decode(UInt64.self, forKey: .generation),
                profiles: container.decode([Profile].self, forKey: .profiles),
                activeProfileID: container.decodeIfPresent(
                    Profile.ID.self,
                    forKey: .activeProfileID
                )
            )
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid profile catalog",
                    underlyingError: error
                )
            )
        }
    }
}

public protocol ProfileCatalogRepository: Sendable {
    func snapshot() async throws -> ProfileCatalogSnapshot
    func replace(
        profiles: [Profile],
        activeProfileID: Profile.ID?,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot
}

public actor InMemoryProfileCatalogRepository: ProfileCatalogRepository {
    private var current: ProfileCatalogSnapshot

    public init(snapshot: ProfileCatalogSnapshot = .empty) {
        current = snapshot
    }

    public func snapshot() -> ProfileCatalogSnapshot {
        current
    }

    public func replace(
        profiles: [Profile],
        activeProfileID: Profile.ID?,
        expectedGeneration: UInt64
    ) throws -> ProfileCatalogSnapshot {
        guard current.generation == expectedGeneration else {
            throw ProfileCatalogError.generationConflict(
                expected: expectedGeneration,
                actual: current.generation
            )
        }
        let next = try ProfileCatalogSnapshot(
            generation: current.generation + 1,
            profiles: profiles,
            activeProfileID: activeProfileID
        )
        current = next
        return next
    }
}

public actor JSONProfileCatalogRepository: ProfileCatalogRepository {
    private static let schemaVersion = 1

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
    }

    private struct Envelope: Codable {
        let schemaVersion: Int
        let snapshot: ProfileCatalogSnapshot
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func snapshot() throws -> ProfileCatalogSnapshot {
        try loadSnapshot()
    }

    public func replace(
        profiles: [Profile],
        activeProfileID: Profile.ID?,
        expectedGeneration: UInt64
    ) throws -> ProfileCatalogSnapshot {
        let current = try loadSnapshot()
        guard current.generation == expectedGeneration else {
            throw ProfileCatalogError.generationConflict(
                expected: expectedGeneration,
                actual: current.generation
            )
        }
        let next = try ProfileCatalogSnapshot(
            generation: current.generation + 1,
            profiles: profiles,
            activeProfileID: activeProfileID
        )
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(
                Envelope(schemaVersion: Self.schemaVersion, snapshot: next)
            )
            try data.write(
                to: fileURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch let error as ProfileCatalogError {
            throw error
        } catch {
            throw ProfileCatalogError.storeWriteFailed
        }
        return next
    }

    private func loadSnapshot() throws -> ProfileCatalogSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let version = try decoder.decode(SchemaProbe.self, from: data).schemaVersion
            guard version == Self.schemaVersion else {
                throw ProfileCatalogError.unsupportedSchemaVersion(version)
            }
            return try decoder.decode(Envelope.self, from: data).snapshot
        } catch let error as ProfileCatalogError {
            throw error
        } catch {
            throw ProfileCatalogError.storeReadFailed
        }
    }
}

public actor ProfileCatalog {
    private let repository: any ProfileCatalogRepository

    public init(repository: any ProfileCatalogRepository) {
        self.repository = repository
    }

    public func snapshot() async throws -> ProfileCatalogSnapshot {
        try await repository.snapshot()
    }

    public func create(
        _ profile: Profile,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard !current.profiles.contains(where: { $0.id == profile.id }) else {
            throw ProfileCatalogError.profileAlreadyExists(profile.id)
        }
        return try await repository.replace(
            profiles: current.profiles + [profile],
            activeProfileID: current.activeProfileID ?? profile.id,
            expectedGeneration: expectedGeneration
        )
    }

    public func createAndActivate(
        _ profile: Profile,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard !current.profiles.contains(where: { $0.id == profile.id }) else {
            throw ProfileCatalogError.profileAlreadyExists(profile.id)
        }
        return try await repository.replace(
            profiles: current.profiles + [profile],
            activeProfileID: profile.id,
            expectedGeneration: expectedGeneration
        )
    }

     
     
     
    public func createAll(
        _ profiles: [Profile],
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard !profiles.isEmpty else { return current }
        var identifiers = Set(current.profiles.map(\.id))
        for profile in profiles where !identifiers.insert(profile.id).inserted {
            throw ProfileCatalogError.profileAlreadyExists(profile.id)
        }
        return try await repository.replace(
            profiles: current.profiles + profiles,
            activeProfileID: current.activeProfileID ?? profiles.first?.id,
            expectedGeneration: expectedGeneration
        )
    }

    public func update(
        _ profile: Profile,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard let index = current.profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileCatalogError.profileNotFound(profile.id)
        }
        var profiles = current.profiles
        var replacement = profile
        replacement.order = profiles[index].order
        profiles[index] = replacement
        return try await repository.replace(
            profiles: profiles,
            activeProfileID: current.activeProfileID,
            expectedGeneration: expectedGeneration
        )
    }

    public func updateAndActivate(
        _ profile: Profile,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard let index = current.profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileCatalogError.profileNotFound(profile.id)
        }
        var profiles = current.profiles
        var replacement = profile
        replacement.order = profiles[index].order
        profiles[index] = replacement
        return try await repository.replace(
            profiles: profiles,
            activeProfileID: profile.id,
            expectedGeneration: expectedGeneration
        )
    }

    public func activate(
        _ profileID: Profile.ID,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard current.profiles.contains(where: { $0.id == profileID }) else {
            throw ProfileCatalogError.profileNotFound(profileID)
        }
        guard current.activeProfileID != profileID else { return current }
        return try await repository.replace(
            profiles: current.profiles,
            activeProfileID: profileID,
            expectedGeneration: expectedGeneration
        )
    }

    public func remove(
        _ profileID: Profile.ID,
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard current.activeProfileID != profileID else {
            throw ProfileCatalogError.activeProfileCannotBeRemoved(profileID)
        }
        guard current.profiles.contains(where: { $0.id == profileID }) else {
            throw ProfileCatalogError.profileNotFound(profileID)
        }
        return try await repository.replace(
            profiles: current.profiles.filter { $0.id != profileID },
            activeProfileID: current.activeProfileID,
            expectedGeneration: expectedGeneration
        )
    }

    public func reorder(
        _ profileIDs: [Profile.ID],
        expectedGeneration: UInt64
    ) async throws -> ProfileCatalogSnapshot {
        let current = try await current(expectedGeneration: expectedGeneration)
        guard profileIDs.count == current.profiles.count,
              Set(profileIDs).count == profileIDs.count,
              Set(profileIDs) == Set(current.profiles.map(\.id)) else {
            throw ProfileCatalogError.invalidReorder
        }
        let profilesByID = Dictionary(uniqueKeysWithValues: current.profiles.map { ($0.id, $0) })
        let reordered = profileIDs.enumerated().compactMap { index, profileID -> Profile? in
            guard var profile = profilesByID[profileID] else { return nil }
            profile.order = index
            return profile
        }
        return try await repository.replace(
            profiles: reordered,
            activeProfileID: current.activeProfileID,
            expectedGeneration: expectedGeneration
        )
    }

    private func current(expectedGeneration: UInt64) async throws -> ProfileCatalogSnapshot {
        let current = try await repository.snapshot()
        guard current.generation == expectedGeneration else {
            throw ProfileCatalogError.generationConflict(
                expected: expectedGeneration,
                actual: current.generation
            )
        }
        return current
    }
}
