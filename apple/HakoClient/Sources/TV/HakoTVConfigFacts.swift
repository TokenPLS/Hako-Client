import Foundation
import Hako

 
 
 
 
 
 
 
 
 
struct HakoTVConfigFacts: Equatable {
    let rules: [HakoRuleLineSnapshot]
    let dnsEnhancedMode: String
    let dnsNameservers: [String]
    let dnsFallback: [String]
    let dnsDefaultNameservers: [String]
     
    let proxyGroupNames: [String]
     
     
     
    let proxyGroups: [HakoProxyGroupSnapshot]
     
    let nodeCount: Int
     
    let mode: String

    enum ReadingError: LocalizedError {
        case notAnObject
        var errorDescription: String? { "The configuration did not read as a document." }
    }

    init(yaml: String) throws {
        var error: NSError?
        guard let box = HakoYamlToJSON(yaml, &error) else {
            throw error ?? ReadingError.notAnObject
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(box.value.utf8)) as? [String: Any] else {
            throw ReadingError.notAnObject
        }
        try self.init(root: root)
    }

    init(root: [String: Any]) throws {
        let rawRules = root["rules"] as? [Any] ?? []
        rules = rawRules.compactMap { Self.ruleLine(from: "\($0)") }
        let dns = root["dns"] as? [String: Any] ?? [:]
        dnsEnhancedMode = dns["enhanced-mode"] as? String ?? ""
        dnsNameservers = Self.strings(dns["nameserver"])
        dnsFallback = Self.strings(dns["fallback"])
        dnsDefaultNameservers = Self.strings(dns["default-nameserver"])
        let declaredGroups = root["proxy-groups"] as? [[String: Any]] ?? []
         
         
         
         
         
        let rawGroups = declaredGroups.filter { $0["hidden"] as? Bool != true }
         
         
         
         
         
        proxyGroupNames = rawGroups.compactMap { $0["name"] as? String }.filter { $0 != "GLOBAL" }
        let rawProxies = root["proxies"] as? [[String: Any]] ?? []
        nodeCount = rawProxies.count
        var typeByName: [String: String] = [:]
        for proxy in rawProxies {
            if let name = proxy["name"] as? String { typeByName[name] = proxy["type"] as? String ?? "" }
        }
        let groupNames = Set(declaredGroups.compactMap { $0["name"] as? String })
        for group in declaredGroups {
            if let name = group["name"] as? String { typeByName[name] = group["type"] as? String ?? "" }
        }
        let visible = rawGroups.compactMap { group -> HakoProxyGroupSnapshot? in
            guard let name = group["name"] as? String else { return nil }
            let members = Self.strings(group["proxies"]).map { member in
                HakoProxyMemberSnapshot(name: member, type: typeByName[member] ?? "", isGroup: groupNames.contains(member))
            }
            return HakoProxyGroupSnapshot(name: name, type: group["type"] as? String ?? "", members: members)
        }
         
         
         
        let authored = visible.filter { $0.name != "GLOBAL" }
        let global = visible.first { $0.name == "GLOBAL" }.map { [$0] } ?? Self.synthesizedGlobal(
            declaredGroupNames: declaredGroups.compactMap { $0["name"] as? String },
            proxies: rawProxies,
            typeByName: typeByName
        )
        proxyGroups = authored + global
        mode = (root["mode"] as? String)?.lowercased() ?? "rule"
    }

    private static func strings(_ value: Any?) -> [String] {
        (value as? [Any] ?? []).map { "\($0)" }
    }

     
     
     
     
     
     
     
     
     
     
    private static func synthesizedGlobal(
        declaredGroupNames: [String],
        proxies: [[String: Any]],
        typeByName: [String: String]
    ) -> [HakoProxyGroupSnapshot] {
        guard !declaredGroupNames.contains("GLOBAL") else { return [] }
        let builtIn = ["DIRECT", "REJECT"].map {
            HakoProxyMemberSnapshot(name: $0, type: $0.capitalized, isGroup: false)
        }
        let nodes = proxies.compactMap { proxy -> HakoProxyMemberSnapshot? in
            guard let name = proxy["name"] as? String else { return nil }
            return HakoProxyMemberSnapshot(name: name, type: proxy["type"] as? String ?? "", isGroup: false)
        }
        let groups = declaredGroupNames.map {
            HakoProxyMemberSnapshot(name: $0, type: typeByName[$0] ?? "", isGroup: true)
        }
        return [HakoProxyGroupSnapshot(name: "GLOBAL", type: "Selector", members: builtIn + nodes + groups)]
    }

     
     
     
     
     
    static func ruleLine(from raw: String) -> HakoRuleLineSnapshot? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        if let structured = HakoStructuredRule.parse(line) {
            return HakoRuleLineSnapshot(
                raw: line,
                type: structured.action.rawValue,
                payload: structured.content,
                target: structured.target
            )
        }
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let type = fields.first, !type.isEmpty else { return nil }
        if fields.count == 1 {
            return HakoRuleLineSnapshot(raw: line, type: type, payload: "", target: "")
        }
        if fields.count == 2 {
            return HakoRuleLineSnapshot(raw: line, type: type, payload: "", target: fields[1])
        }
        let flags: Set<String> = ["no-resolve", "src"]
        var trailing = Array(fields.dropFirst())
        while trailing.count > 2, let last = trailing.last, flags.contains(last.lowercased()) {
            trailing.removeLast()
        }
        let target = trailing.last ?? ""
        let payload = trailing.dropLast().joined(separator: ",")
        return HakoRuleLineSnapshot(raw: line, type: type, payload: payload, target: target)
    }
}
