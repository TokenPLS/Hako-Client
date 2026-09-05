import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
enum ProfileSourceDNSFacts {
    struct Facts: Equatable {
         
         
        var proxyServerResolversAllOutbound = false
        var inherited: HakoDNSOverrideDraft.Inherited = .none
        var ruleProviders: HakoDNSRuleProviders = .unknown

        static let unknown = Facts()
    }

     
     
     
     
     
     
     
     
     
    static func read(profile: Profile, sourceYAML: String?) -> Facts {
        guard let sourceYAML else { return .unknown }
        let generated = try? ProfileRuntimeConfigBuilder.buildProduction(
            raw: sourceYAML,
            profile: profile,
            applyProxyChain: false
        )
        return read(sourceYAML: generated ?? sourceYAML)
    }

     
     
    static func read(sourceYAML: String?) -> Facts {
        guard let sourceYAML,
              let json = try? ConfigTransforms.yamlToJSON(sourceYAML),
              let root = try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
              ) as? [String: Any]
        else { return .unknown }

        var facts = Facts()
        if let dns = root["dns"] as? [String: Any] {
            let entries = dns["proxy-server-nameserver"] as? [Any] ?? []
            facts.inherited = .init(proxyServerNameserverCount: entries.count)
             
             
             
            let mainlandMarkers = [
                "223.5.5.5", "223.6.6.6", "119.29.29.29", "119.28.28.28",
                "doh.pub", "alidns.com", "dns.360.cn",
            ]
            let strings = entries.compactMap { $0 as? String }
            facts.proxyServerResolversAllOutbound = !strings.isEmpty
                && !strings.contains { entry in
                    mainlandMarkers.contains { entry.contains($0) }
                }
        }
         
        let declared = root["rule-providers"] as? [String: Any] ?? [:]
        facts.ruleProviders = .known(
            declared.reduce(into: [:]) { result, entry in
                let behavior = (entry.value as? [String: Any])?["behavior"] as? String
                result[entry.key] = behavior?.lowercased() ?? ""
            }
        )
        return facts
    }
}
