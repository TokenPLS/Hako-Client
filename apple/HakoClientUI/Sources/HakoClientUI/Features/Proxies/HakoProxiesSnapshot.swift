import Foundation
import HakoClientKit

public struct HakoProxiesDisplayPreferences:
    Codable,
    Equatable,
    Sendable
{
    public enum Style: String, CaseIterable, Codable, Sendable {
        case list
        case tabs
    }

    public enum Sort: String, CaseIterable, Codable, Sendable {
        case standard
        case delay
        case name
    }

    public enum Layout: String, CaseIterable, Codable, Sendable {
        case loose
        case compact
    }

    public enum Size: String, CaseIterable, Codable, Sendable {
        case standard
        case compact
        case minimal
    }

    public var style: Style
    public var sort: Sort
    public var layout: Layout
    public var size: Size
     
     
     
     
     
     
     
     
     
     
     
     
    public var groupIconImages: Bool

    public init(
        style: Style = .list,
        sort: Sort = .standard,
        layout: Layout = .loose,
        size: Size = .standard,
        groupIconImages: Bool = false
    ) {
        self.style = style
        self.sort = sort
        self.layout = layout
        self.size = size
        self.groupIconImages = groupIconImages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decodeIfPresent(Style.self, forKey: .style) ?? .list
        sort = try container.decodeIfPresent(Sort.self, forKey: .sort) ?? .standard
        layout = try container.decodeIfPresent(Layout.self, forKey: .layout) ?? .loose
        size = try container.decodeIfPresent(Size.self, forKey: .size) ?? .standard
        groupIconImages = try container.decodeIfPresent(
            Bool.self, forKey: .groupIconImages
        ) ?? false
    }
}

public enum HakoProxyLatencyState: Codable, Equatable, Sendable {
    case untested
    case testing
    case measured(milliseconds: Int)
    case failed
    case timedOut

    var normalized: HakoProxyLatencyState {
        switch self {
        case .measured(let milliseconds):
            guard (1...3_600_000).contains(milliseconds) else {
                return milliseconds <= 0 ? .timedOut : .failed
            }
            return self
        case .untested, .testing, .failed, .timedOut:
            return self
        }
    }

     
     
     
     
    public var tier: HakoProxyLatencyTier? {
        guard case .measured(let milliseconds) = self else { return nil }
        if milliseconds < 800 { return .fast }
        if milliseconds < 1_600 { return .slow }
        return .slower
    }
}

 
 
public enum HakoProxyLatencyTier: Equatable, Sendable {
    case fast
    case slow
    case slower
}

 
 
 
 
 
 
 
public enum HakoProxyLatencyAffordance: Equatable, Sendable {
    case offersTest
    case inProgress
    case showsResultAndRetests

    public static func of(
        _ state: HakoProxyLatencyState
    ) -> HakoProxyLatencyAffordance {
        switch state {
        case .untested: .offersTest
        case .testing: .inProgress
         
         
        case .measured, .failed, .timedOut: .showsResultAndRetests
        }
    }
}

public struct HakoProxySnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public var id: String { name }
    public let name: String
    public let type: String

    public init(name: String, type: String) {
         
         
         
         
         
         
        self.name = name
        self.type = Self.presentationText(type)
    }

    private static func presentationText(_ value: String) -> String {
        String(value.prefix(256))
    }
}

public struct HakoProxyMemberSnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public var id: String { name }
    public let name: String
    public let type: String
    public let isGroup: Bool
     
     
     
     
     
     
     
    public let chainedThrough: String?

    public init(
        name: String,
        type: String,
        isGroup: Bool = false,
        chainedThrough: String? = nil
    ) {
         
         
         
         
         
         
        self.name = name
        self.type = String(type.prefix(256))
        self.isGroup = isGroup
        self.chainedThrough = chainedThrough.map { String($0.prefix(256)) }
    }
}

public struct HakoProxyGroupSnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public var id: String { name }
    public let name: String
    public let type: String
    public let members: [HakoProxyMemberSnapshot]
    public let configuredSelection: String?
    public let runtimeSelection: String?
    public let resolvedRuntimeRoute: String?
     
     
    public let icon: String?

    public init(
        name: String,
        type: String,
        members: [HakoProxyMemberSnapshot],
        configuredSelection: String? = nil,
        runtimeSelection: String? = nil,
        resolvedRuntimeRoute: String? = nil,
        icon: String? = nil
    ) {
         
         
         
         
         
         
        self.name = name
        self.type = String(type.prefix(256))
        self.members = members
        self.configuredSelection = Self.normalizedSelection(
            configuredSelection,
            members: members
        )
        self.runtimeSelection = Self.normalizedSelection(
            runtimeSelection,
            members: members
        )
        self.resolvedRuntimeRoute = Self.nonemptyPresentationText(
            resolvedRuntimeRoute
        )
         
         
         
         
         
        let trimmedIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = (trimmedIcon?.isEmpty ?? true) ? nil : trimmedIcon
    }

    public var currentSelection: String? {
        runtimeSelection ?? configuredSelection
    }

    private var normalizedType: String {
        type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isManual: Bool {
        normalizedType == "select" || normalizedType == "selector"
    }

     
     
     
     
     
     
     
    public var allowsMemberChoice: Bool {
        isManual || canBeUnpinned
    }

     
     
     
     
     
     
     
     
     
    public var memberChoiceRefusal: String? {
        guard !allowsMemberChoice else { return nil }
        if normalizedType == "relay" {
            return "A relay sends traffic through its members in order, so there is no one member to choose."
        }
        if normalizedType == "load-balance" || normalizedType == "loadbalance" {
            return "A load-balance group spreads connections across its members, so it has no single route to pin."
        }
        return "This group picks its own member."
    }

     
     
     
    public var canBeUnpinned: Bool {
         
         
         
         
         
        ["url-test", "urltest", "fallback"].contains(normalizedType)
    }

     
     
     
     
     
     
    public var allowsOfflineConfiguredRoute: Bool {
        isManual || configuredSelection != nil
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static func normalizedSelection(
        _ value: String?,
        members: [HakoProxyMemberSnapshot]
    ) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              members.contains(where: { $0.name == value }) else {
            return nil
        }
        return value
    }

    private static func nonemptyPresentationText(
        _ value: String?
    ) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(256))
    }
}

public struct HakoProxyProviderSnapshot:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public var id: String { name }
    public let name: String
    public let type: String
    public let nodeCount: Int?
     
     
     
     
     
     
     
     
    public let nodes: [HakoProxyMemberSnapshot]?

     
     
     
     
     
     
     
     
     
     
     
     
     
    public let loadFailure: String?

    public init(
        name: String,
        type: String,
        nodeCount: Int? = nil,
        nodes: [HakoProxyMemberSnapshot]? = nil,
        loadFailure: String? = nil
    ) {
         
         
         
         
         
         
        self.name = name
        self.type = String(type.prefix(256))
        self.nodeCount = nodeCount.map { max(0, $0) }
        self.nodes = nodes
        self.loadFailure = loadFailure.flatMap {
            $0.isEmpty ? nil : String($0.prefix(2048))
        }
    }
}

public enum HakoProxiesCatalogState:
    Codable,
    Equatable,
    Sendable
{
    case disconnected
    case loading
    case ready
    case failed(message: String)
}

 
 
 
 
 
public struct HakoProxiesSnapshot: Codable, Equatable, Sendable {
    public let groups: [HakoProxyGroupSnapshot]
    public let searchableProxies: [HakoProxySnapshot]
    public let providers: [HakoProxyProviderSnapshot]
    public let ungrouped: [HakoProxySnapshot]
     
     
     
     
     
     
     
    public let browsingSuppressedByDirectMode: Bool
    public let latencyByName: [String: HakoProxyLatencyState]
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public let failureCategories: [String: String]
    public let isConnected: Bool
    public let isTestingLatency: Bool
    public let latencyCompletedCount: Int
    public let latencyTotalCount: Int
    public let initiallyExpandedGroup: String?
     
     
     
    public let rememberedExpandedGroups: Set<String>
    public let displayPreferences: HakoProxiesDisplayPreferences
     
     
    public let catalogState: HakoProxiesCatalogState?
     
     
    public let canRefreshCatalog: Bool?
     
     
     
     
     
     
     
     
    public let canUnpinGroups: Bool?

     
     
     
     
     
     
     
     
     
    public let actionRefusals: [String: String]

     
    public func offersUnpin(for group: HakoProxyGroupSnapshot) -> Bool {
        guard canUnpinGroups == true else { return false }
         
         
         
         
        return group.canBeUnpinned && group.configuredSelection != nil
    }

    public init(
        groups: [HakoProxyGroupSnapshot] = [],
        searchableProxies: [HakoProxySnapshot] = [],
        providers: [HakoProxyProviderSnapshot] = [],
        ungrouped: [HakoProxySnapshot] = [],
        browsingSuppressedByDirectMode: Bool = false,
        latencyByName: [String: HakoProxyLatencyState] = [:],
        failureCategories: [String: String] = [:],
        isConnected: Bool = false,
        isTestingLatency: Bool = false,
        latencyCompletedCount: Int = 0,
        latencyTotalCount: Int = 0,
        initiallyExpandedGroup: String? = nil,
        rememberedExpandedGroups: Set<String> = [],
        displayPreferences: HakoProxiesDisplayPreferences = .init(),
        catalogState: HakoProxiesCatalogState? = nil,
        canRefreshCatalog: Bool? = nil,
        canUnpinGroups: Bool? = nil,
        actionRefusals: [String: String] = [:]
    ) {
        self.groups = groups
        self.searchableProxies = searchableProxies
        self.providers = providers
        self.ungrouped = ungrouped
        self.browsingSuppressedByDirectMode = browsingSuppressedByDirectMode
        self.latencyByName = latencyByName.reduce(into: [:]) {
            normalized, entry in
            let key = String(entry.key.prefix(256))
            if normalized[key] == nil {
                normalized[key] = entry.value.normalized
            }
        }
        self.failureCategories = failureCategories
        self.isConnected = isConnected
        self.isTestingLatency = isTestingLatency
        let total = max(0, latencyTotalCount)
        self.latencyTotalCount = total
        self.latencyCompletedCount = min(
            max(0, latencyCompletedCount),
            total
        )
        self.initiallyExpandedGroup = initiallyExpandedGroup.flatMap { name in
             
            groups.contains(where: { $0.name == name }) ? name : nil
        }
         
         
        let declared = Set(groups.map(\.name))
        self.rememberedExpandedGroups =
            rememberedExpandedGroups.intersection(declared)
        self.displayPreferences = displayPreferences
        self.catalogState = catalogState.map {
            switch $0 {
            case .failed(let message):
                return .failed(
                    message: String(message.prefix(512))
                )
            case .disconnected:
                return .disconnected
            case .loading:
                return .loading
            case .ready:
                return .ready
            }
        }
        self.canRefreshCatalog = canRefreshCatalog
        self.canUnpinGroups = canUnpinGroups
        self.actionRefusals = actionRefusals
    }

    public static let empty = HakoProxiesSnapshot()

    public var effectiveCatalogState: HakoProxiesCatalogState {
        catalogState ?? .ready
    }

    public func group(named name: String) -> HakoProxyGroupSnapshot? {
        groups.first { $0.name == name }
    }

    public func latency(for name: String) -> HakoProxyLatencyState {
        latencyByName[name] ?? .untested
    }

    public func members(
        in group: HakoProxyGroupSnapshot,
        sortedBy sort: HakoProxiesDisplayPreferences.Sort
    ) -> [HakoProxyMemberSnapshot] {
        switch sort {
        case .standard:
            return group.members
        case .name:
            return group.members.enumerated().sorted {
                let comparison = $0.element.name.localizedStandardCompare(
                    $1.element.name
                )
                return comparison == .orderedSame
                    ? $0.offset < $1.offset
                    : comparison == .orderedAscending
            }.map(\.element)
        case .delay:
            return group.members.enumerated().sorted {
                let lhs = delaySortKey(
                    displayedLatency(for: $0.element),
                    offset: $0.offset
                )
                let rhs = delaySortKey(
                    displayedLatency(for: $1.element),
                    offset: $1.offset
                )
                return lhs < rhs
            }.map(\.element)
        }
    }

     
     
     
     
     
     
     
     
     
    public func groups(matching query: String) -> [HakoProxyGroupSnapshot] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return groups }
        return groups.compactMap { group in
            let members = group.members.filter {
                $0.name.localizedCaseInsensitiveContains(needle)
            }
            guard !members.isEmpty else { return nil }
            return HakoProxyGroupSnapshot(
                name: group.name,
                type: group.type,
                members: members,
                configuredSelection: group.configuredSelection,
                runtimeSelection: group.runtimeSelection,
                resolvedRuntimeRoute: group.resolvedRuntimeRoute,
                 
                 
                 
                icon: group.icon
            )
        }
    }

     
     
     
    public func ungroupedNodes(matching query: String) -> [HakoProxySnapshot] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return ungrouped }
        return ungrouped.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
        }
    }

     
     
     
    public func resolvedDisplayRoute(
        for member: HakoProxyMemberSnapshot
    ) -> String? {
        guard member.isGroup, let group = group(named: member.name) else {
            return member.name
        }
        if isConnected {
            return group.resolvedRuntimeRoute ?? group.runtimeSelection
        }
        guard group.allowsOfflineConfiguredRoute else { return nil }
        return resolvedConfiguredRoute(forGroupNamed: group.name)
    }

     
     
     
     
    public func displayedLatency(
        for member: HakoProxyMemberSnapshot
    ) -> HakoProxyLatencyState {
        let direct = latency(for: member.name)
        guard direct == .untested,
              let route = resolvedDisplayRoute(for: member) else {
            return direct
        }
        return latency(for: route)
    }

    public func resolvedConfiguredRoute(
        forGroupNamed name: String
    ) -> String? {
        let selections = Dictionary(
            uniqueKeysWithValues: groups.compactMap { group in
                group.configuredSelection.map { (group.name, $0) }
            }
        )
        return resolvedRoute(
            from: selections[name],
            selectionsByGroup: selections
        )
    }

    private func resolvedRoute(
        from initial: String?,
        selectionsByGroup: [String: String]
    ) -> String? {
        guard var current = initial, !current.isEmpty else { return nil }
        var visited = Set<String>()
        while group(named: current) != nil {
            guard visited.insert(current).inserted,
                  let next = selectionsByGroup[current],
                  !next.isEmpty else {
                return nil
            }
            current = next
        }
        return current
    }

    private func delaySortKey(
        _ latency: HakoProxyLatencyState,
        offset: Int
    ) -> (Int, Int, Int) {
        switch latency {
        case .measured(let milliseconds):
            return (0, milliseconds, offset)
        case .testing:
            return (1, 0, offset)
        case .untested:
            return (2, 0, offset)
        case .failed:
            return (3, 0, offset)
        case .timedOut:
            return (4, 0, offset)
        }
    }
}

 
 
public enum HakoProxyBrowsing {
     
     
     
     
    public static let ungroupedKey = "\u{0}ungrouped"

     
     
     
     
     
    public static func inspects(_ member: HakoProxyMemberSnapshot) -> Bool {
        if member.isGroup { return false }
        if LatencyProbeNamePolicy.builtinNames.contains(
            member.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        ) { return false }
         
         
         
        return !routeTypesWithoutABody.contains(
            member.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

     
     
    private static let routeTypesWithoutABody: Set<String> = [
        "direct", "reject", "reject-drop", "pass", "compatible",
    ]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static func groupAnchor(_ name: String) -> AnyHashable {
        "proxies.group.\(name)"
    }

    public static func columnCount(
        availableWidth: Double,
        layout: HakoProxiesDisplayPreferences.Layout
    ) -> Int {
        let readableCardWidth = 250.0
        let base = max(Int((availableWidth / readableCardWidth).rounded(.up)), 2)
        switch layout {
        case .loose: return max(base - 1, 1)
        case .compact: return base
        }
    }

     
     
     
     
     
    public static func groupsToOpenOnEntry(
        remembered: Set<String>,
        destination: String?
    ) -> Set<String> {
        if let destination { return [destination] }
        return remembered.count == 1 ? remembered : []
    }

    public static func showsMembers(
        of group: String,
        expanded: Set<String>,
        isSearching: Bool
    ) -> Bool {
        isSearching || expanded.contains(group)
    }
}
