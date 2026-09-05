import Foundation

enum CustomOverwriteError: LocalizedError, Equatable {
    case removedRelay(group: String)
    case unsupportedGroupType(group: String, type: String)
    case missingMembers(group: String)
    case groupEmptyFallback(group: String, target: String)
    case invalidExpression(group: String, field: String)
    case unknownMember(group: String, member: String)
    case unknownProvider(group: String, provider: String)
    case unknownEmptyFallback(group: String, target: String)
    case duplicateGroupName(group: String)

    var errorDescription: String? {
        switch self {
        case .removedRelay(let group):
            return "Proxy group \"\(group)\" uses the removed relay type. Configure dialer-proxy on proxies instead."
        case .unsupportedGroupType(let group, let type):
            return "Proxy group \"\(group)\" uses unsupported type \"\(type)\"."
        case .missingMembers(let group):
            return "Proxy group \"\(group)\" has no members. Add a proxy, a provider, or one of the include options."
        case .groupEmptyFallback(let group, let target):
            return "Proxy group \"\(group)\" falls back to \"\(target)\", which is a group. Empty fallback must name a proxy."
        case .invalidExpression(let group, let field):
            return "Proxy group \"\(group)\" has a \(field) that is not a valid regular expression."
        case .unknownMember(let group, let member):
            return "Proxy group \"\(group)\" lists \"\(member)\", which does not exist in this profile."
        case .unknownProvider(let group, let provider):
            return "Proxy group \"\(group)\" uses provider \"\(provider)\", which does not exist in this profile."
        case .unknownEmptyFallback(let group, let target):
            return "Proxy group \"\(group)\" falls back to \"\(target)\", which does not exist. Empty fallback must name a proxy."
        case .duplicateGroupName(let group):
            return "The name \"\(group)\" is already taken in this profile. Proxies, groups and the built-in outbounds share one namespace."
        }
    }
}

struct CustomProxyGroup: Codable, Equatable, Identifiable {
    var name: String
    var type: String
    var proxies: [String] = []
    var providers: [String] = []
    var interval: Int?
     
     
    var lazy: Bool = true
    var disableUDP: Bool = false
    var url: String?
    var timeout: Int?
    var maxFailedTimes: Int?
    var emptyFallback: String?
    var filter: String?
    var excludeFilter: String?
    var excludeType: String?
    var expectedStatus: String?
    var includeAll: Bool?
    var includeAllProxies: Bool = false
    var includeAllProviders: Bool = false
    var defaultSelected: String?
    var tolerance: Int?
    var strategy: String?
    var hidden: Bool = false
    var icon: String?

     
     
    var explicitKeys: Set<String>?

     
     
    var unknownFields: [String: CustomJSONValue]?

    var id: String { name }

    static let types = ["select", "url-test", "fallback", "load-balance"]

    private static let knownKeys: Set<String> = [
        "name", "type", "proxies", "use", "url", "interval", "timeout",
        "max-failed-times", "empty-fallback", "lazy", "disable-udp",
        "filter", "exclude-filter", "exclude-type", "expected-status",
        "include-all", "include-all-proxies", "include-all-providers",
        "default-selected", "tolerance", "strategy", "hidden", "icon",
    ]

    init(name: String, type: String = "select") {
        self.name = name
        self.type = type
    }

    init(json: [String: Any]) {
        name = json["name"] as? String ?? ""
        let rawType = json["type"] as? String ?? "select"
        type = rawType
        proxies = json["proxies"] as? [String] ?? []
        providers = json["use"] as? [String] ?? []
        interval = Self.int(json["interval"])
        lazy = json["lazy"] as? Bool ?? true
        disableUDP = json["disable-udp"] as? Bool ?? false
        url = json["url"] as? String
        timeout = Self.int(json["timeout"])
        maxFailedTimes = Self.int(json["max-failed-times"])
        emptyFallback = json["empty-fallback"] as? String
        filter = json["filter"] as? String
        excludeFilter = json["exclude-filter"] as? String
        excludeType = json["exclude-type"] as? String
        expectedStatus = json["expected-status"] as? String
        includeAll = json["include-all"] as? Bool
        includeAllProxies = json["include-all-proxies"] as? Bool ?? false
        includeAllProviders = json["include-all-providers"] as? Bool ?? false
        defaultSelected = json["default-selected"] as? String
        tolerance = Self.int(json["tolerance"])
        strategy = json["strategy"] as? String
        hidden = json["hidden"] as? Bool ?? false
        icon = json["icon"] as? String
        explicitKeys = Set(json.keys).intersection(Self.knownKeys)
        let unknown = json.reduce(into: [String: CustomJSONValue]()) { result, item in
            guard !Self.knownKeys.contains(item.key),
                  let value = CustomJSONValue(any: item.value) else { return }
            result[item.key] = value
        }
        unknownFields = unknown.isEmpty ? nil : unknown
    }

    var validationError: CustomOverwriteError? {
        validationError(knownGroupNames: [])
    }

     
     
     
     
    struct ValidationContext {
        var nodeNames: Set<String>
        var groupNames: Set<String>
        var providerNames: Set<String>
        var siblingGroupNames: Set<String>
    }

    func validationError(
        context: ValidationContext
    ) -> CustomOverwriteError? {
        if let shape = validationError(
            knownGroupNames: context.groupNames
                .union(context.siblingGroupNames)
        ) {
            return shape
        }
        let builtins: Set<String> = [
            "COMPATIBLE", "DIRECT", "REJECT", "REJECT-DROP", "PASS", "PASS-RULE",
        ]
         
         
         
         
         
         
        let taken = builtins
            .union(context.nodeNames)
            .union(context.siblingGroupNames)
        if taken.contains(name) {
            return .duplicateGroupName(group: name)
        }
         
         
         
         
         
         
        let sweepsProxies = includeAll == true || includeAllProxies
        let sweepsProviders = (includeAll == true || includeAllProviders)
            && !context.providerNames.isEmpty
        if proxies.isEmpty, providers.isEmpty,
           !sweepsProxies, !sweepsProviders {
            return .missingMembers(group: name)
        }
         
         
         
         
        let resolvableMembers = context.nodeNames
            .union(context.groupNames)
            .union(context.siblingGroupNames)
            .union(builtins)
        for member in proxies
        where !resolvableMembers.contains(member) || member == name {
            return .unknownMember(group: name, member: member)
        }
        for provider in providers
        where !context.providerNames.contains(provider) {
            return .unknownProvider(group: name, provider: provider)
        }
         
         
         
        if let emptyFallback, !emptyFallback.isEmpty,
           !context.nodeNames.contains(emptyFallback),
           !builtins.contains(emptyFallback) {
            return .unknownEmptyFallback(group: name, target: emptyFallback)
        }
        return nil
    }

     
     
     
     
     
     
     
     
     
    func validationError(
        knownGroupNames: Set<String>
    ) -> CustomOverwriteError? {
        if type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "relay" {
            return .removedRelay(group: name)
        }
        guard Self.types.contains(type) else {
            return .unsupportedGroupType(group: name, type: type)
        }
         
         
         
         
        if proxies.isEmpty, providers.isEmpty,
           includeAll != true, !includeAllProxies, !includeAllProviders {
            return .missingMembers(group: name)
        }
         
         
        if let emptyFallback,
           !emptyFallback.isEmpty,
           emptyFallback == name || knownGroupNames.contains(emptyFallback) {
            return .groupEmptyFallback(group: name, target: emptyFallback)
        }
         
         
         
        for (field, expression) in [
            ("filter", filter), ("exclude-filter", excludeFilter),
        ] {
            guard let expression, !expression.isEmpty else { continue }
            for piece in expression.split(
                separator: "`",
                omittingEmptySubsequences: false
            ) where (try? NSRegularExpression(pattern: String(piece))) == nil {
                return .invalidExpression(group: name, field: field)
            }
        }
        return nil
    }

    func validate() throws {
        if let validationError { throw validationError }
    }

    func validate(knownGroupNames: Set<String>) throws {
        if let error = validationError(knownGroupNames: knownGroupNames) {
            throw error
        }
    }

    var json: [String: Any] {
        var value = (unknownFields ?? [:]).mapValues(\.anyValue)
        value["name"] = name
        value["type"] = type
        if !proxies.isEmpty || wasExplicit("proxies") { value["proxies"] = proxies }
        if !providers.isEmpty || wasExplicit("use") { value["use"] = providers }
        if let interval { value["interval"] = interval }
        if !lazy || wasExplicit("lazy") { value["lazy"] = lazy }
        if disableUDP || wasExplicit("disable-udp") { value["disable-udp"] = disableUDP }
        if let url { value["url"] = url }
        if let timeout { value["timeout"] = timeout }
        if let maxFailedTimes { value["max-failed-times"] = maxFailedTimes }
        if let emptyFallback { value["empty-fallback"] = emptyFallback }
        if let filter { value["filter"] = filter }
        if let excludeFilter { value["exclude-filter"] = excludeFilter }
        if let excludeType { value["exclude-type"] = excludeType }
        if let expectedStatus { value["expected-status"] = expectedStatus }
        if let includeAll { value["include-all"] = includeAll }
        if includeAllProxies || wasExplicit("include-all-proxies") {
            value["include-all-proxies"] = includeAllProxies
        }
        if includeAllProviders || wasExplicit("include-all-providers") {
            value["include-all-providers"] = includeAllProviders
        }
         
         
         
         
         
         
         
         
        if let defaultSelected, type == "select" { value["default-selected"] = defaultSelected }
        if let tolerance, type == "url-test" { value["tolerance"] = tolerance }
        if let strategy, type == "load-balance" { value["strategy"] = strategy }
        if hidden || wasExplicit("hidden") { value["hidden"] = hidden }
        if let icon { value["icon"] = icon }
        return value
    }

    private func wasExplicit(_ key: String) -> Bool {
        explicitKeys?.contains(key) == true
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }
}

 
 
indirect enum CustomJSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([CustomJSONValue])
    case object([String: CustomJSONValue])

    init?(any: Any) {
        switch any {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else if value.doubleValue.rounded(.towardZero) == value.doubleValue,
                      value.doubleValue >= Double(Int.min),
                      value.doubleValue <= Double(Int.max) {
                self = .integer(value.intValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as Int:
            self = .integer(value)
        case let value as Double:
            self = .number(value)
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            var result: [CustomJSONValue] = []
            for item in value {
                guard let encoded = CustomJSONValue(any: item) else { return nil }
                result.append(encoded)
            }
            self = .array(result)
        case let value as [String: Any]:
            var result: [String: CustomJSONValue] = [:]
            for (key, item) in value {
                guard let encoded = CustomJSONValue(any: item) else { return nil }
                result[key] = encoded
            }
            self = .object(result)
        default:
            return nil
        }
    }

    var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return value
        case .integer(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let values): return values.map(\.anyValue)
        case .object(let values): return values.mapValues(\.anyValue)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([CustomJSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: CustomJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

struct CustomOverwriteSpec: Codable, Equatable {
    var proxyGroups: [CustomProxyGroup] = []
    var rules: [String] = []

     
     
     
     
     
     
     
     
     
     
     
     
    mutating func renameProxyGroup(from oldName: String, to newName: String) {
         
         
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, newName != oldName,
              proxyGroups.contains(where: { $0.name == oldName }),
              !proxyGroups.contains(where: { $0.name == newName })
        else { return }

        proxyGroups = proxyGroups.map { group in
            var group = group
            if group.name == oldName { group.name = newName }
            group.proxies = group.proxies.map { $0 == oldName ? newName : $0 }
            return group
        }
        rules = rules.map { rule in
             
             
             
            guard var parsed = StructuredRule.parse(rule),
                  parsed.target == oldName else { return rule }
            parsed.target = newName
            return parsed.rawValue
        }
    }

    static func parse(sourceYAML: String) throws -> CustomOverwriteSpec {
        let json = try ConfigTransforms.yamlToJSON(sourceYAML)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        let groups = (root["proxy-groups"] as? [[String: Any]] ?? [])
            .map(CustomProxyGroup.init(json:))
            .filter { !$0.name.isEmpty }
        let rules = root["rules"] as? [String] ?? []
        let spec = CustomOverwriteSpec(proxyGroups: groups, rules: rules)
        try spec.validate()
        return spec
    }

     
     
     
    func apply(to sourceYAML: String) throws -> String {
        try apply(to: sourceYAML, allowingLegacyRelayForFinalMigration: false)
    }

     
     
     
     
    func applyForFinalRuntimeMigration(to sourceYAML: String) throws -> String {
        try apply(to: sourceYAML, allowingLegacyRelayForFinalMigration: true)
    }

    private func apply(
        to sourceYAML: String,
        allowingLegacyRelayForFinalMigration: Bool
    ) throws -> String {
        try validate(
            allowingLegacyRelayForFinalMigration: allowingLegacyRelayForFinalMigration
        )
        let json = try ConfigTransforms.yamlToJSON(sourceYAML)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
         
         
         
         
         
         
         
        if !proxyGroups.isEmpty {
            root["proxy-groups"] = proxyGroups.map(\.json)
        }
        if !rules.isEmpty {
            root["rules"] = rules
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

    func validate() throws {
        try validate(allowingLegacyRelayForFinalMigration: false)
    }

    private func validate(allowingLegacyRelayForFinalMigration: Bool) throws {
        try proxyGroups.forEach { group in
            let normalizedType = group.type
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if allowingLegacyRelayForFinalMigration && normalizedType == "relay" {
                return
            }
            try group.validate()
        }
    }

    var patchJSON: String {
        let object: [String: Any] = [
            "proxy-groups": proxyGroups.map(\.json),
            "rules": rules,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}


 
enum CustomGroupSavePolicy {
     
     
     
    static func normalizedName(_ typed: String) -> String? {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : typed
    }
}

 
typealias CustomGroupValidationContext = CustomProxyGroup.ValidationContext
