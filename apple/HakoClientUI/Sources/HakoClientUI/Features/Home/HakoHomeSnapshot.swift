import Foundation

public enum HakoHomeTrafficScope: String, Codable, Equatable, Sendable {
    case proxiedOnly
    case allTraffic
}

public struct HakoHomeDomainSnapshot: Codable, Equatable, Sendable {
    public let count: Int?
     
     
     
    public let countUnit: String?
    public let breakdown: String?
    public let names: [String]

    public init(
        count: Int? = nil,
        countUnit: String? = nil,
        breakdown: String? = nil,
        names: [String] = []
    ) {
        self.count = count.map { max(0, $0) }
        self.countUnit = countUnit.map { String($0.prefix(64)) }
        self.breakdown = breakdown.map { String($0.prefix(256)) }
        self.names = names.prefix(12).map { String($0.prefix(128)) }
    }

    public static let empty = HakoHomeDomainSnapshot()
}

public struct HakoHomeEgressSnapshot: Codable, Equatable, Sendable {
    public let address: String?
    public let flag: String
    public let detail: String
    public let canRefresh: Bool
    public let isChecking: Bool

    public init(
        address: String? = nil,
        flag: String = "",
        detail: String = "",
        canRefresh: Bool = false,
        isChecking: Bool = false
    ) {
        self.address = address.map { String($0.prefix(128)) }
        self.flag = String(flag.prefix(16))
        self.detail = String(detail.prefix(256))
        self.canRefresh = canRefresh
        self.isChecking = isChecking
    }

    public static let unavailable = HakoHomeEgressSnapshot()
}

public struct HakoHomeAdjustmentSnapshot: Codable, Equatable, Sendable {
    public let module: HakoHomeAdjustmentModule
    public let summary: String

    public init(module: HakoHomeAdjustmentModule, summary: String? = nil) {
        self.module = module
        self.summary = String((summary ?? module.subtitle).prefix(256))
    }
}

public enum HakoHomeRecoveryMode: String, Codable, Equatable, Sendable {
    case none
    case direct
}

public enum HakoHomeConnectionPhase:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Sendable
{
    case noProfile
    case ready
    case connecting
    case connected
    case switching
    case recoverableError
    case directRecovery
}

public enum HakoHomePrimaryAction: String, Codable, Equatable, Sendable {
    case openProfiles
    case connect
    case cancel
    case disconnect
    case retry
    case retryProxy
    case none
}

public struct HakoHomeConnectionIssue:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
     
     
     
     
     
     
     
     
    public enum Kind: String, Codable, Equatable, Sendable {
        case connectionFailure
         
         
        case startupStopped
    }

    public let message: String
    public let kind: Kind
    public let allowsSystemVPNProfileReset: Bool

    public init(
        message: String,
        kind: Kind = .connectionFailure,
        allowsSystemVPNProfileReset: Bool = false
    ) {
        self.message = String(
            message
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(512)
        )
        self.kind = kind
        self.allowsSystemVPNProfileReset = allowsSystemVPNProfileReset
    }

    public var id: String {
        "\(kind.rawValue)|\(allowsSystemVPNProfileReset)|\(message)"
    }
}

public struct HakoHomeConnectionFacts: Codable, Equatable, Sendable {
    public var activeProfileName: String?
    public var vpnStatus: String
    public var errorMessage: String
     
     
     
    public var errorIsStartupStopped: Bool
    public var allowsSystemVPNProfileReset: Bool
    public var isSwitchingProxy: Bool
    public var recoveryMode: HakoHomeRecoveryMode
    public var mode: String
    public var selectedProxyName: String?
    public var selectedProxyDelayMilliseconds: Int?

    public init(
        activeProfileName: String?,
        vpnStatus: String,
        errorMessage: String = "",
        errorIsStartupStopped: Bool = false,
        allowsSystemVPNProfileReset: Bool = false,
        isSwitchingProxy: Bool = false,
        recoveryMode: HakoHomeRecoveryMode = .none,
        mode: String = "rule",
        selectedProxyName: String? = nil,
        selectedProxyDelayMilliseconds: Int? = nil
    ) {
        self.activeProfileName = activeProfileName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.vpnStatus = vpnStatus
        self.errorMessage = errorMessage
        self.errorIsStartupStopped = errorIsStartupStopped
        self.allowsSystemVPNProfileReset = allowsSystemVPNProfileReset
        self.isSwitchingProxy = isSwitchingProxy
        self.recoveryMode = recoveryMode
        self.mode = mode
        self.selectedProxyName = selectedProxyName
        self.selectedProxyDelayMilliseconds = selectedProxyDelayMilliseconds
    }
}

public struct HakoHomeConnectionPresentation:
    Codable,
    Equatable,
    Sendable
{
    public let phase: HakoHomeConnectionPhase
    public let title: String
     
     
     
     
    public let subtitle: HakoDisplayText
    public let primaryAction: HakoHomePrimaryAction
    public let primaryActionTitle: String?
    public let issue: HakoHomeConnectionIssue?

    public init(
        phase: HakoHomeConnectionPhase,
        title: String,
        subtitle: HakoDisplayText,
        primaryAction: HakoHomePrimaryAction,
        primaryActionTitle: String?,
        issue: HakoHomeConnectionIssue? = nil
    ) {
        self.phase = phase
        self.title = String(title.prefix(160))
        self.subtitle = subtitle
        self.primaryAction = primaryAction
        self.primaryActionTitle = primaryActionTitle.map {
            String($0.prefix(64))
        }
        self.issue = issue
    }

    public var primaryActionEnabled: Bool {
        primaryAction != .none
    }

    public static let unavailable = HakoHomeConnectionPresentation(
        phase: .noProfile,
        title: "Profile Unavailable",
        subtitle: "The local Direct profile could not be prepared",
        primaryAction: .openProfiles,
        primaryActionTitle: "Open Profiles"
    )
}

public enum HakoHomeConnectionPresenter {
    public static func presentation(
        for facts: HakoHomeConnectionFacts
    ) -> HakoHomeConnectionPresentation {
        if facts.recoveryMode == .direct {
            return .init(
                phase: .directRecovery,
                title: "Direct Recovery Mode",
                subtitle: "Proxy is not in use",
                primaryAction: .retryProxy,
                primaryActionTitle: "Retry Proxy"
            )
        }

        let status = facts.vpnStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let hasProfile = facts.activeProfileName?.isEmpty == false
        let boundedError = facts.errorMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let issue = boundedError.isEmpty ? nil : HakoHomeConnectionIssue(
            message: boundedError,
            kind: facts.errorIsStartupStopped
                ? .startupStopped
                : .connectionFailure,
             
             
             
            allowsSystemVPNProfileReset: facts.errorIsStartupStopped
                ? false
                : facts.allowsSystemVPNProfileReset
        )

        if !hasProfile {
            return .unavailable
        }
        if facts.isSwitchingProxy
            && ["connected", "reasserting"].contains(status)
        {
            return .init(
                phase: .switching,
                title: "Switching Route",
                 
                 
                subtitle: "Switching Route",
                 
                 
                 
                 
                 
                 
                 
                 
                primaryAction: .cancel,
                primaryActionTitle: "STOP"
            )
        }
        if ["connecting", "disconnecting"].contains(status) {
            let closing = status == "disconnecting"
            return .init(
                phase: .connecting,
                 
                 
                 
                 
                 
                 
                 
                 
                title: closing ? "STOPPING" : "STARTING",
                subtitle: closing ? "STOPPING" : "STARTING",
                 
                 
                 
                 
                 
                 
                 
                primaryAction: closing ? .none : .cancel,
                primaryActionTitle: nil
            )
        }
        if ["connected", "reasserting"].contains(status) {
            return .init(
                phase: .connected,
                title: "Connected",
                subtitle: .verbatim(connectedSubtitle(facts)),
                primaryAction: .disconnect,
                primaryActionTitle: "STOP"
            )
        }
        if issue != nil || ["invalid", "unknown"].contains(status) {
            return .init(
                phase: .recoverableError,
                title: "Connection Not Completed",
                subtitle: "Not Connected",
                primaryAction: .retry,
                primaryActionTitle: "Retry",
                issue: issue
            )
        }

        return .init(
            phase: .ready,
            title: facts.activeProfileName ?? "Profile",
            subtitle: "Not Connected",
            primaryAction: .connect,
             
             
             
             
             
             
             
            primaryActionTitle: "START"
        )
    }

    public static func semanticMode(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        {
        case "global":
            "Global"
        case "direct":
            "Direct"
        default:
            "Rule"
        }
    }

    private static func connectedSubtitle(
        _ facts: HakoHomeConnectionFacts
    ) -> String {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        guard semanticMode(facts.mode) == "Global" else { return "" }
        var parts: [String] = []
        if let selected = facts.selectedProxyName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !selected.isEmpty {
            parts.append(selected)
        }
        if let delay = facts.selectedProxyDelayMilliseconds, delay >= 0 {
            parts.append("\(delay) ms")
        }
        return parts.joined(separator: " · ")
    }
}

public enum HakoHomeCommand: Codable, Equatable, Sendable {
    case openProfiles
    case performPrimaryAction(HakoHomePrimaryAction)
    case showConnectionIssue
    case openProxies
    case openRules
    case openAdjustment(HakoHomeAdjustmentAction)
    case openRuntimeConfiguration
    case setCards([HakoHomeCard])
    case setTrafficScope(HakoHomeTrafficScope)
    case refreshExternalIP
    case refreshLANIP
}
