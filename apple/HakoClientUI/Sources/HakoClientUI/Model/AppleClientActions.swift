import Foundation
import HakoClientKit

public enum AppleClientRefreshScope: String, Codable, Equatable, Sendable {
    case profileCatalog
    case proxyCatalog
    case activity
    case runtime
    case resources
}

public enum HakoProfilesCommand: Codable, Equatable, Sendable {
    case createEmpty
    case openImport
    case openBackup
    case syncAll
    case select(id: Profile.ID)
    case reorder(ids: [Profile.ID])
    case sync(id: Profile.ID)
    case rename(id: Profile.ID, label: String)
    case saveSubscription(
        id: Profile.ID,
        url: String,
        autoUpdate: Bool,
        intervalHours: Int
    )
    case copySubscriptionLink(id: Profile.ID)
    case openSourceEditor(id: Profile.ID)
    case duplicate(id: Profile.ID)
    case export(id: Profile.ID)
    case openRuntimePreview(id: Profile.ID)
    case restoreLastKnownGood(id: Profile.ID)
    case delete(id: Profile.ID)
    case retryFailure
     
     
     
    case adoptHeldBackUpdate(id: Profile.ID, keyPath: String)
     
    case dismissHeldBackUpdates(id: Profile.ID)
    case cancelBatch
    case retryBatchItem(id: Profile.ID)
    case dismissBatch
}

public enum HakoProxiesCommand: Codable, Equatable, Sendable {
    case refresh
    case testAll(visibleGroupNames: [String])
    case testGroup(name: String)
    case select(group: String, member: String)
     
     
     
    case unpin(group: String)
     
     
    case testMember(name: String)
     
     
     
     
     
    case editMember(name: String)
     
    case inspectMember(name: String)
    case setDisplayPreferences(HakoProxiesDisplayPreferences)
     
     
    case setVisibleGroup(name: String?)
     
     
     
     
     
     
     
     
    case updateProvider(name: String)
     
     
     
     
    case setGroupExpanded(name: String, isExpanded: Bool)
     
     
     
    case setGroupsExpanded(names: [String], isExpanded: Bool)
    case cancelLatency
}

public enum HakoActivityCommand: Codable, Equatable, Sendable {
    case refresh
    case closeConnection(id: String)
    case closeAllConnections
    case clearLogs
    case exportLogs
     
     
     
    case setLogRecording(Bool)
     
     
     
    case setLogRetention(String)
     
     
     
     
    case setLogSeverityFilter([String])
     
     
     
    case openLogSettings
    case copyText(String)
}

public enum HakoRulesCommand: Codable, Equatable, Sendable {
     
     
     
     
    case openActiveRules
    case openProxiesGroup(name: String)
    case saveProfileRules(HakoProfileRulesDraft)
}

public enum AppleClientActionResult: Codable, Equatable, Sendable {
    case none
    case profileCreated(id: Profile.ID)
    case profileSelected(id: Profile.ID)
     
     
     
    case profileSelectionFailurePresented
    case profileDeleted(id: Profile.ID)
     
     
     
     
    case profileActionRefused(reason: HakoDisplayText)
}

 
 
public enum AppleClientAction: Codable, Equatable, Sendable {
    case home(HakoHomeCommand)
    case profiles(HakoProfilesCommand)
    case proxies(HakoProxiesCommand)
    case activity(HakoActivityCommand)
    case rules(HakoRulesCommand)
    case dns(HakoDNSCommand)
    case openUtility(HakoUtilitiesDestination)
    case openMore(HakoMoreDestination)
    case selectProfile(id: Profile.ID)
    case connection(AppleClientConnectionIntent)
    case setOutboundMode(AppleClientOutboundMode)
    case applyRoutingPolicy
    case checkEgress
    case collectMemory
    case refresh(AppleClientRefreshScope)
    case cancel(AppleClientOperation)

    public var capability: AppleClientCapability {
        switch self {
        case .home:
            .home
        case .profiles:
            .profiles
        case .proxies:
            .proxies
        case .activity:
            .activity
        case .rules:
            .rules
        case .dns:
            .dns
        case .openUtility:
            .utilities
        case .openMore:
            .more
        case .selectProfile:
            .profileSelection
        case .connection(let intent):
            switch intent {
            case .activateSystemExtension, .updateSystemExtension:
                .systemIntegration
            case .installConfiguration:
                .configuration
            case .connect, .disconnect:
                .connection
            }
        case .setOutboundMode:
            .outboundMode
        case .applyRoutingPolicy:
            .routingPolicy
        case .checkEgress:
            .egressLookup
        case .collectMemory:
            .memoryMaintenance
        case .refresh:
            .refresh
        case .cancel:
            .cancellation
        }
    }
}

public enum AppleClientActionError: Error, Equatable, Sendable {
    case unavailable(
        AppleClientCapability,
        AppleClientUnavailableReason
    )
    case failed(AppleClientFailure)
    case adapterFailure(AppleClientCapability)
}

extension AppleClientActionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unavailable(_, let reason):
            switch reason {
            case .notProvidedByAdapter:
                "This action is not available on this device."
            case .unsupportedPlatform:
                "This action is not supported on this platform."
            case .requiresProfile:
                "Choose a profile before using this action."
            case .requiresConnection:
                "Connect Clash before using this action."
            case .permissionDenied:
                "This action needs system permission."
            case .busy:
                "Another operation is already in progress."
            }
        case .failed(let failure):
            failure.message
        case .adapterFailure:
            "The system action could not be completed."
        }
    }
}

 
 
 
@MainActor
public struct AppleClientActions {
    public typealias Handler = @MainActor @Sendable (
        AppleClientAction
    ) async throws -> Void
    public typealias ResultHandler = @MainActor @Sendable (
        AppleClientAction
    ) async throws -> AppleClientActionResult

    private var handlers: [AppleClientCapability: ResultHandler]

    private init(handlers: [AppleClientCapability: ResultHandler]) {
        self.handlers = handlers
    }

    public init(
        capability: AppleClientCapability,
        handler: @escaping Handler
    ) {
        handlers = [
            capability: { action in
                try await handler(action)
                return .none
            },
        ]
    }

    public init(
        resultCapability capability: AppleClientCapability,
        handler: @escaping ResultHandler
    ) {
        handlers = [capability: handler]
    }

    public static var unavailable: AppleClientActions {
        AppleClientActions(handlers: [:])
    }

    public var providedCapabilities: Set<AppleClientCapability> {
        Set(handlers.keys)
    }

    public func combining(
        _ other: AppleClientActions
    ) throws -> AppleClientActions {
        var combined = handlers
        for (capability, handler) in other.handlers {
            guard combined[capability] == nil else {
                throw AppleClientCompositionError.duplicateCapability(capability)
            }
            combined[capability] = handler
        }
        return AppleClientActions(handlers: combined)
    }

    public static func composing(
        _ components: [AppleClientActions]
    ) throws -> AppleClientActions {
        try components.reduce(AppleClientActions.unavailable) { partial, component in
            try partial.combining(component)
        }
    }

    public func perform(
        _ action: AppleClientAction,
        allowedBy snapshot: AppleClientSnapshot
    ) async throws {
        _ = try await performForResult(action, allowedBy: snapshot)
    }

    public func performForResult(
        _ action: AppleClientAction,
        allowedBy snapshot: AppleClientSnapshot
    ) async throws -> AppleClientActionResult {
        try Task.checkCancellation()

        let capability = action.capability
        switch snapshot.capabilities.availability(for: capability) {
        case .available:
            break
        case .unavailable(let reason):
            throw AppleClientActionError.unavailable(capability, reason)
        }

        guard let handler = handlers[capability] else {
            throw AppleClientActionError.unavailable(
                capability,
                .notProvidedByAdapter
            )
        }

        do {
            let result = try await handler(action)
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppleClientActionError {
            throw error
        } catch {
             
             
            throw AppleClientActionError.adapterFailure(capability)
        }
    }
}
