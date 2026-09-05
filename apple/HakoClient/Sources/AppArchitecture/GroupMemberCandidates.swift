import Foundation

 
 
 
 
 
 
enum GroupMemberCandidates {
     
     
     
    static func offer(
        proxies: [String],
        groups: [String],
        excluding chosen: [String],
        selfName: String
    ) -> [String] {
         
        let taken = Set(chosen)
        var seen: Set<String> = []
        return (proxies + groups).filter { name in
            guard !name.isEmpty, name != selfName, !taken.contains(name),
                  !seen.contains(name)
            else { return false }
            seen.insert(name)
            return true
        }
    }

     
     
     
     
     
     
     
     
     
    static func validationContext(
        sourceYAML: String?,
        profile: Profile,
        draftGroups: [CustomProxyGroup] = []
    ) -> CustomGroupValidationContext {
        var context = CustomGroupValidationContext(
            nodeNames: [], groupNames: [], providerNames: [],
            siblingGroupNames: []
        )
         
         
         
         
         
         
         
         
         
        var asSaved = profile
        if !draftGroups.isEmpty {
            asSaved.overwriteMode = .custom
            var spec = profile.customOverwrite ?? CustomOverwriteSpec()
            spec.proxyGroups = draftGroups
            asSaved.customOverwrite = spec
        }
        let production = sourceYAML.flatMap { yaml in
            try? ProfileRuntimeConfigBuilder.buildProduction(
                raw: yaml,
                profile: asSaved,
                applyProxyChain: false
            )
        }
         
         
         
         
        guard
            let projected = production
                ?? CustomNodesGroupMaterializer.projectForUI(
                    sourceYAML: sourceYAML,
                    profile: profile,
                    replacingSourceGroups: !draftGroups.isEmpty
                ),
            let inventory = try? ProxyChainSpec.inventory(from: projected)
        else { return context }
        for identity in inventory {
            switch identity.kind {
            case .group:
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                if identity.name == CustomNodesGroupMaterializer.groupName {
                    context.groupNames.insert(identity.name)
                }
            case .proxy:
                context.nodeNames.insert(identity.name)
            case .payloadProxy:
                 
                 
                 
                break
            case .builtin:
                break
            }
        }
        if let json = try? ConfigTransforms.yamlToJSON(projected),
           let root = try? JSONSerialization.jsonObject(with: Data(json.utf8))
               as? [String: Any],
           let providers = root["proxy-providers"] as? [String: Any] {
            context.providerNames.formUnion(providers.keys)
        }
        return context
    }
}
