import Foundation
import HakoClientKit
import HakoClientUI

public typealias HakoMacDestination = HakoClientUI.HakoRootDestination
public typealias HakoHomeSection = HakoClientUI.HakoHomeSection

public enum HakoConnectionPhase: String, Equatable, Sendable {
    case disconnected
    case preparing
    case connected
    case disconnecting
    case unavailable

    public var isActive: Bool {
        switch self {
        case .preparing, .connected, .disconnecting:
            true
        case .disconnected, .unavailable:
            false
        }
    }
}

public enum HakoConnectionAction: String, Equatable, Sendable {
    case activateSystemExtension
    case updateSystemExtension
    case installConfiguration
    case connect
    case disconnect
    case busy
    case unavailable
}

public struct HakoConnectionSnapshot: Equatable, Sendable {
    public var phase: HakoConnectionPhase
    public var action: HakoConnectionAction
    public var selectedRouteName: String?
    public var selectedRouteDelayMilliseconds: Int?
    public var issueDescription: String?

    public init(
        phase: HakoConnectionPhase,
        action: HakoConnectionAction? = nil,
        selectedRouteName: String? = nil,
        selectedRouteDelayMilliseconds: Int? = nil,
        issueDescription: String? = nil
    ) {
        self.phase = phase
        self.action = action ?? Self.defaultAction(for: phase)
        self.selectedRouteName = selectedRouteName
        self.selectedRouteDelayMilliseconds = selectedRouteDelayMilliseconds
        self.issueDescription = issueDescription
    }

    private static func defaultAction(for phase: HakoConnectionPhase) -> HakoConnectionAction {
        switch phase {
        case .connected: .disconnect
        case .preparing, .disconnecting: .busy
        case .disconnected: .connect
        case .unavailable: .unavailable
        }
    }
}

public enum HakoOutboundMode: String, CaseIterable, Identifiable, Sendable {
    case global = "Global"
    case rule = "Rule"
    case direct = "Direct"

    public var id: String { rawValue }
}

public struct HakoOverviewSnapshot: Equatable, Sendable {
    public var outboundMode: HakoOutboundMode
    public var selectedProxyName: String?
    public var proxyGroupCount: Int
    public var proxyCount: Int
    public var ruleCount: Int
    public var proxyNames: [String]
    public var ruleTargets: [String]

    public init(
        outboundMode: HakoOutboundMode,
        selectedProxyName: String? = nil,
        proxyGroupCount: Int = 0,
        proxyCount: Int = 0,
        ruleCount: Int = 0,
        proxyNames: [String] = [],
        ruleTargets: [String] = []
    ) {
        self.outboundMode = outboundMode
        self.selectedProxyName = selectedProxyName
        self.proxyGroupCount = max(0, proxyGroupCount)
        self.proxyCount = max(0, proxyCount)
        self.ruleCount = max(0, ruleCount)
        self.proxyNames = proxyNames
        self.ruleTargets = ruleTargets
    }
}

public typealias HakoMacProxyCatalogPhase =
    HakoClientUI.HakoProxyRuntimeCatalogPhase
public typealias HakoMacProxyNodeSnapshot =
    HakoClientUI.HakoProxyRuntimeNodeSnapshot
public typealias HakoMacProxyGroupSnapshot =
    HakoClientUI.HakoProxyRuntimeGroupSnapshot
public typealias HakoMacProxiesSnapshot =
    HakoClientUI.HakoProxiesRuntimeSnapshot
public typealias HakoMacLatencySweepSnapshot =
    HakoClientUI.HakoProxyLatencySweepSnapshot
public typealias HakoMacLatencyProbePlan =
    HakoClientUI.HakoProxyLatencyProbePlan
public typealias HakoMacProxyLatencyResult =
    HakoClientUI.HakoProxyLatencyResult
public typealias HakoMacLatencySweepController =
    HakoClientUI.HakoProxyLatencySweepController

@MainActor
public struct HakoMacProxiesActions {
    public var refresh: @MainActor () -> Void
    public var select: @MainActor (_ group: String, _ member: String) -> Void
    public var testAll: @MainActor (_ visibleGroupNames: [String]) -> Void
    public var cancelLatencyTests: @MainActor () -> Void

    public init(
        refresh: @escaping @MainActor () -> Void,
        select: @escaping @MainActor (_ group: String, _ member: String) -> Void,
        testAll: @escaping @MainActor (_ visibleGroupNames: [String]) -> Void = { _ in },
        cancelLatencyTests: @escaping @MainActor () -> Void = {}
    ) {
        self.refresh = refresh
        self.select = select
        self.testAll = testAll
        self.cancelLatencyTests = cancelLatencyTests
    }

    public static let none = Self(refresh: {}, select: { _, _ in })
}

public enum HakoMacActivityPhase: Equatable, Sendable {
    case disconnected
    case loading
    case ready
    case failed
}

 
 
public struct HakoMacActivitySnapshot: Equatable, Sendable {
    public var phase: HakoMacActivityPhase
    public var activeConnectionCount: Int
    public var recentLogCount: Int
    public var uploadBytesPerSecond: Int64
    public var downloadBytesPerSecond: Int64
    public var uploadTotalBytes: Int64
    public var downloadTotalBytes: Int64
    public var errorDescription: String?

    public init(
        phase: HakoMacActivityPhase,
        activeConnectionCount: Int = 0,
        recentLogCount: Int = 0,
        uploadBytesPerSecond: Int64 = 0,
        downloadBytesPerSecond: Int64 = 0,
        uploadTotalBytes: Int64 = 0,
        downloadTotalBytes: Int64 = 0,
        errorDescription: String? = nil
    ) {
        self.phase = phase
        self.activeConnectionCount = max(0, activeConnectionCount)
        self.recentLogCount = max(0, recentLogCount)
        self.uploadBytesPerSecond = max(0, uploadBytesPerSecond)
        self.downloadBytesPerSecond = max(0, downloadBytesPerSecond)
        self.uploadTotalBytes = max(0, uploadTotalBytes)
        self.downloadTotalBytes = max(0, downloadTotalBytes)
        self.errorDescription = errorDescription
    }

    public static let disconnected = Self(phase: .disconnected)
    public static let loading = Self(phase: .loading)
    public static let readyEmpty = Self(phase: .ready)

    public static func failed(_ message: String) -> Self {
        Self(phase: .failed, errorDescription: message)
    }
}

@MainActor
public struct HakoMacActivityActions {
    public var refresh: @MainActor () -> Void

    public init(refresh: @escaping @MainActor () -> Void) {
        self.refresh = refresh
    }

    public static let none = Self(refresh: {})
}

public struct HakoUtilitiesSnapshot: Equatable, Sendable {
    public var activeConnectionCount: Int
    public var requestCount: Int
    public var logCount: Int
    public var uploadBytesPerSecond: Int64
    public var downloadBytesPerSecond: Int64
    public var providerCount: Int?

    public init(
        activeConnectionCount: Int = 0,
        requestCount: Int = 0,
        logCount: Int = 0,
        uploadBytesPerSecond: Int64 = 0,
        downloadBytesPerSecond: Int64 = 0,
        providerCount: Int? = nil
    ) {
        self.activeConnectionCount = max(0, activeConnectionCount)
        self.requestCount = max(0, requestCount)
        self.logCount = max(0, logCount)
        self.uploadBytesPerSecond = max(0, uploadBytesPerSecond)
        self.downloadBytesPerSecond = max(0, downloadBytesPerSecond)
        self.providerCount = providerCount.map { max(0, $0) }
    }
}

public struct HakoMoreSnapshot: Equatable, Sendable {
    public var onDemandEnabled: Bool
    public var onDemandRuleCount: Int
    public var proxyShareStatus: String
    public var dnsOnlyActive: Bool
    public var systemIntegrationStatus: String

    public init(
        onDemandEnabled: Bool = false,
        onDemandRuleCount: Int = 0,
        proxyShareStatus: String = "Off",
        dnsOnlyActive: Bool = false,
        systemIntegrationStatus: String = "Ready"
    ) {
        self.onDemandEnabled = onDemandEnabled
        self.onDemandRuleCount = max(0, onDemandRuleCount)
        self.proxyShareStatus = proxyShareStatus
        self.dnsOnlyActive = dnsOnlyActive
        self.systemIntegrationStatus = systemIntegrationStatus
    }
}

 
 
 
@available(
    *,
    deprecated,
    renamed: "AppleClientSnapshot",
    message: "Construct AppleClientSnapshot directly in the macOS Adapter."
)
public typealias HakoMacClientSnapshot = AppleClientSnapshot

public extension AppleClientSnapshot {
    init(
        profile: Profile?,
        connection: HakoConnectionSnapshot,
        overview: HakoOverviewSnapshot,
        rules: HakoRulesSnapshot = .empty,
        dns: HakoDNSSnapshot = .empty,
        utilities: HakoUtilitiesSnapshot = HakoUtilitiesSnapshot(),
        more: HakoMoreSnapshot = HakoMoreSnapshot(),
        isPreview: Bool = false
    ) {
        let selectedProfile = profile.map {
            AppleClientProfileSnapshot(id: $0.id, label: $0.label)
        }
        let sharedMode = overview.outboundMode.appleClientMode
        let connectionPresentation =
            HakoHomeConnectionPresenter.presentation(
                for: HakoHomeConnectionFacts(
                    activeProfileName: profile?.label,
                    vpnStatus: connection.phase.rawValue,
                    errorMessage: connection.issueDescription ?? "",
                    mode: sharedMode.rawValue,
                    selectedProxyName:
                        connection.selectedRouteName
                        ?? overview.selectedProxyName,
                    selectedProxyDelayMilliseconds:
                        connection.selectedRouteDelayMilliseconds
                )
            )

        self.init(
            revision: 0,
            selectedProfile: selectedProfile,
            connection: AppleClientConnectionSnapshot(
                phase: connection.phase.appleClientPhase,
                primaryIntent: connection.action.appleClientIntent,
                selectedRouteName:
                    connection.selectedRouteName
                    ?? overview.selectedProxyName,
                selectedRouteDelayMilliseconds:
                    connection.selectedRouteDelayMilliseconds,
                issue: connection.issueDescription.map {
                    AppleClientFailure(
                        code: .connection,
                        title: "Connection",
                        message: $0
                    )
                }
            ),
            home: AppleClientHomeSnapshot(
                routing: AppleClientRoutingSnapshot(mode: sharedMode),
                traffic: AppleClientTrafficSnapshot(
                    uploadBytesPerSecond:
                        utilities.uploadBytesPerSecond,
                    downloadBytesPerSecond:
                        utilities.downloadBytesPerSecond
                ),
                proxyGroupCount: overview.proxyGroupCount,
                proxyCount: overview.proxyCount,
                ruleCount: overview.ruleCount,
                connection: connectionPresentation,
                proxies: HakoHomeDomainSnapshot(
                    count: overview.proxyCount,
                    breakdown: Self.countedNoun(
                        overview.proxyGroupCount,
                        singular: "group"
                    ),
                    names: overview.proxyNames
                ),
                rules: HakoHomeDomainSnapshot(
                    count: overview.ruleCount,
                    names: overview.ruleTargets
                )
            ),
            rules: rules,
            dns: dns,
            utilities: HakoClientUI.HakoUtilitiesSnapshot(
                nativeAPIConnected: connection.phase == .connected,
                activeConnectionCount:
                    utilities.activeConnectionCount,
                requestCount: utilities.requestCount,
                logCount: utilities.logCount,
                providerCount: utilities.providerCount,
                proxyShareStatus: more.proxyShareStatus,
                proxyShareEnabled: more.proxyShareStatus != "Off"
            ),
            more: HakoClientUI.HakoMoreSnapshot(
                onDemandEnabled: more.onDemandEnabled,
                onDemandRuleCount: more.onDemandRuleCount,
                dnsOnlyActive: more.dnsOnlyActive,
                showsDeveloperDestination: isPreview
            ),
            capabilities: AppleClientCapabilities([
                .home: .available,
                .utilities: .available,
                .more: .available,
                .connection: .available,
                .systemIntegration: .available,
                .configuration: .available,
                .outboundMode: .available,
                .rules: .available,
                .dns: .available,
            ])
        )
    }

    private static func countedNoun(
        _ value: Int,
        singular: String
    ) -> String? {
        guard value > 0 else { return nil }
        return "\(value) \(value == 1 ? singular : singular + "s")"
    }
}

public typealias HakoUtilityDestination = HakoClientUI.HakoUtilitiesDestination

public extension HakoUtilityDestination {
     
     
    @available(
        *,
        deprecated,
        renamed: "connections",
        message: "Use the shared Connections destination."
    )
    static var liveTraffic: Self { .connections }
}

public typealias HakoMoreDestination = HakoClientUI.HakoMoreDestination

 
 
 
public enum HakoMacSecondaryDestination: Hashable, Sendable {
    case profiles
    case proxies
    case rules
    case activeRules
    case dnsQuery
    case homeAdjustment(HakoHomeAdjustmentAction)
    case runtimeConfiguration
    case configuration
    case utility(HakoUtilityDestination)
    case more(HakoMoreDestination)

    public static let all: [Self] = [
        .profiles,
        .proxies,
        .rules,
        .activeRules,
        .dnsQuery,
    ]
        + HakoHomeAdjustmentAction.allCases.map(Self.homeAdjustment)
        + [
            .runtimeConfiguration,
            .configuration,
        ]
        + HakoClientUI.HakoUtilitiesCatalog.sections
            .flatMap(\.destinations)
            .map(Self.utility)
        + HakoClientUI.HakoMoreCatalog.sections
            .flatMap(\.destinations)
            .map(Self.more)

    public var title: String {
        switch self {
        case .profiles:
            "Profiles"
        case .proxies:
            "Proxies"
        case .rules:
            "Rules"
        case .activeRules:
            "Active Rules"
        case .dnsQuery:
            "DNS Query"
        case .homeAdjustment(let action):
            action.title
        case .runtimeConfiguration:
            "Runtime Configuration"
        case .configuration:
            "Configuration"
        case .utility(let destination):
            destination.title
        case .more(let destination):
            destination.title
        }
    }

    public init?(homeCommand: HakoHomeCommand) {
        switch homeCommand {
        case .openAdjustment(let action):
            self = .homeAdjustment(action)
        case .openRuntimeConfiguration:
            self = .runtimeConfiguration
        case .openProfiles, .performPrimaryAction, .showConnectionIssue,
             .openProxies, .openRules, .setCards, .setTrafficScope,
             .refreshExternalIP, .refreshLANIP:
            return nil
        }
    }
}

 
 
 
@available(
    *,
    deprecated,
    renamed: "AppleClientActions",
    message: "Construct capability-scoped AppleClientActions in the macOS Adapter."
)
public typealias HakoMacClientActions = AppleClientActions

@MainActor
public extension AppleClientActions {
    init(
        selectProfile: @escaping @MainActor () -> Void,
        performPrimaryAction: @escaping @MainActor () -> Void,
        selectOutboundMode: @escaping @MainActor (HakoOutboundMode) -> Void,
        openProxies: @escaping @MainActor () -> Void,
        openRules: @escaping @MainActor () -> Void,
        openActiveRules: @escaping @MainActor () -> Void,
        openDNSQuery: @escaping @MainActor () -> Void,
        customizeHome: @escaping @MainActor () -> Void,
        openUtility: @escaping @MainActor (HakoUtilityDestination) -> Void,
        openMore: @escaping @MainActor (HakoMoreDestination) -> Void
    ) {
        self = try! AppleClientActions.composing([
            AppleClientActions(capability: .home) { action in
                guard case .home(let command) = action else { return }
                switch command {
                case .openProfiles:
                    selectProfile()
                case .performPrimaryAction:
                    performPrimaryAction()
                case .openProxies:
                    openProxies()
                case .openRules:
                    openRules()
                case .openAdjustment, .openRuntimeConfiguration:
                    customizeHome()
                case .showConnectionIssue,
                     .setCards,
                     .setTrafficScope,
                     .refreshExternalIP,
                     .refreshLANIP:
                    break
                }
            },
            AppleClientActions(capability: .connection) { action in
                guard case .connection = action else { return }
                performPrimaryAction()
            },
            AppleClientActions(capability: .systemIntegration) { action in
                guard case .connection = action else { return }
                performPrimaryAction()
            },
            AppleClientActions(capability: .configuration) { action in
                guard case .connection = action else { return }
                performPrimaryAction()
            },
            AppleClientActions(capability: .outboundMode) { action in
                guard case .setOutboundMode(let mode) = action else {
                    return
                }
                selectOutboundMode(mode.hakoMacMode)
            },
            AppleClientActions(capability: .rules) { action in
                guard case .rules(let command) = action else { return }
                switch command {
                case .openActiveRules:
                    openActiveRules()
                case .openProxiesGroup:
                    openProxies()
                case .saveProfileRules:
                    throw AppleClientActionError.unavailable(
                        .rules,
                        .unsupportedPlatform
                    )
                }
            },
            AppleClientActions(capability: .dns) { action in
                guard case .dns(let command) = action else { return }
                switch command {
                case .openDNSQuery:
                    openDNSQuery()
                case .saveSettings, .saveLocalMappings:
                    throw AppleClientActionError.unavailable(
                        .dns,
                        .unsupportedPlatform
                    )
                }
            },
            AppleClientActions(capability: .utilities) { action in
                guard case .openUtility(let destination) = action else {
                    return
                }
                openUtility(destination)
            },
            AppleClientActions(capability: .more) { action in
                guard case .openMore(let destination) = action else {
                    return
                }
                openMore(destination)
            },
        ])
    }

    static var none: AppleClientActions {
        .unavailable
    }
}

private extension HakoConnectionPhase {
    var appleClientPhase: AppleClientConnectionPhase {
        switch self {
        case .disconnected: .disconnected
        case .preparing: .preparing
        case .connected: .connected
        case .disconnecting: .disconnecting
        case .unavailable: .unavailable
        }
    }
}

private extension HakoConnectionAction {
    var appleClientIntent: AppleClientConnectionIntent? {
        switch self {
        case .activateSystemExtension: .activateSystemExtension
        case .updateSystemExtension: .updateSystemExtension
        case .installConfiguration: .installConfiguration
        case .connect: .connect
        case .disconnect: .disconnect
        case .busy, .unavailable: nil
        }
    }
}

private extension HakoOutboundMode {
    var appleClientMode: AppleClientOutboundMode {
        switch self {
        case .global: .global
        case .rule: .rule
        case .direct: .direct
        }
    }
}

private extension AppleClientOutboundMode {
    var hakoMacMode: HakoOutboundMode {
        switch self {
        case .global: .global
        case .rule: .rule
        case .direct: .direct
        }
    }
}
