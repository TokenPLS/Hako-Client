import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct MemoryTrimSpec: Codable, Equatable {
    var droppedRuleProviders: [String] = []
     
    var droppedDNSPolicyKeys: [String] = []
     
    var droppedFakeIPFilterEntries: [String] = []
     
    var droppedGeoSiteRules: [String] = []
     
    var droppedGeoIPRules: [String] = []

     
     
    init(
        droppedRuleProviders: [String] = [],
        droppedDNSPolicyKeys: [String] = [],
        droppedFakeIPFilterEntries: [String] = [],
        droppedGeoSiteRules: [String] = [],
        droppedGeoIPRules: [String] = []
    ) {
        self.droppedRuleProviders = droppedRuleProviders
        self.droppedDNSPolicyKeys = droppedDNSPolicyKeys
        self.droppedFakeIPFilterEntries = droppedFakeIPFilterEntries
        self.droppedGeoSiteRules = droppedGeoSiteRules
        self.droppedGeoIPRules = droppedGeoIPRules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        droppedRuleProviders = try c.decodeIfPresent(
            [String].self, forKey: .droppedRuleProviders) ?? []
        droppedDNSPolicyKeys = try c.decodeIfPresent(
            [String].self, forKey: .droppedDNSPolicyKeys) ?? []
        droppedFakeIPFilterEntries = try c.decodeIfPresent(
            [String].self, forKey: .droppedFakeIPFilterEntries) ?? []
        droppedGeoSiteRules = try c.decodeIfPresent(
            [String].self, forKey: .droppedGeoSiteRules) ?? []
        droppedGeoIPRules = try c.decodeIfPresent(
            [String].self, forKey: .droppedGeoIPRules) ?? []
    }

    var isEmpty: Bool {
        droppedRuleProviders.isEmpty
            && droppedDNSPolicyKeys.isEmpty
            && droppedFakeIPFilterEntries.isEmpty
            && droppedGeoSiteRules.isEmpty
            && droppedGeoIPRules.isEmpty
    }

    func apply(to yaml: String) throws -> String {
        guard !isEmpty else { return yaml }
        var document = try ConfigTransforms.ParsedDocument(yaml: yaml)
        guard try apply(to: &document.root) else { return yaml }
        return try document.serialized()
    }

     
     
     
    @discardableResult
    func apply(to root: inout [String: Any]) throws -> Bool {
        guard !isEmpty else { return false }
        let dropped = Set(droppedRuleProviders)

        var touched = false

        if var providers = root["rule-providers"] as? [String: Any] {
            for name in dropped where providers[name] != nil {
                providers.removeValue(forKey: name)
                touched = true
            }
            root["rule-providers"] = providers
        }

        if let rules = root["rules"] as? [Any] {
             
             
             
             
            let droppedSites = Set(droppedGeoSiteRules.map { $0.uppercased() })
            let droppedIPs = Set(droppedGeoIPRules.map { $0.uppercased() })
            let kept = rules.filter { rule in
                guard let line = rule as? String else { return true }
                let fields = line.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard fields.count >= 2 else { return true }
                switch fields[0].uppercased() {
                case "RULE-SET":
                    return !dropped.contains(fields[1])
                case "GEOSITE":
                    return !droppedSites.contains(fields[1].uppercased())
                case "GEOIP":
                    return !droppedIPs.contains(fields[1].uppercased())
                default:
                    return true
                }
            }
            if kept.count != rules.count { touched = true }
            root["rules"] = kept
        }

        if var dns = root["dns"] as? [String: Any] {
             
            if var policy = dns["nameserver-policy"] as? [String: Any] {
                for key in droppedDNSPolicyKeys where policy[key] != nil {
                    policy.removeValue(forKey: key)
                    touched = true
                }
                dns["nameserver-policy"] = policy
            }
            if let filter = dns["fake-ip-filter"] as? [Any] {
                let droppedEntries = Set(droppedFakeIPFilterEntries)
                let kept = filter.filter {
                    guard let line = $0 as? String else { return true }
                    return !droppedEntries.contains(line)
                }
                if kept.count != filter.count { touched = true }
                dns["fake-ip-filter"] = kept
            }
            root["dns"] = dns
        }

        if var dns = root["dns"] as? [String: Any],
           let filter = dns["fake-ip-filter"] as? [Any]
        {
            var kept: [Any] = []
            for entry in filter {
                guard let line = entry as? String,
                      line.lowercased().hasPrefix("rule-set:")
                else {
                    kept.append(entry)
                    continue
                }
                let names = line.dropFirst("rule-set:".count)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !dropped.contains($0) }
                if names.count != line.split(separator: ",").count {
                    touched = true
                }
                 
                 
                 
                if !names.isEmpty {
                    kept.append("rule-set:" + names.joined(separator: ","))
                }
            }
            dns["fake-ip-filter"] = kept
            root["dns"] = dns
        }

        return touched
    }
}
