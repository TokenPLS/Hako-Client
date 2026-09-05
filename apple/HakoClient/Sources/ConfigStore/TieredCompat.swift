import Foundation

 
 
 
 
 
 
 
 
 
 
enum TieredCompat {
     
     
     
    enum Layer: String, CaseIterable {
        case tuning
        case dns
        case rules
        case groups
    }

     
     
    static func keys(for layer: Layer) -> Set<String> {
        switch layer {
        case .groups: return ["proxy-groups"]
        case .rules: return ["rules", "rule-providers", "sub-rules"]
        case .dns: return ["dns", "hosts"]
        case .tuning: return []  
        }
    }

    private static let floorKeys: Set<String> = ["proxies", "proxy-providers"]

     
     
    private static var essentialKeys: Set<String> {
        floorKeys
            .union(keys(for: .groups))
            .union(keys(for: .rules))
            .union(keys(for: .dns))
    }

     
     
     
     
     
    static func dropOrder(for config: OrderedJSON) -> [Layer] {
        if extractPlainIPResolver(from: config) != nil {
            return [.tuning, .dns, .rules, .groups]
        }
        return [.tuning, .rules, .groups]
    }

     
     
     
     
     
     
     
     
    static func candidate(from config: OrderedJSON, droppingFirst depth: Int) -> OrderedJSON {
        guard case var .object(pairs) = config else { return config }
        let order = dropOrder(for: config)
        let dropped = Set(order.prefix(depth))

        if dropped.contains(.tuning) {
             
            pairs = pairs.filter { essentialKeys.contains($0.key) }
        }
        for layer in dropped where layer != .tuning {
            let layerKeys = keys(for: layer)
            pairs = pairs.filter { !layerKeys.contains($0.key) }
        }
        var result = OrderedJSON.object(pairs)

         
        if dropped.contains(.groups) {
            result = result.settingTopLevel("proxy-groups", to: synthesizedDefaultGroup(from: config))
        }
        if dropped.contains(.rules) {
            result = result.settingTopLevel("rules", to: synthesizedMinimalRules())
        }
        if dropped.contains(.dns), let resolver = extractPlainIPResolver(from: config) {
            result = result.settingTopLevel("dns", to: synthesizedMinimalDNS(resolver: resolver))
        }
        return result
    }

     

     
    static func proxyNames(in config: OrderedJSON) -> [String] {
        guard case let .array(items)? = config.topLevelValue("proxies") else { return [] }
        return items.compactMap { item in
            guard case let .object(fields) = item else { return nil }
            guard case let .string(name)? = fields.first(where: { $0.key == "name" })?.value else { return nil }
            return name
        }
    }

     
     
     
    static func extractPlainIPResolver(from config: OrderedJSON) -> String? {
        guard case let .object(dnsFields)? = config.topLevelValue("dns") else { return nil }
        let slots = ["nameserver", "default-nameserver", "fallback",
                     "proxy-server-nameserver", "direct-nameserver"]
        for slot in slots {
            guard case let .array(entries)? = dnsFields.first(where: { $0.key == slot })?.value else { continue }
            for entry in entries {
                guard case let .string(value) = entry else { continue }
                if isPlainIP(value) { return value }
            }
        }
        return nil
    }

     
    static func isPlainIP(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains("://"), !trimmed.contains("#"), !trimmed.contains("/") else { return false }
        var v4 = in_addr(), v6 = in6_addr()
        return trimmed.withCString { inet_pton(AF_INET, $0, &v4) == 1 || inet_pton(AF_INET6, $0, &v6) == 1 }
    }

     

     
    static func synthesizedDefaultGroup(from config: OrderedJSON) -> OrderedJSON {
        let members = proxyNames(in: config).map { OrderedJSON.string($0) } + [.string("DIRECT")]
        return .array([
            .object([
                (key: "name", value: .string("Proxy")),
                (key: "type", value: .string("select")),
                (key: "proxies", value: .array(members)),
            ]),
        ])
    }

     
    static func synthesizedMinimalRules() -> OrderedJSON {
        .array([
            .string("IP-CIDR,127.0.0.0/8,DIRECT,no-resolve"),
            .string("IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"),
            .string("IP-CIDR,172.16.0.0/12,DIRECT,no-resolve"),
            .string("IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"),
            .string("MATCH,Proxy"),
        ])
    }

     
     
    static func synthesizedMinimalDNS(resolver: String) -> OrderedJSON {
        .object([
            (key: "enable", value: .scalar("true")),
            (key: "nameserver", value: .array([.string(resolver)])),
        ])
    }
}
