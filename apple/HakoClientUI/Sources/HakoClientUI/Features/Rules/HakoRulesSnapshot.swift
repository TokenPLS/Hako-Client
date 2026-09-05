import Foundation

public struct HakoRuleLineSnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public let raw: String
    public let type: String
    public let payload: String
    public let target: String

    public var id: String { raw }

    public init(
        raw: String,
        type: String,
        payload: String,
        target: String
    ) {
        self.raw = String(raw.prefix(8_192))
        self.type = String(type.prefix(128))
        self.payload = String(payload.prefix(4_096))
        self.target = String(target.prefix(256))
    }
}

public struct HakoRuleBucketSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let target: String
    public let rules: [HakoRuleLineSnapshot]
    public let canOpenProxiesGroup: Bool

    public var id: String { target }

    public init(
        target: String,
        rules: [HakoRuleLineSnapshot],
        canOpenProxiesGroup: Bool = false
    ) {
        self.target = String(target.prefix(256))
        self.rules = rules
        self.canOpenProxiesGroup = canOpenProxiesGroup
    }
}

public struct HakoRuleSetSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let name: String
    public let detail: String
     
     
     
     
    public let blockedReason: String?
     
     
     
     
    public let entryCount: Int?

    public var id: String { name }

    public init(name: String, detail: String, blockedReason: String? = nil, entryCount: Int? = nil) {
        self.entryCount = entryCount
         
         
         
        self.name = name
        self.detail = String(detail.prefix(512))
        self.blockedReason = blockedReason.map { String($0.prefix(512)) }
    }
}

public struct HakoRulesOverviewSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let inlineCount: Int
    public let inapplicableCount: Int
     
     
     
     
     
     
     
     
    public let platformTitle: String
    public let buckets: [HakoRuleBucketSnapshot]
    public let ruleSets: [HakoRuleSetSnapshot]
    public let fallback: [HakoRuleLineSnapshot]
    public let searchableRules: [HakoRuleLineSnapshot]
    public let jumpableTargets: Set<String>

    public init(
        inlineCount: Int = 0,
        inapplicableCount: Int = 0,
        platformTitle: String = "",
        buckets: [HakoRuleBucketSnapshot] = [],
        ruleSets: [HakoRuleSetSnapshot] = [],
        fallback: [HakoRuleLineSnapshot] = [],
        searchableRules: [HakoRuleLineSnapshot]? = nil,
        jumpableTargets: Set<String> = []
    ) {
        self.inlineCount = max(0, inlineCount)
        self.inapplicableCount = max(0, inapplicableCount)
        self.platformTitle = platformTitle
        self.buckets = buckets
        self.ruleSets = ruleSets
        self.fallback = fallback
        self.searchableRules =
            searchableRules ?? buckets.flatMap(\.rules) + fallback
        self.jumpableTargets = jumpableTargets
    }

    public static let empty = HakoRulesOverviewSnapshot()

    public func search(_ query: String) -> [HakoRuleLineSnapshot] {
        let normalized = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { return [] }
        return searchableRules.filter {
            $0.raw.localizedCaseInsensitiveContains(normalized)
        }
    }
}

public enum HakoRuleTargetVerdict:
    String,
    Codable,
    Equatable,
    Sendable
{
    case builtin
    case followsFallback
    case known
    case unknown
}

public struct HakoRulePolicySnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public let name: String
    public let type: String

    public var id: String { name }

    public init(name: String, type: String) {
         
         
         
        self.name = name
        self.type = String(type.prefix(128))
    }
}

public struct HakoRulePolicyOptions:
    Codable,
    Equatable,
    Sendable
{
    public let groups: [HakoRulePolicySnapshot]
    public let proxies: [HakoRulePolicySnapshot]
    public let ruleSets: [String]
     
     
     
    public let subRuleNames: [String]?

    public init(
        groups: [HakoRulePolicySnapshot] = [],
        proxies: [HakoRulePolicySnapshot] = [],
        ruleSets: [String] = [],
        subRuleNames: [String]? = nil
    ) {
        self.groups = groups
        self.proxies = proxies
        self.ruleSets = ruleSets.map { String($0.prefix(256)) }
        self.subRuleNames = subRuleNames.map { names in
            names.map { String($0.prefix(256)) }
        }
    }

    public static let empty = HakoRulePolicyOptions()

    public static let builtinPolicies: Set<String> = [
        "DIRECT", "REJECT", "REJECT-DROP", "PASS", "PASS-RULE",
        "COMPATIBLE", "GLOBAL",
    ]

    public func verdict(forTarget target: String) -> HakoRuleTargetVerdict {
        if Self.builtinPolicies.contains(target) {
            return .builtin
        }
        if target == "MATCH" {
            return .followsFallback
        }
        if groups.contains(where: { $0.name == target })
            || proxies.contains(where: { $0.name == target })
        {
            return .known
        }
        return .unknown
    }

     
     
     
     
     
     
     
    public func flagsUnknownTarget(of rule: HakoStructuredRule) -> Bool {
        guard rule.action != .subRule else {
            guard let subRuleNames else { return false }
            return !subRuleNames.contains(rule.target)
        }
        return verdict(forTarget: rule.target) == .unknown
    }
}

 
 
 
 
 
 
 
 
public enum HakoRuleDeletion {
    public static func needsConfirmation(count: Int) -> Bool { count > 1 }

     
     
    public static func removing(
        _ indices: Set<Int>,
        from rules: [HakoPersonalRuleSnapshot]
    ) -> [HakoPersonalRuleSnapshot] {
        var kept = rules
        for index in indices.sorted(by: >) where kept.indices.contains(index) {
            kept.remove(at: index)
        }
        return kept
    }
}

public struct HakoPersonalRuleSnapshot:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let raw: String
    public let isEnabled: Bool
    public let comment: String?

    public var id: String { raw }

    public init(
        raw: String,
        isEnabled: Bool = true,
        comment: String? = nil
    ) {
        self.raw = String(raw.prefix(8_192))
        self.isEnabled = isEnabled
        self.comment = comment.map { String($0.prefix(1_024)) }
    }
}

public struct HakoProfileRulesSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let profileName: String
    public let rules: [HakoPersonalRuleSnapshot]
    public let prependRules: Bool
    public let policyOptions: HakoRulePolicyOptions
    public let initialRuleBuilderRaw: String?
    public let initialRuleBuilderRoute: HakoRuleBuilderRoute?

     
     
     
     
     
    public static let prependsByDefault = true

    public init(
        profileName: String,
        rules: [HakoPersonalRuleSnapshot] = [],
        prependRules: Bool = HakoProfileRulesSnapshot.prependsByDefault,
        policyOptions: HakoRulePolicyOptions = .empty,
        initialRuleBuilderRaw: String? = nil,
        initialRuleBuilderRoute: HakoRuleBuilderRoute? = nil
    ) {
        self.profileName = String(profileName.prefix(256))
        self.rules = rules
        self.prependRules = prependRules
        self.policyOptions = policyOptions
        self.initialRuleBuilderRaw = initialRuleBuilderRaw.map {
            String($0.prefix(8_192))
        }
        self.initialRuleBuilderRoute = initialRuleBuilderRoute
    }
}

public enum HakoRuleBuilderRoute:
    String,
    Codable,
    Equatable,
    Sendable
{
    case country
    case policy
    case category
}

public enum HakoRuleGeoResource:
    String,
    Codable,
    Equatable,
    Sendable
{
    case geoIP
    case geoSite
}

public struct HakoProfileRulesDraft:
    Codable,
    Equatable,
    Sendable
{
    public var rules: [HakoPersonalRuleSnapshot]
    public var prependRules: Bool

    public init(
        rules: [HakoPersonalRuleSnapshot],
        prependRules: Bool
    ) {
        self.rules = rules
        self.prependRules = prependRules
    }
}

public struct HakoRulesSnapshot:
    Codable,
    Equatable,
    Sendable
{
    public let overview: HakoRulesOverviewSnapshot
    public let editor: HakoProfileRulesSnapshot?
    public let canInspectActiveRules: Bool

    public init(
        overview: HakoRulesOverviewSnapshot = .empty,
        editor: HakoProfileRulesSnapshot? = nil,
        canInspectActiveRules: Bool = false
    ) {
        self.overview = overview
        self.editor = editor
        self.canInspectActiveRules = canInspectActiveRules
    }

    public static let empty = HakoRulesSnapshot()
}

public struct HakoLogicCondition:
    Codable,
    Equatable,
    Sendable
{
    public var action: HakoStructuredRule.Action
    public var content: String
    public var noResolve: Bool
    public var src: Bool

    public init(
        action: HakoStructuredRule.Action,
        content: String,
        noResolve: Bool = false,
        src: Bool = false
    ) {
        self.action = action
        self.content = content
        self.noResolve = noResolve
        self.src = src
    }

    public var raw: String {
        var fields = [action.rawValue, content]
        if action.supportsSrc, src {
            fields.append("src")
        }
        if action.supportsNoResolve, noResolve {
            fields.append("no-resolve")
        }
        return fields.joined(separator: ",")
    }
}

public enum HakoLogicExpressionCodec {
    public static func serialize(
        action: HakoStructuredRule.Action,
        conditions: [HakoLogicCondition]
    ) -> String {
        let inner = conditions.map { "(\($0.raw))" }
            .joined(separator: ",")
        return action == .subRule
            ? "(\(conditions.first?.raw ?? ""))"
            : "(\(inner))"
    }

    public static func parse(
        action: HakoStructuredRule.Action,
        content: String
    ) -> [HakoLogicCondition]? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else {
            return nil
        }
        let subPayloads: [String]
        if action == .subRule {
            subPayloads = [String(trimmed.dropFirst().dropLast())]
        } else {
            let inner = String(trimmed.dropFirst().dropLast())
            guard let groups = topLevelGroups(inner) else {
                return nil
            }
            subPayloads = groups
        }
        guard !subPayloads.isEmpty else { return nil }
        var conditions: [HakoLogicCondition] = []
        for payload in subPayloads {
            guard let condition = parseCondition(payload) else {
                return nil
            }
            conditions.append(condition)
        }
        if action == .not || action == .subRule,
            conditions.count != 1
        {
            return nil
        }
        return conditions
    }

    public static func summary(
        action: HakoStructuredRule.Action,
        content: String
    ) -> String? {
        parse(action: action, content: content)?
            .map(\.content)
            .joined(separator: " · ")
    }

    private static func topLevelGroups(
        _ inner: String
    ) -> [String]? {
        var groups: [String] = []
        var depth = 0
        var current = ""
        for character in inner {
            switch character {
            case "(":
                depth += 1
                if depth > 1 {
                    current.append(character)
                }
            case ")":
                depth -= 1
                if depth < 0 {
                    return nil
                }
                if depth == 0 {
                    groups.append(current)
                    current = ""
                } else {
                    current.append(character)
                }
            case ",":
                if depth != 0 {
                    current.append(character)
                }
            default:
                if depth == 0 {
                    guard character.isWhitespace else {
                        return nil
                    }
                } else {
                    current.append(character)
                }
            }
        }
        return depth == 0 && !groups.isEmpty ? groups : nil
    }

    private static func parseCondition(
        _ payload: String
    ) -> HakoLogicCondition? {
        let fields = payload.split(
            separator: ",",
            omittingEmptySubsequences: false
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count >= 2,
            let head = fields.first,
            let action = HakoStructuredRule.Action(
                rawValue: head.uppercased()
            )
        else {
            return nil
        }
        switch action {
        case .and, .or, .not, .subRule, .match:
            return nil
        case .domainRegex:
            return HakoLogicCondition(
                action: action,
                content: fields.dropFirst().joined(separator: ",")
            )
        default:
            let value = fields[1]
            guard !value.isEmpty else { return nil }
            var noResolve = false
            var src = false
            for parameter in fields.dropFirst(2) {
                switch parameter.lowercased() {
                case "no-resolve":
                    noResolve = true
                case "src":
                    src = true
                default:
                    return nil
                }
            }
            return HakoLogicCondition(
                action: action,
                content: value,
                noResolve: noResolve,
                src: src
            )
        }
    }
}

 
 
 
public enum HakoAppleRuntimeProfile:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Sendable
{
    case iosPacketTunnel
    case macosPacketTunnel
     
     
     
     
     
     
    case tvosPacketTunnel

     
     
     
     
     
     
     
     

     
    public var removedRuleActionNames: Set<String> {
        switch self {
        case .macosPacketTunnel: []
        case .iosPacketTunnel, .tvosPacketTunnel: ["UID"]
        }
    }

     
     
    public var keptNeverMatchRuleActionNames: Set<String> {
        let needInboundOrAuditToken: Set<String> = [
            "IN-USER",
            "SOURCE-APP-SIGNING-ID",
            "SOURCE-APP-TEAM-ID",
        ]
        switch self {
        case .macosPacketTunnel:
            return needInboundOrAuditToken
        case .iosPacketTunnel, .tvosPacketTunnel:
            return needInboundOrAuditToken.union([
                "PROCESS-NAME",
                "PROCESS-PATH",
                "PROCESS-NAME-REGEX",
                "PROCESS-PATH-REGEX",
                "PROCESS-NAME-WILDCARD",
                "PROCESS-PATH-WILDCARD",
            ])
        }
    }

     
     
     
     
    public var unavailableRuleActionNames: Set<String> {
        removedRuleActionNames.union(keptNeverMatchRuleActionNames)
    }

    public var platformTitle: String {
        switch self {
        case .iosPacketTunnel: "iOS"
        case .macosPacketTunnel: "macOS"
        case .tvosPacketTunnel: "tvOS"
        }
    }

    public var unavailableMetadataExplanation: String {
        switch self {
        case .macosPacketTunnel:
            "IN-USER and SOURCE-APP-* rules need inbound authentication or flow audit-token metadata the macOS packet tunnel cannot resolve. PROCESS-* and UID rules are available."
        case .tvosPacketTunnel:
            "On tvOS these rules are kept but match nothing: the owner metadata they test cannot be resolved, so the next rule decides. UID is the exception — it is removed, because a UID rule cannot be built on this platform and keeping it would stop the whole configuration from loading. Use domain, IP, GEOSITE or GEOIP conditions instead."
        case .iosPacketTunnel:
             
             
             
             
             
             
             
             
            "On iOS these rules are kept but match nothing: the owner metadata they test cannot be resolved, so the next rule decides. UID is the exception — it is removed, because a UID rule cannot be built on this platform and keeping it would stop the whole configuration from loading. Use domain, IP, GEOSITE or GEOIP conditions instead."
        }
    }

    public var inlineRuleEditorNotice: String {
        switch self {
        case .macosPacketTunnel:
            "PROCESS-* and UID rules run on macOS. IN-USER and SOURCE-APP-* rules are stripped at activation with a per-rule notice."
        case .tvosPacketTunnel:
            "On tvOS, process-, inbound-user- and source-app-based rules run but match nothing, because the owner metadata they test cannot be resolved; UID rules are removed at activation. The editor lets you write them and marks them, so the same profile can carry them for a Mac."
        case .iosPacketTunnel:
            "On iOS, process-, inbound-user- and source-app-based rules run but match nothing, because the owner metadata they test cannot be resolved; UID rules are removed at activation. The editor lets you write them and marks them, so the same profile can carry them for a Mac."
        }
    }
}

public struct HakoStructuredRule:
    Codable,
    Equatable,
    Sendable
{
    public enum Category:
        String,
        CaseIterable,
        Codable,
        Identifiable,
        Sendable
    {
        case domain
        case address
        case connection
        case resources
        case logic
        case advanced

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .domain: "Domain"
            case .address: "Address"
            case .connection: "Connection"
            case .resources: "Resources"
            case .logic: "Logic"
            case .advanced: "Advanced metadata"
            }
        }
    }

    public enum Action:
        String,
        CaseIterable,
        Codable,
        Identifiable,
        Sendable
    {
        case domain = "DOMAIN"
        case domainSuffix = "DOMAIN-SUFFIX"
        case domainKeyword = "DOMAIN-KEYWORD"
        case domainRegex = "DOMAIN-REGEX"
        case domainWildcard = "DOMAIN-WILDCARD"
        case geosite = "GEOSITE"
        case geoip = "GEOIP"
        case srcGeoIP = "SRC-GEOIP"
        case ipASN = "IP-ASN"
        case srcIPASN = "SRC-IP-ASN"
        case ipCIDR = "IP-CIDR"
        case ipCIDR6 = "IP-CIDR6"
        case srcIPCIDR = "SRC-IP-CIDR"
        case ipSuffix = "IP-SUFFIX"
        case srcIPSuffix = "SRC-IP-SUFFIX"
        case srcPort = "SRC-PORT"
        case dstPort = "DST-PORT"
        case inPort = "IN-PORT"
        case dscp = "DSCP"
        case processName = "PROCESS-NAME"
        case processPath = "PROCESS-PATH"
        case processNameRegex = "PROCESS-NAME-REGEX"
        case processPathRegex = "PROCESS-PATH-REGEX"
        case processNameWildcard = "PROCESS-NAME-WILDCARD"
        case processPathWildcard = "PROCESS-PATH-WILDCARD"
        case uid = "UID"
        case sourceAppSigningID = "SOURCE-APP-SIGNING-ID"
        case sourceAppTeamID = "SOURCE-APP-TEAM-ID"
        case network = "NETWORK"
        case inType = "IN-TYPE"
        case inName = "IN-NAME"
        case inUser = "IN-USER"
        case rematchName = "REMATCH-NAME"
        case subRule = "SUB-RULE"
        case and = "AND"
        case or = "OR"
        case not = "NOT"
        case ruleSet = "RULE-SET"
        case match = "MATCH"

        public var id: String { rawValue }

        public var category: Category {
            switch self {
            case .domain, .domainSuffix, .domainKeyword,
                .domainRegex, .domainWildcard, .geosite:
                .domain
            case .geoip, .srcGeoIP, .ipASN, .srcIPASN,
                .ipCIDR, .ipCIDR6, .srcIPCIDR, .ipSuffix,
                .srcIPSuffix:
                .address
            case .srcPort, .dstPort, .inPort, .dscp, .network:
                .connection
            case .ruleSet:
                .resources
            case .subRule, .and, .or, .not, .match:
                .logic
            case .processName, .processPath, .processNameRegex,
                .processPathRegex, .processNameWildcard,
                .processPathWildcard, .uid, .sourceAppSigningID,
                .sourceAppTeamID, .inType, .inName, .inUser,
                .rematchName:
                .advanced
            }
        }

        public var title: String {
            switch self {
            case .domain: "Exact domain"
            case .domainSuffix: "Domain suffix"
            case .domainKeyword: "Domain keyword"
            case .domainRegex: "Domain regular expression"
            case .domainWildcard: "Domain wildcard"
            case .geosite: "GeoSite category"
            case .geoip: "Destination country or region"
            case .srcGeoIP: "Source country or region"
            case .ipASN: "Destination network ASN"
            case .srcIPASN: "Source network ASN"
            case .ipCIDR: "Destination IPv4 network"
            case .ipCIDR6: "Destination IPv6 network"
            case .srcIPCIDR: "Source IP network"
            case .ipSuffix: "Destination IP suffix"
            case .srcIPSuffix: "Source IP suffix"
            case .srcPort: "Source port"
            case .dstPort: "Destination port"
            case .inPort: "Inbound port"
            case .dscp: "DSCP value"
            case .processName: "Process name"
            case .processPath: "Process path"
            case .processNameRegex: "Process name regular expression"
            case .processPathRegex: "Process path regular expression"
            case .processNameWildcard: "Process name wildcard"
            case .processPathWildcard: "Process path wildcard"
            case .uid: "Process user ID"
            case .sourceAppSigningID: "Source app signing ID"
            case .sourceAppTeamID: "Source app team ID"
            case .network: "Transport protocol"
            case .inType: "Inbound type"
            case .inName: "Inbound name"
            case .inUser: "Inbound user"
            case .rematchName: "Rematch name"
            case .subRule: "Sub-rule branch"
            case .and: "All conditions"
            case .or: "Any condition"
            case .not: "Not condition"
            case .ruleSet: "Rule-set provider"
            case .match: "All remaining traffic"
            }
        }

        public var summary: String {
            switch self {
            case .domain:
                "Matches when the request domain equals this value exactly."
            case .domainSuffix:
                "Matches the domain itself and any of its subdomains."
            case .domainKeyword:
                "Matches when the request domain contains this text."
            case .domainRegex:
                "Matches the request domain against a regular expression."
            case .domainWildcard:
                "Matches the request domain against a wildcard pattern (* and ?)."
            case .geosite:
                "Matches domains listed in this built-in GeoSite category."
            case .geoip:
                "Matches the destination address's GeoIP country or region."
            case .srcGeoIP:
                "Matches the source address's GeoIP country or region."
            case .ipASN:
                "Matches the destination address's autonomous system number."
            case .srcIPASN:
                "Matches the source address's autonomous system number."
            case .ipCIDR:
                "Matches destination IPv4 addresses inside this network."
            case .ipCIDR6:
                "Matches destination IPv6 addresses inside this network."
            case .srcIPCIDR:
                "Matches source addresses inside this network."
            case .ipSuffix:
                "Matches the trailing bits of the destination address."
            case .srcIPSuffix:
                "Matches the trailing bits of the source address."
            case .srcPort:
                "Matches the connection's source port."
            case .dstPort:
                "Matches the connection's destination port."
            case .inPort:
                "Matches the listener port that accepted the connection."
            case .dscp:
                "Matches the packet's DSCP marking."
            case .processName:
                "Matches the executable name the core resolves from the socket owner."
            case .processPath:
                "Matches the executable path the core resolves from the socket owner."
            case .processNameRegex:
                "Matches the resolved executable name against a regular expression."
            case .processPathRegex:
                "Matches the resolved executable path against a regular expression."
            case .processNameWildcard:
                "Matches the resolved executable name against a wildcard pattern."
            case .processPathWildcard:
                "Matches the resolved executable path against a wildcard pattern."
            case .uid:
                "Matches the numeric user ID the core resolves from the socket owner."
            case .sourceAppSigningID:
                "Matches the code-signing identifier of the app that opened the connection."
            case .sourceAppTeamID:
                "Matches the developer team ID of the app that opened the connection."
            case .network:
                "Matches the transport protocol, tcp or udp."
            case .inType:
                "Matches the inbound type that accepted the connection."
            case .inName:
                "Matches the inbound name that accepted the connection."
            case .inUser:
                "Matches the user name the inbound authenticated for this connection."
            case .rematchName:
                "Matches the rematch lane this connection was re-evaluated under."
            case .subRule:
                "Branches into the named sub-rule list when the condition matches."
            case .and:
                "Matches only when every listed condition matches."
            case .or:
                "Matches when any one of the listed conditions matches."
            case .not:
                "Matches when the wrapped condition does not match."
            case .ruleSet:
                "Matches entries supplied by the named rule provider."
            case .match:
                "Matches every request not matched by the rules above."
            }
        }

        public var iOSInertNote: String? {
            self == .dscp
                ? "Unreliable on iOS — the packet tunnel never sets DSCP, so every flow reads as 0: DSCP,0 matches all traffic and any other value never matches."
                : nil
        }

        public var needsContent: Bool { self != .match }

        public var payloadConsumesRemainingFields: Bool {
            switch self {
            case .domainRegex, .processNameRegex, .processPathRegex,
                .subRule, .and, .or, .not:
                true
            default:
                false
            }
        }

        public var supportsNoResolve: Bool {
            switch self {
            case .geoip, .ipCIDR, .ipCIDR6, .ipASN,
                .ipSuffix, .ruleSet:
                true
            default:
                false
            }
        }

        public var supportsSrc: Bool {
            switch self {
            case .geoip, .ipCIDR, .ipCIDR6, .ipASN,
                .ipSuffix, .ruleSet:
                true
            default:
                false
            }
        }

        public var contentLabel: String {
            switch self {
            case .ruleSet: "Rule-set name"
            case .subRule, .and, .or, .not: "Condition expression"
            case .network: "Protocol"
            case .inType: "Inbound kind"
            case .inName: "Inbound name"
            case .inUser: "Inbound user"
            case .rematchName: "Rematch name"
            default: "Match value"
            }
        }

        public var contentPlaceholder: String {
            switch self {
            case .geoip, .srcGeoIP: "CN"
            case .geosite: "gfw"
            case .ipCIDR, .srcIPCIDR: "10.0.0.0/8"
            case .ipCIDR6: "2620:0:2d0::/48"
            case .ipASN, .srcIPASN: "13335"
            case .ipSuffix, .srcIPSuffix: "1.1"
            case .dstPort, .srcPort, .inPort: "443 or 8000-9000"
            case .dscp: "0-63"
            case .processName: "curl"
            case .processPath: "/usr/bin/curl"
            case .processNameRegex: "^curl$"
            case .processPathRegex: "^/usr/bin/.*"
            case .processNameWildcard: "curl*"
            case .processPathWildcard: "/usr/bin/*"
            case .uid: "501"
            case .sourceAppSigningID: "com.example.app"
            case .sourceAppTeamID: "ABCDE12345"
            case .network: "TCP or UDP"
            case .ruleSet: "provider name"
            case .subRule: "(OR,((NETWORK,TCP),(NETWORK,UDP)))"
            case .and: "((DOMAIN,a.example),(NETWORK,TCP))"
            case .or: "((DOMAIN,a.example),(DOMAIN,b.example))"
            case .not: "(DOMAIN,blocked.example)"
            case .domainRegex: "^api[0-9]+\\.example\\.com$"
            case .domainWildcard: "test.*.example.com"
            case .inType: "TUN"
            case .inName: "hako-tun"
            case .inUser: "alice"
            case .rematchName: "lane-a/lane-b"
            default: "example.com"
            }
        }

        public var targetLabel: String {
            self == .subRule ? "Sub-rule list" : "Route"
        }

        public var hasLimitedIOSMeaning: Bool {
            switch self {
            case .inType, .inName, .rematchName:
                true
            default:
                false
            }
        }
    }

    public static let allCoreActionNames: Set<String> = [
        "DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "DOMAIN-REGEX",
        "DOMAIN-WILDCARD", "GEOSITE", "GEOIP", "SRC-GEOIP",
        "IP-ASN", "SRC-IP-ASN", "IP-CIDR", "IP-CIDR6",
        "SRC-IP-CIDR", "IP-SUFFIX", "SRC-IP-SUFFIX", "SRC-PORT",
        "DST-PORT", "IN-PORT", "DSCP", "PROCESS-NAME",
        "PROCESS-PATH", "PROCESS-NAME-REGEX", "PROCESS-PATH-REGEX",
        "PROCESS-NAME-WILDCARD", "PROCESS-PATH-WILDCARD",
        "NETWORK", "UID", "IN-TYPE", "IN-USER", "IN-NAME",
        "REMATCH-NAME", "SUB-RULE", "AND", "OR", "NOT", "RULE-SET",
        "MATCH", "SOURCE-APP-SIGNING-ID", "SOURCE-APP-TEAM-ID",
    ]

    @available(*, deprecated)
    public static let unavailableOnIOSActionNames =
        HakoAppleRuntimeProfile.iosPacketTunnel
            .unavailableRuleActionNames

     
     
     
     
     
     
     
    public static func availableActions(
        for runtimeProfile: HakoAppleRuntimeProfile
    ) -> [Action] {
        Action.allCases
    }

     
     
     
     
    public static func platformNote(
        for actionName: String,
        runtimeProfile: HakoAppleRuntimeProfile
    ) -> HakoDisplayText? {
        let name = actionName.uppercased()
        if runtimeProfile.removedRuleActionNames.contains(name) {
            return .format("%@ rules cannot be built in Clash's %@ packet tunnel and are removed at activation; the rule stays in the profile for other platforms.", [name, runtimeProfile.platformTitle])
        }
        if runtimeProfile.keptNeverMatchRuleActionNames.contains(name) {
            return .format("%@ rules are kept but never match in Clash's %@ packet tunnel: the owner metadata they test cannot be resolved here, so the next rule decides.", [name, runtimeProfile.platformTitle])
        }
        return nil
    }

     
     
    public static func platformNote(
        _ rule: String,
        runtimeProfile: HakoAppleRuntimeProfile
    ) -> HakoDisplayText? {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if let head = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let note = platformNote(for: head, runtimeProfile: runtimeProfile) {
            return note
        }
        let pattern = runtimeProfile.unavailableRuleActionNames
            .map(NSRegularExpression.escapedPattern).sorted().joined(separator: "|")
        guard !pattern.isEmpty,
              let range = trimmed.range(
                  of: #"(?:^|\()\s*("# + pattern + #")\s*,"#,
                  options: [.regularExpression, .caseInsensitive]
              )
        else { return nil }
        let nested = String(trimmed[range]).trimmingCharacters(in: CharacterSet(charactersIn: "(, \t"))
        return platformNote(for: nested, runtimeProfile: runtimeProfile)
    }

    public var action: Action
    public var content: String
    public var target: String
    public var noResolve: Bool
    public var src: Bool
    public var additionalParams: [String]

    public init(
        action: Action,
        content: String,
        target: String,
        noResolve: Bool = false,
        src: Bool = false,
        additionalParams: [String] = []
    ) {
        self.action = action
        self.content = content
        self.target = target
        self.noResolve = noResolve
        self.src = src
        self.additionalParams = additionalParams
    }

    public var rawValue: String {
        var fields = [action.rawValue]
        if action.needsContent {
            fields.append(content)
        }
        fields.append(target)
        if action.supportsSrc, src {
            fields.append("src")
        }
        if action.supportsNoResolve, noResolve {
            fields.append("no-resolve")
        }
        fields.append(contentsOf: additionalParams)
        return fields.joined(separator: ",")
    }

    public static func parse(_ raw: String) -> HakoStructuredRule? {
        let fields = raw.split(
            separator: ",",
            omittingEmptySubsequences: false
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let head = fields.first,
            let action = Action(rawValue: head.uppercased())
        else {
            return nil
        }

        if action == .match {
            guard fields.count == 2, !fields[1].isEmpty else {
                return nil
            }
            return HakoStructuredRule(
                action: action,
                content: "",
                target: fields[1]
            )
        }

        if action.payloadConsumesRemainingFields {
            guard fields.count >= 3,
                let target = fields.last,
                !target.isEmpty
            else {
                return nil
            }
            let content = fields[1..<(fields.count - 1)]
                .joined(separator: ",")
            guard !content.isEmpty else { return nil }
            return HakoStructuredRule(
                action: action,
                content: content,
                target: target
            )
        }

        guard fields.count >= 3,
            !fields[1].isEmpty,
            !fields[2].isEmpty
        else {
            return nil
        }
        let parameters = Array(fields.dropFirst(3))
            .filter { !$0.isEmpty }
        let noResolve = action.supportsNoResolve
            && parameters.contains {
                $0.caseInsensitiveCompare("no-resolve")
                    == .orderedSame
            }
        let src = action.supportsSrc
            && parameters.contains {
                $0.caseInsensitiveCompare("src") == .orderedSame
            }
        let additional = parameters.filter {
            $0.caseInsensitiveCompare("src") != .orderedSame
                && $0.caseInsensitiveCompare("no-resolve")
                    != .orderedSame
        }
        return HakoStructuredRule(
            action: action,
            content: fields[1],
            target: fields[2],
            noResolve: noResolve,
            src: src,
            additionalParams: additional
        )
    }

    public static func disallowReason(
        _ rule: String,
        runtimeProfile: HakoAppleRuntimeProfile
    ) -> String? {
        let trimmed = rule.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            return "The rule is empty."
        }
         
         
        guard let parsed = parse(trimmed) else {
            return "This is not a rule head Clash recognizes."
        }
        if let reason = payloadDisallowReason(
            action: parsed.action,
            content: parsed.content
        ) {
            return reason
        }
        return nil
    }

     
     
     
     
    public static func rawDisallowReason(
        _ rule: String,
        runtimeProfile: HakoAppleRuntimeProfile
    ) -> String? {
        let trimmed = rule.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            return "The rule is empty."
        }
        guard let parsed = parse(trimmed) else {
            return nil
        }
        return payloadDisallowReason(
            action: parsed.action,
            content: parsed.content
        )
    }

    private static func payloadDisallowReason(
        action: Action,
        content: String
    ) -> String? {
        switch action {
        case .srcPort, .dstPort, .inPort:
            return unsignedRangeDisallowReason(
                content,
                actionName: action.rawValue,
                maximum: UInt64(UInt16.max),
                permitsWildcard: false
            )
        case .dscp:
            return unsignedRangeDisallowReason(
                content,
                actionName: action.rawValue,
                maximum: 63,
                permitsWildcard: true
            )
        case .uid:
            return unsignedRangeDisallowReason(
                content,
                actionName: action.rawValue,
                maximum: UInt64(UInt32.max),
                permitsWildcard: false
            )
        case .and, .or, .not, .subRule:
            guard let conditions = HakoLogicExpressionCodec.parse(
                action: action,
                content: content
            ) else {
                return nil
            }
            for condition in conditions {
                if let reason = payloadDisallowReason(
                    action: condition.action,
                    content: condition.content
                ) {
                    return reason
                }
            }
            return nil
        default:
            return nil
        }
    }

     
     
     
     
     
    private static func unsignedRangeDisallowReason(
        _ content: String,
        actionName: String,
        maximum: UInt64,
        permitsWildcard: Bool
    ) -> String? {
        let trimmed = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if permitsWildcard, trimmed == "*" {
            return nil
        }
        guard !trimmed.isEmpty, trimmed != "*" else {
            return rangeExplanation(
                actionName: actionName,
                maximum: maximum
            )
        }

        let terms = trimmed
            .replacingOccurrences(of: ",", with: "/")
            .split(separator: "/", omittingEmptySubsequences: false)
        guard terms.count <= 28 else {
            return "\(actionName) supports at most 28 values or ranges."
        }

        var foundValue = false
        for term in terms {
            if term.isEmpty {
                continue
            }
            foundValue = true
            let bounds = term.split(
                separator: "-",
                omittingEmptySubsequences: false
            )
            guard bounds.count == 1 || bounds.count == 2 else {
                return rangeExplanation(
                    actionName: actionName,
                    maximum: maximum
                )
            }
            for bound in bounds {
                let valueText = bound.trimmingCharacters(
                    in: CharacterSet(charactersIn: "[] ")
                )
                guard !valueText.isEmpty,
                    let value = UInt64(valueText),
                    value <= maximum
                else {
                    return rangeExplanation(
                        actionName: actionName,
                        maximum: maximum
                    )
                }
            }
        }
        return foundValue
            ? nil
            : rangeExplanation(
                actionName: actionName,
                maximum: maximum
            )
    }

    private static func rangeExplanation(
        actionName: String,
        maximum: UInt64
    ) -> String {
        "\(actionName) must use values from 0 through \(maximum), with ranges such as 8000-9000."
    }
}
