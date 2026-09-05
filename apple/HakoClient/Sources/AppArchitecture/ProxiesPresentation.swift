import Foundation
import HakoClientUI

enum ProxyGroupControlKind: Equatable, Sendable {
    case manual
    case automatic
    case loadBalance
    case readOnly

    init(rawType: String) {
        let normalized = rawType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "selector", "select":
            self = .manual
        case "urltest", "fallback":
            self = .automatic
        case "loadbalance":
            self = .loadBalance
        default:
            self = .readOnly
        }
    }

     
     
     
     
     
     
     
     
    var acceptsMemberChoice: Bool {
        self == .manual || self == .automatic
    }

     
     
     
    var canBeUnpinned: Bool { self == .automatic }

    var badgeTitle: String {
        switch self {
        case .manual: return "Manual"
        case .automatic: return "Automatic"
        case .loadBalance: return "Load Balance"
        case .readOnly: return "Read Only"
        }
    }

    var detail: String {
        switch self {
        case .manual: return "Choose the route used by this group"
        case .automatic: return "This profile chooses the route automatically"
        case .loadBalance: return "Each connection may use a different route"
        case .readOnly: return "This group is managed by the current profile"
        }
    }
}

struct ProxyNodeRecord: Equatable, Identifiable, Sendable {
    let name: String
    let type: String
    let delay: Int?
    let groupNames: [String]
    let protocolDetails: ProxyProtocolDetails?

    init(
        name: String,
        type: String,
        delay: Int?,
        groupNames: [String],
        protocolDetails: ProxyProtocolDetails? = nil
    ) {
        self.name = name
        self.type = type
        self.delay = delay
        self.groupNames = groupNames
        self.protocolDetails = protocolDetails
    }

    var id: String { name }
}

struct ProxyRoutePresentation: Equatable, Identifiable {
    let originalName: String
    let title: String
    let subtitle: String
    let providerName: String?
    let delayMilliseconds: Int?
    let isSelected: Bool
    let isSelectable: Bool
    let supportsLatencyTest: Bool
    let symbol: HakoSymbol
    let kind: ProxyRouteKind
    let resolvedRouteTitle: String?
    let countryFlag: String

    var id: String { originalName }

    var secondaryTitle: String {
        if kind == .policyGroup, let resolvedRouteTitle, !resolvedRouteTitle.isEmpty {
            return resolvedRouteTitle
        }
        return subtitle
    }

    var delayState: ProxyDelayState {
        guard let delayMilliseconds else { return .unavailable }
        guard delayMilliseconds > 0 else { return .failed }
        return .measured(delayMilliseconds)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var delayTitle: String {
        switch delayState {
        case .unavailable: return ""
        case .failed: return HakoProbeFailureCopy.neutralBadge
        case let .measured(milliseconds): return "\(milliseconds) ms"
        }
    }

    var supportsNodeDetails: Bool { kind == .node }
}

enum ProxyRouteKind: Equatable, Sendable {
    case node
    case policyGroup
    case builtin
}

enum ProxyDelayState: Equatable, Sendable {
    case unavailable
    case failed
    case measured(Int)
}

enum ProxyRoutePresenter {
    static func presentation(
        name: String,
        type: String,
        delay: Int?,
        providerName: String?,
        isSelected: Bool,
        isSelectable: Bool = true,
        kind: ProxyRouteKind = .node,
        resolvedRouteTitle: String? = nil
    ) -> ProxyRoutePresentation {
         
         
         
        let semantic = semanticBuiltin(name)
        let isBuiltin = BuiltinProxyName.all.contains(name)
        let resolvedKind: ProxyRouteKind = isBuiltin ? .builtin : kind
        return ProxyRoutePresentation(
            originalName: name,
            title: semantic?.title ?? name,
            subtitle: semantic?.subtitle ?? ProxyTypePresentation.title(for: type),
            providerName: isBuiltin ? nil : normalizedProvider(providerName),
            delayMilliseconds: isBuiltin ? nil : delay,
            isSelected: isSelected,
            isSelectable: isSelectable,
            supportsLatencyTest: resolvedKind == .node,
            symbol: semantic?.symbol ?? ProxyTypePresentation.symbol(for: type),
            kind: resolvedKind,
            resolvedRouteTitle: resolvedRouteTitle,
            countryFlag: resolvedKind == .node
                ? ProxyCountryPresentation.flag(for: name)
                : ""
        )
    }

    static func displayName(for name: String) -> String {
        semanticBuiltin(name)?.title ?? name
    }

    private static func normalizedProvider(_ provider: String?) -> String? {
        guard let value = provider?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private static func semanticBuiltin(
        _ normalized: String
    ) -> (title: String, subtitle: String, symbol: HakoSymbol)? {
        switch normalized {
        case "DIRECT":
            return ("Direct Connection", "Connect without a proxy", .arrowLeftArrowRight)
        case "REJECT", "REJECT-DROP":
            return ("Block Connection", "Stop matching connections", .xmarkOctagonFill)
        case "PASS":
            return ("Continue Matching", "Continue with the next matching rule", .arrowUturnForward)
        case "COMPATIBLE":
            return ("Compatible Route", "Use the profile's compatible route", .network)
        default:
            return nil
        }
    }
}

enum ProxyCountryPresentation {
    private static let regionalIndicatorRange = 0x1F1E6...0x1F1FF

    private static let markers: [(flag: String, values: [String])] = [
        ("🇭🇰", ["香港", "hong kong", "hk"]),
        ("🇸🇬", ["新加坡", "singapore", "sg"]),
        ("🇯🇵", ["日本", "东京", "東京", "大阪", "japan", "tokyo", "osaka", "jp"]),
        ("🇺🇸", ["美国", "洛杉矶", "洛杉磯", "硅谷", "矽谷", "纽约", "紐約", "united states", "los angeles", "silicon valley", "new york", "usa", "us"]),
        ("🇹🇼", ["台湾", "臺灣", "台北", "taiwan", "taipei", "tw"]),
        ("🇰🇷", ["韩国", "韓國", "首尔", "首爾", "korea", "seoul", "kr"]),
        ("🇬🇧", ["英国", "英國", "伦敦", "倫敦", "united kingdom", "london", "uk", "gb"]),
        ("🇫🇷", ["法国", "法國", "巴黎", "france", "paris", "fr"]),
        ("🇩🇪", ["德国", "德國", "法兰克福", "法蘭克福", "germany", "frankfurt", "de"]),
        ("🇨🇦", ["加拿大", "多伦多", "多倫多", "canada", "toronto", "ca"]),
        ("🇦🇺", ["澳大利亚", "澳洲", "悉尼", "australia", "sydney", "au"]),
        ("🇳🇱", ["荷兰", "荷蘭", "阿姆斯特丹", "netherlands", "amsterdam", "nl"]),
    ]

    static func flag(for name: String) -> String {
        let scalars = Array(name.unicodeScalars)
        if scalars.count >= 2 {
            for index in 0..<(scalars.count - 1) {
                if regionalIndicatorRange.contains(Int(scalars[index].value)),
                   regionalIndicatorRange.contains(Int(scalars[index + 1].value)) {
                    return String(String.UnicodeScalarView([scalars[index], scalars[index + 1]]))
                }
            }
        }

        let normalized = name.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()
        let tokens = Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        for marker in markers {
            if marker.values.contains(where: { value in
                value.unicodeScalars.allSatisfy(\.isASCII) && value.count <= 3
                    ? tokens.contains(value)
                    : normalized.contains(value)
            }) {
                return marker.flag
            }
        }
        return "🌐"
    }
}

struct ProxyGroupPresentation: Equatable, Identifiable {
    let name: String
    let controlKind: ProxyGroupControlKind
    let badgeTitle: String
    let detail: String
    let currentTitle: String
    let currentDetail: String
    let routes: [ProxyRoutePresentation]
    let configurationDetails: ProxyGroupConfigurationDetails?
    let trafficUsage: ProxyTrafficUsage?

    init(
        name: String,
        controlKind: ProxyGroupControlKind,
        badgeTitle: String,
        detail: String,
        currentTitle: String,
        currentDetail: String,
        routes: [ProxyRoutePresentation],
        configurationDetails: ProxyGroupConfigurationDetails? = nil,
        trafficUsage: ProxyTrafficUsage? = nil
    ) {
        self.name = name
        self.controlKind = controlKind
        self.badgeTitle = badgeTitle
        self.detail = detail
        self.currentTitle = currentTitle
        self.currentDetail = currentDetail
        self.routes = routes
        self.configurationDetails = configurationDetails
        self.trafficUsage = trafficUsage
    }

    var id: String { name }

    var currentRouteTitle: String {
        let prefix = "Current → "
        guard currentTitle.hasPrefix(prefix) else { return currentTitle }
        return String(currentTitle.dropFirst(prefix.count))
    }

    var catalogSubtitle: String {
        trafficUsage?.catalogTitle ?? "No routing rules target this group"
    }

    func filteredRoutes(query: String) -> [ProxyRoutePresentation] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return routes }
        return routes.filter { route in
            route.title.localizedCaseInsensitiveContains(value)
                || route.originalName.localizedCaseInsensitiveContains(value)
                || route.subtitle.localizedCaseInsensitiveContains(value)
                || route.providerName?.localizedCaseInsensitiveContains(value) == true
        }
    }
}

 
 
 
enum ProxyGroupBrowser {
    static func activeGroup(
        in groups: [ProxyGroupPresentation],
        preferredName: String?
    ) -> ProxyGroupPresentation? {
        if let preferredName,
           let preferred = groups.first(where: { $0.name == preferredName }) {
            return preferred
        }
        return groups.first
    }
}

enum ProxyBrowserCatalog {
    static func filteredGroups(
        _ groups: [ProxyGroupPresentation],
        query: String
    ) -> [ProxyGroupPresentation] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(value)
                || group.badgeTitle.localizedCaseInsensitiveContains(value)
                || group.currentTitle.localizedCaseInsensitiveContains(value)
                || group.currentDetail.localizedCaseInsensitiveContains(value)
                || group.trafficUsage?.descriptions.contains(where: {
                    $0.localizedCaseInsensitiveContains(value)
                }) == true
                || group.routes.contains { route in
                    route.title.localizedCaseInsensitiveContains(value)
                        || route.originalName.localizedCaseInsensitiveContains(value)
                        || route.providerName?.localizedCaseInsensitiveContains(value) == true
                }
        }
    }

    static func filteredNodes(
        _ nodes: [ProxyNodeRecord],
        providerNamesByProxy: [String: String],
        query: String
    ) -> [ProxyNodeRecord] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nodes }
        return nodes.filter { node in
            node.name.localizedCaseInsensitiveContains(value)
                || node.type.localizedCaseInsensitiveContains(value)
                || node.groupNames.contains {
                    $0.localizedCaseInsensitiveContains(value)
                }
                || providerNamesByProxy[node.name]?
                    .localizedCaseInsensitiveContains(value) == true
        }
    }
}

enum ProxyGroupPresenter {
    static func presentation(
        group: ProxyGroup,
        delays: [String: Int],
        providerNamesByProxy: [String: String],
        trafficUsage: ProxyTrafficUsage? = nil
    ) -> ProxyGroupPresentation {
        let controlKind = ProxyGroupControlKind(rawType: group.type)
        let selectedName = ProxyRoutePresenter.displayName(for: group.now)
        let resolvedName = ProxyRoutePresenter.displayName(for: group.resolvedNow)
        let currentTitle: String
        if controlKind == .loadBalance {
            currentTitle = "\(group.members.count) candidate routes"
        } else if !selectedName.isEmpty, selectedName != resolvedName {
            currentTitle = "Current → \(selectedName) → \(resolvedName)"
        } else {
            currentTitle = "Current → \(resolvedName)"
        }
        return ProxyGroupPresentation(
            name: group.name,
            controlKind: controlKind,
            badgeTitle: controlKind.badgeTitle,
            detail: controlKind.detail,
            currentTitle: currentTitle,
            currentDetail: currentDetail(group: group, kind: controlKind),
            routes: group.members.map { member in
                ProxyRoutePresenter.presentation(
                    name: member,
                    type: group.memberTypes[member] ?? "?",
                    delay: delays[member],
                    providerName: providerNamesByProxy[member],
                    isSelected: controlKind != .loadBalance && member == group.now,
                    isSelectable: controlKind == .manual,
                    kind: group.memberGroupNames.contains(member) ? .policyGroup : .node,
                    resolvedRouteTitle: group.memberResolvedNames[member]
                )
            },
            configurationDetails: group.configurationDetails,
            trafficUsage: trafficUsage
        )
    }

    private static func currentDetail(
        group: ProxyGroup,
        kind: ProxyGroupControlKind
    ) -> String {
        switch kind {
        case .manual:
            if group.now == group.resolvedNow { return "Selected manually" }
            return "Via \(ProxyRoutePresenter.displayName(for: group.now))"
        case .automatic:
            return "Chosen automatically"
        case .loadBalance:
            return "A route is chosen for each connection"
        case .readOnly:
            return "Managed by this profile"
        }
    }
}

struct ProxyTrafficUsage: Equatable, Sendable {
    let ruleCount: Int
    let descriptions: [String]

    var catalogTitle: String {
        guard let first = descriptions.first else { return "No direct traffic rules" }
        let remaining = max(0, ruleCount - 1)
        return remaining == 0 ? first : "\(first) + \(remaining) more"
    }
}

enum ProxyTrafficUsageInspector {
    static func summariesByGroupName(yaml: String) -> [String: ProxyTrafficUsage] {
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: yaml) else { return [:] }
        return parsed.memo("proxies.trafficUsage") { summariesByGroupName(root: parsed.root) }
    }

    static func summariesByGroupName(root: [String: Any]) -> [String: ProxyTrafficUsage] {
        var rules = root["rules"] as? [String] ?? []
        if let subRules = root["sub-rules"] as? [String: [String]] {
            rules.append(contentsOf: subRules.values.flatMap { $0 })
        }
        return summaries(rules: rules)
    }

    static func activeSummaries() -> [String: ProxyTrafficUsage] {


         
         
        guard let yaml = ActiveConfigurationText.current() else { return [:] }
        return summariesByGroupName(yaml: yaml)
    }

    static func summaries(rules: [String]) -> [String: ProxyTrafficUsage] {
        var descriptionsByTarget: [String: [String]] = [:]
         
         
         
         
        var seenByTarget: [String: Set<String>] = [:]
        var countsByTarget: [String: Int] = [:]
        for rawRule in rules {
            guard let rule = StructuredRule.parse(rawRule) else { continue }
            countsByTarget[rule.target, default: 0] += 1
            let description = description(for: rule)
            if seenByTarget[rule.target, default: []].insert(description).inserted {
                descriptionsByTarget[rule.target, default: []].append(description)
            }
        }
        return descriptionsByTarget.reduce(into: [:]) { result, entry in
            result[entry.key] = ProxyTrafficUsage(
                ruleCount: countsByTarget[entry.key] ?? entry.value.count,
                descriptions: entry.value
            )
        }
    }

    private static func description(for rule: StructuredRule) -> String {
        switch rule.action {
        case .match:
            return "All remaining traffic"
        case .domain:
            return rule.content
        case .domainSuffix:
            return "\(rule.content) and subdomains"
        case .domainKeyword:
            return "Domains containing “\(rule.content)”"
        case .domainRegex:
            return "Domains matching a configured pattern"
        case .domainWildcard:
            return "Domains matching · \(rule.content)"
        case .geosite:
            if rule.content.localizedCaseInsensitiveContains("ads") {
                return "Ads and tracking domains"
            }
            return "GeoSite · \(rule.content)"
        case .geoip:
            return "Destination region · \(rule.content)"
        case .srcGeoIP:
            return "Source region · \(rule.content)"
        case .ipCIDR, .ipCIDR6:
            return "Destination network · \(rule.content)"
        case .ipASN:
            return "Destination ASN · \(rule.content)"
        case .srcIPASN:
            return "Source ASN · \(rule.content)"
        case .srcIPCIDR:
            return "Source network · \(rule.content)"
        case .ipSuffix:
            return "Destination IP suffix · \(rule.content)"
        case .srcIPSuffix:
            return "Source IP suffix · \(rule.content)"
        case .dstPort:
            return "Destination port · \(rule.content)"
        case .srcPort:
            return "Source port · \(rule.content)"
        case .inPort:
            return "Inbound port · \(rule.content)"
        case .dscp:
            return "DSCP · \(rule.content)"
        case .processName:
            return "Process name · \(rule.content)"
        case .processPath:
            return "Process path · \(rule.content)"
        case .processNameRegex:
            return "Process name matching a configured pattern"
        case .processPathRegex:
            return "Process path matching a configured pattern"
        case .processNameWildcard:
            return "Process name wildcard · \(rule.content)"
        case .processPathWildcard:
            return "Process path wildcard · \(rule.content)"
        case .uid:
            return "UID · \(rule.content)"
        case .network:
            return "\(rule.content.uppercased()) traffic"
        case .inType:
            return "Inbound type · \(rule.content)"
        case .inName:
            return "Inbound name · \(rule.content)"
        case .inUser:
            return "Inbound user · \(rule.content)"
        case .sourceAppSigningID:
            return "Source app signing ID · \(rule.content)"
        case .sourceAppTeamID:
            return "Source app team ID · \(rule.content)"
        case .rematchName:
            return "Rematch · \(rule.content)"
        case .subRule:
            return "Sub-rule branch · \(rule.target)"
        case .and:
            return "All configured conditions"
        case .or:
            return "Any configured condition"
        case .not:
            return "When a configured condition does not match"
        case .ruleSet:
            return "Rule set · \(rule.content)"
        }
    }
}

extension ProxyProviderRuntime {
     
     
     
     
     
     
     
     
    var isKernelInternal: Bool {
        vehicleType?.caseInsensitiveCompare("Compatible") == .orderedSame
            || name == "default"
    }
}

enum ProxyProviderAttribution {
    static func uniqueProviderNames(
        in catalog: ProviderRuntimeCatalog
    ) -> [String: String] {
        var providersByProxy: [String: Set<String>] = [:]
        for provider in catalog.proxyProviders.values where !provider.isKernelInternal {
             
            let providerName = provider.name
            guard !providerName.isEmpty else { continue }
            for proxy in provider.proxies {
                let proxyName = proxy.name
                guard !proxyName.isEmpty else { continue }
                providersByProxy[proxyName, default: []].insert(providerName)
            }
        }
        return providersByProxy.reduce(into: [:]) { result, entry in
            guard entry.value.count == 1, let provider = entry.value.first else { return }
            result[entry.key] = provider
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxiesRuntimeCatalogComposer {
    static func groups(
        source: [ProxiesOverviewModel.Group],
        runtime: [ProxyGroup],
        isConnected: Bool
    ) -> [ProxiesOverviewModel.Group] {
         
         
         
        guard isConnected, !runtime.isEmpty else { return source }

        let configuredByGroup = Dictionary(
            source.map { ($0.name, $0.configuredSelection) },
            uniquingKeysWith: { first, _ in first }
        )
         
         
         
         
         
         
        let chainedByNode = Dictionary(
            source.flatMap { $0.members }
                .compactMap { member in
                    member.chainedThrough.map { (member.name, $0) }
                },
            uniquingKeysWith: { first, _ in first }
        )
         
         
         
         
         
         
        let iconByGroup = Dictionary(
            source.compactMap { group in group.icon.map { (group.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        return runtime.map { group in
            ProxiesOverviewModel.Group(
                name: group.name,
                type: group.type,
                members: group.members.map { member in
                    let isGroup = group.memberGroupNames.contains(member)
                    return ProxiesOverviewModel.Member(
                        name: member,
                        type: group.memberTypes[member] ?? "",
                        isGroup: isGroup,
                         
                         
                        chainedThrough: isGroup ? nil : chainedByNode[member]
                    )
                },
                 
                 
                 
                 
                 
                configuredSelection: configuredByGroup[group.name] ?? nil,
                hidden: group.hidden,
                 
                 
                 
                 
                icon: group.iconURL ?? iconByGroup[group.name]
            )
        }
    }
     
     
     
     
     
     
     
     
    static func searchableProxies(
        source: [ProxiesOverviewModel.Proxy],
        runtime: [ProxiesOverviewModel.Proxy],
        isConnected: Bool,
        runtimeIsAuthoritative: Bool = false
    ) -> [ProxiesOverviewModel.Proxy] {
        guard isConnected, !runtime.isEmpty || runtimeIsAuthoritative else {
            return source
        }
        return runtime
    }

     
     
     
    static func ungrouped(
        source: [ProxiesOverviewModel.Proxy],
        runtimeNodes: [ProxiesOverviewModel.Proxy],
        runtimeGroups: [ProxyGroup],
        isConnected: Bool,
        runtimeIsAuthoritative: Bool = false
    ) -> [ProxiesOverviewModel.Proxy] {
        guard isConnected, !runtimeNodes.isEmpty || runtimeIsAuthoritative else {
            return source
        }
        var listed = Set<String>()
        for group in runtimeGroups {
            listed.insert(group.name)
            listed.formUnion(group.members)
        }
        return runtimeNodes.filter { !listed.contains($0.name) }
    }

     
     
     
    static func providers(
        source: [ProxiesOverviewModel.Provider],
        runtime: ProviderRuntimeCatalog,
        isConnected: Bool,
    ) -> [ProxiesOverviewModel.Provider] {
        guard isConnected, !runtime.proxyProviders.isEmpty else {
            return source
        }
         
         
         
         
         
        var order: [String: Int] = [:]
        for (index, provider) in source.enumerated() where order[provider.name] == nil {
            order[provider.name] = index
        }
        let names = runtime.proxyProviders
            .filter { !$0.value.isKernelInternal }
            .keys
            .sorted { lhs, rhs in
                let left = order[lhs] ?? Int.max
                let right = order[rhs] ?? Int.max
                if left != right { return left < right }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
         
         
         
         
         
         
        var failureByName: [String: String] = [:]
        for provider in source where provider.loadFailure != nil {
            failureByName[provider.name] = provider.loadFailure
        }
        return names.map { name in
                let provider = runtime.proxyProviders[name]
                let liveCount = provider?.proxies.count ?? 0
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                return ProxiesOverviewModel.Provider(
                    name: name,
                    type: provider?.vehicleType?.lowercased() ?? "",
                    nodeCount: provider?.proxies.count,
                    loadFailure: liveCount > 0 ? nil : failureByName[name]
                )
            }
    }

}
