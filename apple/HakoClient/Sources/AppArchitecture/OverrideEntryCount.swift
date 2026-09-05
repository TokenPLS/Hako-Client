import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum OverrideEntryCount {

     
    static var renderedKeys: Set<String> {
        Set(UpstreamBoolDefault.table.keys)
            .union(UpstreamTextDefault.table.keys)
            .union(UpstreamNumberDefault.table.keys)
            .union(UpstreamListDefault.table.keys)
    }

     
     
     
    static func keys(for capability: ConfigurationCapabilityID) -> Set<String> {
        guard let placement = ConfigurationSurfaceCatalog.configCapabilities
            .first(where: { $0.id == capability })
        else { return [] }
        let owned = placement.sourceKeys
        return renderedKeys.filter { key in
            owned.contains { key == $0 || key.hasPrefix("\($0).") }
        }
    }

     
    static func count(for capability: ConfigurationCapabilityID, in patchJSON: String) -> Int {
        let overridden = overriddenKeys(in: patchJSON)
        return keys(for: capability).filter(overridden.contains).count
    }

     
     
     
     
    static let moreDestinations: [HakoMoreDestination: ConfigurationCapabilityID] = [
        .tunnelAndRoutes: .tunnelAndAddressing,
        .coreBehavior: .advancedRuntime,
        .dnsAndHosts: .dnsAndHosts,
    ]

     
     
    static func moreCounts(in patchJSON: String) -> [HakoMoreDestination: Int] {
        let overridden = overriddenKeys(in: patchJSON)
        guard !overridden.isEmpty else { return [:] }
        return moreDestinations.compactMapValues { capability in
            let count = keys(for: capability).filter(overridden.contains).count
            return count > 0 ? count : nil
        }
    }

     
     
     
    static func overriddenKeys(in patchJSON: String) -> Set<String> {
         
         
        guard !patchJSON.isEmpty,
              let data = patchJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var keys: Set<String> = []
        for (key, value) in root {
            keys.insert(key)
            guard let child = value as? [String: Any] else { continue }
            for (childKey, childValue) in child {
                keys.insert("\(key).\(childKey)")
                guard let grandchild = childValue as? [String: Any] else { continue }
                for grandchildKey in grandchild.keys {
                    keys.insert("\(key).\(childKey).\(grandchildKey)")
                }
            }
        }
        return keys
    }
}
