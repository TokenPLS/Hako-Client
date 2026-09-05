import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ConfiguredProxyOrder: Equatable, Sendable {
     
    let groupNames: [String]
     
    let nodeNames: [String]
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    let providerNames: [String]

    private let groupIndices: [String: Int]
    private let nodeIndices: [String: Int]
    private let providerIndices: [String: Int]

    init(groupNames: [String] = [], nodeNames: [String] = [], providerNames: [String] = []) {
        self.groupNames = groupNames
        self.nodeNames = nodeNames
        self.providerNames = providerNames
         
         
        var groups: [String: Int] = [:]
        for (index, name) in groupNames.enumerated() where groups[name] == nil {
            groups[name] = index
        }
        var nodes: [String: Int] = [:]
        for (index, name) in nodeNames.enumerated() where nodes[name] == nil {
            nodes[name] = index
        }
        var providers: [String: Int] = [:]
        for (index, name) in providerNames.enumerated() where providers[name] == nil {
            providers[name] = index
        }
        groupIndices = groups
        nodeIndices = nodes
        providerIndices = providers
    }

    static let none = ConfiguredProxyOrder()

    var isEmpty: Bool { groupNames.isEmpty && nodeNames.isEmpty && providerNames.isEmpty }

     
    func groupIndex(of name: String) -> Int? { groupIndices[name] }
    func nodeIndex(of name: String) -> Int? { nodeIndices[name] }
    func providerIndex(of name: String) -> Int? { providerIndices[name] }

     
     
     
     
    static func read(yaml: String) -> ConfiguredProxyOrder {
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: yaml)
        else { return .none }
         
         
        return parsed.memo("proxies.configuredOrder") { read(parsed: parsed) }
    }

    private static func read(parsed: ConfigTransforms.ParsedConfiguration) -> ConfiguredProxyOrder {
        let root = parsed.root
        let json = parsed.json
        let groups = (root["proxy-groups"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String }
            .filter { !$0.isEmpty }
        let nodes = (root["proxies"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String }
            .filter { !$0.isEmpty }
        return ConfiguredProxyOrder(
            groupNames: groups,
            nodeNames: nodes,
            providerNames: providerNames(inJSON: json)
        )
    }

     
     
     
     
     
     
     
    static func sortedProviderNames(_ names: [String], inJSON json: String) -> [String] {
        ConfiguredProxyOrder(providerNames: providerNames(inJSON: json))
            .sortedProviders(names) { $0 }
    }

    private static func providerNames(inJSON json: String) -> [String] {
        guard case .object(let pairs)? = try? OrderedJSON.parse(json),
              let providers = pairs.first(where: { $0.key == "proxy-providers" })?.value,
              case .object(let entries) = providers
        else { return [] }
        return entries.map(\.key).filter { !$0.isEmpty }
    }

     
     
     
     
     
    func sorted<Element>(
        _ elements: [Element],
        by name: (Element) -> String,
        index: (ConfiguredProxyOrder, String) -> Int?
    ) -> [Element] {
        elements.sorted { lhs, rhs in
            let leftName = name(lhs)
            let rightName = name(rhs)
            let left = index(self, leftName) ?? Int.max
            let right = index(self, rightName) ?? Int.max
            if left != right { return left < right }
            return leftName.localizedStandardCompare(rightName) == .orderedAscending
        }
    }

    func sortedGroups<Element>(_ elements: [Element], by name: (Element) -> String) -> [Element] {
        sorted(elements, by: name) { $0.groupIndex(of: $1) }
    }

    func sortedNodes<Element>(_ elements: [Element], by name: (Element) -> String) -> [Element] {
        sorted(elements, by: name) { $0.nodeIndex(of: $1) }
    }

     
     
     
     
     
     
     
    func sortedNodes<Element>(
        _ elements: [Element],
        runtimeOrder: [String: Int],
        by name: (Element) -> String
    ) -> [Element] {
        let configured = nodeNames.count
        return elements.sorted { lhs, rhs in
            let leftName = name(lhs)
            let rightName = name(rhs)
            let left = nodeIndex(of: leftName)
                ?? runtimeOrder[leftName].map { configured + $0 }
                ?? Int.max
            let right = nodeIndex(of: rightName)
                ?? runtimeOrder[rightName].map { configured + $0 }
                ?? Int.max
            if left != right { return left < right }
            return leftName.localizedStandardCompare(rightName) == .orderedAscending
        }
    }

    func sortedProviders<Element>(_ elements: [Element], by name: (Element) -> String) -> [Element] {
        sorted(elements, by: name) { $0.providerIndex(of: $1) }
    }
}
