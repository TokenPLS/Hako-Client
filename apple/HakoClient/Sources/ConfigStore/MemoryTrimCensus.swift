import Foundation

 
 
 
 
 
 
 
 
 
 
enum MemoryTrimCensus {
     
     
     
     
     
     
     
     
    static func ruleProviders(
        sourceYAML: String?,
        effectiveYAML: String? = nil,
        dropped: [String],
        prices: [String: Int64],
        runPrices: [String: Int64] = [:],
        estimates: [String: Int64] = [:]
    ) -> [MemoryTrimManageView.Item] {
        let fromSource = Set(providerNames(in: sourceYAML))
        let fromEffective = Set(providerNames(in: effectiveYAML))
         
         
         
        var names = Array(fromSource.union(fromEffective))
         
         
         
         
        let known = Set(names)
        for name in dropped where !known.contains(name) {
            names.append(name)
        }
         
         
         
        func origin(of name: String) -> MemoryTrimManageView.Item.Origin {
            fromSource.contains(name) ? .profile : .override
        }
        return names.sorted().map { name in
            let from = origin(of: name)
            return item(
                name: name, origin: from, prices: prices,
                runPrices: runPrices, estimates: estimates
            )
        }
    }

    private static func providerNames(in yaml: String?) -> [String] {
        guard let yaml,
              let root = Self.root(yaml),
              let providers = root["rule-providers"] as? [String: Any]
        else { return [] }
        return Array(providers.keys)
    }

    private static func item(
        name: String,
        origin: MemoryTrimManageView.Item.Origin,
        prices: [String: Int64],
        runPrices: [String: Int64],
        estimates: [String: Int64]
    ) -> MemoryTrimManageView.Item {
        if let run = runPrices[name] {
            return MemoryTrimManageView.Item(
                name: name, measuredBytes: run, origin: origin
            )
        }
        if prices[name] == nil, let est = estimates[name] {
            return MemoryTrimManageView.Item(
                name: name, measuredBytes: est, isEstimate: true,
                origin: origin
            )
        }
        return MemoryTrimManageView.Item(
            name: name,
            measuredBytes: prices[name],
            fromEarlierRun: prices[name] != nil,
            origin: origin
        )
    }

     
     
     
     
     
     
     
    static func dnsPolicyKeys(
        sourceYAML: String?, effectiveYAML: String? = nil, dropped: [String]
    ) -> [String] {
        var keys = Set(policyKeys(in: sourceYAML))
        keys.formUnion(policyKeys(in: effectiveYAML))
        keys.formUnion(dropped)
        return keys.sorted()
    }

    private static func policyKeys(in yaml: String?) -> [String] {
        guard let yaml,
              let root = Self.root(yaml),
              let dns = root["dns"] as? [String: Any],
              let policy = dns["nameserver-policy"] as? [String: Any]
        else { return [] }
        return Array(policy.keys)
    }

    static func fakeIPFilterEntries(
        sourceYAML: String?, dropped: [String]
    ) -> [String] {
        var entries: [String] = []
        if let root = Self.root(sourceYAML),
           let dns = root["dns"] as? [String: Any],
           let filter = dns["fake-ip-filter"] as? [Any]
        {
            entries = filter.compactMap { $0 as? String }
        }
        let known = Set(entries)
        entries.append(contentsOf: dropped.filter { !known.contains($0) })
        return entries
    }

     
    static func proxyProviderNames(sourceYAML: String?) -> [String] {
        guard let root = Self.root(sourceYAML),
              let providers = root["proxy-providers"] as? [String: Any]
        else { return [] }
        return Array(providers.keys)
    }

     
     
     
     
    static func dnsEntryBytes(
        _ entry: String,
        container: URL?,
        rulePrices: [String: Int64]
    ) -> Int64? {
        guard let container else { return nil }
        var total: Int64 = 0
        var found = false
        for part in entry.split(separator: ",") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            func artifact(_ dir: String, _ name: String) {
                 
                 
                 
                let file = name
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased() + ".mrs"
                let url = container
                    .appendingPathComponent("working/\(dir)")
                    .appendingPathComponent(file)
                if let size = (try? FileManager.default.attributesOfItem(
                    atPath: url.path
                )[.size]) as? NSNumber {
                    total += size.int64Value
                    found = true
                }
            }
            if piece.lowercased().hasPrefix("geosite:") {
                artifact("compiled-geosite",
                         String(piece.dropFirst("geosite:".count)))
            } else if piece.lowercased().hasPrefix("geo:") {
                artifact("compiled-geoip",
                         String(piece.dropFirst("geo:".count)))
            } else if piece.lowercased().hasPrefix("rule-set:") {
                for name in piece.dropFirst("rule-set:".count)
                    .split(separator: ",")
                {
                    if let price = rulePrices[
                        name.trimmingCharacters(in: .whitespaces)
                    ] {
                        total += price
                        found = true
                    }
                }
            } else if !piece.contains(":") {
                 
                 
                artifact("compiled-geosite", piece)
            }
        }
        return found ? total : nil
    }

     
     
     
    static func geoRuleNames(
        sourceYAML: String?, kind: String, dropped: [String]
    ) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        if let rules = root(sourceYAML)?["rules"] as? [Any] {
            for rule in rules {
                guard let line = rule as? String else { continue }
                let fields = line.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard fields.count >= 2,
                      fields[0].uppercased() == kind,
                      seen.insert(fields[1].uppercased()).inserted
                else { continue }
                out.append(fields[1])
            }
        }
        for name in dropped where seen.insert(name.uppercased()).inserted {
            out.append(name)
        }
        return out
    }

     
     
     
    static func geoArtifactBytes(
        kind: String, name: String, container: URL?
    ) -> Int64? {
        guard let container else { return nil }
        let dir = kind == "GEOIP" ? "compiled-geoip" : "compiled-geosite"
        let url = container
            .appendingPathComponent("working/\(dir)")
            .appendingPathComponent(name.lowercased() + ".mrs")
        guard let size = (try? FileManager.default.attributesOfItem(
            atPath: url.path
        )[.size]) as? NSNumber else { return nil }
        return size.int64Value
    }

     
     
     
     
     
     
     
    static func effectiveYAML(container: URL?) -> String? {
        guard let container else { return nil }
        return try? String(
            contentsOf: container.appendingPathComponent(
                "working/active/config.yaml"
            ),
            encoding: .utf8
        )
    }

     
     
     
     
    static func stagedFileSizes(
        kind: String, container: URL?
    ) -> [String: Int64] {
        guard let container else { return [:] }
        let active = container
            .appendingPathComponent("working/active/config.yaml")
        guard let yaml = try? String(contentsOf: active, encoding: .utf8),
              let providers = root(yaml)?[kind] as? [String: Any]
        else { return [:] }
        var out: [String: Int64] = [:]
        for (name, def) in providers {
            guard let path = (def as? [String: Any])?["path"] as? String
            else { continue }
            let url = path.hasPrefix("/")
                ? URL(fileURLWithPath: path)
                : container.appendingPathComponent("working/active")
                    .appendingPathComponent(path)
            if let size = (try? FileManager.default.attributesOfItem(
                atPath: url.path
            )[.size]) as? NSNumber {
                out[name] = size.int64Value
            }
        }
        return out
    }

    private static func root(_ sourceYAML: String?) -> [String: Any]? {
        guard let yaml = sourceYAML,
              let json = try? ConfigTransforms.yamlToJSON(yaml)
        else { return nil }
        return (try? JSONSerialization.jsonObject(
            with: Data(json.utf8)
        )) as? [String: Any]
    }
}
