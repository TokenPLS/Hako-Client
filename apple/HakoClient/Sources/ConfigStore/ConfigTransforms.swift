import Foundation
import Hako

 
 
struct RemoteResourcePlan: Decodable {
    struct Provider: Decodable {
        let name, kind, behavior, type, url, path, format: String
        let headers: [String: [String]]
        let proxy: String
         
        let resourceKey: String?
         
         
        let updateIntervalSeconds: Int64

        init(
            name: String,
            kind: String,
            behavior: String,
            type: String,
            url: String,
            path: String,
            format: String,
            headers: [String: [String]],
            proxy: String,
            resourceKey: String?,
            updateIntervalSeconds: Int64 = 0
        ) {
            self.name = name
            self.kind = kind
            self.behavior = behavior
            self.type = type
            self.url = url
            self.path = path
            self.format = format
            self.headers = headers
            self.proxy = proxy
            self.resourceKey = resourceKey
            self.updateIntervalSeconds = updateIntervalSeconds
        }

        private enum CodingKeys: String, CodingKey {
            case name, kind, behavior, type, url, path, format, headers, proxy, resourceKey
            case updateIntervalSeconds
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: .name)
            kind = try values.decode(String.self, forKey: .kind)
            behavior = try values.decode(String.self, forKey: .behavior)
            type = try values.decode(String.self, forKey: .type)
            url = try values.decode(String.self, forKey: .url)
            path = try values.decode(String.self, forKey: .path)
            format = try values.decode(String.self, forKey: .format)
            headers = try values.decode([String: [String]].self, forKey: .headers)
            proxy = try values.decode(String.self, forKey: .proxy)
            resourceKey = try values.decodeIfPresent(String.self, forKey: .resourceKey)
            updateIntervalSeconds = try values.decodeIfPresent(
                Int64.self,
                forKey: .updateIntervalSeconds
            ) ?? 0
        }
    }
    struct Geo: Decodable {
        let kind, url: String
    }
    struct Failure: Decodable {
        let field, reason: String
    }

    let providers: [Provider]
    let geodata: [Geo]
    let notices: [String]

     
     
     
     
     
     
     
     
    let structuredNotices: [StructuredNotice]?

     
     
     
    init(
        providers: [Provider] = [],
        geodata: [Geo] = [],
        notices: [String] = [],
        structuredNotices: [StructuredNotice]? = [],
        errors: [Failure] = []
    ) {
        self.providers = providers
        self.geodata = geodata
        self.notices = notices
        self.structuredNotices = structuredNotices
        self.errors = errors
    }

    struct StructuredNotice: Decodable {
        let kind: String
        let field: String?
        let value: String?
        let count: Int?
        let ruleKind: String?
         
         
        let text: String
    }
    let errors: [Failure]
}

enum ConfigTransformsError: LocalizedError {
    case bridgeReturnedNil(String)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .bridgeReturnedNil(let operation):
            return "The configuration operation \(operation) did not return a result."
        case .invalidConfiguration(let reason):
            return "The downloaded configuration is invalid: \(Self.readable(reason))"
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
    static func readable(_ reason: String) -> String {
        var text = reason
        let frames = ["hako", "parse config", "collect config deviations",
                      "finalize", "plan resources", "validate"]
        while let range = text.range(of: ": "), range.lowerBound != text.startIndex {
            let head = String(text[text.startIndex..<range.lowerBound])
            guard frames.contains(head.lowercased()) else { break }
            let rest = String(text[range.upperBound...])
             
             
             
            guard !rest.isEmpty, !frames.contains(rest.lowercased()) else { break }
            text = rest
        }
        return text
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
let hakoAppleRuntimeProfileName: String = {
#if os(macOS)
    "macosPacketTunnel"
#elseif os(tvOS)
    "tvosPacketTunnel"
#else
    "iosPacketTunnel"
#endif
}()

enum ConfigTransforms {

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func validateSource(_ yaml: String) throws {
        var error: NSError?
        guard HakoValidateConfigShape(yaml, &error) else {
            throw ConfigTransformsError.invalidConfiguration(
                error?.localizedDescription ?? "the core rejected the YAML"
            )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func invalidDomainSites(
        in yaml: String, runtimeProfile: String
    ) -> [InvalidDomainSite]? {
        var error: NSError?
        guard let box = HakoInvalidDomainPatternsJSON(yaml, runtimeProfile, &error),
            error == nil
        else { return nil }
        return InvalidDomainSite.sites(fromJSON: box.value ?? "")
    }

    static func mergeOverride(raw: String, overrideJSON: String) throws -> String {
        var error: NSError?
        guard let box = HakoMergeOverrideForIOS(raw, overrideJSON, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("MergeOverrideForIOS")
        }
        return box.value
    }

     
     
     
     
     
     
     
     
     
     
    static func configDeviationsJSON(configContent: String, targetProfile: String) throws -> String {
        var error: NSError?
        guard let box = HakoConfigDeviationsJSON(configContent, targetProfile, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("ConfigDeviationsJSON")
        }
        return box.value
    }

     
     
     
     
     
     
     
     
     
     
    static func planResources(
        mergedYAML: String,
        targetProfile: String = hakoAppleRuntimeProfileName
    ) throws -> RemoteResourcePlan {
        var error: NSError?
        guard let box = HakoPlanResourcesForProfile(mergedYAML, targetProfile, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("PlanResourcesForProfile")
        }
        return try JSONDecoder().decode(RemoteResourcePlan.self, from: Data(box.value.utf8))
    }

    static func finalize(
        mergedYAML: String,
        providerPaths: [String: String],
        providerReadPaths: [String: String]? = nil
    ) throws -> String {
        var payload: [String: [String: String]] = ["providerPaths": providerPaths]
        if let providerReadPaths {
            payload["providerReadPaths"] = providerReadPaths
        }
        let map = try JSONEncoder().encode(payload)
        var error: NSError?
        guard let mapJSON = String(data: map, encoding: .utf8),
              let box = HakoFinalizeForIOS(mergedYAML, mapJSON, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("FinalizeForIOS")
        }
        return box.value
    }

     
     
     
     
     
     
     
     
     
    static let maximumConfigurationDepth = 60

     
     
    static func jsonNestingDepth(_ json: String) -> Int {
        var depth = 0, deepest = 0
        var inString = false, escaped = false
        for byte in json.utf8 {
            if escaped { escaped = false; continue }
            switch byte {
            case UInt8(ascii: "\\"): if inString { escaped = true }
            case UInt8(ascii: "\""): inString.toggle()
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                if !inString { depth += 1; deepest = max(deepest, depth) }
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                if !inString { depth -= 1 }
            default: break
            }
        }
        return deepest
    }

     
     
     
     
     
     
     
     
     
     
     
    static func parsedRoot(forYAML yaml: String) -> ParsedConfiguration? {
        ParsedConfigurationCache.shared.parsed(for: yaml)
    }

    struct ParsedConfiguration {
         
         
        let json: String
         
         
        let root: [String: Any]
         
         
         
        let derivations = ParsedConfigurationDerivations()

         
         
         
         
         
        func memo<T>(_ key: String, _ compute: () -> T) -> T {
            derivations.value(for: key, compute)
        }
    }

    static func yamlToJSON(
        _ yaml: String,
        caller: StaticString = #fileID,
        line: UInt = #line
    ) throws -> String {



        var error: NSError?
        guard let box = HakoYamlToJSON(yaml, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("YamlToJSON")
        }
         
         
         
         
         
         
         
        var json = box.value
        json.makeContiguousUTF8()
        let depth = jsonNestingDepth(json)
        if depth > Self.maximumConfigurationDepth {
            throw ConfigTransformsError.invalidConfiguration(
                "it nests \(depth) levels deep; \(Self.maximumConfigurationDepth) is the most a configuration can mean"
            )
        }
        return json
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    struct ParsedDocument {
        var root: [String: Any]
         
         
         
         
         
         
         
         
         
         
         
         
        private let writtenOrder: OrderedJSON?

        init(root: [String: Any]) {
            self.root = root
            self.writtenOrder = nil
        }

        init(yaml: String) throws {
            let json = try ConfigTransforms.yamlToJSON(yaml)
            guard let root = try JSONSerialization
                .jsonObject(with: Data(json.utf8)) as? [String: Any] else {
                throw ConfigTransformsError.invalidConfiguration(
                    "the configuration's root is not a mapping"
                )
            }
            self.root = root
            self.writtenOrder = try? OrderedJSON.parse(json)
        }

         
         
         
         
        func serialized() throws -> String {
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.sortedKeys]
            )
            let sorted = String(decoding: data, as: UTF8.self)
             
             
             
             
            guard let writtenOrder,
                  let tree = try? OrderedJSON.parse(sorted) else {
                return try ConfigTransforms.jsonToYAML(sorted)
            }
            let restored = tree.reorderingMappings(following: writtenOrder)
            return try ConfigTransforms.jsonToYAML(restored.serialized())
        }
    }

     
     
    static func jsonToYAML(
        _ json: String,
        caller: StaticString = #fileID,
        line: UInt = #line
    ) throws -> String {



        var error: NSError?
        guard let box = HakoJSONToYaml(json, &error) else {
            throw error ?? ConfigTransformsError.bridgeReturnedNil("JSONToYaml")
        }
        return box.value
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let dnsBootstrapFallbacks = ["223.5.5.5", "119.29.29.29"]

    static func applyDNSBootstrapInsurance(_ yaml: String) throws -> String {
        let json = try yamlToJSON(yaml)
        var root = try OrderedJSON.parse(json)
        guard case .object = root,
              case var .object(dns)? = root.topLevelValue("dns")
        else { return yaml }
        func appended(_ list: OrderedJSON?) -> OrderedJSON {
            var items: [OrderedJSON]
            if case let .array(existing)? = list { items = existing }
            else { items = [] }
            for ip in dnsBootstrapFallbacks
                where !items.contains(.string(ip)) && !items.contains(.scalar(ip))
            {
                items.append(.string(ip))
            }
            return .array(items)
        }
        for key in ["proxy-server-nameserver", "default-nameserver"] {
            let value = appended(
                dns.first(where: { $0.key == key })?.value
            )
            if let index = dns.firstIndex(where: { $0.key == key }) {
                dns[index] = (key: key, value: value)
            } else {
                dns.append((key: key, value: value))
            }
        }
        root = root.settingTopLevel("dns", to: .object(dns))
        return try jsonToYAML(root.serialized())
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func restoringMappingOrder(of transformed: String, following source: String) -> String {
        guard transformed != source,
              let sourceJSON = try? yamlToJSON(source),
              let transformedJSON = try? yamlToJSON(transformed),
              let sourceTree = try? OrderedJSON.parse(sourceJSON),
              let transformedTree = try? OrderedJSON.parse(transformedJSON)
        else { return transformed }
        let restored = transformedTree.reorderingMappings(following: sourceTree)
        guard restored != transformedTree,
              let yaml = try? jsonToYAML(restored.serialized())
        else { return transformed }
        return yaml
    }

    static func applyClientRuntimePolicy(
        _ yaml: String,
        udpFallback: UDPFallbackPolicy
    ) throws -> String {
        var root = try clientRuntimeRootBeforeUDPFallbackGuard(yaml)
        try appendUDPFallbackGuard(udpFallback, to: &root)
        return try jsonToYAML(root.serialized())
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    struct UDPFallbackGuardInput: Equatable {
        var rules: [String]
        var subRules: [String: [String]]
    }

    static func udpFallbackGuardInput(_ yaml: String) throws -> UDPFallbackGuardInput {
        let root = try clientRuntimeRootBeforeUDPFallbackGuard(yaml)
        var input = UDPFallbackGuardInput(rules: [], subRules: [:])
        if case let .array(rules)? = root.topLevelValue("rules") {
            input.rules = ruleTexts(rules)
        }
        if case let .object(lists)? = root.topLevelValue("sub-rules") {
            for entry in lists {
                if case let .array(list) = entry.value {
                    input.subRules[entry.key] = ruleTexts(list)
                }
            }
        }
        return input
    }

     
     
     
     
    private static func clientRuntimeRootBeforeUDPFallbackGuard(
        _ yaml: String
    ) throws -> OrderedJSON {
        let json = try yamlToJSON(yaml)
         
         
         
         
         
         
         
         
         
         
         
        var root = try OrderedJSON.parse(json)
        guard case .object = root else {
            throw ConfigTransformsError.invalidConfiguration(
                "the runtime configuration root must be an object"
            )
        }

#if !os(macOS)
         
         
         
         
         
         
        root = root.settingTopLevel("find-process-mode", to: .string("off"))
#endif
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let dnsSection = root.topLevelValue("dns")
        let dnsEnabled = dnsSection?.topLevelValue("enable") == .scalar("true")
        if !dnsEnabled,
           case let .object(fields)? = dnsSection,
           fields.contains(where: { $0.key == "nameserver" }) {
            var updated = fields.filter { $0.key != "enable" }
            updated.insert((key: "enable", value: .scalar("true")), at: 0)
            root = root.settingTopLevel("dns", to: .object(updated))
        }

         
         
         
         
         
         
         
        for key in iosUnsupportedTopLevelKeys {
            root = root.removingTopLevel(key)
        }

        return root
    }

     
     
    private static func appendUDPFallbackGuard(
        _ udpFallback: UDPFallbackPolicy,
        to root: inout OrderedJSON
    ) throws {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if case let .array(existingRules)? = root.topLevelValue("rules"),
           let guarded = Self.appendingUDPFallback(
               udpFallback, to: existingRules
           ) {
            root = root.settingTopLevel("rules", to: .array(guarded))
        }

         
         
         
         
         
         
         
        if case let .object(lists)? = root.topLevelValue("sub-rules") {
            var updated = lists
            for (offset, entry) in lists.enumerated() {
                guard case let .array(subRules) = entry.value,
                      let guarded = Self.appendingUDPFallback(
                          udpFallback, to: subRules
                      )
                else { continue }
                updated[offset] = (key: entry.key, value: .array(guarded))
            }
            root = root.settingTopLevel("sub-rules", to: .object(updated))
        }
    }

     
     
    private static func appendingUDPFallback(
        _ policy: UDPFallbackPolicy,
        to rules: [OrderedJSON]
    ) -> [OrderedJSON]? {
        guard let rule = UDPFallbackGuard.ruleToInject(
            policy: policy, existingRules: ruleTexts(rules)
        ) else { return nil }
        return rules + [.string(rule)]
    }

     
     
    private static func ruleTexts(_ rules: [OrderedJSON]) -> [String] {
        rules.compactMap { item -> String? in
            if case let .string(text) = item { return text }
            return nil
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let iosUnsupportedTopLevelKeys: Set<String> = [
         
         
         
         
         
        "redir-port", "tproxy-port",
         
         
         
        "external-controller-pipe",
    ]

}

 
 
 
 
 
final class ParsedConfigurationDerivations: @unchecked Sendable {
    private let condition = NSCondition()
    private var values: [String: Any] = [:]
    private var inFlight: Set<String> = []

    func value<T>(for key: String, _ compute: () -> T) -> T {
        condition.lock()
        while true {
            if let known = values[key] as? T {
                condition.unlock()
                return known
            }
            if !inFlight.contains(key) { break }
            condition.wait()
        }
        inFlight.insert(key)
        condition.unlock()

        let computed = compute()

        condition.lock()
        inFlight.remove(key)
        let result: T
        if let known = values[key] as? T {
            result = known
        } else {
            values[key] = computed
            result = computed
        }
        condition.broadcast()
        condition.unlock()
        return result
    }
}

 
 
 
 
final class ParsedConfigurationCache: @unchecked Sendable {
    static let shared = ParsedConfigurationCache()

    private let lock = NSLock()
    private var slots: [(yaml: String, parsed: ConfigTransforms.ParsedConfiguration)] = []
    private var parseCount = 0
    private let capacity = 2

    func parsed(for yaml: String) -> ConfigTransforms.ParsedConfiguration? {
        lock.lock()
        if let index = slots.firstIndex(where: { $0.yaml == yaml }) {
            let hit = slots.remove(at: index)
            slots.append(hit)
            lock.unlock()
            return hit.parsed
        }
        lock.unlock()
         
         
         
        guard let json = try? ConfigTransforms.yamlToJSON(yaml),
              let root = try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
              ) as? [String: Any]
        else { return nil }
        let parsed = ConfigTransforms.ParsedConfiguration(json: json, root: root)
        lock.lock()
        parseCount += 1
        slots.removeAll { $0.yaml == yaml }
        slots.append((yaml, parsed))
        if slots.count > capacity {
            slots.removeFirst(slots.count - capacity)
        }
        lock.unlock()
        return parsed
    }

     
    var parses: Int {
        lock.lock(); defer { lock.unlock() }
        return parseCount
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        slots.removeAll()
        parseCount = 0
    }
}


