import Combine
import Foundation
import HakoClientKit
import HakoClientUI

struct ProxyGroup: Identifiable, Equatable {
    let name: String
    let type: String        
    let now: String         
    let resolvedNow: String  
    let members: [String]
    let memberTypes: [String: String]
    let memberGroupNames: Set<String>
    let memberResolvedNames: [String: String]
    let configurationDetails: ProxyGroupConfigurationDetails?
     
    let hidden: Bool
     
     
     
     
    let testURL: String?
     
     
     
     
     
    let iconURL: String?
    var id: String { name }
    var selectable: Bool { type.lowercased().contains("selector") || type.lowercased() == "select" }

     
     
     
     
     
     
     
     
    var acceptsMemberChoice: Bool {
        ProxyGroupControlKind(rawType: type).acceptsMemberChoice
    }

    init(name: String, type: String, now: String, members: [String],
         resolvedNow: String? = nil, memberTypes: [String: String] = [:],
         memberGroupNames: Set<String> = [],
         memberResolvedNames: [String: String] = [:],
         configurationDetails: ProxyGroupConfigurationDetails? = nil,
         hidden: Bool = false,
         testURL: String? = nil,
         iconURL: String? = nil) {
        self.hidden = hidden
        self.testURL = testURL
        self.iconURL = iconURL
        self.name = name
        self.type = type
        self.now = now
        self.resolvedNow = resolvedNow ?? now
        self.members = members
        self.memberTypes = memberTypes
        self.memberGroupNames = memberGroupNames
        self.memberResolvedNames = memberResolvedNames
        self.configurationDetails = configurationDetails
    }
}

@MainActor
protocol NodesCommanding: AnyObject, Sendable {
    var isConnected: Bool { get }
     
     
     
    var isReopeningControlSession: Bool { get }
    var mode: String { get }
    var proxiesData: Data? { get }
    func refreshMetadata() async
    func select(group: String, name: String) async -> Bool
    func unfix(group: String) async -> Bool
     
     
     
    var lastCommandError: String { get }
    func closeConnectionsAfterProxySelection() async
    func reconnectAfterRuntimeChange()
     
     
    func nodesTestDelay(name: String, url: String) async -> Int
     
     
     
     
    func nodesTestDelayWithReason(
        name: String,
        url: String
    ) async -> (delay: Int, category: String)
     
     
    func extensionFootprintBytes() async -> Int64
    func nodesProviderCatalog() async throws -> ProviderRuntimeCatalog
     
     
     
     
     
     
     
    func nodesHealthCheckProvider(named name: String) async -> [String: Int]
     
     
    var extensionMemoryBytes: Int64 { get }
}

extension NodesCommanding {
     
     
     
     
    func nodesTestDelayWithReason(
        name: String,
        url: String
    ) async -> (delay: Int, category: String) {
        (await nodesTestDelay(name: name, url: url), "")
    }
}

extension NodesCommanding {
     
     
    var extensionMemoryBytes: Int64 { 0 }
}

extension ClashCommandClient: NodesCommanding {
    var extensionMemoryBytes: Int64 { memoryBytes }

    func nodesTestDelay(name: String, url: String) async -> Int {
        await nodesTestDelayWithReason(name: name, url: url).delay
    }

    func nodesTestDelayWithReason(
        name: String,
        url: String
    ) async -> (delay: Int, category: String) {
        let outcome = await urlTestQuietly(name: name, url: url)
         
         
        let delay = outcome.failureCategory == "admission-deferred"
            ? -2
            : outcome.delay
        return (delay, outcome.failureCategory)
    }

    func extensionFootprintBytes() async -> Int64 {
         
         
        memoryFootprintBytes
    }

    func nodesProviderCatalog() async throws -> ProviderRuntimeCatalog {
        try await providerRuntimeCatalog()
    }

    func nodesHealthCheckProvider(named name: String) async -> [String: Int] {
        guard let provider = try? await healthCheckProxyProvider(named: name) else {
            return [:]
        }
        return provider.proxies.reduce(into: [String: Int]()) { result, proxy in
            if let delay = proxy.latestDelayMilliseconds, delay > 0 {
                result[proxy.name] = delay
            } else if proxy.alive == false {
                result[proxy.name] = -1
            }
        }
    }

    func reconnectAfterRuntimeChange() {
        reconnectIfNeeded()
    }
}

extension NodesCommanding {
     
    var isReopeningControlSession: Bool { false }

    func extensionFootprintBytes() async -> Int64 { 0 }

    var mode: String { "rule" }
    func unfix(group: String) async -> Bool { false }
    var lastCommandError: String { "" }
    func reconnectAfterRuntimeChange() {}
    func nodesProviderCatalog() async throws -> ProviderRuntimeCatalog { .empty }
    func nodesHealthCheckProvider(named name: String) async -> [String: Int] { [:] }
}

extension JSONEncoder {
     
    static var sortedKeys: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

struct NodesRuntimeIdentity: Equatable {
    let profileID: String
    let revision: String

    static func load() -> NodesRuntimeIdentity? {
        guard let container = HakoAppIdentifiers.appGroupContainer,
        let store = try? ConfigResourceStore(containerURL: container),
        let pointer = try? store.activeIdentity() else {
            return nil
        }
        return NodesRuntimeIdentity(
            profileID: pointer.profileID,
            revision: pointer.revision
        )
    }
}

 
 
 
 
struct NodesInventoryProjection: Equatable, Sendable {
    var protocolDetails: [String: ProxyProtocolDetails] = [:]
    var groupDetails: [String: ProxyGroupConfigurationDetails] = [:]
    var order: ConfiguredProxyOrder = .none
    var trafficUsage: [String: ProxyTrafficUsage] = [:]

    static func read(yaml: String) -> NodesInventoryProjection {
        NodesInventoryProjection(
            protocolDetails: ProxyConfigurationInspector.detailsByNodeName(yaml: yaml),
            groupDetails: ProxyGroupConfigurationInspector.detailsByGroupName(yaml: yaml),
            order: ConfiguredProxyOrder.read(yaml: yaml),
            trafficUsage: ProxyTrafficUsageInspector.summariesByGroupName(yaml: yaml)
        )
    }
}

struct OfflineProxyCatalogSnapshot {
    let profileID: String
    let yaml: String
    let selectedMap: [String: String]
    let runtimeData: Data
}

 
 
 
 
enum OfflineProxyCatalogBuilder {
    static func runtimeData(
        yaml: String,
        selectedMap: [String: String]
    ) -> Data? {
         
         
        guard let root = ConfigTransforms.parsedRoot(forYAML: yaml)?.root
        else { return nil }

        let rawProxies = root["proxies"] as? [[String: Any]] ?? []
        let rawGroups = root["proxy-groups"] as? [[String: Any]] ?? []
        var proxies: [String: Any] = [:]

        for mapping in rawProxies {
            guard let name = nonEmptyString(mapping["name"]) else { continue }
            proxies[name] = [
                "type": nonEmptyString(mapping["type"]) ?? "?",
                "history": [],
            ]
        }

        for mapping in rawGroups {
            guard let name = nonEmptyString(mapping["name"]),
                  let type = nonEmptyString(mapping["type"]) else { continue }
            let members = (mapping["proxies"] as? [String]) ?? []
            let selected = selectedMap[name].flatMap { members.contains($0) ? $0 : nil }
                ?? defaultSelection(type: type, members: members)
            proxies[name] = [
                "type": runtimeGroupType(type),
                "now": selected,
                "all": members,
            ]
            for member in members where proxies[member] == nil {
                guard let builtin = builtinType(member) else { continue }
                proxies[member] = ["type": builtin, "history": []]
            }
        }

        return try? JSONSerialization.data(withJSONObject: ["proxies": proxies])
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private static func runtimeGroupType(_ type: String) -> String {
        switch type.lowercased() {
        case "select": return "Selector"
        case "url-test": return "URLTest"
        case "fallback": return "Fallback"
        case "load-balance": return "LoadBalance"
        default: return type
        }
    }

    private static func defaultSelection(type: String, members: [String]) -> String {
        type.lowercased() == "load-balance" ? "" : (members.first ?? "")
    }

     
     
    private static func builtinType(_ name: String) -> String? {
        switch name {
        case "DIRECT": return "Direct"
        case "REJECT", "REJECT-DROP": return "Reject"
        case "PASS": return "Pass"
        case "COMPATIBLE": return "Compatible"
        default: return nil
        }
    }
}

enum OfflineProxyCatalogLoader {
     
     
    private struct SourceKey: Equatable {
        let profileID: String
        let pointer: ActiveConfigurationPointer?
        let sidecarSize: Int
        let sidecarModified: Double
    }

    private struct SnapshotKey: Equatable {
        let source: SourceKey
        let selectedMap: [String: String]
    }

     
     
     
     
     
     
    private static let memoLock = NSLock()
    private static var textMemo: (key: SourceKey, text: String)?
    private static var snapshotMemo: (key: SnapshotKey, snapshot: OfflineProxyCatalogSnapshot)?

    static func resetMemoForTesting() {
        memoLock.lock(); defer { memoLock.unlock() }
        textMemo = nil
        snapshotMemo = nil
    }

    static func load() -> OfflineProxyCatalogSnapshot? {
        guard let container = HakoAppIdentifiers.appGroupContainer else { return nil }
        return load(containerURL: container)
    }

    static func load(
        containerURL container: URL,
        preferredProfileID: String? = nil
    ) -> OfflineProxyCatalogSnapshot? {
        let working = container.appendingPathComponent("working", isDirectory: true)
        let profileStore = ProfileStore(
            fileURL: working.appendingPathComponent("store/profiles.json")
        )
        try? LocalDefaultProfileProvisioner.provisionIfNeeded(
            store: profileStore,
            workingDirectory: working
        )
        let profiles = profileStore.load().sorted { $0.order < $1.order }
        let configStore = try? ConfigResourceStore(containerURL: container)
        let activePointer: ActiveConfigurationPointer? = {
            guard let configStore else { return nil }
            return try? configStore.activeIdentity()
        }()
        let profileID = preferredProfileID
            ?? activePointer?.profileID
            ?? ProfileCenterPolicy.automaticSelectionID(
                profiles: profiles,
                activeProfileID: nil
            )
        guard let profileID,
              let profile = profiles.first(where: { $0.id == profileID }) else { return nil }

        let sidecarURL = working
            .appendingPathComponent("store/\(profileID)", isDirectory: true)
            .appendingPathComponent("source.yaml")
        let usesPointer = activePointer?.profileID == profileID && configStore != nil
        let sidecarAttributes = usesPointer
            ? nil
            : try? FileManager.default.attributesOfItem(atPath: sidecarURL.path)
        let sourceKey = SourceKey(
            profileID: profileID,
            pointer: usesPointer ? activePointer : nil,
            sidecarSize: (sidecarAttributes?[.size] as? NSNumber)?.intValue ?? -1,
            sidecarModified: (sidecarAttributes?[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? -1
        )
        let snapshotKey = SnapshotKey(source: sourceKey, selectedMap: profile.selectedMap)
        memoLock.lock()
        let rememberedSnapshot = snapshotMemo.flatMap { $0.key == snapshotKey ? $0.snapshot : nil }
        let rememberedText = textMemo.flatMap { $0.key == sourceKey ? $0.text : nil }
        memoLock.unlock()
        if let rememberedSnapshot { return rememberedSnapshot }

        let yaml: String
        if let rememberedText {
            yaml = rememberedText
        } else if activePointer?.profileID == profileID,
           let configStore,
           let current = try? configStore.loadCurrent().text {
            yaml = current
        } else {
            let source = working
                .appendingPathComponent("store/\(profileID)", isDirectory: true)
                .appendingPathComponent("source.yaml")
            guard let stored = try? String(contentsOf: source, encoding: .utf8) else {
                return nil
            }
            yaml = stored
        }
        guard let runtimeData = OfflineProxyCatalogBuilder.runtimeData(
            yaml: yaml,
            selectedMap: profile.selectedMap
        ) else { return nil }
        let snapshot = OfflineProxyCatalogSnapshot(
            profileID: profileID,
            yaml: yaml,
            selectedMap: profile.selectedMap,
            runtimeData: runtimeData
        )
        memoLock.lock()
        textMemo = (sourceKey, yaml)
        snapshotMemo = (snapshotKey, snapshot)
        memoLock.unlock()
        return snapshot
    }
}

 
 
 
 
 
 
 
 
enum BuiltinProxyName {
    static let direct = "DIRECT"
    static let all = LatencyProbeNamePolicy.builtinNames
}

 
 
 
 
 
 
enum GlobalProxySelectionPolicy {
    static let groupName = "GLOBAL"

    static func target(
        groups: [ProxyGroup],
        preferredGroupName: String?
    ) -> String? {
        guard let global = globalGroup(in: groups),
              ProxyGroupControlKind(rawType: global.type) == .manual else {
            return nil
        }

        let hasSafeCurrentRoute = isProxyMember(
            global.now,
            of: global,
            allGroups: groups
        )

         
         
         
         
        if hasSafeCurrentRoute,
           isExplicitProxyChoice(global.now, groups: groups) {
            return global.now
        }
        if let preferredGroupName,
           isProxyMember(preferredGroupName, of: global, allGroups: groups),
           isSafeManualGroup(preferredGroupName, groups: groups) {
            return preferredGroupName
        }
        if hasSafeCurrentRoute {
            return global.now
        }
        return global.members.first {
            isProxyMember($0, of: global, allGroups: groups)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func refusal(groups: [ProxyGroup]) -> String? {
        guard let global = globalGroup(in: groups) else {
             
             
            return """
                The core has not reported the built-in GLOBAL group yet. \
                Reconnect and try again.
                """
        }
         
         
         
         
        guard global.members.contains(where: {
            isProxyMember($0, of: global, allGroups: groups)
        }) else {
            return """
                The GLOBAL group has no proxy or policy group to select. Global \
                mode sends every flow through GLOBAL, so this profile needs at \
                least one outbound.
                """
        }
        return nil
    }

    static func isProxySelected(groups: [ProxyGroup]) -> Bool {
        guard let global = globalGroup(in: groups) else { return false }
        return isProxyMember(global.now, of: global, allGroups: groups)
    }

    static func isSafeManualGroup(
        _ name: String,
        groups: [ProxyGroup]
    ) -> Bool {
        guard let group = groups.first(where: { $0.name == name }),
              ProxyGroupControlKind(rawType: group.type) == .manual else {
            return false
        }
        let resolved = group.resolvedNow
        guard !resolved.isEmpty,
              !BuiltinProxyName.all.contains(resolved) else {
            return false
        }
        return !groups.contains { $0.name == resolved }
    }

    private static func globalGroup(in groups: [ProxyGroup]) -> ProxyGroup? {
         
         
        groups.first { $0.name == groupName }
    }

    private static func isExplicitProxyChoice(
        _ name: String,
        groups: [ProxyGroup]
    ) -> Bool {
        guard groups.contains(where: { $0.name == name }) else {
            return true
        }
        return isSafeManualGroup(name, groups: groups)
    }

    private static func isProxyMember(
        _ member: String,
        of global: ProxyGroup,
        allGroups: [ProxyGroup]
    ) -> Bool {
        guard !member.isEmpty, global.members.contains(member) else {
            return false
        }
        let resolved = global.memberResolvedNames[member] ?? member
        guard !resolved.isEmpty,
              !BuiltinProxyName.all.contains(resolved) else {
            return false
        }
         
         
        return !allGroups.contains { $0.name == resolved }
    }
}

enum NodeInventory {
     
     
     
     
    static func proxies(in data: Data?) -> [String: Any]? {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return root["proxies"] as? [String: Any]
    }

    static func parse(
        _ data: Data?,
        groupConfigurationDetailsByName: [String: ProxyGroupConfigurationDetails] = [:],
        providerCatalog: ProviderRuntimeCatalog = .empty,
        configuredOrder: ConfiguredProxyOrder = .none
    ) -> ([ProxyGroup], [String: Int]) {
        parse(
            proxies: proxies(in: data),
            groupConfigurationDetailsByName: groupConfigurationDetailsByName,
            providerCatalog: providerCatalog,
            configuredOrder: configuredOrder
        )
    }

    static func parse(
        proxies: [String: Any]?,
        groupConfigurationDetailsByName: [String: ProxyGroupConfigurationDetails] = [:],
        providerCatalog: ProviderRuntimeCatalog = .empty,
        configuredOrder: ConfiguredProxyOrder = .none
    ) -> ([ProxyGroup], [String: Int]) {
        guard let proxies else { return ([], [:]) }

        var rawGroups: [
            String: (
                type: String, now: String, members: [String], hidden: Bool,
                testURL: String?, iconURL: String?
            )
        ] = [:]
        var proxyTypes: [String: String] = [:]
        var delays: [String: Int] = [:]

         
         
         
         
         
         
         
        for provider in providerCatalog.proxyProviders.values {
            for proxy in provider.proxies {
                if let type = proxy.type, !type.isEmpty {
                    proxyTypes[proxy.name] = type
                }
                if let delay = proxy.latestDelayMilliseconds, delay > 0 {
                    delays[proxy.name] = delay
                } else if proxy.alive == false {
                     
                     
                    delays[proxy.name] = -1
                }
            }
        }

        func firstOccurrences(of members: [String]) -> [String] {
            var seen = Set<String>()
            return members.filter { seen.insert($0).inserted }
        }

         
         
         
         
         
         
         
        func native(_ value: String) -> String {
            var copy = value
            copy.makeContiguousUTF8()
            return copy
        }
        for (rawName, raw) in proxies {
            guard let proxy = raw as? [String: Any] else { continue }
            let name = native(rawName)
            proxyTypes[name] = (proxy["type"] as? String).map(native) ?? "?"
            if let history = proxy["history"] as? [[String: Any]], let last = history.last {
                delays[name] = last["delay"] as? Int ?? -1
            }
            if let members = proxy["all"] as? [String] {
                let declaredURL = (proxy["testUrl"] as? String)
                    .flatMap { $0.isEmpty ? nil : native($0) }
                let declaredIcon = (proxy["icon"] as? String)
                    .flatMap { $0.isEmpty ? nil : native($0) }
                rawGroups[name] = (
                    (proxy["type"] as? String).map(native) ?? "?",
                    (proxy["now"] as? String).map(native) ?? "",
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    firstOccurrences(of: members.map(native)),
                    proxy["hidden"] as? Bool ?? false,
                    declaredURL,
                    declaredIcon
                )
            }
        }

        func resolve(_ value: String) -> String {
            var current = value
            var visited = Set<String>()
            while let group = rawGroups[current], visited.insert(current).inserted,
                  !group.now.isEmpty {
                current = group.now
            }
            return current
        }

        let groups = rawGroups.map { name, value in
            ProxyGroup(
                name: name,
                type: value.type,
                now: value.now,
                members: value.members,
                resolvedNow: resolve(value.now),
                memberTypes: Dictionary(uniqueKeysWithValues: value.members.map {
                    ($0, proxyTypes[$0] ?? "?")
                }),
                memberGroupNames: Set(value.members.filter { rawGroups[$0] != nil }),
                memberResolvedNames: Dictionary(uniqueKeysWithValues: value.members.compactMap {
                    rawGroups[$0] == nil ? nil : ($0, resolve($0))
                }),
                configurationDetails: groupConfigurationDetailsByName[name],
                hidden: value.hidden,
                testURL: value.testURL,
                iconURL: value.iconURL
            )
        }
         
         
         
         
         
         
         
         
         
         
         
         
        let ordered = configuredOrder.sortedGroups(groups) { $0.name }
        return (ordered, delays)
    }

     
     
     
     
     
     
     
     
     
     
     
    static func probeURLsByMember(
        in groups: [ProxyGroup],
        fallback: String
    ) -> [String: String] {
        var urls: [String: String] = [:]
        for group in groups {
            for member in group.members {
                let resolved = group.memberResolvedNames[member] ?? member
                guard urls[resolved] == nil else { continue }
                urls[resolved] = group.testURL ?? fallback
            }
        }
        return urls
    }

    static func filter(_ groups: [ProxyGroup], query: String) -> [ProxyGroup] {
         
         
        let visible = groups.filter { !$0.hidden }
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return visible }
        return visible.compactMap { group in
            if group.name.localizedCaseInsensitiveContains(value) { return group }
            let members = group.members.filter { $0.localizedCaseInsensitiveContains(value) }
            guard !members.isEmpty else { return nil }
             
             
             
            let survivors = Set(members)
            return ProxyGroup(
                name: group.name,
                type: group.type,
                now: group.now,
                members: members,
                resolvedNow: group.resolvedNow,
                memberTypes: group.memberTypes.filter { survivors.contains($0.key) },
                memberGroupNames: group.memberGroupNames.intersection(survivors),
                memberResolvedNames: group.memberResolvedNames.filter {
                    survivors.contains($0.key)
                },
                configurationDetails: group.configurationDetails,
                hidden: group.hidden
            )
        }
    }

    static func nodeCatalog(
        _ data: Data?,
        protocolDetailsByNodeName: [String: ProxyProtocolDetails] = [:],
        providerCatalog: ProviderRuntimeCatalog = .empty,
        configuredOrder: ConfiguredProxyOrder = .none
    ) -> [ProxyNodeRecord] {
        nodeCatalog(
            proxies: proxies(in: data),
            protocolDetailsByNodeName: protocolDetailsByNodeName,
            providerCatalog: providerCatalog,
            configuredOrder: configuredOrder
        )
    }

    static func nodeCatalog(
        proxies: [String: Any]?,
        protocolDetailsByNodeName: [String: ProxyProtocolDetails] = [:],
        providerCatalog: ProviderRuntimeCatalog = .empty,
        configuredOrder: ConfiguredProxyOrder = .none
    ) -> [ProxyNodeRecord] {
        guard let proxies else { return [] }

        let groupNames = Set(proxies.compactMap { name, raw -> String? in
            guard let proxy = raw as? [String: Any], proxy["all"] is [String] else {
                return nil
            }
            return name
        })
        var memberships: [String: Set<String>] = [:]
        for (groupName, raw) in proxies {
            guard let proxy = raw as? [String: Any],
                  let members = proxy["all"] as? [String] else { continue }
            for member in members where !groupNames.contains(member) {
                memberships[member, default: []].insert(groupName)
            }
        }

        var records = proxies.compactMap { name, raw -> ProxyNodeRecord? in
            guard !groupNames.contains(name),
                  !BuiltinProxyName.all.contains(name),
                  let proxy = raw as? [String: Any] else { return nil }
            let history = proxy["history"] as? [[String: Any]]
            return ProxyNodeRecord(
                name: name,
                type: proxy["type"] as? String ?? "?",
                delay: history?.last?["delay"] as? Int,
                groupNames: (memberships[name] ?? []).sorted(),
                protocolDetails: protocolDetailsByNodeName[name]
            )
        }

         
         
         
         
         
        let known = Set(records.map(\.name))
         
         
         
         
        var runtimeNodeOrder: [String: Int] = [:]
        let orderedProviders = configuredOrder.sortedProviders(
            Array(providerCatalog.proxyProviders.keys)
        ) { $0 }
        for providerName in orderedProviders {
            guard let provider = providerCatalog.proxyProviders[providerName] else { continue }
            for proxy in provider.proxies where runtimeNodeOrder[proxy.name] == nil {
                runtimeNodeOrder[proxy.name] = runtimeNodeOrder.count
            }
        }
        for providerName in orderedProviders {
            guard let provider = providerCatalog.proxyProviders[providerName] else { continue }
            for proxy in provider.proxies where !known.contains(proxy.name)
                && !groupNames.contains(proxy.name) {
                records.append(
                    ProxyNodeRecord(
                        name: proxy.name,
                        type: proxy.type ?? "?",
                        delay: proxy.latestDelayMilliseconds
                            ?? (proxy.alive == false ? -1 : nil),
                        groupNames: (memberships[proxy.name] ?? []).sorted(),
                        protocolDetails: protocolDetailsByNodeName[proxy.name]
                    )
                )
            }
        }

         
         
         
         
        return configuredOrder.sortedNodes(records, runtimeOrder: runtimeNodeOrder) { $0.name }
    }
}

@MainActor
final class NodesModel: ObservableObject {
    @Published var groups: [ProxyGroup] = [] {
        didSet {
            HakoPerf.count("pub.nodes.groups")
            deriveGroupSelections()
        }
    }
    @Published var delays: [String: Int] = [:] {
        didSet { HakoPerf.count("pub.nodes.delays") }
    }
     
     
    private var delaysTestURL = DelayTestSettings.url()
    @Published private(set) var nodeCatalog: [ProxyNodeRecord] = [] {
        didSet {
            HakoPerf.count("pub.nodes.catalog")
            deriveRuntimeProxies()
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private(set) var nowByGroup: [String: String] = [:]
    private(set) var resolvedNowByGroup: [String: String] = [:]
    private(set) var runtimeProxies: [ProxiesOverviewModel.Proxy] = []

    private func deriveGroupSelections() {
         
         
        nowByGroup = Dictionary(
            groups.map { ($0.name, $0.now) },
            uniquingKeysWith: { first, _ in first }
        )
        resolvedNowByGroup = Dictionary(
            groups.map { ($0.name, $0.resolvedNow) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func deriveRuntimeProxies() {
        runtimeProxies = nodeCatalog.map {
            ProxiesOverviewModel.Proxy(name: $0.name, type: $0.type)
        }
    }
     
     
    private(set) var catalogRebuild: Task<Void, Never>?
    private var catalogGeneration: UInt64 = 0
    private var inventoryApplyGeneration: UInt64 = 0
    @Published var query = ""
    @Published private(set) var testingNames = Set<String>() {
        didSet { HakoPerf.count("pub.nodes.testing") }
    }
    @Published private(set) var currentGroupName: String? {
        didSet { HakoPerf.count("pub.nodes.current") }
    }
    @Published private(set) var unfoldedGroups = Set<String>() {
        didSet { HakoPerf.count("pub.nodes.unfolded") }
    }
    @Published private(set) var isSwitchingProxy = false {
        didSet { HakoPerf.count("pub.nodes.switching") }
    }
     
     
     
     
     
    @Published private(set) var routeGeneration = 0

    func noteRouteChanged() {
        routeGeneration &+= 1
    }
    @Published private(set) var providerNamesByProxy: [String: String] = [:]
     
     
     
    @Published private(set) var runtimeProviderCatalog = ProviderRuntimeCatalog.empty {
        didSet { HakoPerf.count("pub.nodes.providers") }
    }
     
     
    private var appliedProviderCatalog = ProviderRuntimeCatalog.empty
     
    private var appliedProxiesData: Data?
    private var appliedProtocolDetails: [String: ProxyProtocolDetails] = [:]
    private var appliedGroupDetails: [String: ProxyGroupConfigurationDetails] = [:]
     
     
     
    @Published private(set) var actionRefusals: [String: String] = [:]
    @Published private(set) var isRuntimeAvailable = false
    @Published private(set) var trafficUsageByGroupName: [String: ProxyTrafficUsage] = [:] {
        didSet { HakoPerf.count("pub.nodes.traffic") }
    }
    @Published private(set) var isTestingLatency = false
    @Published private(set) var latencyCompletedCount = 0
    @Published private(set) var latencyTotalCount = 0

    var testing: Bool { isTestingLatency }

    private weak var command: NodesCommanding?
    private let preferences: NodeProfilePreferencesStore?
    private let protocolDetailsLoader: () -> [String: ProxyProtocolDetails]
    private let groupConfigurationDetailsLoader: () -> [String: ProxyGroupConfigurationDetails]
    private let configuredOrderLoader: () -> ConfiguredProxyOrder
    private let trafficUsageLoader: () -> [String: ProxyTrafficUsage]
    private let offlineCatalogLoader: () -> OfflineProxyCatalogSnapshot?
    private let runtimeIdentityLoader: () -> NodesRuntimeIdentity?
    private var protocolDetailsByNodeName: [String: ProxyProtocolDetails] = [:]
    private var locallyEditedProtocolDetails: [String: ProxyProtocolDetails] = [:]
    private var groupConfigurationDetailsByName: [String: ProxyGroupConfigurationDetails] = [:]
     
     
    private var configuredOrder: ConfiguredProxyOrder = .none
     
     
    private var lastRuntimeInventory: Data?
    private var inventoryProjectionGeneration: UInt64 = 0
    private var inventoryProjectionTasks: [UInt64: Task<Void, Never>] = [:]
     
     
    private(set) var inventoryApplications = 0
    private var observedRuntimeIdentity: NodesRuntimeIdentity?
    private var restoredRuntimeKey: String?
    private var providerCatalogGeneration: UInt64 = 0
    private var latencyRunID: UInt64 = 0
    private var latencyTask: Task<LatencyProbeSummary, Never>?
     
    private var subscriptionHealth: SubscriptionHealthRuns?
    private var latencyCancellation: LatencyProbeCancellation?
    private let shouldCloseConnectionsOnSwitch: () -> Bool

    init(
        preferences: NodeProfilePreferencesStore? = .live(),
        protocolDetailsLoader: @escaping () -> [String: ProxyProtocolDetails] = {
            ProxyConfigurationInspector.activeDetails()
        },
        groupConfigurationDetailsLoader: @escaping () -> [String: ProxyGroupConfigurationDetails] = {
            ProxyGroupConfigurationInspector.activeDetails()
        },
        configuredOrderLoader: @escaping () -> ConfiguredProxyOrder = {
            ProxyGroupConfigurationInspector.activeConfiguredOrder()
        },
        trafficUsageLoader: @escaping () -> [String: ProxyTrafficUsage] = {
            ProxyTrafficUsageInspector.activeSummaries()
        },
        offlineCatalogLoader: @escaping () -> OfflineProxyCatalogSnapshot? = {
            OfflineProxyCatalogLoader.load()
        },
        runtimeIdentityLoader: @escaping () -> NodesRuntimeIdentity? = {
            NodesRuntimeIdentity.load()
        },
        shouldCloseConnectionsOnSwitch: @escaping () -> Bool = {
            NodeSwitchSettings.autoCloseOnSwitch()
        },
        runtimeRestartGrace: TimeInterval = 20
    ) {
        self.preferences = preferences
        self.protocolDetailsLoader = protocolDetailsLoader
        self.groupConfigurationDetailsLoader = groupConfigurationDetailsLoader
        self.configuredOrderLoader = configuredOrderLoader
        self.trafficUsageLoader = trafficUsageLoader
        self.offlineCatalogLoader = offlineCatalogLoader
        self.runtimeIdentityLoader = runtimeIdentityLoader
        self.shouldCloseConnectionsOnSwitch =
            shouldCloseConnectionsOnSwitch
        self.runtimeRestartGrace = runtimeRestartGrace
    }

     
     
     
     
    private let runtimeRestartGrace: TimeInterval
     
     
    private var runtimeRestartRequestedAt: Date?

    func bind(command: NodesCommanding) {
        self.command = command
        if observedRuntimeIdentity == nil {
            observedRuntimeIdentity = currentRuntimeIdentity()
        }
        providerCatalogGeneration &+= 1
        let providerToken = providerCatalogGeneration
        providerNamesByProxy = [:]
        let hadInventory = !groups.isEmpty
        HakoPerf.measure("nodes.reloadInventory") {
            reloadInventory(command: command)
        }
        if !hadInventory,
           unfoldedGroups.isEmpty,
           preferences?.load()?.unfoldedGroups == nil {
            unfoldedGroups = Set(groups.map(\.name))
        }
         
         
         
         
         
         
        bindSettle = Task { [weak self, weak command] in
            guard let self, let command else { return }
            await self.restoreActiveProfileSelectionIfNeeded(command: command)
            await self.loadProviderSources(command: command, token: providerToken)
        }
    }

     
     
    private var bindSettle: Task<Void, Never>?

    func refresh() async {
        if let settle = bindSettle {
            bindSettle = nil
            await settle.value
        }
        guard let command else {
             
             
             
             
             
             
             
             
            HakoLogStore.shared.append(
                "proxies refresh ignored: no command \("channel") bound",
                stream: .app,
                level: .warning
            )
             
             
             
            FrameLogFile.append("proxies refresh ignored: no command \("channel")")
            return
        }
        if await transitionRuntimeIfNeeded(command: command) {
            return
        }
        if !command.isConnected {
            await cancelLatencyTests(reason: .disconnected)
             
             
             
             
             
             
             
            restoredRuntimeKey = nil
        }
        providerCatalogGeneration &+= 1
        let providerToken = providerCatalogGeneration
        if command.isConnected { await command.refreshMetadata() }
         
         
         
         
         
         
         
        await reloadInventoryOffMain(command: command)
        await restoreActiveProfileSelectionIfNeeded(command: command)
        await loadProviderSources(command: command, token: providerToken)
         
         
         
         
        FrameLogFile.append(
            "proxies refresh done connected=\(command.isConnected) groups=\(groups.count)"
        )
    }

    func select(group: String, name: String) async {
        guard let command, !isSwitchingProxy,
              let targetGroup = groups.first(where: { $0.name == group }),
              ProxyGroupControlKind(rawType: targetGroup.type).acceptsMemberChoice,
              targetGroup.members.contains(name) else { return }
        if command.isConnected {
            isSwitchingProxy = true
            defer { isSwitchingProxy = false }
            let confirmed = await command.select(
                group: group,
                name: name
            )
             
             
             
             
            if confirmed { noteKernelAcceptedSelection(group: group, name: name) }
            await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
            guard confirmed,
                  groups.first(where: { $0.name == group })?.now
                    == name else {
                return
            }

            if command.mode.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased() == "global",
               group != GlobalProxySelectionPolicy.groupName,
               let global = groups.first(where: {
                    $0.name == GlobalProxySelectionPolicy.groupName
               }),
               global.now != group,
               global.members.contains(group),
               GlobalProxySelectionPolicy.isSafeManualGroup(
                    group,
                    groups: groups
               ) {
                let retargeted = await command.select(
                    group: global.name,
                    name: group
                )
                if retargeted { noteKernelAcceptedSelection(group: global.name, name: group) }
                await command.refreshMetadata()
                await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
                guard retargeted,
                      groups.first(where: {
                          $0.name == GlobalProxySelectionPolicy.groupName
                      })?.now == group else {
                    return
                }
            }
        }
        preferences?.saveSelection(group: group, proxy: name)
        noteRouteChanged()
        HakoLogStore.shared.append(
            "node switched  group=\(group) -> \(name)",
            stream: .app
        )
        currentGroupName = group
        if !command.isConnected {
            applyOfflineSelection(group: group, name: name)
        }
        if command.isConnected, shouldCloseConnectionsOnSwitch() {
            await command.closeConnectionsAfterProxySelection()
        }
    }

     
     
     
     
    @discardableResult
    func ensureGlobalProxySelection() async -> Bool {
        guard let command, command.isConnected else { return false }
        await command.refreshMetadata()
        await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)

        guard GlobalProxySelectionPolicy.refusal(groups: groups) == nil,
              let global = groups.first(where: {
                  $0.name == GlobalProxySelectionPolicy.groupName
              }) else {
            return false
        }

         
         
         
         
        if let target = GlobalProxySelectionPolicy.target(
            groups: groups,
            preferredGroupName: currentGroupName
        ), global.now != target {
            await select(group: global.name, name: target)
        }
         
         
         
         
         
         
         
        return GlobalProxySelectionPolicy.isProxySelected(groups: groups)
    }

     
     
     
     
     
     
     
     
     
     
    func unfix(group: String) async {
        guard let command else {
             
             
             
             
             
            let forgotten = preferences?.clearSelection(group: group) ?? false
            HakoLogStore.shared.append(
                "unfix  tunnel down  group=\(group)  profile pin forgotten=\(forgotten)",
                stream: .app, level: .info
            )
            return
        }
        guard let target = groups.first(where: { $0.name == group }) else {
            HakoLogStore.shared.append("unfix refused  no such group=\(group)", stream: .app, level: .warning)
            refuse(group: group, because: "This group is no longer in the running configuration.")
            return
        }
        guard ProxyGroupControlKind(rawType: target.type).canBeUnpinned else {
            HakoLogStore.shared.append("unfix refused  group=\(group) type=\(target.type) cannot be unpinned", stream: .app, level: .warning)
            refuse(group: group, because: "A \(target.type) group has no pin to release.")
            return
        }
        if let preferences, let pinned = preferences.load()?.selectedMap[group] {
            guard preferences.clearSelection(group: group) else {
                 
                 
                 
                HakoLogStore.shared.append(
                    "unfix refused  group=\(group)  the profile's pin could not be cleared",
                    stream: .app, level: .warning
                )
                refuse(group: group, because: "The profile's saved selection could not be cleared.")
                return
            }
            guard await command.unfix(group: group) else {
                HakoLogStore.shared.append(
                    "unfix refused by core  group=\(group)  reason=\(command.lastCommandError)",
                    stream: .app, level: .warning
                )
                refuse(group: group, because: command.lastCommandError)
                if !preferences.restoreSelection(group: group, proxy: pinned) {
                     
                     
                     
                     
                     
                    await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
                }
                return
            }
        } else {
            guard await command.unfix(group: group) else {
                HakoLogStore.shared.append(
                    "unfix refused by core  group=\(group)  reason=\(command.lastCommandError)",
                    stream: .app, level: .warning
                )
                refuse(group: group, because: command.lastCommandError)
                return
            }
        }
        actionRefusals[group] = nil
         
         
        HakoLogStore.shared.append("unfix  group=\(group)  released", stream: .app)
        await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
    }

     
     
     
     
    private func refuse(group: String, because reason: String) {
        let sentence = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        actionRefusals[group] = sentence.isEmpty
            ? "The core did not release this group's pin."
            : sentence
    }

    func setExpanded(_ expanded: Bool, group: String) {
        if expanded {
            unfoldedGroups.insert(group)
            currentGroupName = group
        } else {
            unfoldedGroups.remove(group)
        }
        preferences?.savePresentation(
            currentGroup: currentGroupName,
            unfoldedGroups: unfoldedGroups
        )
    }

     
     
     
     
     
     
     
     
     
     
    func setExpanded(_ expanded: Bool, groups names: [String]) {
        guard !names.isEmpty else { return }
        if expanded {
            unfoldedGroups.formUnion(names)
        } else {
            unfoldedGroups.subtract(names)
        }
        preferences?.savePresentation(
            currentGroup: currentGroupName,
            unfoldedGroups: unfoldedGroups
        )
    }

    func setCurrentGroup(_ group: String) {
        guard groups.contains(where: { $0.name == group }) else { return }
         
         
         
         
         
         
         
         
        guard currentGroupName != group else { return }
        currentGroupName = group
        preferences?.savePresentation(
            currentGroup: group,
            unfoldedGroups: unfoldedGroups
        )
    }

    func test(_ name: String) async {
        await runLatencyTest(
            plan: makeLatencyPlan(
                groups: [ProxyGroup(name: "requested", type: "", now: name, members: [name])],
                visibleGroupNames: ["requested"]
            )
        )
    }

    func test(group: ProxyGroup) async {
        await runLatencyTest(
            plan: makeLatencyPlan(groups: [group], visibleGroupNames: [group.name])
        )
    }



    func testAll() async {
        await runLatencyTest(
            plan: makeLatencyPlan(
                groups: groups,
                visibleGroupNames: currentGroupName.map { [$0] } ?? []
            )
        )
    }

    func cancelLatencyTests(reason: LatencyProbeCancellationReason) async {
        if isTestingLatency {
            HakoLogStore.shared.append(
                "sweep interrupted  reason=\(reason)  completed=\(sweepCompleted)/\(latencyTotalCount)",
                stream: .app,
                level: .warning
            )
        }
        latencyRunID &+= 1
        await latencyCancellation?.cancel(reason: reason)
        latencyTask?.cancel()
         
         
         
         
        if let health = subscriptionHealth {
            subscriptionHealth = nil
            await health.cancel()
        }
         
         
        let completed = sweepCompleted
        let total = latencyTotalCount
        let settledDelays = sweepDelays
        commitSweepToPublished(completed: completed, total: total)
        latencySweepConduit.send(LatencySweepBatch(
            results: settledDelays, testing: [],
            groupTerminals: resolvedNowByGroup,
            completed: completed, total: total, finished: true
        ))
    }

     
     
     
    func applyNodeEdit(name: String, configurationJSON: String) {
        guard let mapping = ProxyProtocolCatalog.mapping(from: configurationJSON),
              let details = ProxyProtocolCatalog.details(for: mapping) else { return }
        locallyEditedProtocolDetails[name] = details
        protocolDetailsByNodeName[name] = details
        nodeCatalog = nodeCatalog.map { record in
            guard record.name == name else { return record }
            return ProxyNodeRecord(
                name: record.name,
                type: record.type,
                delay: record.delay,
                groupNames: record.groupNames,
                protocolDetails: details
            )
        }
    }

    func makeLatencyPlan(
        groups: [ProxyGroup],
        visibleGroupNames: [String]
    ) -> LatencyProbePlan {
         
         
         
         
        var probeGroups = groups.map { group in
            LatencyProbeGroup(
                name: group.name,
                members: group.members.map {
                    group.memberResolvedNames[$0] ?? $0
                },
                selectedName: group.members.contains(group.now)
                    ? (group.memberResolvedNames[group.now] ?? group.now)
                    : nil
            )
        }
         
         
         
         
         
         
         
         
         
         
         
         
        let members = probeGroups.flatMap(\.members)
         
         
         
        let excludedNames = Set(members.filter {
            LatencyProbeNamePolicy.probeExcludedNames.contains($0)
        })
        let freshnessByName = Dictionary(uniqueKeysWithValues: Set(members).map { name in
            let freshness: LatencyProbeFreshness
            if let delay = delays[name] {
                freshness = delay > 0 ? .fresh : .failed
            } else if sessionProbeFailures.contains(name) {
                freshness = .failed
            } else {
                freshness = .neverTested
            }
            return (name, freshness)
        })
        return LatencyProbePlan(
            groups: probeGroups,
            visibleGroupNames: visibleGroupNames,
            freshnessByName: freshnessByName,
            excludedNames: excludedNames
        )
    }

    private func runLatencyTest(plan: LatencyProbePlan) async {
        guard let command, command.isConnected else { return }

        latencyRunID &+= 1
        let runID = latencyRunID
        let previousTask = latencyTask
        await latencyCancellation?.cancel(reason: .superseded)
        previousTask?.cancel()
        if let previousTask {
             
             
             
             
            let yielded = await withTaskGroup(of: Bool.self) { group in
                group.addTask { _ = await previousTask.value; return true }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
            if !yielded {
                let verdict = "unresponsive"
                HakoLogStore.shared.append(
                    "sweep supersede  previous run \(verdict), proceeding",
                    stream: .app, level: .warning)
            }
        }
        guard runID == latencyRunID, command.isConnected else {
            HakoLogStore.shared.append(
                "sweep refused  connected=\(command.isConnected)  reopening=\(command.isReopeningControlSession)",
                stream: .app, level: .warning)
            return
        }
        if command.isReopeningControlSession {
             
             
             
            let why = "reopening"
            HakoLogStore.shared.append(
                "sweep refused  control session \(why)",
                stream: .app, level: .warning)
            return
        }

        let orderedNames = LatencyProbeScheduler.orderedNames(for: plan)
        let totalCount = orderedNames.count
        guard totalCount > 0 else { return }
        logSweepCoverage(planned: orderedNames)
        let cancellation = LatencyProbeCancellation()
        latencyCancellation = cancellation
         
         
         
         
         
         
         
         
         
         
         
        let memorySentry = Task { [weak self] in
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            let pauseAtBytes: Int64 = 42_500_000
            let resumeAtBytes: Int64 = 41 * 1_048_576
            let maxPauseNanoseconds: UInt64 = 20_000_000_000
            var pauses = 0
            var blindTicks = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                guard let command = await MainActor.run(body: { self.command }) else { continue }
                let footprint = await command.extensionFootprintBytes()
                if footprint <= 0 {
                     
                     
                     
                    blindTicks += 1
                    if blindTicks == 10 {
                        HakoLogStore.shared.append(
                            "sweep sentry blind  no footprint after \(blindTicks)s; pause/resume disabled for this run",
                            stream: .app, level: .warning)
                    }
                    continue
                }
                guard footprint >= pauseAtBytes else { continue }

                pauses += 1
                let progress = await MainActor.run {
                    "\(self.sweepCompleted)/\(self.latencyTotalCount)"
                }
                await cancellation.pause()
                HakoLogStore.shared.append(
                    "sweep paused  reason=memoryPressure  pause=#\(pauses)  completed=\(progress)  footprint=\(footprint)",
                    stream: .app, level: .warning)
                let pausedAt = DispatchTime.now().uptimeNanoseconds
                var recovered = false
                while !Task.isCancelled,
                      DispatchTime.now().uptimeNanoseconds &- pausedAt < maxPauseNanoseconds {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let now = await command.extensionFootprintBytes()
                    if now > 0, now <= resumeAtBytes {
                        recovered = true
                        HakoLogStore.shared.append(
                            "sweep resumed  after=\((DispatchTime.now().uptimeNanoseconds &- pausedAt) / 1_000_000_000)s  pause=#\(pauses)  footprint=\(now)",
                            stream: .app, level: .info)
                        break
                    }
                }
                if recovered {
                    await cancellation.resume()
                } else {
                    HakoLogStore.shared.append(
                        "sweep interrupted  reason=memoryPressure  pause=#\(pauses) never recovered in 20s",
                        stream: .app, level: .warning)
                    await self.cancelLatencyTests(reason: .memoryPressure)
                    return
                }
            }
        }
        defer { memorySentry.cancel() }
        latencyCompletedCount = 0
        latencyTotalCount = totalCount
        isTestingLatency = true
        testingNames.removeAll()
         
         
         
         
         
        delays = delays.filter { $0.value > 0 }
        nodeCatalog = nodeCatalog.map { record in
            guard let delay = record.delay, delay <= 0 else { return record }
            return ProxyNodeRecord(
                name: record.name,
                type: record.type,
                delay: nil,
                groupNames: record.groupNames,
                protocolDetails: record.protocolDetails
            )
        }
        sweepDelays = [:]
        sweepTesting = []
        sweepCompleted = 0
        failureReasons = [:]
        let testURL = DelayTestSettings.url()
        let urlsByMember = NodeInventory.probeURLsByMember(
            in: groups,
            fallback: testURL
        )
         
         
         
         
         
        let latencyPolicy = Self.activeLatencyPolicy
        announceLatencyRoster(Set(urlsByMember.keys), total: totalCount)
        let subscriptionHealth = SubscriptionHealthRuns(
            providerNamesByProxy: providerNamesByProxy,
            usesBulkHealth: latencyPolicy.usesBulkProviderHealth(
                for: totalCount,
                 
                 
                 
                 
                 
                 
                 
                catalogCount: groups.reduce(0) { $0 + $1.members.count }
                    + providerNamesByProxy.count
            )
        )
        self.subscriptionHealth = subscriptionHealth
        let task = Task { [weak self] in
            await LatencyProbeScheduler.run(
                runID: runID,
                plan: plan,
                policy: latencyPolicy,
                cancellation: cancellation,
                onEvent: { [weak self] event in
                    await self?.applyLatencyEvent(event)
                },
                probe: { name in
                     
                     
                     
                    final class Phase: @unchecked Sendable {
                        private let lock = NSLock()
                        private var value = "health-wait"
                        func set(_ v: String) { lock.lock(); value = v; lock.unlock() }
                        func get() -> String { lock.lock(); defer { lock.unlock() }; return value }
                    }
                    let phase = Phase()
                    let outcome: LatencyProbeOutcome? = await withTaskGroup(
                        of: LatencyProbeOutcome?.self
                    ) { group in
                        group.addTask {
                            if let measured = await subscriptionHealth.delay(
                                for: name, command: command
                            ) {
                                return measured > 0
                                    ? .success(milliseconds: measured) : .failure
                            }
                            phase.set("urltest")
                            let probe = await command.nodesTestDelayWithReason(
                                name: name,
                                url: urlsByMember[name] ?? testURL
                            )
                            if probe.delay == -2 { return .deferred }
                            if probe.delay <= 0 {
                                 
                                 
                                 
                                await MainActor.run { [weak self] in
                                    self?.recordFailureReason(
                                        name, category: probe.category
                                    )
                                }
                                return .failure
                            }
                            return .success(milliseconds: probe.delay)
                        }
                        group.addTask {
                            try? await Task.sleep(nanoseconds: 20_000_000_000)
                            return nil
                        }
                        let first = await group.next() ?? nil
                        group.cancelAll()
                        return first
                    }
                    guard let outcome else {
                        HakoLogStore.shared.append(
                            "probe stalled  name=\(name)  phase=\(phase.get())",
                            stream: .app, level: .warning)
                        return .failure
                    }
                    return outcome
                }
            )
        }
        latencyTask = task
        let heartbeat = Task { @MainActor [weak self] in
            var beat = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, self.isTestingLatency else { break }
                beat += 1
                HakoLogStore.shared.append(
                    "sweep heartbeat  #\(beat)  completed=\(self.sweepCompleted)/\(self.latencyTotalCount)  testing=\(self.sweepTesting.count)",
                    stream: .app, level: .info)
            }
        }
        _ = await task.value
        heartbeat.cancel()
        guard runID == latencyRunID else { return }
        let ok = sweepDelays.values.filter { $0 > 0 }.count
        HakoLogStore.shared.append(
             
             
             
             
             
            "sweep done  planned=\(totalCount)  measured=\(sweepDelays.count)  ok=\(ok)  causes=\(failureCauseSummary())",
            stream: .app, level: ok == 0 ? .warning : .info)
        latencyTask = nil
        latencyCancellation = nil
    }

     
     
     
     
     
     
     
    private var pendingLatency: [String: LatencyProbeEvent] = [:]
    private var pendingStartedNames: Set<String> = []
    private var latencyFlushScheduled = false
     
     
     
     
     
     
     
     
     
    let latencySweepConduit = PassthroughSubject<LatencySweepBatch, Never>()
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func announceLatencyRoster(_ roster: Set<String>, total: Int) {
        guard !roster.isEmpty else { return }
        sweepTesting = roster
        latencySweepConduit.send(LatencySweepBatch(
            results: [:],
            testing: roster,
            groupTerminals: resolvedNowByGroup,
            completed: 0,
            total: total,
            finished: false
        ))
    }

    func announceLatencyRosterForTesting(_ roster: Set<String>, total: Int) {
        isTestingLatency = true
        latencyTotalCount = total
        announceLatencyRoster(roster, total: total)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @Published private(set) var failureReasons: [String: String] = [:]

     
     
    func failureCauseSummary() -> String {
        guard !failureReasons.isEmpty else { return "-" }
        let tally = failureReasons.values.reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }
        return tally
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key)×\($0.value)" }
            .joined(separator: " ")
    }

    func failureReason(for name: String) -> String? {
        failureReasons[name]
    }

    func recordFailureReason(_ name: String, category: String) {
        guard !category.isEmpty, category != "admission-deferred" else { return }
        failureReasons[name] = category
    }

    func recordFailureReasonForTesting(_ name: String, category: String) {
        recordFailureReason(name, category: category)
    }

    private var sweepDelays: [String: Int] = [:]
     
     
     
     
     
     
     
     
     
     
    static var activeLatencyPolicy: LatencyProbePolicy {
        var policy = LatencyProbePolicy.currentPlatform


        return policy
    }

    var sessionProbeFailures: Set<String> = []
    private var sweepTesting: Set<String> = []
    private var sweepCompleted = 0
     
     
    static var latencyFlushNanoseconds: UInt64 = 250_000_000



    private func applyLatencyEvent(_ event: LatencyProbeEvent) {
        switch event {
        case .started(let started):
            guard started.runID == latencyRunID else { return }
            pendingStartedNames.insert(started.name)
            pendingLatency["started:\(started.name)"] = event
            scheduleLatencyFlush()
        case .result(let result):
            guard result.runID == latencyRunID else { return }
            pendingStartedNames.remove(result.name)
            pendingLatency["result:\(result.name)"] = event
            scheduleLatencyFlush()
        case .cancelled(let cancelled):
            guard cancelled.runID == latencyRunID else { return }
            pendingStartedNames.remove(cancelled.name)
            pendingLatency["cancelled:\(cancelled.name)"] = event
            scheduleLatencyFlush()
        case .finished:
             
            pendingLatency["finished"] = event
            flushLatencyEvents()
        }
    }

    private func scheduleLatencyFlush() {
        guard !latencyFlushScheduled else { return }
        latencyFlushScheduled = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.latencyFlushNanoseconds)
            self?.flushLatencyEvents()
        }
    }

     
     
     
     
     
     
    var latencyPublishQuietUntil: Date?

    private func flushLatencyEvents() {
        latencyFlushScheduled = false
        guard !pendingLatency.isEmpty else { return }
        if let until = latencyPublishQuietUntil {
            if Date() < until {
                scheduleLatencyFlush()
                return
            }
            latencyPublishQuietUntil = nil
        }
        let batch = pendingLatency
        pendingLatency.removeAll()
        let flushSpan = HakoPerf.signposter.beginInterval(
            "latency.flush", id: HakoPerf.signposter.makeSignpostID()
        )
        let flushBegan = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.signposter.endInterval("latency.flush", flushSpan)
            let elapsed = Double(
                DispatchTime.now().uptimeNanoseconds - flushBegan
            ) / 1_000_000
            HakoPerf.span(
                "latency.flush",
                milliseconds: elapsed,
                detail: "batch=\(batch.count) groups=\(groups.count)"
            )
        }

        var names = isTestingLatency ? sweepTesting : testingNames
        var newDelays: [String: Int] = [:]
        var completed = isTestingLatency ? sweepCompleted : latencyCompletedCount
        var total = latencyTotalCount
        var finishedSummary: LatencyProbeEvent?

        for event in batch.values {
            switch event {
            case .started(let started):
                 
                 
                if pendingStartedNames.contains(started.name)
                    || batch["result:\(started.name)"] == nil {
                    names.insert(started.name)
                }
                completed = max(completed, started.completedCount)
                total = started.totalCount
            case .result(let result):
                names.remove(result.name)
                switch result.outcome {
                case .success(let milliseconds):
                    newDelays[result.name] = milliseconds
                    sessionProbeFailures.remove(result.name)
                case .failure:
                    newDelays[result.name] = -1
                    sessionProbeFailures.insert(result.name)
                case .deferred:
                     
                     
                    break
                }
                completed = max(completed, result.completedCount)
                total = result.totalCount
            case .cancelled(let cancelled):
                names.remove(cancelled.name)
            case .finished:
                finishedSummary = event
            }
        }

        if let finishedSummary,
           case .finished(let summary) = finishedSummary,
           summary.runID == latencyRunID {
             
             
            sweepDelays.merge(newDelays) { _, new in new }
             
             
            HakoLogStore.shared.append(
                "sweep finished  completed=\(summary.completedCount)/\(summary.totalCount)  cancelled=\(summary.cancellationReason.map(String.init(describing:)) ?? "no")  ok=\(sweepDelays.values.filter { $0 > 0 }.count)  failed=\(sweepDelays.values.filter { $0 <= 0 }.count)  untested=\(max(0, summary.totalCount - sweepDelays.count))",
                stream: .app, level: .info)
             
             
             
             
            let settledDelays = sweepDelays
            commitSweepToPublished(
                completed: summary.completedCount,
                total: summary.totalCount
            )
             
             
             
             
             
             
             
            latencyRunID &+= 1
            pendingLatency.removeAll()
            pendingStartedNames.removeAll()
            latencySweepConduit.send(LatencySweepBatch(
                results: settledDelays,
                testing: [],
                groupTerminals: resolvedNowByGroup,
                completed: summary.completedCount,
                total: summary.totalCount,
                finished: true
            ))
            return
        }

        if isTestingLatency {
             
             
            sweepTesting = names
            sweepDelays.merge(newDelays) { _, new in new }
            sweepCompleted = completed
            latencySweepConduit.send(LatencySweepBatch(
                results: newDelays,
                testing: names,
                groupTerminals: resolvedNowByGroup,
                completed: completed,
                total: total,
                finished: false
            ))
            return
        }

         
         
        testingNames = names
        if !newDelays.isEmpty {
            var merged = delays
            for (name, delay) in newDelays { merged[name] = delay }
            delays = merged
            nodeCatalog = nodeCatalog.map { record in
                guard let delay = newDelays[record.name] else { return record }
                return ProxyNodeRecord(
                    name: record.name,
                    type: record.type,
                    delay: delay,
                    groupNames: record.groupNames,
                    protocolDetails: record.protocolDetails
                )
            }
        }
        latencyCompletedCount = completed
        latencyTotalCount = total
    }

     
     
     
     
     
     
     
     
     
    private func commitSweepToPublished(completed: Int, total: Int) {
        if !sweepDelays.isEmpty {
            var merged = delays
            for (name, delay) in sweepDelays { merged[name] = delay }
            delays = merged
        }
        sweepDelays = [:]
        sweepTesting = []
        sweepCompleted = 0
        failureReasons = [:]
        testingNames.removeAll()
        latencyCompletedCount = completed
        latencyTotalCount = total
        isTestingLatency = false
    }

     
     
     
     
     
     
     
     
     
     
     
     
    func discardDelaysMeasuredAgainstAnotherEndpoint(
        currentTestURL: String = DelayTestSettings.url()
    ) {
        guard currentTestURL != delaysTestURL else { return }
        delaysTestURL = currentTestURL
        delays = [:]
    }

     
     
    enum InventoryApplicationReason {
         
         
        case periodicRefresh
         
         
         
         
         
        case selectionReadback
    }

     
    nonisolated static func inventorySkipsDuringSweep(
        reason: InventoryApplicationReason,
        hasGroups: Bool,
        hasData: Bool
    ) -> Bool {
        guard case .periodicRefresh = reason else { return false }
        return hasGroups && hasData
    }

    private func applyInventory(
        _ data: Data?,
        reason: InventoryApplicationReason = .periodicRefresh
    ) {
        guard inventoryApplicationIsWanted(data, reason: reason) else { return }
        inventoryApplyGeneration &+= 1
         
         
         
        let proxies = HakoPerf.measure("inventory.decode") {
            NodeInventory.proxies(in: data)
        }
        let inventory = HakoPerf.measure(
            "inventory.parse",
            detail: "entries=\(proxies?.count ?? 0) providers=\(runtimeProviderCatalog.proxyProviders.count)"
        ) {
            NodeInventory.parse(
                proxies: proxies,
                groupConfigurationDetailsByName: groupConfigurationDetailsByName,
                providerCatalog: runtimeProviderCatalog,
                configuredOrder: configuredOrder
            )
        }
        publishInventory(data: data, proxies: proxies, inventory: inventory)
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private func applyInventoryOffMain(
        _ data: Data?,
        reason: InventoryApplicationReason
    ) async {
        guard inventoryApplicationIsWanted(data, reason: reason) else { return }
        inventoryApplyGeneration &+= 1
        let generation = inventoryApplyGeneration
        let groupDetails = groupConfigurationDetailsByName
        let providerCatalog = runtimeProviderCatalog
        let order = configuredOrder
        let parsed = await Task.detached(
            priority: .userInitiated
        ) { () -> ([String: Any]?, ([ProxyGroup], [String: Int]), Double) in
            let began = DispatchTime.now().uptimeNanoseconds
            let proxies = NodeInventory.proxies(in: data)
            let inventory = NodeInventory.parse(
                proxies: proxies,
                groupConfigurationDetailsByName: groupDetails,
                providerCatalog: providerCatalog,
                configuredOrder: order
            )
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
            return (proxies, inventory, elapsed)
        }.value
        HakoPerf.span(
            "inventory.parse.offmain",
            milliseconds: parsed.2,
            detail: "entries=\(parsed.0?.count ?? 0)"
        )
         
         
         
         
         
         
         
        if let command, command.isConnected, let latest = command.proxiesData {
            if latest != data {
                await applyInventoryOffMain(latest, reason: reason)
                return
            }
        } else if generation != inventoryApplyGeneration {
            return
        }
        if data == appliedProxiesData, !groups.isEmpty { return }
        publishInventory(data: data, proxies: parsed.0, inventory: parsed.1)
    }

     
     
     
    private func inventoryApplicationIsWanted(
        _ data: Data?,
        reason: InventoryApplicationReason
    ) -> Bool {
        inventoryApplications &+= 1
        discardDelaysMeasuredAgainstAnotherEndpoint()
         
         
         
         
         
         
         
         
        if isTestingLatency,
           Self.inventorySkipsDuringSweep(
               reason: reason,
               hasGroups: !groups.isEmpty,
               hasData: data != nil
           ) {
            return false
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
        if let data,
           data == appliedProxiesData,
           runtimeProviderCatalog == appliedProviderCatalog,
           protocolDetailsByNodeName == appliedProtocolDetails,
           groupConfigurationDetailsByName == appliedGroupDetails,
           !groups.isEmpty {
            return false
        }
        return true
    }

    private func publishInventory(
        data: Data?,
        proxies: [String: Any]?,
        inventory: ([ProxyGroup], [String: Int])
    ) {
        appliedProxiesData = data
        appliedProviderCatalog = runtimeProviderCatalog
        appliedProtocolDetails = protocolDetailsByNodeName
        appliedGroupDetails = groupConfigurationDetailsByName
         
         
         
        HakoPerf.measure("inventory.publish") {
            groups = inventory.0
            delays = inventory.1.merging(delays) { new, old in
                old > 0 ? old : new
            }
        }
        HakoPerf.measure("inventory.catalog") {
            rebuildCatalog(from: proxies)
        }
    }

     
     
     
    private func reloadInventoryOffMain(command: NodesCommanding) async {
        guard command.isConnected, let data = command.proxiesData else {
            reloadInventory(command: command)
            return
        }
        runtimeRestartRequestedAt = nil
        isRuntimeAvailable = true
        lastRuntimeInventory = data
        await applyInventoryOffMain(data, reason: .periodicRefresh)
        scheduleConnectedProjection()
    }

    private func rebuildCatalog(from proxies: [String: Any]?) {
        catalogGeneration &+= 1
        let generation = catalogGeneration
        guard let proxies else {
            catalogRebuild = nil
            nodeCatalog = []
            return
        }
        let details = protocolDetailsByNodeName
        let providerCatalog = runtimeProviderCatalog
        let order = configuredOrder
        catalogRebuild = Task { [weak self] in
            let records = await Task.detached(priority: .userInitiated) {
                NodeInventory.nodeCatalog(
                    proxies: proxies,
                    protocolDetailsByNodeName: details,
                    providerCatalog: providerCatalog,
                    configuredOrder: order
                )
            }.value
            guard let self, generation == self.catalogGeneration else { return }
            self.nodeCatalog = records.map { record in
                ProxyNodeRecord(
                    name: record.name,
                    type: record.type,
                    delay: self.delays[record.name] ?? record.delay,
                    groupNames: record.groupNames,
                    protocolDetails: record.protocolDetails
                )
            }
        }
    }

    private func reloadInventory(command: NodesCommanding) {
        if command.isConnected, let data = command.proxiesData {
            runtimeRestartRequestedAt = nil
            isRuntimeAvailable = true
             
             
             
             
             
             
            lastRuntimeInventory = data
            applyInventory(data)
            scheduleConnectedProjection()
            return
        }

         
         
         
         
         
         
        if command.isReopeningControlSession { return }

         
         
         
         
        if let requested = runtimeRestartRequestedAt {
            if Date().timeIntervalSince(requested) < runtimeRestartGrace,
               !groups.isEmpty {
                return
            }
            runtimeRestartRequestedAt = nil
        }

        isRuntimeAvailable = false
        providerNamesByProxy = [:]
         
         
         
         
         
         
        let load = offlineCatalogLoader
        scheduleOfflineCatalog(load)
    }

    private func scheduleOfflineCatalog(
        _ load: @escaping @Sendable () -> OfflineProxyCatalogSnapshot?
    ) {
        inventoryProjectionGeneration &+= 1
        let generation = inventoryProjectionGeneration
        inventoryProjectionTasks[generation] = Task.detached(priority: .userInitiated) { [weak self] in
            let began = DispatchTime.now().uptimeNanoseconds
            let snapshot = load()
            let projection = snapshot.map { NodesInventoryProjection.read(yaml: $0.yaml) }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
            await MainActor.run {
                self?.receiveOfflineCatalog(
                    snapshot,
                    projection: projection,
                    generation: generation,
                    milliseconds: elapsed
                )
            }
        }
    }

    private func receiveOfflineCatalog(
        _ snapshot: OfflineProxyCatalogSnapshot?,
        projection: NodesInventoryProjection?,
        generation: UInt64,
        milliseconds: Double
    ) {
        inventoryProjectionTasks[generation] = nil
        guard generation == inventoryProjectionGeneration else { return }
        HakoPerf.span(
            "proxies.offline",
            milliseconds: milliseconds,
            detail: "nodes=\(projection?.protocolDetails.count ?? 0)"
        )
        guard let snapshot, let projection else {
            lastRuntimeInventory = nil
            protocolDetailsByNodeName = [:]
            groupConfigurationDetailsByName = [:]
            configuredOrder = .none
            trafficUsageByGroupName = [:]
            applyInventory(nil)
            return
        }
        let protocolDetails = projection.protocolDetails.merging(
            locallyEditedProtocolDetails
        ) { _, edited in edited }
        if !groups.isEmpty,
           lastRuntimeInventory == snapshot.runtimeData,
           protocolDetails == protocolDetailsByNodeName,
           projection.groupDetails == groupConfigurationDetailsByName,
           projection.order == configuredOrder,
           projection.trafficUsage == trafficUsageByGroupName {
            return
        }
        protocolDetailsByNodeName = protocolDetails
        groupConfigurationDetailsByName = projection.groupDetails
        configuredOrder = projection.order
        trafficUsageByGroupName = projection.trafficUsage
        lastRuntimeInventory = snapshot.runtimeData
        applyInventory(snapshot.runtimeData)
    }

     
    private func scheduleConnectedProjection() {
        let protocolDetails = protocolDetailsLoader
        let groupDetails = groupConfigurationDetailsLoader
        let order = configuredOrderLoader
        let trafficUsage = trafficUsageLoader
        scheduleInventoryProjection {
            NodesInventoryProjection(
                protocolDetails: protocolDetails(),
                groupDetails: groupDetails(),
                order: order(),
                trafficUsage: trafficUsage()
            )
        }
    }

     
     
     
    private func scheduleInventoryProjection(
        _ read: @escaping @Sendable () -> NodesInventoryProjection
    ) {
        inventoryProjectionGeneration &+= 1
        let generation = inventoryProjectionGeneration
        inventoryProjectionTasks[generation] = Task.detached(priority: .userInitiated) { [weak self] in
            let began = DispatchTime.now().uptimeNanoseconds
            let projection = read()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
            await MainActor.run {
                self?.receiveInventoryProjection(
                    projection,
                    generation: generation,
                    milliseconds: elapsed
                )
            }
        }
    }

    private func receiveInventoryProjection(
        _ projection: NodesInventoryProjection,
        generation: UInt64,
        milliseconds: Double
    ) {
        inventoryProjectionTasks[generation] = nil
        guard generation == inventoryProjectionGeneration else { return }
        HakoPerf.span(
            "proxies.projection",
            milliseconds: milliseconds,
            detail: "nodes=\(projection.protocolDetails.count) groups=\(projection.groupDetails.count)"
        )
        let protocolDetails = projection.protocolDetails.merging(
            locallyEditedProtocolDetails
        ) { _, edited in edited }
        if protocolDetails == protocolDetailsByNodeName,
           projection.groupDetails == groupConfigurationDetailsByName,
           projection.order == configuredOrder,
           projection.trafficUsage == trafficUsageByGroupName {
            return
        }
        protocolDetailsByNodeName = protocolDetails
        groupConfigurationDetailsByName = projection.groupDetails
        configuredOrder = projection.order
        trafficUsageByGroupName = projection.trafficUsage
         
         
         
        if let command, command.isConnected, let current = command.proxiesData {
            lastRuntimeInventory = current
        }
        applyInventory(lastRuntimeInventory)
    }

     
     
    func settleInventoryProjection() async {
        for task in inventoryProjectionTasks.values {
            await task.value
        }
    }

     
     
     
    private func noteKernelAcceptedSelection(group: String, name: String) {
        applyOfflineSelection(group: group, name: name)
    }

    private func applyOfflineSelection(group: String, name: String) {
        guard let index = groups.firstIndex(where: { $0.name == group }) else { return }
        let current = groups[index]
        groups[index] = ProxyGroup(
            name: current.name,
            type: current.type,
            now: name,
            members: current.members,
            resolvedNow: current.memberResolvedNames[name] ?? name,
            memberTypes: current.memberTypes,
            memberGroupNames: current.memberGroupNames,
            memberResolvedNames: current.memberResolvedNames,
            configurationDetails: current.configurationDetails,
            hidden: current.hidden
        )
    }

    private func restoreActiveProfileSelectionIfNeeded(command: NodesCommanding) async {
        guard let state = preferences?.load() else { return }
         
         
         
         
         
         
         
         
         
         
         
        let selectionFingerprint = (try? JSONEncoder.sortedKeys.encode(
            state.selectedMap
        )).map { String(decoding: $0, as: UTF8.self) } ?? ""

        let runtimeKey = (currentRuntimeIdentity().map {
            "\($0.profileID)|\($0.revision)"
        } ?? state.profileID) + "|" + selectionFingerprint
        guard runtimeKey != restoredRuntimeKey else { return }
        currentGroupName = state.currentGroupName
        unfoldedGroups = state.unfoldedGroups ?? Set(groups.map(\.name))

         
         
         
        guard command.isConnected else { return }

        let restorePlan = groups.compactMap {
            group -> (group: String, member: String)? in
            guard let preferred = state.selectedMap[group.name],
                  group.acceptsMemberChoice,
                  group.members.contains(preferred) else {
                return nil
            }
            return (group.name, preferred)
        }
        var restoredManualGroup: String?
        for item in restorePlan {
            guard let current = groups.first(
                where: { $0.name == item.group }
            ) else {
                continue
            }
            if ProxyGroupControlKind(rawType: current.type) == .manual,
               item.group != GlobalProxySelectionPolicy.groupName {
                restoredManualGroup = restoredManualGroup ?? item.group
            }
            guard current.now != item.member else { continue }
            let confirmed = await command.select(
                group: item.group,
                name: item.member
            )
            if confirmed { noteKernelAcceptedSelection(group: item.group, name: item.member) }
            await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
            guard confirmed,
                  groups.first(where: { $0.name == item.group })?.now
                    == item.member else {
                 
                 
                return
            }
        }

        if command.mode.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased() == "global",
           let global = groups.first(where: {
               $0.name == GlobalProxySelectionPolicy.groupName
           }) {
            let candidates = [
                state.currentGroupName,
                restoredManualGroup,
            ].compactMap { $0 }
            let preferred = candidates.first {
                global.members.contains($0)
                    && GlobalProxySelectionPolicy.isSafeManualGroup(
                        $0,
                        groups: groups
                    )
            }
            if let preferred, global.now != preferred {
                let confirmed = await command.select(
                    group: global.name,
                    name: preferred
                )
                if confirmed { noteKernelAcceptedSelection(group: global.name, name: preferred) }
                await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
                guard confirmed,
                      groups.first(where: {
                          $0.name == GlobalProxySelectionPolicy.groupName
                      })?.now == preferred else {
                    return
                }
            }
        }

        await applyInventoryOffMain(command.proxiesData, reason: .selectionReadback)
         
         
        restoredRuntimeKey = runtimeKey
    }

    private func currentRuntimeIdentity() -> NodesRuntimeIdentity? {
        if let identity = runtimeIdentityLoader() {
            return identity
        }
        return preferences?.load().map {
            NodesRuntimeIdentity(profileID: $0.profileID, revision: "")
        }
    }

     
     
     
     
     
     
    private func transitionRuntimeIfNeeded(command: NodesCommanding) async -> Bool {
        guard let identity = currentRuntimeIdentity() else { return false }
        guard let previous = observedRuntimeIdentity else {
            observedRuntimeIdentity = identity
            return false
        }
        guard identity != previous else { return false }
        observedRuntimeIdentity = identity

        await cancelLatencyTests(reason: .superseded)
        providerCatalogGeneration &+= 1
        restoredRuntimeKey = nil
         
         
         
         
         
         
         
        delays = [:]
        sessionProbeFailures = []
        nodeCatalog = []
        query = ""
        testingNames = []
        currentGroupName = nil
        unfoldedGroups = []
        isSwitchingProxy = false
        providerNamesByProxy = [:]
        isRuntimeAvailable = false
        trafficUsageByGroupName = [:]
        protocolDetailsByNodeName = [:]
        locallyEditedProtocolDetails = [:]
        groupConfigurationDetailsByName = [:]
        latencyCompletedCount = 0
        latencyTotalCount = 0

        guard command.isConnected else { return false }
        await command.closeConnectionsAfterProxySelection()
         
         
         
         
         
         
        runtimeRestartRequestedAt = Date()
        command.reconnectAfterRuntimeChange()
        return false
    }

    private func loadProviderSources(command: NodesCommanding, token: UInt64) async {
        guard command.isConnected else {
            if token == providerCatalogGeneration {
                providerNamesByProxy = [:]
                runtimeProviderCatalog = .empty
            }
            return
        }
        do {
            let catalog = try await command.nodesProviderCatalog()
            guard token == providerCatalogGeneration else { return }
            providerNamesByProxy = ProxyProviderAttribution.uniqueProviderNames(in: catalog)
            runtimeProviderCatalog = catalog
             
             
             
             
            reapplyInventoryWithProviderCatalog(command: command)
        } catch {
            guard token == providerCatalogGeneration else { return }
            providerNamesByProxy = [:]
            runtimeProviderCatalog = .empty
             
             
             
             
             
             
             
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard token == providerCatalogGeneration,
                  command.isConnected,
                  let retried = try? await command.nodesProviderCatalog(),
                  token == providerCatalogGeneration else { return }
            providerNamesByProxy = ProxyProviderAttribution.uniqueProviderNames(in: retried)
            runtimeProviderCatalog = retried
            reapplyInventoryWithProviderCatalog(command: command)
        }
    }

     
     
     
     
     
     
     
     
    private func reapplyInventoryWithProviderCatalog(command: NodesCommanding) {
        guard runtimeProviderCatalog != appliedProviderCatalog,
              command.isConnected,
              let data = command.proxiesData else { return }
        applyInventory(data)
    }

}

 
 
 
 
 
 
 
private actor SubscriptionHealthRuns {
    private let providerNamesByProxy: [String: String]
    private let usesBulkHealth: Bool
    private let startedAt: Date
    private var runs: [String: Task<[String: Int], Never>] = [:]
     
    private var early: [String: Int] = [:]
    private var finished: Set<String> = []
    private var cancelled = false

    init(
        providerNamesByProxy: [String: String],
        usesBulkHealth: Bool = true,
        startedAt: Date = Date()
    ) {
        self.providerNamesByProxy = providerNamesByProxy
        self.usesBulkHealth = usesBulkHealth
        self.startedAt = startedAt
    }

     
     
    func delay(for name: String, command: NodesCommanding) async -> Int? {
        guard usesBulkHealth,
              let provider = providerNamesByProxy[name] else { return nil }
        let run = run(for: provider, command: command)
         
         
         
        while !finished.contains(provider), !cancelled, !Task.isCancelled {
            if let seen = early[name] { return seen }
            await pollOnce(provider: provider, command: command)
        }
         
         
         
         
        guard !cancelled, !Task.isCancelled else { return -1 }
        if let measured = await run.value[name], measured > 0 {
            return measured
        }
        if let seen = early[name] { return seen }
         
         
         
         
         
         
        return nil
    }

     
    func cancel() {
        cancelled = true
        for run in runs.values { run.cancel() }
    }

    private func run(
        for provider: String, command: NodesCommanding
    ) -> Task<[String: Int], Never> {
        if let existing = runs[provider] { return existing }
        let began = Date()
        HakoLogStore.shared.append(
            "provider-health start  provider=\(provider)",
            stream: .app, level: .info)
        let created = Task { await command.nodesHealthCheckProvider(named: provider) }
        runs[provider] = created
        Task { [weak self] in
            let map = await created.value
            let ok = map.values.filter { $0 > 0 }.count
            HakoLogStore.shared.append(
                "provider-health done  provider=\(provider)  ok=\(ok)/\(map.count)  in=\(String(format: "%.1f", Date().timeIntervalSince(began)))s",
                stream: .app, level: ok == 0 ? .warning : .info)
            await self?.markFinished(provider)
        }
        return created
    }

    private func markFinished(_ provider: String) {
        finished.insert(provider)
    }

     
     
     
     
    private func pollOnce(provider: String, command: NodesCommanding) async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !cancelled, !Task.isCancelled,
              let catalog = try? await command.nodesProviderCatalog(),
              let live = catalog.proxyProviders[provider] else { return }
        for proxy in live.proxies {
            guard let measuredAt = proxy.measuredAt, measuredAt >= startedAt else { continue }
            if let delay = proxy.latestDelayMilliseconds, delay > 0 {
                early[proxy.name] = delay
            } else if proxy.alive == false {
                early[proxy.name] = -1
            }
        }
    }
}


extension NodesModel {
     
     
     
     
     
     
    private func logSweepCoverage(planned: [String]) {
        let subscriptionNames = runtimeProviderCatalog.proxyProviders.values
            .filter { !$0.isKernelInternal }
            .flatMap { $0.proxies.map(\.name) }
        guard !subscriptionNames.isEmpty else { return }
        var seen: Set<String> = []
        var folded: [String] = []
        for name in subscriptionNames {
            if !seen.insert(name).inserted { folded.append(name) }
        }
        let plannedSet = Set(planned)
        let excluded = plannedSet.isEmpty ? [] : Array(
            Set(subscriptionNames).subtracting(plannedSet)
                .subtracting(folded)
        ).sorted().prefix(6)
        var parts = [
            "sweep coverage  catalog=\(subscriptionNames.count)",
            "planned=\(planned.count)",
            "workers=\(Self.activeLatencyPolicy.concurrentProbeCount(for: planned.count))",
            "providerHealth=\(LatencyProbePolicy.currentPlatform.usesBulkProviderHealth(for: planned.count, catalogCount: groups.reduce(0) { $0 + $1.members.count } + providerNamesByProxy.count) ? "bulk" : "per-node")",
        ]
        if !folded.isEmpty {
            parts.append("folded=\(folded.count) [\(folded.prefix(6).joined(separator: ", "))]")
        }
        if !excluded.isEmpty {
            parts.append("unplanned=[\(excluded.joined(separator: ", "))]")
        }
        HakoLogStore.shared.append(parts.joined(separator: "  "), stream: .app)
    }
}

 
struct LatencySweepBatch: Equatable, Sendable {
     
    let results: [String: Int]
     
    let testing: Set<String>
     
    let groupTerminals: [String: String]
    let completed: Int
    let total: Int
    let finished: Bool
}
