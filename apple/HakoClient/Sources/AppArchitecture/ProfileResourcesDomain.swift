import Combine
import Foundation

enum ProfileResourceSummaryError: LocalizedError, Equatable {
    case sourceUnavailable
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return "This profile’s saved configuration is unavailable. Sync or import it again before reviewing resources."
        case .invalidConfiguration:
            return "Resources could not be read from this profile. The previous configuration remains unchanged."
        }
    }
}

enum ProfileProviderDefinitionError: LocalizedError, Equatable {
    case invalidConfiguration
    case missingName
    case duplicateName
    case missingDefinition
    case invalidDefinition
    case invalidTransport
    case missingURL
    case invalidURL
    case missingManagedFile
    case invalidPayload
    case invalidInterval
    case invalidSizeLimit
    case invalidHeader
    case credentialStorageUnavailable
    case invalidBehavior
    case invalidFormat
    case profileChanged
     
     
     
     
     
     
     
     
     
    case buildRefused(String)

    var errorDescription: String? {
        switch self {
        case let .buildRefused(reason):
            return reason
        case .invalidConfiguration:
            return "Provider definitions could not be read from this profile."
        case .missingName:
            return "Enter a name for this provider."
        case .duplicateName:
            return "A provider with this name already exists."
        case .missingDefinition:
            return "This provider no longer exists. Reopen the editor and try again."
        case .invalidDefinition:
            return "The provider definition is not a valid object."
        case .invalidTransport:
            return "Choose HTTP, File, or Inline as the provider source."
        case .missingURL:
            return "Enter a URL for this provider."
        case .invalidURL:
            return "Enter a URL that starts with http:// or https:// and includes a host."
        case .missingManagedFile:
            return "Choose a managed local file for this provider."
        case .invalidPayload:
            return "The inline provider content does not match its provider type."
        case .invalidInterval:
            return "The update interval must be zero or a positive number of seconds."
        case .invalidSizeLimit:
            return "The download limit must be zero or a positive number of bytes."
        case .invalidHeader:
            return "HTTP headers must use non-empty names and string values."
        case .credentialStorageUnavailable:
            return "Provider credentials could not be saved securely. The previous configuration remains unchanged."
        case .invalidBehavior:
            return "Choose Classical, Domain, or IP CIDR for this rule set."
        case .invalidFormat:
            return "The selected rule-set format is not valid for this behavior."
        case .profileChanged:
            return "This profile changed while the provider editor was open. Reopen it before saving."
        }
    }
}

extension ProfileProviderDefinitionError {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func rejecting(_ value: String) -> ProfileProviderDefinitionError? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .missingName : nil
    }
}

enum ProfileProviderFieldCatalog {
    static let proxyTopLevelKeys = [
        "type", "path", "url", "proxy", "interval", "filter", "exclude-filter",
        "exclude-type", "size-limit", "payload", "age-secret-key",
        "header", "health-check", "override",
    ]
    static let ruleTopLevelKeys = [
        "type", "behavior", "path", "url", "proxy", "format", "interval",
        "size-limit", "payload", "header", "path-in-bundle",
    ]
    static let proxyHealthCheckKeys = [
        "enable", "url", "interval", "timeout", "lazy", "expected-status",
    ]
    static let proxyOverrideKeys = [
        "tfo", "mptcp", "udp", "udp-over-tcp", "up", "down", "dialer-proxy",
        "skip-cert-verify", "name-cert-verify", "interface-name", "routing-mark",
        "ip-version", "additional-prefix", "additional-suffix", "proxy-name",
        "override-expr",
    ]
}

struct ProfileProviderDefinitionRecord: Identifiable, Equatable {
    let name: String
    var definitionJSON: String

    var id: String { name }
    var transport: ProfileProviderTransport {
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(definitionJSON.utf8)
        ) as? [String: Any],
              let raw = object["type"] as? String else { return .inline }
        return ProfileProviderTransport(rawValue: raw.lowercased()) ?? .inline
    }

    var mapping: [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(definitionJSON.utf8))
            as? [String: Any]) ?? [:]
    }
}

 
 
 
 
 
struct ProfileProviderDefinitionsDraft {
    let profileID: String
    private let baseline: [ProfileProviderKind: [String: String]]
    private var working: [ProfileProviderKind: [String: String]]
    private var managedFiles: [String: ExternalResourceImportFile] = [:]

     
     
     
     
     
     
     
    var hasUnsavedChanges: Bool {
        working != baseline || !managedFiles.isEmpty
    }

    init(
        profile: Profile,
        baselineYAML: String,
        effectiveYAML: String? = nil,
        yamlToJSON: (String) throws -> String = { try ConfigTransforms.yamlToJSON($0) }
    ) throws {
        profileID = profile.id
        baseline = try Self.catalogs(
            in: baselineYAML,
            yamlToJSON: yamlToJSON
        )
        if let effectiveYAML {
            working = try Self.catalogs(
                in: effectiveYAML,
                yamlToJSON: yamlToJSON
            )
        } else {
            working = try Self.applying(
                profile.providerDefinitions ?? ProfileProviderDefinitionSpec(),
                to: baseline
            )
        }
    }

    func records(kind: ProfileProviderKind) -> [ProfileProviderDefinitionRecord] {
        (working[kind] ?? [:]).map {
            ProfileProviderDefinitionRecord(name: $0.key, definitionJSON: $0.value)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    mutating func addDefinition(
        named name: String,
        kind: ProfileProviderKind,
        definitionJSON: String
    ) throws {
        try Self.validateName(name)
        guard working[kind]?[name] == nil else {
            throw ProfileProviderDefinitionError.duplicateName
        }
        let canonical = try Self.canonicalDefinitionJSON(definitionJSON, kind: kind)
        working[kind, default: [:]][name] = canonical
    }

    mutating func updateDefinition(
        named name: String,
        kind: ProfileProviderKind,
        definitionJSON: String
    ) throws {
        try Self.validateName(name)
        guard working[kind]?[name] != nil else {
            throw ProfileProviderDefinitionError.missingDefinition
        }
        working[kind, default: [:]][name] = try Self.canonicalDefinitionJSON(
            definitionJSON,
            kind: kind
        )
    }

    mutating func renameDefinition(
        named name: String,
        to newName: String,
        kind: ProfileProviderKind
    ) throws {
        try Self.validateName(newName)
        guard let definition = working[kind]?[name] else {
            throw ProfileProviderDefinitionError.missingDefinition
        }
        guard name == newName || working[kind]?[newName] == nil else {
            throw ProfileProviderDefinitionError.duplicateName
        }
        working[kind]?.removeValue(forKey: name)
        working[kind, default: [:]][newName] = definition
        if let file = managedFiles.removeValue(forKey: Self.fileKey(kind: kind, name: name)) {
            managedFiles[Self.fileKey(kind: kind, name: newName)] = file
        }
    }

     
     
     
     
    mutating func setPayloadDialer(
        provider: String,
        node: String,
        dialerProxy: String?
    ) throws {
        guard let definitionJSON = working[.proxy]?[provider],
              var definition = try JSONSerialization.jsonObject(
                with: Data(definitionJSON.utf8)
              ) as? [String: Any],
              var payload = definition["payload"] as? [[String: Any]],
              let index = payload.firstIndex(where: {
                  ($0["name"] as? String) == node
              }) else {
            throw ProfileProviderDefinitionError.missingDefinition
        }
        if let dialerProxy, !dialerProxy.isEmpty {
            payload[index]["dialer-proxy"] = dialerProxy
        } else {
            payload[index].removeValue(forKey: "dialer-proxy")
        }
        definition["payload"] = payload
        let json = String(
            decoding: try JSONSerialization.data(withJSONObject: definition),
            as: UTF8.self
        )
        try updateDefinition(named: provider, kind: .proxy, definitionJSON: json)
    }

    mutating func removeDefinition(named name: String, kind: ProfileProviderKind) throws {
        guard working[kind]?[name] != nil else {
            throw ProfileProviderDefinitionError.missingDefinition
        }
        working[kind]?.removeValue(forKey: name)
        managedFiles.removeValue(forKey: Self.fileKey(kind: kind, name: name))
    }

    mutating func setManagedFile(
        _ file: ExternalResourceImportFile?,
        for name: String,
        kind: ProfileProviderKind
    ) throws {
        try Self.validateName(name)
        guard let definitionJSON = working[kind]?[name] else {
            throw ProfileProviderDefinitionError.missingDefinition
        }
        let key = Self.fileKey(kind: kind, name: name)
        guard let file else {
            managedFiles.removeValue(forKey: key)
            return
        }
        let basename = file.fileName
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .last
            .map(String.init) ?? ""
         
         
         
         
        let format = (try? JSONSerialization.jsonObject(with: Data(definitionJSON.utf8)))
            .flatMap { ($0 as? [String: Any])?["format"] as? String }?
            .lowercased()
        let requiresUTF8Text = format != "mrs"
        guard !basename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !file.data.isEmpty,
              file.data.count <= ProfileExternalResourceImporter.maximumResourceBytes,
              !requiresUTF8Text || String(data: file.data, encoding: .utf8) != nil else {
            throw ProfileProviderDefinitionError.missingManagedFile
        }
        managedFiles[key] = ExternalResourceImportFile(fileName: basename, data: file.data)
    }

    func managedFile(
        for name: String,
        kind: ProfileProviderKind
    ) -> ExternalResourceImportFile? {
        managedFiles[Self.fileKey(kind: kind, name: name)]
    }

    func applying(to profile: Profile, currentBaselineYAML: String) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileProviderDefinitionError.profileChanged
        }
        let latest = try Self.catalogs(in: currentBaselineYAML)
        guard latest == baseline else {
            throw ProfileProviderDefinitionError.profileChanged
        }

        var spec = ProfileProviderDefinitionSpec()
        for kind in ProfileProviderKind.allCases {
            let source = baseline[kind] ?? [:]
            let edited = working[kind] ?? [:]
            var mutations: [ProfileProviderDefinitionMutation] = []
            for name in Set(source.keys).union(edited.keys) {
                if let definition = edited[name], source[name] != definition {
                    mutations.append(.init(name: name, definitionJSON: definition))
                } else if source[name] != nil, edited[name] == nil {
                    mutations.append(.init(name: name, definitionJSON: nil))
                }
            }
            spec.replaceMutations(mutations, kind: kind)
        }
        var updated = profile
        updated.providerDefinitions = spec.isEmpty ? nil : spec
        return updated
    }

     
     
     
     
     
    static func catalogs(
        in yaml: String,
        yamlToJSON: (String) throws -> String = { try ConfigTransforms.yamlToJSON($0) }
    ) throws -> [ProfileProviderKind: [String: String]] {
        let json = try yamlToJSON(yaml)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileProviderDefinitionError.buildRefused(
                HakoCopy.string(
                    "The configuration's top level is not a set of settings.",
                    locale: .current
                )
            )
        }
        var catalogs: [ProfileProviderKind: [String: String]] = [:]
        for kind in ProfileProviderKind.allCases {
            catalogs[kind] = try catalog(in: root, kind: kind)
        }
        return catalogs
    }

    private static func catalog(
        in root: [String: Any],
        kind: ProfileProviderKind
    ) throws -> [String: String] {
        guard let raw = root[kind.configurationKey] else { return [:] }
         
         
         
         
         
         
         
         
         
         
         
        if raw is NSNull { return [:] }
        guard let providers = raw as? [String: Any] else {
             
             
             
             
             
            throw ProfileProviderDefinitionError.buildRefused(
                String(
                    format: HakoCopy.string("%@ is not a list of named definitions", locale: .current),
                    kind.configurationKey
                )
            )
        }
        var result: [String: String] = [:]
        for (name, value) in providers {
            try validateName(name)
            guard let definition = value as? [String: Any] else {
                throw ProfileProviderDefinitionError.invalidDefinition
            }
            let data = try JSONSerialization.data(
                withJSONObject: definition,
                options: [.sortedKeys]
            )
            result[name] = String(decoding: data, as: UTF8.self)
        }
        return result
    }

     
     
     
     
    private static func applying(
        _ spec: ProfileProviderDefinitionSpec,
        to baseline: [ProfileProviderKind: [String: String]]
    ) throws -> [ProfileProviderKind: [String: String]] {
        var result = baseline
        for kind in ProfileProviderKind.allCases {
            let mutations = kind == .proxy
                ? spec.proxyProviders
                : spec.ruleProviders
            for mutation in mutations {
                try validateName(mutation.name)
                guard let definitionJSON = mutation.definitionJSON else {
                    result[kind, default: [:]].removeValue(
                        forKey: mutation.name
                    )
                    continue
                }
                guard let definition = try JSONSerialization.jsonObject(
                    with: Data(definitionJSON.utf8)
                ) as? [String: Any] else {
                    throw ProfileProviderDefinitionError.invalidDefinition
                }
                let data = try JSONSerialization.data(
                    withJSONObject: definition,
                    options: [.sortedKeys]
                )
                result[kind, default: [:]][mutation.name] = String(
                    decoding: data,
                    as: UTF8.self
                )
            }
        }
        return result
    }

    static func canonicalDefinitionJSON(
        _ json: String,
        kind: ProfileProviderKind
    ) throws -> String {
        guard let definition = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidDefinition
        }
        try validate(definition, kind: kind)
        let data = try JSONSerialization.data(withJSONObject: definition, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private static func validateName(_ value: String) throws {
        if let rejection = ProfileProviderDefinitionError.rejecting(value) {
            throw rejection
        }
    }

    private static func validate(
        _ definition: [String: Any],
        kind: ProfileProviderKind
    ) throws {
        guard let rawType = definition["type"] as? String,
              let transport = ProfileProviderTransport(rawValue: rawType.lowercased()) else {
            throw ProfileProviderDefinitionError.invalidTransport
        }
         
         
        try validateInteger(definition["interval"], error: .invalidInterval)
        try validateInteger(definition["size-limit"], error: .invalidSizeLimit)
        try validateHeaders(definition["header"])

        switch transport {
        case .http:
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            let rawURL = (definition["url"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawURL.isEmpty else {
                throw ProfileProviderDefinitionError.missingURL
            }
            guard let url = URL(string: rawURL),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  url.host != nil else {
                throw ProfileProviderDefinitionError.invalidURL
            }
        case .file:
            guard let path = definition["path"] as? String,
                  !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProfileProviderDefinitionError.missingManagedFile
            }
        case .inline:
            guard let payload = definition["payload"] as? [Any] else {
                throw ProfileProviderDefinitionError.invalidPayload
            }
            switch kind {
            case .proxy:
                guard payload.allSatisfy({ item in
                    guard let proxy = item as? [String: Any],
                          let type = proxy["type"] as? String else { return false }
                     
                     
                     
                    return ProxyProtocolCatalog.specifications.contains { $0.typeID == type }
                }) else {
                    throw ProfileProviderDefinitionError.invalidPayload
                }
            case .rule:
                guard payload.allSatisfy({ $0 is String }) else {
                    throw ProfileProviderDefinitionError.invalidPayload
                }
                 
                 
                 
                 
            }
        }

        if kind == .rule {
             
             
             
            guard let behavior = definition["behavior"] as? String,
                  ["classical", "domain", "ipcidr"].contains(behavior) else {
                throw ProfileProviderDefinitionError.invalidBehavior
            }
            let format = definition["format"] as? String ?? "yaml"
            guard ["yaml", "text", "mrs"].contains(format),
                  !(format == "mrs" && behavior == "classical") else {
                throw ProfileProviderDefinitionError.invalidFormat
            }
        }

        if let health = definition["health-check"], !(health is [String: Any]) {
            throw ProfileProviderDefinitionError.invalidDefinition
        }
        if let override = definition["override"], !(override is [String: Any]) {
            throw ProfileProviderDefinitionError.invalidDefinition
        }
    }

     
     
     
     
    private static func validateInteger(
        _ value: Any?,
        error: ProfileProviderDefinitionError
    ) throws {
        guard let value else { return }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.rounded() == number.doubleValue else { throw error }
    }

     
     
     
     
    private static func validateHeaders(_ value: Any?) throws {
        guard let value else { return }
        guard let headers = value as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidHeader
        }
        for (name, value) in headers {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProfileProviderDefinitionError.invalidHeader
            }
             
             
            if let string = value as? String {
                guard !Self.hasLineBreak(string) else {
                    throw ProfileProviderDefinitionError.invalidHeader
                }
            } else if let values = value as? [String] {
                guard !values.contains(where: Self.hasLineBreak) else {
                    throw ProfileProviderDefinitionError.invalidHeader
                }
            } else {
                throw ProfileProviderDefinitionError.invalidHeader
            }
        }
    }

    private static func hasLineBreak(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0 == "\r" || $0 == "\n" }
    }

    private static func fileKey(kind: ProfileProviderKind, name: String) -> String {
        "\(kind.rawValue)\u{0}\(name)"
    }
}

 
 
 
@MainActor
final class ProfileProviderDefinitionEditorDraft: ObservableObject {
    let originalName: String?
    let kind: ProfileProviderKind
    @Published var name: String
    @Published private(set) var mapping: [String: Any]

     
     
     
    private let originalMapping: [String: Any]

     
     
    var hasUnsavedChanges: Bool {
        name != (originalName ?? "")
            || !NSDictionary(dictionary: originalMapping).isEqual(to: mapping)
    }

    init(record: ProfileProviderDefinitionRecord?, kind: ProfileProviderKind) {
        self.originalName = record?.name
        self.kind = kind
        self.name = record?.name ?? ""
        if let data = record?.definitionJSON.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let migrated = Self.migratingLegacyDialerProxy(decoded, kind: kind)
            mapping = migrated
            originalMapping = migrated
        } else {
            let fresh = Self.defaultMapping(kind: kind, transport: .http)
            mapping = fresh
            originalMapping = fresh
        }
    }

     
     
     
     
    static func migratingLegacyDialerProxy(
        _ decoded: [String: Any],
        kind: ProfileProviderKind
    ) -> [String: Any] {
        var mapping = decoded
        guard kind == .proxy,
              let legacy = mapping.removeValue(forKey: "dialer-proxy") as? String,
              !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            mapping.removeValue(forKey: "dialer-proxy")
            return mapping
        }
        var override = mapping["override"] as? [String: Any] ?? [:]
        if (override["dialer-proxy"] as? String)?.isEmpty != false {
            override["dialer-proxy"] = legacy
        }
        mapping["override"] = override
        return mapping
    }

    var transport: ProfileProviderTransport {
        get {
            ProfileProviderTransport(rawValue: string(path: ["type"]).lowercased()) ?? .http
        }
        set {
            objectWillChange.send()
            let previous = transport
            mapping["type"] = newValue.rawValue
            guard previous != newValue else { return }
            switch newValue {
            case .http:
                mapping.removeValue(forKey: "path")
                mapping.removeValue(forKey: "payload")
                if mapping["url"] == nil { mapping["url"] = "" }
            case .file:
                mapping.removeValue(forKey: "url")
                mapping.removeValue(forKey: "payload")
                mapping.removeValue(forKey: "header")
                if mapping["path"] == nil { mapping["path"] = "" }
            case .inline:
                mapping.removeValue(forKey: "url")
                mapping.removeValue(forKey: "path")
                mapping.removeValue(forKey: "header")
                if mapping["payload"] == nil { mapping["payload"] = [Any]() }
            }
        }
    }

    var definitionJSON: String {
        guard JSONSerialization.isValidJSONObject(mapping),
              let data = try? JSONSerialization.data(withJSONObject: mapping, options: [.sortedKeys])
        else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    var unknownFieldCount: Int {
        let known = Set(kind == .proxy
            ? ProfileProviderFieldCatalog.proxyTopLevelKeys
            : ProfileProviderFieldCatalog.ruleTopLevelKeys)
        var count = mapping.keys.filter { !known.contains($0) }.count
         
         
         
        if kind == .proxy, let override = mapping["override"] as? [String: Any] {
            let overrideKnown = Set(ProfileProviderFieldCatalog.proxyOverrideKeys)
            count += override.keys.filter { !overrideKnown.contains($0) }.count
        }
        if kind == .proxy, let health = mapping["health-check"] as? [String: Any] {
            let healthKnown = Set(ProfileProviderFieldCatalog.proxyHealthCheckKeys)
            count += health.keys.filter { !healthKnown.contains($0) }.count
        }
        return count
    }

    func validatedDefinitionJSON() throws -> String {
        try ProfileProviderDefinitionsDraft.canonicalDefinitionJSON(
            definitionJSON,
            kind: kind
        )
    }

    func string(path: [String]) -> String {
        guard let value = value(path: path) else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    func bool(path: [String]) -> Bool {
        optionalBool(path: path) ?? false
    }

    func optionalBool(path: [String]) -> Bool? {
        guard let number = value(path: path) as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    func stringList(path: [String]) -> String {
        ((value(path: path) as? [String]) ?? []).joined(separator: ", ")
    }

    func setString(
        _ value: String,
        path: [String],
        number: Bool = false,
        omitWhenEmpty: Bool = true
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if omitWhenEmpty && trimmed.isEmpty {
            set(nil, path: path)
        } else if number, let integer = Int(trimmed) {
            set(integer, path: path)
        } else {
            set(value, path: path)
        }
    }

    func setBool(_ value: Bool, path: [String]) { set(value, path: path) }
    func setOptionalBool(_ value: Bool?, path: [String]) { set(value, path: path) }

    func setStringList(_ value: String, path: [String]) {
        let values = value.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        set(values.isEmpty ? nil : values, path: path)
    }

    func removeValue(path: [String]) { set(nil, path: path) }

    func proxyPayload() -> [[String: Any]] {
        mapping["payload"] as? [[String: Any]] ?? []
    }

    func replaceProxyPayload(_ payload: [[String: Any]]) {
        set(payload, path: ["payload"])
    }

    func rulePayload() -> [String] {
        mapping["payload"] as? [String] ?? []
    }

    func replaceRulePayload(_ payload: [String]) {
        set(payload, path: ["payload"])
    }

    func headers() -> [(name: String, value: String)] {
        guard let headers = mapping["header"] as? [String: Any] else { return [] }
        return headers.compactMap { name, value in
            if let string = value as? String { return (name, string) }
            if let values = value as? [String] { return (name, values.joined(separator: ", ")) }
            return nil
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func replaceHeaders(_ pairs: [(name: String, value: String)]) {
        let headers = Dictionary(uniqueKeysWithValues: pairs.map { ($0.name, $0.value) })
        set(headers.isEmpty ? nil : headers, path: ["header"])
    }

     
     
     
    func overrideExprSummary() -> String? {
        guard let exprs = value(path: ["override", "override-expr"]) as? [Any],
              !exprs.isEmpty else {
            return nil
        }
        return exprs.count == 1 ? "1 expression" : "\(exprs.count) expressions"
    }

     
     
     
     
    func overrideProxyNameSummary() -> String? {
        guard let rules = value(path: ["override", "proxy-name"]) as? [Any],
              !rules.isEmpty else {
            return nil
        }
        return rules.count == 1 ? "1 rename rule" : "\(rules.count) rename rules"
    }

    private func value(path: [String]) -> Any? {
        guard !path.isEmpty else { return nil }
        var current: Any = mapping
        for key in path {
            guard let object = current as? [String: Any], let next = object[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func set(_ value: Any?, path: [String]) {
        guard let first = path.first else { return }
        objectWillChange.send()
        if path.count == 1 {
            if let value { mapping[first] = value } else { mapping.removeValue(forKey: first) }
            return
        }
        var child = mapping[first] as? [String: Any] ?? [:]
        Self.set(value, path: Array(path.dropFirst()), dictionary: &child)
        if child.isEmpty { mapping.removeValue(forKey: first) } else { mapping[first] = child }
    }

    private static func set(_ value: Any?, path: [String], dictionary: inout [String: Any]) {
        guard let first = path.first else { return }
        if path.count == 1 {
            if let value { dictionary[first] = value } else { dictionary.removeValue(forKey: first) }
            return
        }
        var child = dictionary[first] as? [String: Any] ?? [:]
        set(value, path: Array(path.dropFirst()), dictionary: &child)
        if child.isEmpty { dictionary.removeValue(forKey: first) } else { dictionary[first] = child }
    }

    private static func defaultMapping(
        kind: ProfileProviderKind,
        transport: ProfileProviderTransport
    ) -> [String: Any] {
        var result: [String: Any] = ["type": transport.rawValue]
        if kind == .rule {
            result["behavior"] = "classical"
            result["format"] = "yaml"
        }
        switch transport {
        case .http: result["url"] = ""
        case .file: result["path"] = ""
        case .inline: result["payload"] = [Any]()
        }
        return result
    }
}

 
 
 
struct ProfileResourceSummary: Equatable {
    let proxyProviderCount: Int
    let ruleProviderCount: Int
    let supportingFileCount: Int

    var hasResources: Bool {
        proxyProviderCount > 0 || ruleProviderCount > 0 || supportingFileCount > 0
    }

    init(profile: Profile, sourceYAML: String) throws {
        do {
            var proxyProviders = Set<String>()
            var ruleProviders = Set<String>()
            let source = try Self.yamlRoot(sourceYAML)
            Self.collectProviders(
                from: source,
                proxyProviders: &proxyProviders,
                ruleProviders: &ruleProviders
            )

             
             
             
             
            if (profile.overwriteMode ?? .standard) == .standard {
                try Self.collectPatch(
                    profile.override.patchJSON,
                    proxyProviders: &proxyProviders,
                    ruleProviders: &ruleProviders
                )
            }
            if let migrated = profile.migratedGlobalOverride {
                try Self.collectPatch(
                    migrated.patchJSON,
                    proxyProviders: &proxyProviders,
                    ruleProviders: &ruleProviders
                )
            }

            proxyProviderCount = proxyProviders.count
            ruleProviderCount = ruleProviders.count
            supportingFileCount = profile.externalResources?.count ?? 0
        } catch {
            throw ProfileResourceSummaryError.invalidConfiguration
        }
    }

    private static func yamlRoot(_ yaml: String) throws -> [String: Any] {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileResourceSummaryError.invalidConfiguration
        }
        return root
    }

    private static func collectPatch(
        _ patchJSON: String,
        proxyProviders: inout Set<String>,
        ruleProviders: inout Set<String>
    ) throws {
        guard !patchJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(patchJSON.utf8))
                as? [String: Any] else {
            throw ProfileResourceSummaryError.invalidConfiguration
        }
        collectProviders(
            from: root,
            proxyProviders: &proxyProviders,
            ruleProviders: &ruleProviders
        )
    }

    private static func collectProviders(
        from root: [String: Any],
        proxyProviders: inout Set<String>,
        ruleProviders: inout Set<String>
    ) {
        if let providers = root["proxy-providers"] as? [String: Any] {
            proxyProviders.formUnion(providers.keys)
        }
        if let providers = root["rule-providers"] as? [String: Any] {
            ruleProviders.formUnion(providers.keys)
        }
    }
}
