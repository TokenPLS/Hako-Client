import Foundation

public struct RevisionDocument: Equatable, Sendable, CustomStringConvertible {
    public let revision: Revision
    public let data: Data

    public init(revision: Revision, data: Data) {
        self.revision = revision
        self.data = data
    }

    public var description: String {
        "RevisionDocument(revision: \(revision), data: <redacted>)"
    }
}

public struct SourceRuntimeState: Equatable, Sendable {
    public let generation: UInt64
    public let sourceRevision: Revision?
    public let runtimeRevision: Revision?

    public init(
        generation: UInt64,
        sourceRevision: Revision?,
        runtimeRevision: Revision?
    ) {
        self.generation = generation
        self.sourceRevision = sourceRevision
        self.runtimeRevision = runtimeRevision
    }
}

public struct SourceRuntimeCommit: Sendable {
    public let profileID: Profile.ID
    public let source: RevisionDocument
    public let runtime: RevisionDocument

    public init(
        profileID: Profile.ID,
        source: RevisionDocument,
        runtime: RevisionDocument
    ) {
        self.profileID = profileID
        self.source = source
        self.runtime = runtime
    }
}

public enum SourceRuntimeRepositoryError: LocalizedError, Equatable, Sendable {
    case generationConflict(expected: UInt64, actual: UInt64)

    public var errorDescription: String? {
        switch self {
        case let .generationConflict(expected, actual):
            return "Source/runtime generation changed (expected \(expected), actual \(actual))."
        }
    }
}

public protocol SourceRuntimeRepository: Sendable {
    func state(for profileID: Profile.ID) async throws -> SourceRuntimeState
    func commit(
        _ commit: SourceRuntimeCommit,
        expectedGeneration: UInt64
    ) async throws -> SourceRuntimeState
}

public actor InMemorySourceRuntimeRepository: SourceRuntimeRepository {
    private struct Entry: Sendable {
        var state: SourceRuntimeState
        var source: RevisionDocument
        var runtime: RevisionDocument
    }

    private var entries: [Profile.ID: Entry] = [:]

    public init() {}

    public func state(for profileID: Profile.ID) -> SourceRuntimeState {
        entries[profileID]?.state
            ?? SourceRuntimeState(
                generation: 0,
                sourceRevision: nil,
                runtimeRevision: nil
            )
    }

    public func commit(
        _ commit: SourceRuntimeCommit,
        expectedGeneration: UInt64
    ) throws -> SourceRuntimeState {
        let current = state(for: commit.profileID)
        guard current.generation == expectedGeneration else {
            throw SourceRuntimeRepositoryError.generationConflict(
                expected: expectedGeneration,
                actual: current.generation
            )
        }
        let next = SourceRuntimeState(
            generation: current.generation + 1,
            sourceRevision: commit.source.revision,
            runtimeRevision: commit.runtime.revision
        )
        entries[commit.profileID] = Entry(
            state: next,
            source: commit.source,
            runtime: commit.runtime
        )
        return next
    }

    public func sourceDocument(for profileID: Profile.ID) -> RevisionDocument? {
        entries[profileID]?.source
    }

    public func runtimeDocument(for profileID: Profile.ID) -> RevisionDocument? {
        entries[profileID]?.runtime
    }
}

public struct SourceRuntimeRequest: Sendable {
    public let profile: Profile
    public let source: RevisionDocument
    public let expectedGeneration: UInt64
    public let credentialMutations: [CredentialMutation]

    public init(
        profile: Profile,
        source: RevisionDocument,
        expectedGeneration: UInt64,
        credentialMutations: [CredentialMutation] = []
    ) {
        self.profile = profile
        self.source = source
        self.expectedGeneration = expectedGeneration
        self.credentialMutations = credentialMutations
    }
}

public struct SourceRuntimeResult: Sendable {
    public let profile: Profile
    public let state: SourceRuntimeState

    public init(profile: Profile, state: SourceRuntimeState) {
        self.profile = profile
        self.state = state
    }
}

public typealias RuntimeBuilder = @Sendable (
    _ profile: Profile,
    _ source: RevisionDocument,
    _ credentials: any CredentialReading
) async throws -> RevisionDocument

public typealias RuntimePreflight = @Sendable (
    _ candidate: RevisionDocument
) async throws -> Void

public enum SourceRuntimeTransactionError: LocalizedError, Equatable, Sendable {
    case duplicateCredentialReference(CredentialReference)
    case credentialRollbackFailed

    public var errorDescription: String? {
        switch self {
        case .duplicateCredentialReference(let reference):
            return "Credential mutation is duplicated for \(reference.id)."
        case .credentialRollbackFailed:
            return "Credential rollback failed; no runtime commit was published."
        }
    }
}

public actor SourceRuntimeTransaction {
    private let repository: any SourceRuntimeRepository
    private let vault: any CredentialVault
    private var transactionInProgress = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(
        repository: any SourceRuntimeRepository,
        vault: any CredentialVault
    ) {
        self.repository = repository
        self.vault = vault
    }

    public func execute(
        _ request: SourceRuntimeRequest,
        build: @escaping RuntimeBuilder,
        preflight: @escaping RuntimePreflight
    ) async throws -> SourceRuntimeResult {
        await acquireTransactionSlot()
        defer { releaseTransactionSlot() }
        try Task.checkCancellation()
        return try await executeLocked(request, build: build, preflight: preflight)
    }

    private func executeLocked(
        _ request: SourceRuntimeRequest,
        build: RuntimeBuilder,
        preflight: RuntimePreflight
    ) async throws -> SourceRuntimeResult {
        var references = Set<CredentialReference>()
        for mutation in request.credentialMutations {
            guard references.insert(mutation.reference).inserted else {
                throw SourceRuntimeTransactionError.duplicateCredentialReference(
                    mutation.reference
                )
            }
        }

        let initialState = try await repository.state(for: request.profile.id)
        guard initialState.generation == request.expectedGeneration else {
            throw SourceRuntimeRepositoryError.generationConflict(
                expected: request.expectedGeneration,
                actual: initialState.generation
            )
        }

        var backups: [(CredentialReference, Data?)] = []
        for mutation in request.credentialMutations {
            backups.append((
                mutation.reference,
                try await vault.data(for: mutation.reference)
            ))
        }

        var applied: [CredentialReference] = []
        do {
            let stagedCredentials = StagedCredentialReader(
                base: vault,
                mutations: request.credentialMutations
            )
            let runtime = try await build(
                request.profile,
                request.source,
                stagedCredentials
            )
            try Task.checkCancellation()
            try await preflight(runtime)
            try Task.checkCancellation()

            for mutation in request.credentialMutations {
                try Task.checkCancellation()
                switch mutation {
                case let .set(reference, value):
                    applied.append(reference)
                    try await vault.set(value, for: reference)
                case .remove(let reference):
                    applied.append(reference)
                    try await vault.remove(reference)
                }
            }
            try Task.checkCancellation()

            let state = try await repository.commit(
                SourceRuntimeCommit(
                    profileID: request.profile.id,
                    source: request.source,
                    runtime: runtime
                ),
                expectedGeneration: request.expectedGeneration
            )
            var updatedProfile = request.profile
            updatedProfile.activeRuntimeRevision = runtime.revision
            return SourceRuntimeResult(profile: updatedProfile, state: state)
        } catch {
            let originalError = error
            let rollbackFailed = await rollbackCredentials(
                applied: applied,
                backups: backups
            )
            if rollbackFailed {
                throw SourceRuntimeTransactionError.credentialRollbackFailed
            }
            throw originalError
        }
    }

    private func rollbackCredentials(
        applied: [CredentialReference],
        backups: [(CredentialReference, Data?)]
    ) async -> Bool {
        var failed = false
        for reference in applied.reversed() {
            let previous = backups.first { $0.0 == reference }?.1
            do {
                if let previous {
                    try await vault.set(previous, for: reference)
                } else {
                    try await vault.remove(reference)
                }
            } catch {
                failed = true
            }
        }
        return failed
    }

    private func acquireTransactionSlot() async {
        if !transactionInProgress {
            transactionInProgress = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func releaseTransactionSlot() {
        if waiters.isEmpty {
            transactionInProgress = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

private struct StagedCredentialReader: CredentialReading {
    private enum Value: Sendable {
        case set(Data)
        case removed
    }

    private let base: any CredentialReading
    private let values: [CredentialReference: Value]

    init(base: any CredentialReading, mutations: [CredentialMutation]) {
        self.base = base
        values = Dictionary(uniqueKeysWithValues: mutations.map { mutation in
            switch mutation {
            case let .set(reference, value):
                return (reference, .set(value))
            case .remove(let reference):
                return (reference, .removed)
            }
        })
    }

    func data(for reference: CredentialReference) async throws -> Data? {
        switch values[reference] {
        case .set(let value):
            return value
        case .removed:
            return nil
        case nil:
            return try await base.data(for: reference)
        }
    }
}
