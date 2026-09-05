import Foundation
import Security
import CryptoKit

 
 
 
 
 
 

 
 
 
 
enum ProxyCredentialVault {
    struct Extraction {
        let redactedYAML: String
        let entries: [(reference: ProxyCredentialReference, value: Data)]

        var references: [ProxyCredentialReference] {
            entries.map(\.reference)
        }
    }

    enum VaultError: LocalizedError, Equatable {
        case invalidConfiguration
        case missingCredential(proxy: String, field: String)
        case missingProxyIdentity(String)
        case credentialCollision(proxy: String, field: String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "The proxy credential configuration is invalid."
            case let .missingCredential(proxy, field):
                return "Credential \(field) for proxy '\(proxy)' is missing. Re-enter it in Credentials."
            case let .missingProxyIdentity(proxy):
                return "Proxy '\(proxy)' referenced by a saved credential no longer exists. Migrate or remove it in Credentials before saving."
            case let .credentialCollision(proxy, field):
                return "Proxy '\(proxy)' already has a credential for \(field)."
            }
        }
    }

    private static let secretKeys: Set<String> = [
        "access-token", "api-key", "auth-key", "auth-str", "authorization",
        "bearer-token",
        "client-cert", "client-certificate", "client-key",
        "obfs-password",
        "password", "pre-shared-key", "private-key", "private-key-passphrase",
        "proxy-authorization",
        "psk", "refresh-token", "secret", "secret-key", "tls-cert", "tls-key",
        "token", "username",
        "uuid",
    ]
     
     
    static func contextualSecretKeys(forProxyType type: String) -> Set<String> {
        switch type {
         
         
         
         
        case "openvpn": ["key", "tls-auth", "tls-crypt", "tls-crypt-v2"]
        case "hysteria":
             
             
             
             
            ["auth", "obfs"]
        case "hysteria2": ["auth"]
        case "sudoku": ["key"]
         
         
         
         
         
        case "vmess": ["primary-key"]
        default: []
        }
    }

     
     
     
     
     
     
     
    static func contextualSecretPaths(forProxyType type: String) -> [[String]] {
        switch type {
         
         
        case "ss", "ssr":
            [["plugin-opts", "key"]]
         
         
         
        case "vmess", "vless":
            [
                ["mkcp-opts", "seed"],
                ["mekya-opts", "kcp", "seed"],
                 
                 
                 
                 
                ["headers", "value"],
                ["headers", "values"],
            ]
        default:
            []
        }
    }

     
     
     
    static var allContextualSecretKeys: Set<String> {
        ["openvpn", "sudoku", "vmess", "hysteria", "hysteria2"].reduce(into: Set<String>()) {
            $0.formUnion(contextualSecretKeys(forProxyType: $1))
        }
    }

     
     
    static var allContextualSecretPathLeaves: Set<String> {
        ["ss", "ssr", "vmess", "vless"].reduce(into: Set<String>()) { names, type in
            for rule in contextualSecretPaths(forProxyType: type) {
                if let leaf = rule.last { names.insert(leaf) }
            }
        }
    }

     
    static var secretVocabulary: Set<String> { secretKeys }

    private static let arrayPrefix = "$"

     
     
     
     
     
     
     
    static func extractSplitting(
        from yaml: String,
        profileID: String,
        preservingLayout: Bool = true
    ) throws -> Extraction {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw VaultError.invalidConfiguration
        }
        var entries: [(ProxyCredentialReference, Data)] = []
        if var proxies = root["proxies"] as? [[String: Any]] {
            try redactProxies(&proxies, profileID: profileID, entries: &entries)
            root["proxies"] = proxies
        }
         
         
         
         
         
         
         
         
        for namespace in ["proxy-providers", "rule-providers"] {
            guard var providers = root[namespace] as? [String: Any] else { continue }
            for providerName in providers.keys.sorted() {
                guard var provider = providers[providerName] as? [String: Any]
                else { continue }
                if var payload = provider["payload"] as? [[String: Any]] {
                    try redactProxies(
                        &payload,
                        profileID: profileID,
                        container: providerName,
                        entries: &entries
                    )
                    provider["payload"] = payload
                }
                 
                 
                 
                 
                 
                 
                 
                providers[providerName] = provider
            }
            root[namespace] = providers
        }
        entries.sort { lhs, rhs in
            if lhs.0.proxy != rhs.0.proxy { return lhs.0.proxy < rhs.0.proxy }
            return lhs.0.fieldPath.lexicographicallyPrecedes(rhs.0.fieldPath)
        }
        let redacted: String
        if entries.isEmpty {
            redacted = yaml
        } else if preservingLayout,
                  let blanked = blankingValues(in: yaml, entries: entries) {
             
            redacted = blanked
        } else {
             
             
             
             
             
            let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            redacted = try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
        }
        return Extraction(redactedYAML: redacted, entries: entries)
    }

     
     
     
     
     
     
    static func store(_ extraction: Extraction, in store: CredentialStore) throws {
        for entry in extraction.entries {
            try store.set(entry.value, for: entry.reference.key)
        }
    }

    static func inject(
        into yaml: String,
        references: [ProxyCredentialReference],
        store: CredentialStore
    ) throws -> String {
        guard !references.isEmpty else { return yaml }
        let json = try ConfigTransforms.yamlToJSON(yaml)
         
         
         
         
         
        if let filled = fillingBlanks(in: yaml, references: references, store: store) {
            return filled
        }
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw VaultError.invalidConfiguration
        }
        var proxies = root["proxies"] as? [[String: Any]] ?? []
        var providers = root["proxy-providers"] as? [String: Any] ?? [:]
        guard !proxies.isEmpty || !providers.isEmpty else {
            throw VaultError.invalidConfiguration
        }
        for reference in references.sorted(by: referenceOrder) {
             
             
             
            if let container = reference.container {
                guard var provider = providers[container] as? [String: Any],
                      var payload = provider["payload"] as? [[String: Any]],
                      let index = locate(reference, in: payload)
                else {
                    throw VaultError.missingProxyIdentity(reference.proxy)
                }
                payload[index] = try reinject(
                    reference,
                    into: payload[index],
                    store: store
                )
                provider["payload"] = payload
                providers[container] = provider
                continue
            }
            if reference.container != nil || reference.itemIndex != nil,
               let index = locate(reference, in: proxies) {
                proxies[index] = try reinject(
                    reference,
                    into: proxies[index],
                    store: store
                )
                continue
            }
             
             
             
             
             
            guard reference.container == nil, reference.itemIndex == nil else {
                throw VaultError.missingProxyIdentity(reference.proxy)
            }
             
             
             
            var found: (provider: String, index: Int)?
            var rootIndex: Int?
            if !reference.proxy.isEmpty {
                let matches = proxies.indices.filter {
                    (proxies[$0]["name"] as? String) == reference.proxy
                }
                if matches.count > 1 {
                    throw VaultError.missingProxyIdentity(reference.proxy)
                }
                rootIndex = matches.first
            }
            for providerName in providers.keys.sorted() {
                guard let provider = providers[providerName] as? [String: Any],
                      let payload = provider["payload"] as? [[String: Any]],
                      let index = payload.firstIndex(where: {
                          ($0["name"] as? String) == reference.proxy
                      })
                else { continue }
                 
                 
                 
                if found != nil || rootIndex != nil {
                    throw VaultError.missingProxyIdentity(reference.proxy)
                }
                found = (providerName, index)
            }
            if found == nil, let rootIndex {
                proxies[rootIndex] = try reinject(
                    reference,
                    into: proxies[rootIndex],
                    store: store
                )
                continue
            }
            guard let found,
                  var provider = providers[found.provider] as? [String: Any],
                  var payload = provider["payload"] as? [[String: Any]]
            else {
                throw VaultError.missingProxyIdentity(reference.proxy)
            }
            payload[found.index] = try reinject(
                reference,
                into: payload[found.index],
                store: store
            )
            provider["payload"] = payload
            providers[found.provider] = provider
        }
        if !proxies.isEmpty { root["proxies"] = proxies }
        if !providers.isEmpty { root["proxy-providers"] = providers }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

     
     
     
    private static func locate(
        _ reference: ProxyCredentialReference,
        in proxies: [[String: Any]]
    ) -> Int? {
        if let index = reference.itemIndex, proxies.indices.contains(index) {
            let name = (proxies[index]["name"] as? String) ?? ""
            if name == reference.proxy { return index }
        }
        guard !reference.proxy.isEmpty else { return nil }
        return proxies.firstIndex { ($0["name"] as? String) == reference.proxy }
    }

     
     
    private static func reinject(
        _ reference: ProxyCredentialReference,
        into proxy: [String: Any],
        store: CredentialStore
    ) throws -> [String: Any] {
        var proxyValue: Any = proxy
         
         
         
         
         
        if let existing = value(at: reference.fieldPath, in: proxyValue),
           !isBlankValue(existing) {
            return proxy
        }
        guard let stored = store.get(reference.key),
              let decoded = try? JSONSerialization.jsonObject(
                with: stored,
                options: [.fragmentsAllowed]
              ),
              set(decoded, at: reference.fieldPath, in: &proxyValue),
              let dictionary = proxyValue as? [String: Any] else {
            throw VaultError.missingCredential(
                proxy: reference.proxy,
                field: reference.fieldLabel
            )
        }
        return dictionary
    }

    static func remove(
        _ references: [ProxyCredentialReference],
        store: CredentialStore
    ) throws {
        for reference in references { try store.remove(reference.key) }
    }

    static func valueData(_ value: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }

    static func stringValue(_ data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String
    }

    static func reference(
        profileID: String,
        proxy: String,
        fieldPath: [String],
        container: String? = nil,
        itemIndex: Int? = nil
    ) -> ProxyCredentialReference {
        ProxyCredentialReference(
            container: container,
            itemIndex: itemIndex,
            proxy: proxy,
            fieldPath: fieldPath,
            key: key(
                profileID: profileID,
                proxy: proxy,
                fieldPath: fieldPath,
                container: container,
                itemIndex: itemIndex
            )
        )
    }

     
     
     
     
    private static func key(
        profileID: String,
        proxy: String,
        fieldPath: [String],
        container: String? = nil,
        itemIndex: Int? = nil
    ) -> String {
        var parts = [profileID]
        if let container {
            parts.append("proxy-providers")
            parts.append(container)
            parts.append(String(itemIndex ?? 0))
        }
        let identity = (parts + [proxy] + fieldPath).joined(separator: "\u{0}")
        let digest = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "proxy.secret.\(profileID).\(digest.prefix(32))"
    }

     
     
     
     
     


     
     
    private static func fillingBlanks(
        in yaml: String,
        references: [ProxyCredentialReference],
        store: CredentialStore
    ) -> String? {
        var text = yaml
        for reference in references.sorted(by: referenceOrder) {
            guard let key = reference.fieldPath.last(where: { !$0.hasPrefix(arrayPrefix) }),
                  let stored = store.get(reference.key),
                  let value = scalarText(stored),
                  let range = locateBlank(
                      key: key,
                      inProxy: reference.proxy,
                      in: text
                  )
            else { return nil }
            text.replaceSubrange(range, with: value)
        }
        return text
    }

     
     
     
     
     
     
    private static func locateBlank(
        key: String,
        inProxy proxy: String,
        in text: String
    ) -> Range<String.Index>? {
         
         
         
         
         
        guard let scope = proxyBlock(named: proxy, in: text) else { return nil }
        return locateBlank(key: key, in: text, within: scope)
    }

     
    private static func proxyBlock(
        named proxy: String,
        in text: String
    ) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: proxy)
        guard let nameExpression = try? NSRegularExpression(
            pattern: #"(?m)^[ \t-]*name[ \t]*:[ \t]*(["']?)"# + escaped + #"\1[ \t]*(?=#|$)"#
        ) else { return nil }
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = nameExpression.matches(in: text, options: [], range: whole)
        guard matches.count == 1, let start = Range(matches[0].range, in: text)
        else { return nil }
        guard let nextExpression = try? NSRegularExpression(
            pattern: #"(?m)^[ \t]*-[ \t]*name[ \t]*:"#
        ) else { return nil }
        let after = NSRange(start.upperBound..<text.endIndex, in: text)
        if let next = nextExpression.firstMatch(in: text, options: [], range: after),
           let nextRange = Range(next.range, in: text) {
            return start.lowerBound..<nextRange.lowerBound
        }
        return start.lowerBound..<text.endIndex
    }

    private static func locateBlank(
        key: String,
        in text: String,
        within scope: Range<String.Index>
    ) -> Range<String.Index>? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        guard let expression = try? NSRegularExpression(
             
             
             
             
            pattern: #"(?m)^[ \t-]*"# + escapedKey + #"[ \t]*:[ \t]()[ \t]*(?=#|$)"#
        ) else { return nil }
        let searched = NSRange(scope, in: text)
        let matches = expression.matches(in: text, options: [], range: searched)
        guard let first = matches.first,
              let range = Range(first.range(at: 1), in: text)
        else { return nil }
        return range
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private static func blankingValues(
        in yaml: String,
        entries: [(ProxyCredentialReference, Data)]
    ) -> String? {
         
         
         
         
         
        for (reference, _) in entries where proxyBlock(named: reference.proxy, in: yaml) == nil {
            return nil
        }
        var text = yaml
        for (reference, data) in entries {
            guard let key = reference.fieldPath.last(where: { !$0.hasPrefix(arrayPrefix) }),
                  let value = scalarText(data),
                  !value.isEmpty,
                  let range = locate(key: key, value: value, in: text)
            else { return nil }
            text.replaceSubrange(range, with: "")
        }
         
         
         
         
        for (_, data) in entries {
            guard let value = scalarText(data), !value.isEmpty else { return nil }
            if text.contains(value) { return nil }
        }
        return text
    }

     
    private static func scalarText(_ data: Data) -> String? {
        guard let decoded = try? JSONSerialization.jsonObject(
            with: data,
            options: [.fragmentsAllowed]
        ) else { return nil }
        switch decoded {
        case let text as String: return text
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

     
     
     
    private static func locate(
        key: String,
        value: String,
        in text: String
    ) -> Range<String.Index>? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        guard let expression = try? NSRegularExpression(
            pattern: #"(?m)^[ \t-]*"# + escapedKey
                + #"[ \t]*:[ \t]*(["']?)"# + escapedValue + #"\1[ \t]*(?=#|$)"#
        ) else { return nil }
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, options: [], range: whole)
        guard matches.count == 1,
              let match = Range(matches[0].range(at: 0), in: text)
        else { return nil }
         
        guard let valueStart = text.range(
            of: value,
            options: [],
            range: match
        ) else { return nil }
        var start = valueStart.lowerBound
        var end = valueStart.upperBound
        if start > text.startIndex {
            let before = text.index(before: start)
            if text[before] == "\"" || text[before] == "'" {
                start = before
                if end < text.endIndex { end = text.index(after: end) }
            }
        }
        return start..<end
    }

    private static func redactProxies(
        _ proxies: inout [[String: Any]],
        profileID: String,
        container: String? = nil,
        entries: inout [(ProxyCredentialReference, Data)]
    ) throws {
        for index in proxies.indices {
             
             
             
            let proxy = (proxies[index]["name"] as? String) ?? ""
            let proxyType = (proxies[index]["type"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
             
             
             
             
             
             
            var value: Any = proxies[index]
            try redact(
                value: &value,
                proxy: proxy,
                container: container,
                itemIndex: index,
                path: [],
                profileID: profileID,
                contextualSecretKeys: contextualSecretKeys(forProxyType: proxyType),
                contextualSecretPaths: contextualSecretPaths(forProxyType: proxyType),
                entries: &entries
            )
            if let dictionary = value as? [String: Any] { proxies[index] = dictionary }
        }
    }

     
     
     
     
     
     
    private static func isInsideAHeaderMap(_ path: [String]) -> Bool {
         
         
         
         
        let container = path.dropLast().last
        guard container == "headers" || container == "header" else { return false }
         
         
         
         
         
         
         
         
         
        guard let name = path.last?.lowercased(), name == "host" else {
            return true
        }
        return false
    }

     
     
    static func matchesSecretPath(_ path: [String], anyOf rules: [[String]]) -> Bool {
        matches(path: path, anyOf: rules)
    }

     
    static func isSecretHeaderValue(_ path: [String]) -> Bool {
        isInsideAHeaderMap(path)
    }

    private static func matches(path: [String], anyOf rules: [[String]]) -> Bool {
        guard !rules.isEmpty else { return false }
        let named = path.filter { !$0.hasPrefix(arrayPrefix) }
        return rules.contains { rule in
            named.count >= rule.count
                && Array(named.suffix(rule.count)) == rule
        }
    }

    private static func redact(
        value: inout Any,
        proxy: String,
        container: String?,
        itemIndex: Int,
        path: [String],
        profileID: String,
        contextualSecretKeys: Set<String>,
        contextualSecretPaths: [[String]],
        entries: inout [(ProxyCredentialReference, Data)]
    ) throws {
        if var dictionary = value as? [String: Any] {
            for key in dictionary.keys.sorted() {
                guard var child = dictionary[key] else { continue }
                let childPath = path + [key]
                if secretKeys.contains(key.lowercased())
                    || contextualSecretKeys.contains(key.lowercased())
                    || matches(path: childPath, anyOf: contextualSecretPaths)
                    || isInsideAHeaderMap(childPath) {
                    let encoded = try JSONSerialization.data(
                        withJSONObject: child,
                        options: [.fragmentsAllowed]
                    )
                    entries.append((
                        reference(
                            profileID: profileID,
                            proxy: proxy,
                            fieldPath: childPath,
                            container: container,
                            itemIndex: itemIndex
                        ),
                        encoded
                    ))
                    dictionary.removeValue(forKey: key)
                } else {
                    try redact(
                        value: &child,
                        proxy: proxy,
                        container: container,
                        itemIndex: itemIndex,
                        path: childPath,
                        profileID: profileID,
                        contextualSecretKeys: contextualSecretKeys,
                        contextualSecretPaths: contextualSecretPaths,
                        entries: &entries
                    )
                    dictionary[key] = child
                }
            }
            value = dictionary
        } else if var array = value as? [Any] {
            for index in array.indices {
                var child = array[index]
                try redact(
                    value: &child,
                    proxy: proxy,
                    container: container,
                    itemIndex: itemIndex,
                    path: path + [arrayPrefix + String(index)],
                    profileID: profileID,
                    contextualSecretKeys: contextualSecretKeys,
                    contextualSecretPaths: contextualSecretPaths,
                    entries: &entries
                )
                array[index] = child
            }
            value = array
        }
    }

     
    private static func isBlankValue(_ value: Any) -> Bool {
        if value is NSNull { return true }
        if let text = value as? String { return text.isEmpty }
        return false
    }

    private static func value(at path: [String], in root: Any) -> Any? {
        guard let first = path.first else { return root }
        if first.hasPrefix(arrayPrefix),
           let index = Int(first.dropFirst()),
           let array = root as? [Any], array.indices.contains(index) {
            return value(at: Array(path.dropFirst()), in: array[index])
        }
        guard let dictionary = root as? [String: Any], let child = dictionary[first] else {
            return nil
        }
        return value(at: Array(path.dropFirst()), in: child)
    }

    @discardableResult
    private static func set(_ newValue: Any, at path: [String], in root: inout Any) -> Bool {
        guard let first = path.first else {
            root = newValue
            return true
        }
        if first.hasPrefix(arrayPrefix),
           let index = Int(first.dropFirst()),
           var array = root as? [Any], array.indices.contains(index) {
            var child = array[index]
            guard set(newValue, at: Array(path.dropFirst()), in: &child) else { return false }
            array[index] = child
            root = array
            return true
        }
        guard var dictionary = root as? [String: Any] else { return false }
        if path.count == 1 {
            dictionary[first] = newValue
            root = dictionary
            return true
        }
        guard var child = dictionary[first] else { return false }
        guard set(newValue, at: Array(path.dropFirst()), in: &child) else { return false }
        dictionary[first] = child
        root = dictionary
        return true
    }

    private static func referenceOrder(
        _ lhs: ProxyCredentialReference,
        _ rhs: ProxyCredentialReference
    ) -> Bool {
        if lhs.proxy != rhs.proxy { return lhs.proxy < rhs.proxy }
        return lhs.fieldPath.lexicographicallyPrecedes(rhs.fieldPath)
    }
}

 
 
 
 
 
enum ProviderDefinitionCredentialVault {
    struct Entry {
        let reference: ProviderDefinitionCredentialReference
        let value: Data
    }

    struct Extraction {
        let definitionJSON: String
        let entries: [Entry]
    }

    enum VaultError: LocalizedError, Equatable {
        case invalidConfiguration
        case missingCredential

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Provider credentials could not be separated from this definition."
            case .missingCredential:
                return "A saved provider credential is unavailable. Re-enter it before saving or connecting."
            }
        }
    }

     
     
    static func extractDefinitionSplitting(
        _ definitionJSON: String,
        profileID: String,
        providerKind: ProfileProviderKind,
        provider: String
    ) throws -> Extraction {
        guard var definition = try JSONSerialization.jsonObject(
            with: Data(definitionJSON.utf8)
        ) as? [String: Any] else {
            throw VaultError.invalidConfiguration
        }
        var entries: [Entry] = []

        if let headers = definition.removeValue(forKey: "header") {
            guard JSONSerialization.isValidJSONObject(headers),
                  let data = try? JSONSerialization.data(
                    withJSONObject: headers,
                    options: [.sortedKeys]
                  ) else {
                throw VaultError.invalidConfiguration
            }
            entries.append(Entry(
                reference: reference(
                    profileID: profileID,
                    providerKind: providerKind,
                    provider: provider,
                    valueKind: .headers
                ),
                value: data
            ))
        }

        if let age = definition.removeValue(forKey: "age-secret-key") {
            guard providerKind == .proxy, let value = age as? String, !value.isEmpty else {
                throw VaultError.invalidConfiguration
            }
            entries.append(Entry(
                reference: reference(
                    profileID: profileID,
                    providerKind: providerKind,
                    provider: provider,
                    valueKind: .ageSecretKey
                ),
                value: Data(value.utf8)
            ))
        }

        if providerKind == .proxy,
           (definition["type"] as? String)?.lowercased() == "inline",
           let payload = definition["payload"] as? [[String: Any]] {
            let root: [String: Any] = ["proxies": payload]
            let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            let yaml = try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
            let scope = inlineScope(
                profileID: profileID,
                providerKind: providerKind,
                provider: provider
            )
            let extraction = try ProxyCredentialVault.extractSplitting(
                from: yaml,
                profileID: scope,
                preservingLayout: false
            )
            let redactedJSON = try ConfigTransforms.yamlToJSON(extraction.redactedYAML)
            guard let redactedRoot = try JSONSerialization.jsonObject(
                with: Data(redactedJSON.utf8)
            ) as? [String: Any],
                  let redactedPayload = redactedRoot["proxies"] as? [[String: Any]] else {
                throw VaultError.invalidConfiguration
            }
            definition["payload"] = redactedPayload
            entries.append(contentsOf: extraction.entries.map { item in
                Entry(
                    reference: ProviderDefinitionCredentialReference(
                        providerKind: providerKind,
                        provider: provider,
                        valueKind: .inlineProxyField,
                        proxy: item.reference.proxy,
                        fieldPath: item.reference.fieldPath,
                        key: item.reference.key
                    ),
                    value: item.value
                )
            })
        }

        let encoded = try JSONSerialization.data(
            withJSONObject: definition,
            options: [.sortedKeys]
        )
        return Extraction(
            definitionJSON: String(decoding: encoded, as: UTF8.self),
            entries: entries
        )
    }

    static func inject(
        into yaml: String,
        references: [ProviderDefinitionCredentialReference],
        store: CredentialStore
    ) throws -> String {
        guard !references.isEmpty else { return yaml }
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw VaultError.invalidConfiguration
        }
        for kind in ProfileProviderKind.allCases {
            guard var providers = root[kind.configurationKey] as? [String: Any] else { continue }
            let names = Set(references.filter { $0.providerKind == kind }.map(\.provider))
            for name in names {
                guard let definition = providers[name] as? [String: Any] else {
                    throw VaultError.invalidConfiguration
                }
                providers[name] = try injectDefinition(
                    definition,
                    references: references.filter {
                        $0.providerKind == kind && $0.provider == name
                    },
                    store: store
                )
            }
            root[kind.configurationKey] = providers
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

    static func remove(
        _ references: [ProviderDefinitionCredentialReference],
        store: CredentialStore
    ) throws {
        for reference in references { try store.remove(reference.key) }
    }

     
     
     
     
     
     
     
    static func hydrateDefinition(
        _ definitionJSON: String,
        references: [ProviderDefinitionCredentialReference],
        store: CredentialStore
    ) throws -> String {
        guard let definition = try JSONSerialization.jsonObject(
            with: Data(definitionJSON.utf8)
        ) as? [String: Any] else {
            throw VaultError.invalidConfiguration
        }
        let hydrated = try injectDefinition(
            definition,
            references: references,
            store: store
        )
        let encoded = try JSONSerialization.data(
            withJSONObject: hydrated,
            options: [.sortedKeys]
        )
        return String(decoding: encoded, as: UTF8.self)
    }

    private static func injectDefinition(
        _ original: [String: Any],
        references: [ProviderDefinitionCredentialReference],
        store: CredentialStore
    ) throws -> [String: Any] {
        var definition = original
        if let reference = references.first(where: { $0.valueKind == .headers }) {
            guard let data = store.get(reference.key),
                  let headers = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else {
                throw VaultError.missingCredential
            }
            definition["header"] = headers
        }
        if let reference = references.first(where: { $0.valueKind == .ageSecretKey }) {
            guard let data = store.get(reference.key),
                  let value = String(data: data, encoding: .utf8), !value.isEmpty else {
                throw VaultError.missingCredential
            }
            definition["age-secret-key"] = value
        }
        let inline = references.filter { $0.valueKind == .inlineProxyField }
        if !inline.isEmpty {
            guard let payload = definition["payload"] as? [[String: Any]] else {
                throw VaultError.invalidConfiguration
            }
            let root: [String: Any] = ["proxies": payload]
            let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            let yaml = try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
            let hydrated = try ProxyCredentialVault.inject(
                into: yaml,
                references: inline.compactMap { reference in
                    guard let proxy = reference.proxy else { return nil }
                    return ProxyCredentialReference(
                        proxy: proxy,
                        fieldPath: reference.fieldPath,
                        key: reference.key
                    )
                },
                store: store
            )
            let hydratedJSON = try ConfigTransforms.yamlToJSON(hydrated)
            guard let hydratedRoot = try JSONSerialization.jsonObject(
                with: Data(hydratedJSON.utf8)
            ) as? [String: Any],
                  let hydratedPayload = hydratedRoot["proxies"] as? [[String: Any]] else {
                throw VaultError.invalidConfiguration
            }
            definition["payload"] = hydratedPayload
        }
        return definition
    }

    private static func reference(
        profileID: String,
        providerKind: ProfileProviderKind,
        provider: String,
        valueKind: ProviderDefinitionCredentialReference.ValueKind
    ) -> ProviderDefinitionCredentialReference {
        let identity = [profileID, providerKind.rawValue, provider, valueKind.rawValue]
            .joined(separator: "\u{0}")
        let digest = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return ProviderDefinitionCredentialReference(
            providerKind: providerKind,
            provider: provider,
            valueKind: valueKind,
            proxy: nil,
            fieldPath: [],
            key: "provider.definition.\(profileID).\(digest.prefix(32))"
        )
    }

    private static func inlineScope(
        profileID: String,
        providerKind: ProfileProviderKind,
        provider: String
    ) -> String {
        let identity = [providerKind.rawValue, provider].joined(separator: "\u{0}")
        let digest = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(profileID).provider.\(digest.prefix(24))"
    }
}
