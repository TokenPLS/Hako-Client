import Foundation

struct SubscriptionInfo: Codable, Equatable {
    var upload: Int64
    var download: Int64
    var total: Int64
    var expire: Int64    
}

extension SubscriptionInfo {
     
     
     
    static func parse(header: String) -> SubscriptionInfo? {
        var m: [String: Int64] = [:]
        for pair in header.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            m[kv[0].trimmingCharacters(in: .whitespaces)] =
                Int64(kv[1].trimmingCharacters(in: .whitespaces))
        }
        guard !m.isEmpty else { return nil }
        return SubscriptionInfo(upload: m["upload"] ?? 0, download: m["download"] ?? 0,
                                total: m["total"] ?? 0, expire: m["expire"] ?? 0)
    }
}

 
 
struct OverrideSpec: Codable, Equatable {
    var patchJSON: String
    var appendRules: [String]
     
     
     
     
     
     
    var prependRules: Bool
     
     
    var disabledGlobalRules: [String]?
     
     
     
    var disabledAppendRules: [String]?
     
     
    var appendRuleComments: [String: String]?
     
     
     
     
     
     
     
     
    var dnsOverridesProfiles: Bool?

    init(
        patchJSON: String = "",
        appendRules: [String] = [],
        prependRules: Bool = true,
        disabledGlobalRules: [String]? = nil,
        disabledAppendRules: [String]? = nil,
        appendRuleComments: [String: String]? = nil,
        dnsOverridesProfiles: Bool? = nil
    ) {
        self.patchJSON = patchJSON
        self.appendRules = appendRules
        self.prependRules = prependRules
        self.disabledGlobalRules = disabledGlobalRules
        self.disabledAppendRules = disabledAppendRules
        self.appendRuleComments = appendRuleComments
        self.dnsOverridesProfiles = dnsOverridesProfiles
    }
}

 
 
 
enum ProxyIdentityKind: String, Equatable, Hashable {
    case proxy
    case group
    case builtin
     
     
     
     
     
    case payloadProxy
}

struct ProxyIdentity: Equatable, Hashable, Identifiable {
    let name: String
    let type: String
    let dialerProxy: String?
    let kind: ProxyIdentityKind
     
     
     
    var members: [String] = []
     
    var provider: String? = nil

    var id: String { name }
    var canSetDialerProxy: Bool { kind == .proxy }
     
     
    var supportsChainEditing: Bool { kind == .proxy || kind == .payloadProxy }
}

 
 
 
struct ProxyDialerAssignment: Codable, Equatable, Hashable, Identifiable {
    var proxy: String
    var dialerProxy: String?

    var id: String { proxy }
}

 
 
struct ProxyPayloadDialerEdit: Equatable, Hashable, Identifiable {
    var provider: String
    var node: String
    var dialerProxy: String?

    var id: String { "\(provider)/\(node)" }
}

enum ProxyChainError: LocalizedError, Equatable {
    case invalidProxyList
    case missingProxyName(Int)
    case duplicateProxyName(String)
    case duplicateAssignment(String)
    case missingProxy(String)
    case unsupportedChainSource(String)
    case missingDialerProxy(proxy: String, dialerProxy: String)
    case circularDependency([String])
    case payloadNodeNotDialable(proxy: String, dialerProxy: String)
    case renameCollision(String)
    case proxyInUse(proxy: String, dependents: [String])

    var errorDescription: String? {
        switch self {
        case .invalidProxyList:
            return "The generated configuration does not contain a valid proxies list."
        case .missingProxyName(let index):
            return "Proxy entry \(index + 1) has no name."
        case .duplicateProxyName(let name):
            return "Proxy name \"\(name)\" is duplicated. Rename it before configuring a chain."
        case .duplicateAssignment(let name):
            return "Proxy \"\(name)\" has more than one chain override."
        case .missingProxy(let name):
            return "Proxy \"\(name)\" no longer exists. Remove or migrate its chain override."
        case .unsupportedChainSource(let name):
            return "\"\(name)\" can be a dialer target, but dialer-proxy may only be set on an individual proxy."
        case let .missingDialerProxy(proxy, dialerProxy):
            return "Proxy \"\(proxy)\" references missing dialer-proxy \"\(dialerProxy)\". Rebind or clear it."
        case .circularDependency(let path):
            return "Proxy chain contains a cycle: \(path.joined(separator: " → "))."
        case let .payloadNodeNotDialable(proxy, dialerProxy):
             
             
             
             
            return "\"\(proxy)\" cannot dial through \"\(dialerProxy)\": the kernel resolves dialer-proxy in the proxies list only, and \"\(dialerProxy)\" comes from a proxy provider. Dial through a group that contains it instead."
        case .renameCollision(let name):
            return "Proxy \"\(name)\" already has a chain override."
        case let .proxyInUse(proxy, dependents):
            return "Proxy \"\(proxy)\" is used by \(dependents.joined(separator: ", ")). Rebind those proxies before deleting it."
        }
    }
}

struct ProxyChainSpec: Codable, Equatable {
    var assignments: [ProxyDialerAssignment] = []

    var isEmpty: Bool { assignments.isEmpty }

    func assignment(for proxy: String) -> ProxyDialerAssignment? {
        assignments.first { $0.proxy == proxy }
    }

    mutating func setDialerProxy(_ dialerProxy: String?, for proxy: String) {
        let assignment = ProxyDialerAssignment(proxy: proxy, dialerProxy: dialerProxy)
        if let index = assignments.firstIndex(where: { $0.proxy == proxy }) {
            assignments[index] = assignment
        } else {
            assignments.append(assignment)
        }
    }

    mutating func removeAssignment(for proxy: String) {
        assignments.removeAll { $0.proxy == proxy }
    }

     
     
     
     
     
    mutating func clearDialerOverride(
        for proxy: String,
        sourceDialerProxy: String?
    ) {
        if let sourceDialerProxy, !sourceDialerProxy.isEmpty {
            setDialerProxy(nil, for: proxy)
        } else {
            removeAssignment(for: proxy)
        }
    }

     
     
     
    static func inventory(from yaml: String) throws -> [ProxyIdentity] {
        guard let root = ConfigTransforms.parsedRoot(forYAML: yaml)?.root else {
             
             
            _ = try ConfigTransforms.yamlToJSON(yaml)
            throw ProxyChainError.invalidProxyList
        }
        return try inventory(from: root)
    }

     
     
    static func inventory(from root: [String: Any]) throws -> [ProxyIdentity] {
        guard let rows = root["proxies"] as? [Any] else {
            return []
        }

        var names = Set<String>()
        var inventory = try rows.enumerated().map { index, value in
            guard let row = value as? [String: Any] else {
                throw ProxyChainError.invalidProxyList
            }
            let name = (row["name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { throw ProxyChainError.missingProxyName(index) }
            guard names.insert(name).inserted else {
                throw ProxyChainError.duplicateProxyName(name)
            }
            let dialer = (row["dialer-proxy"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ProxyIdentity(
                name: name,
                type: (row["type"] as? String) ?? "unknown",
                dialerProxy: dialer?.isEmpty == false ? dialer : nil,
                kind: .proxy
            )
        }

         
         
         
         
        var payloadNamesByProvider: [String: [String]] = [:]
        if let providers = root["proxy-providers"] as? [String: Any] {
            for providerName in providers.keys.sorted() {
                guard let definition = providers[providerName] as? [String: Any],
                      (definition["type"] as? String) == "inline",
                      let payload = definition["payload"] as? [[String: Any]] else {
                    continue
                }
                for row in payload {
                    let name = (row["name"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !name.isEmpty else { continue }
                    payloadNamesByProvider[providerName, default: []].append(name)
                    guard names.insert(name).inserted else { continue }
                    let dialer = (row["dialer-proxy"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    inventory.append(ProxyIdentity(
                        name: name,
                        type: (row["type"] as? String) ?? "unknown",
                        dialerProxy: dialer?.isEmpty == false ? dialer : nil,
                        kind: .payloadProxy,
                        provider: providerName
                    ))
                }
            }
        }

        if let groups = root["proxy-groups"] as? [Any] {
            for (index, value) in groups.enumerated() {
                guard let row = value as? [String: Any] else {
                    throw ProxyChainError.invalidProxyList
                }
                let name = (row["name"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else {
                    throw ProxyChainError.missingProxyName(rows.count + index)
                }
                guard names.insert(name).inserted else {
                    throw ProxyChainError.duplicateProxyName(name)
                }
                var members = (row["proxies"] as? [String]) ?? []
                for providerName in (row["use"] as? [String]) ?? [] {
                    members.append(
                        contentsOf: payloadNamesByProvider[providerName] ?? []
                    )
                }
                inventory.append(ProxyIdentity(
                    name: name,
                    type: (row["type"] as? String) ?? "group",
                    dialerProxy: nil,
                    kind: .group,
                    members: members
                ))
            }
        }

         
         
         
         
         
         
         
        for builtin in [
            ("DIRECT", "direct"),
            ("REJECT", "reject"),
            ("REJECT-DROP", "reject-drop"),
            ("COMPATIBLE", "compatible"),
            ("PASS", "pass"),
            ("PASS-RULE", "pass-rule"),
             
             
            ("GLOBAL", "selector"),
        ] where names.insert(builtin.0).inserted {
            inventory.append(ProxyIdentity(
                name: builtin.0,
                type: builtin.1,
                dialerProxy: nil,
                kind: .builtin
            ))
        }
        return inventory
    }

    func validate(in inventory: [ProxyIdentity]) throws {
        _ = try effectiveGraph(in: inventory, validateCycles: true)
    }

    func orderedPath(startingAt proxy: String, in inventory: [ProxyIdentity]) throws -> [String] {
        let graph = try effectiveGraph(in: inventory, validateCycles: true)
        guard let identity = inventory.first(where: { $0.name == proxy }) else {
            throw ProxyChainError.missingProxy(proxy)
        }
        guard identity.supportsChainEditing else {
            throw ProxyChainError.unsupportedChainSource(proxy)
        }
        var path: [String] = []
        var current: String? = proxy
        while let name = current {
            path.append(name)
            current = graph[name]
        }
        return path
    }

     
     
     
    func apply(to yaml: String) throws -> String {
         
         
         
        guard !assignments.isEmpty else { return yaml }
        var document = try ConfigTransforms.ParsedDocument(yaml: yaml)
        try apply(to: &document.root)
        return try document.serialized()
    }

     
     
     
    func apply(to root: inout [String: Any]) throws {
        guard !assignments.isEmpty else { return }
        let inventory = try Self.inventory(from: root)
        try validate(in: inventory)

         
         
         
         
        var proxies = (root["proxies"] as? [[String: Any]]) ?? []
         
         
        let indexByName = Dictionary(proxies.enumerated().compactMap {
            index, row in (row["name"] as? String).map { ($0, index) }
        }, uniquingKeysWith: { first, _ in first })
        for assignment in assignments {
            guard let index = indexByName[assignment.proxy] else {
                throw ProxyChainError.missingProxy(assignment.proxy)
            }
            if let dialerProxy = assignment.dialerProxy {
                proxies[index]["dialer-proxy"] = dialerProxy
            } else {
                proxies[index].removeValue(forKey: "dialer-proxy")
            }
        }
        root["proxies"] = proxies
    }

    mutating func renameProxy(from oldName: String, to newName: String) throws {
        guard oldName != newName else { return }
        if assignments.contains(where: { $0.proxy == newName && $0.proxy != oldName }) {
            throw ProxyChainError.renameCollision(newName)
        }
        for index in assignments.indices {
            if assignments[index].proxy == oldName { assignments[index].proxy = newName }
            if assignments[index].dialerProxy == oldName {
                assignments[index].dialerProxy = newName
            }
        }
    }

    func dependents(of proxy: String, in inventory: [ProxyIdentity]) -> [String] {
        var graph = Dictionary(uniqueKeysWithValues: inventory.compactMap { identity in
            identity.dialerProxy.map { (identity.name, $0) }
        })
        for assignment in assignments {
            graph[assignment.proxy] = assignment.dialerProxy
        }
        return graph.compactMap { $0.value == proxy ? $0.key : nil }.sorted()
    }

    mutating func removeProxy(named proxy: String, in inventory: [ProxyIdentity]) throws {
        let dependents = dependents(of: proxy, in: inventory)
        guard dependents.isEmpty else {
            throw ProxyChainError.proxyInUse(proxy: proxy, dependents: dependents)
        }
        removeAssignment(for: proxy)
    }

    private func effectiveGraph(
        in inventory: [ProxyIdentity],
        validateCycles: Bool
    ) throws -> [String: String] {
        let names = Set(inventory.map(\.name))
        let editableNames = Set(inventory.filter(\.canSetDialerProxy).map(\.name))
        var graph = Dictionary(uniqueKeysWithValues: inventory.compactMap { identity in
            identity.dialerProxy.map { (identity.name, $0) }
        })
        var assigned = Set<String>()
        for assignment in assignments {
            guard assigned.insert(assignment.proxy).inserted else {
                throw ProxyChainError.duplicateAssignment(assignment.proxy)
            }
            guard names.contains(assignment.proxy) else {
                throw ProxyChainError.missingProxy(assignment.proxy)
            }
            guard editableNames.contains(assignment.proxy) else {
                throw ProxyChainError.unsupportedChainSource(assignment.proxy)
            }
            if let dialerProxy = assignment.dialerProxy {
                graph[assignment.proxy] = dialerProxy
            } else {
                graph.removeValue(forKey: assignment.proxy)
            }
        }
        for (proxy, dialerProxy) in graph where !names.contains(dialerProxy) {
            throw ProxyChainError.missingDialerProxy(
                proxy: proxy,
                dialerProxy: dialerProxy
            )
        }
        let identityByName = Dictionary(
            uniqueKeysWithValues: inventory.map { ($0.name, $0) }
        )
        for (proxy, dialerProxy) in graph
        where identityByName[dialerProxy]?.kind == .payloadProxy {
            throw ProxyChainError.payloadNodeNotDialable(
                proxy: proxy,
                dialerProxy: dialerProxy
            )
        }
        guard validateCycles else { return graph }

         
         
         
         
         
        func successors(_ name: String) -> [String] {
            var next: [String] = []
            if let dialer = graph[name] { next.append(dialer) }
            if let members = identityByName[name]?.members {
                next.append(contentsOf: members.filter { identityByName[$0] != nil })
            }
            return next
        }
        for start in graph.keys.sorted() {
            var stack: [(node: String, path: [String])] = [(start, [start])]
            var visited: Set<String> = []
            while let (node, path) = stack.popLast() {
                for next in successors(node) {
                    if next == start {
                        throw ProxyChainError.circularDependency(path + [start])
                    }
                    if visited.insert(next).inserted {
                        stack.append((node: next, path: path + [next]))
                    }
                }
            }
        }

        return graph
    }
}

enum ProxyNodeOverrideError: LocalizedError, Equatable {
    case invalidConfiguration
    case invalidPatch(String)
    case duplicateProxyName(String)
    case missingProxy(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "The generated proxy configuration is invalid."
        case .invalidPatch(let name):
            return "The saved settings for proxy \"\(name)\" are invalid."
        case .duplicateProxyName(let name):
            return "Proxy name \"\(name)\" is duplicated. Edit the source before changing this node."
        case .missingProxy(let name):
            return "Proxy \"\(name)\" is no longer present in this profile."
        }
    }
}

 
 
 
 
 
struct ProxyNodeOverride: Codable, Equatable, Hashable, Identifiable {
    var proxy: String
    var patchJSON: String

    var id: String { proxy }
}

struct ProxyNodeOverrideSpec: Codable, Equatable, Hashable {
    var overrides: [ProxyNodeOverride] = []

    var isEmpty: Bool { overrides.isEmpty }

    mutating func setPatch(_ patchJSON: String, for proxy: String) {
        overrides.removeAll { $0.proxy == proxy }
        guard patchJSON != "{}", !patchJSON.isEmpty else { return }
        overrides.append(.init(proxy: proxy, patchJSON: patchJSON))
        overrides.sort { $0.proxy.localizedStandardCompare($1.proxy) == .orderedAscending }
    }

     
    mutating func removePatch(for proxy: String) {
        overrides.removeAll { $0.proxy == proxy }
    }

    func patch(for proxy: String) -> String? {
        overrides.first { $0.proxy == proxy }?.patchJSON
    }

    func apply(to yaml: String) throws -> String {
        guard !overrides.isEmpty else { return yaml }
        var document = try ConfigTransforms.ParsedDocument(yaml: yaml)
        try apply(to: &document.root)
        return try document.serialized()
    }

    func apply(to root: inout [String: Any]) throws {
        guard !overrides.isEmpty else { return }
         
         
         
         
         
         
         
         
         
        var proxies = (root["proxies"] as? [[String: Any]]) ?? []

        var indicesByName: [String: [Int]] = [:]
        for (index, proxy) in proxies.enumerated() {
            guard let name = proxy["name"] as? String, !name.isEmpty else { continue }
            indicesByName[name, default: []].append(index)
        }

        for override in overrides {
             
             
             
            guard let indices = indicesByName[override.proxy], !indices.isEmpty else {
                continue
            }
            guard indices.count == 1, let index = indices.first else {
                throw ProxyNodeOverrideError.duplicateProxyName(override.proxy)
            }
            guard let patch = try JSONSerialization.jsonObject(
                with: Data(override.patchJSON.utf8)
            ) as? [String: Any], patch["name"] == nil, patch["type"] == nil else {
                throw ProxyNodeOverrideError.invalidPatch(override.proxy)
            }
            proxies[index] = Self.merging(patch: patch, into: proxies[index])
        }

        root["proxies"] = proxies
    }

    private static func merging(
        patch: [String: Any],
        into original: [String: Any]
    ) -> [String: Any] {
        var result = original
        for (key, value) in patch {
            if value is NSNull {
                result.removeValue(forKey: key)
            } else if let nestedPatch = value as? [String: Any],
                      let nestedOriginal = result[key] as? [String: Any] {
                result[key] = merging(patch: nestedPatch, into: nestedOriginal)
            } else {
                result[key] = value
            }
        }
        return result
    }
}

enum ProfileProviderKind: String, Codable, CaseIterable, Hashable {
    case proxy
    case rule

    var configurationKey: String {
        switch self {
        case .proxy: return "proxy-providers"
        case .rule: return "rule-providers"
        }
    }
}

enum ProfileProviderTransport: String, Codable, CaseIterable {
    case http
    case file
    case inline
}

 
 
 
 
 
 
struct ProfileProviderDefinitionMutation: Codable, Equatable, Identifiable {
    var name: String
    var definitionJSON: String?

    var id: String { name }
}

 
 
 
 
 
 
enum CustomNodesGroupMaterializer {
    static let groupName = "Custom Nodes"
    static let providerName = "hako-custom"

     
     
     
     
     
     
     
     
     
     
    static func projectForUI(
        sourceYAML: String?,
        profile: Profile,
        replacingSourceGroups: Bool = false
    ) -> String? {
        guard let sourceYAML else { return nil }
        let withProviders = (try? (profile.providerDefinitions
            ?? ProfileProviderDefinitionSpec()).apply(to: sourceYAML)) ?? sourceYAML
        let replaced = replacingSourceGroups
            ? (try? withoutSourceGroups(withProviders)) ?? withProviders
            : withProviders
        let materialized = (try? apply(to: replaced)) ?? replaced
         
         
         
         
        let nodeEdited = (try? (profile.proxyNodeOverrides ?? ProxyNodeOverrideSpec())
            .apply(to: materialized)) ?? materialized
         
         
         
         
         
         
         
        return (try? (profile.proxyChain ?? ProxyChainSpec())
            .apply(to: nodeEdited)) ?? nodeEdited
    }

    private static func withoutSourceGroups(_ yaml: String) throws -> String {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else { return yaml }
        root["proxy-groups"] = [[String: Any]]()
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    static func apply(to yaml: String) throws -> String {
        guard var root = ConfigTransforms.parsedRoot(forYAML: yaml)?.root else {
            _ = try ConfigTransforms.yamlToJSON(yaml)
            return yaml
        }
        let before = root
        try apply(to: &root)
         
         
         
        guard !NSDictionary(dictionary: before).isEqual(to: root) else { return yaml }
        var document = ConfigTransforms.ParsedDocument(root: root)
        return try document.serialized()
    }

     
     
    @discardableResult
    static func applyReportingChange(to root: inout [String: Any]) throws -> Bool {
        let before = root
        try apply(to: &root)
        return !NSDictionary(dictionary: before).isEqual(to: root)
    }

    static func apply(to root: inout [String: Any]) throws {
        guard var providers = root["proxy-providers"] as? [String: Any],
              let definition = providers[providerName] as? [String: Any],
              (definition["type"] as? String) == "inline",
              let payload = definition["payload"] as? [[String: Any]],
              !payload.isEmpty else { return }

        var proxies = (root["proxies"] as? [[String: Any]]) ?? []
        var taken = Set(proxies.compactMap { $0["name"] as? String })
         
         
         
         
         
        var renamed: [String: String] = [:]
        var members: [String] = []
        for var node in payload {
            let original = ((node["name"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !original.isEmpty else { continue }
            var name = original
            if taken.contains(name) {
                name = ProfileLabelPolicy.deduplicate(
                    original, existing: Array(taken)
                )
                renamed[original] = name
            }
            node["name"] = name
            if let dialer = (node["dialer-proxy"] as? String),
               let followed = renamed[dialer] {
                node["dialer-proxy"] = followed
            }
            taken.insert(name)
            members.append(name)
            proxies.append(node)
        }
        guard !members.isEmpty else { return }
        root["proxies"] = proxies

        providers.removeValue(forKey: providerName)
        if providers.isEmpty {
            root.removeValue(forKey: "proxy-providers")
        } else {
            root["proxy-providers"] = providers
        }

        var groups = (root["proxy-groups"] as? [[String: Any]]) ?? []
         
         
        var hosted = false
        for index in groups.indices {
            var uses = (groups[index]["use"] as? [Any])?
                .compactMap { $0 as? String } ?? []
            guard uses.contains(providerName) else { continue }
            uses.removeAll { $0 == providerName }
            var existing = (groups[index]["proxies"] as? [Any])?
                .compactMap { $0 as? String } ?? []
            existing.append(contentsOf: members.filter { !existing.contains($0) })
            groups[index]["proxies"] = existing
            if uses.isEmpty {
                groups[index].removeValue(forKey: "use")
            } else {
                groups[index]["use"] = uses
            }
            hosted = true
        }
        if let index = groups.firstIndex(where: {
            ($0["name"] as? String) == groupName
        }) {
            var existing = (groups[index]["proxies"] as? [Any])?
                .compactMap { $0 as? String } ?? []
            existing.append(contentsOf: members.filter { !existing.contains($0) })
            groups[index]["proxies"] = existing
            hosted = true
        }
        guard !hosted else {
            root["proxy-groups"] = groups
            return
        }

        groups.append([
            "name": groupName,
            "type": "select",
            "proxies": members,
        ])
         
         
         
         
         
         
         
         
         
         
         
         
        if let fallback = Self.finalMatchTarget(in: root),
           let index = groups.firstIndex(where: {
               ($0["name"] as? String) == fallback
                   && Self.isManualGroup($0)
           }) {
            var members = (groups[index]["proxies"] as? [Any])
                .map { $0.compactMap { $0 as? String } } ?? []
            if !members.contains(groupName) {
                members.append(groupName)
                groups[index]["proxies"] = members
            }
        }
        root["proxy-groups"] = groups
    }

     
     
     
     
    private static func finalMatchTarget(in root: [String: Any]) -> String? {
        guard let rules = root["rules"] as? [Any] else { return nil }
        return rules.lazy
            .reversed()
            .compactMap { entry -> String? in
                guard let line = entry as? String,
                      let parsed = StructuredRule.parse(line),
                      parsed.action == .match,
                      !parsed.target.isEmpty,
                      parsed.target != "MATCH" else { return nil }
                return parsed.target
            }
            .first
    }

    private static func isManualGroup(_ group: [String: Any]) -> Bool {
        let type = (group["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return type == "select" || type == "selector"
    }
}

struct ProfileProviderDefinitionSpec: Codable, Equatable {
    var proxyProviders: [ProfileProviderDefinitionMutation] = []
    var ruleProviders: [ProfileProviderDefinitionMutation] = []

    var isEmpty: Bool { proxyProviders.isEmpty && ruleProviders.isEmpty }

    mutating func setDefinition(
        _ definitionJSON: String,
        named name: String,
        kind: ProfileProviderKind
    ) throws {
        guard ProfileProviderDefinitionError.rejecting(name) == nil,
              let definition = try JSONSerialization.jsonObject(
                with: Data(definitionJSON.utf8)
              ) as? [String: Any],
              JSONSerialization.isValidJSONObject(definition) else {
            throw ProfileProviderDefinitionError.invalidDefinition
        }
        let canonical = try Self.canonicalJSON(definition)
        setMutation(.init(name: name, definitionJSON: canonical), kind: kind)
    }

    mutating func deleteDefinition(named name: String, kind: ProfileProviderKind) {
        guard ProfileProviderDefinitionError.rejecting(name) == nil else { return }
        setMutation(.init(name: name, definitionJSON: nil), kind: kind)
    }

    mutating func replaceMutations(
        _ mutations: [ProfileProviderDefinitionMutation],
        kind: ProfileProviderKind
    ) {
        let sorted = mutations.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        switch kind {
        case .proxy: proxyProviders = sorted
        case .rule: ruleProviders = sorted
        }
    }

    func apply(to yaml: String) throws -> String {
        guard !isEmpty else { return yaml }
        var document = try ConfigTransforms.ParsedDocument(yaml: yaml)
        try apply(to: &document.root)
        return try document.serialized()
    }

    func apply(to root: inout [String: Any]) throws {
        guard !isEmpty else { return }
        try Self.apply(proxyProviders, kind: .proxy, root: &root)
        try Self.apply(ruleProviders, kind: .rule, root: &root)
    }

    private mutating func setMutation(
        _ mutation: ProfileProviderDefinitionMutation,
        kind: ProfileProviderKind
    ) {
        var mutations = kind == .proxy ? proxyProviders : ruleProviders
        mutations.removeAll { $0.name == mutation.name }
        mutations.append(mutation)
        replaceMutations(mutations, kind: kind)
    }

    private static func apply(
        _ mutations: [ProfileProviderDefinitionMutation],
        kind: ProfileProviderKind,
        root: inout [String: Any]
    ) throws {
        guard !mutations.isEmpty else { return }
        var providers = root[kind.configurationKey] as? [String: Any] ?? [:]
        for mutation in mutations {
            if let rejection = ProfileProviderDefinitionError.rejecting(mutation.name) {
                throw rejection
            }
            guard let definitionJSON = mutation.definitionJSON else {
                providers.removeValue(forKey: mutation.name)
                continue
            }
            guard let definition = try JSONSerialization.jsonObject(
                with: Data(definitionJSON.utf8)
            ) as? [String: Any] else {
                throw ProfileProviderDefinitionError.invalidDefinition
            }
            providers[mutation.name] = definition
        }
        if providers.isEmpty {
            root.removeValue(forKey: kind.configurationKey)
        } else {
            root[kind.configurationKey] = providers
        }
    }

    private static func canonicalJSON(_ value: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

struct ProviderDefinitionCredentialReference: Codable, Equatable, Hashable, Identifiable {
    enum ValueKind: String, Codable, Hashable {
        case headers
        case ageSecretKey
        case inlineProxyField
    }

    let providerKind: ProfileProviderKind
    let provider: String
    let valueKind: ValueKind
    let proxy: String?
    let fieldPath: [String]
    let key: String

    var id: String { key }
}

struct Profile: Codable, Identifiable, Equatable {
    enum OverwriteMode: String, Codable, CaseIterable, Identifiable {
        case standard
        case script
        case custom

        var id: String { rawValue }
    }
    enum OutboundMode: String, Codable, CaseIterable, Identifiable {
        case global
        case rule
        case direct

        var id: String { rawValue }
    }
    enum Source: Codable, Equatable {
        case url(String)
        case file(String)    
        case clipboard
    }

    let id: String
    var label: String
     
     
     
     
     
     
     
     
     
     
    var labelIsUserAssigned: Bool? = nil
    var source: Source
    var autoUpdate: Bool
    var updateIntervalHours: Int
    var subscriptionInfo: SubscriptionInfo?
    var selectedMap: [String: String]
     
     
    var currentGroupName: String? = nil
    var unfoldedGroups: Set<String>? = nil
     
     
     
     
    var udpFallbackPolicy: UDPFallbackPolicy? = nil
    var override: OverrideSpec = OverrideSpec()
    var activeRevision: String?
    var order: Int
    var lastUpdatedAt: Date?    
    var subscriptionETag: String? = nil
    var subscriptionLastModified: String? = nil
     
     
     
     
    var suppressedUpdates: [SuppressedOverrideUpdate]? = nil
     
     
     
    var usesLocalSourceOverride: Bool? = nil
    var selectedScriptID: String? = nil
     
     
     
     
    var postMergeScriptID: String? = nil
    var overwriteMode: OverwriteMode? = nil
    var customOverwrite: CustomOverwriteSpec? = nil
     
     
    var proxyChain: ProxyChainSpec? = nil
     
     
    var proxyNodeOverrides: ProxyNodeOverrideSpec? = nil
     
     
     
     
    var providerDefinitions: ProfileProviderDefinitionSpec? = nil
     
     
     
     
    var providerDefinitionCredentials: [ProviderDefinitionCredentialReference]? = nil
     
     
     
    var legacyRelayMigrations: [LegacyRelayMigration]?
     
     
    var memoryTrim: MemoryTrimSpec? = nil
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var dnsBootstrapInsurance: Bool? = nil
     
     
    var proxyCredentials: [ProxyCredentialReference]? = nil
     
     
     
     
     
     
     
    var sourceCredentials: [ProxyCredentialReference]? = nil
     
     
     
     
     
     
     
    var sourceCredentialsRedacted: Bool? = nil
     
     
     
    var externalResources: [ProfileExternalResourceReference]? = nil
     
     
     
     
    var migratedGlobalOverride: OverrideSpec? = nil
     
     
    var outboundMode: OutboundMode? = nil
}

struct ProxyCredentialReference: Codable, Equatable, Hashable, Identifiable {
     
     
     
     
     
    var container: String?
     
     
    var itemIndex: Int?
    let proxy: String
    let fieldPath: [String]
    let key: String

    var id: String { key }
    var fieldLabel: String { fieldPath.joined(separator: ".") }
}

struct ProfileExternalResourceReference: Codable, Equatable, Hashable, Identifiable {
    let capabilityID: String
    let proxy: String
    let fieldPath: [String]
    let sourceValueSHA256: String
    let storageKey: String

    var id: String { storageKey }
}
