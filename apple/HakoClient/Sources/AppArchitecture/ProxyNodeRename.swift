import Foundation

 
 
 
 
 
 
 
 
 
enum ProxyNodeRename {
     
     
     
    static func apply(
        from old: String,
        to new: String,
        profile: inout Profile,
        customPayload: inout [[String: Any]]
    ) {
        guard old != new, !old.isEmpty, !new.isEmpty else { return }

         
         
        for (group, selected) in profile.selectedMap where selected == old {
            profile.selectedMap[group] = new
        }

         
         
        if var chain = profile.proxyChain {
            chain.assignments = chain.assignments.map { assignment in
                var updated = assignment
                if updated.proxy == old { updated.proxy = new }
                if updated.dialerProxy == old { updated.dialerProxy = new }
                return updated
            }
            profile.proxyChain = chain
        }

         
         
        if var overrides = profile.proxyNodeOverrides {
            overrides.overrides = overrides.overrides.map { entry in
                var updated = entry
                if updated.proxy == old { updated.proxy = new }
                return updated
            }
            profile.proxyNodeOverrides = overrides
        }

         
        customPayload = applying(to: customPayload, from: old, to: new)

         
         
         
         
        profile.override = renamingRules(in: profile.override, from: old, to: new)
        if let migrated = profile.migratedGlobalOverride {
            profile.migratedGlobalOverride = renamingRules(
                in: migrated, from: old, to: new
            )
        }

         
        if var custom = profile.customOverwrite {
            custom.proxyGroups = custom.proxyGroups.map { group in
                var updated = group
                updated.proxies = group.proxies.map { $0 == old ? new : $0 }
                return updated
            }
            custom.rules = custom.rules.map {
                renamingRulePolicy(in: $0, from: old, to: new)
            }
            profile.customOverwrite = custom
        }

         
         
        if var overrides = profile.proxyNodeOverrides {
            overrides.overrides = overrides.overrides.map { entry in
                var updated = entry
                updated.patchJSON = renamingDialerProxy(
                    in: entry.patchJSON, from: old, to: new
                )
                return updated
            }
            profile.proxyNodeOverrides = overrides
        }

         
         
        if var definitions = profile.providerDefinitions {
            definitions.proxyProviders = definitions.proxyProviders.map { mutation in
                var updated = mutation
                if let json = mutation.definitionJSON {
                    updated.definitionJSON = renamingDialerProxy(
                        in: json, from: old, to: new
                    )
                }
                return updated
            }
            profile.providerDefinitions = definitions
        }

         
         
        if let migrations = profile.legacyRelayMigrations {
            profile.legacyRelayMigrations = migrations.map { migration in
                LegacyRelayMigration(
                    groupName: migration.groupName,
                    members: migration.members.map { $0 == old ? new : $0 }
                )
            }
        }
    }

     
     
     
     
     
    static func applying(
        to payload: [[String: Any]], from old: String, to new: String
    ) -> [[String: Any]] {
        guard old != new, !old.isEmpty, !new.isEmpty else { return payload }
        return payload.map { node in
            var updated = node
            if updated["dialer-proxy"] as? String == old {
                updated["dialer-proxy"] = new
            }
            return updated
        }
    }

     
     
     
     
     
     
    static func renamingRules(
        in spec: OverrideSpec, from old: String, to new: String
    ) -> OverrideSpec {
        var updated = spec
        updated.appendRules = spec.appendRules.map {
            renamingRulePolicy(in: $0, from: old, to: new)
        }
        if let disabled = spec.disabledAppendRules {
            updated.disabledAppendRules = disabled.map {
                renamingRulePolicy(in: $0, from: old, to: new)
            }
        }
        if let comments = spec.appendRuleComments {
            var moved: [String: String] = [:]
            for (rule, comment) in comments {
                moved[renamingRulePolicy(in: rule, from: old, to: new)] = comment
            }
            updated.appendRuleComments = moved
        }
        updated.patchJSON = renamingGroupMembers(
            in: spec.patchJSON, from: old, to: new
        )
        return updated
    }

     
     
     
     
     
    static func renamingDialerProxy(
        in json: String, from old: String, to new: String
    ) -> String {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { return json }

        var touched = false
        func walk(_ value: Any) -> Any {
            if var object = value as? [String: Any] {
                for (key, inner) in object {
                    if key == "dialer-proxy", let name = inner as? String, name == old {
                        object[key] = new
                        touched = true
                    } else {
                        object[key] = walk(inner)
                    }
                }
                return object
            }
            if let array = value as? [Any] { return array.map(walk) }
            return value
        }
        let rewritten = walk(root)
        guard touched,
              let encoded = try? JSONSerialization.data(
                withJSONObject: rewritten, options: [.sortedKeys]
              )
        else { return json }
        return String(decoding: encoded, as: UTF8.self)
    }

     
     
     
     
    static func renamingGroupMembers(
        in patchJSON: String, from old: String, to new: String
    ) -> String {
        guard !patchJSON.isEmpty,
              let data = patchJSON.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              var groups = root["proxy-groups"] as? [[String: Any]]
        else { return patchJSON }

        var touched = false
        groups = groups.map { group in
            var updated = group
            if let members = group["proxies"] as? [Any] {
                updated["proxies"] = members.map { member -> Any in
                    if let name = member as? String, name == old {
                        touched = true
                        return new
                    }
                    return member
                }
            }
             
             
            for key in ["default-selected", "empty-fallback"] {
                if let value = group[key] as? String, value == old {
                    updated[key] = new
                    touched = true
                }
            }
            return updated
        }
        guard touched else { return patchJSON }
        root["proxy-groups"] = groups
        guard let encoded = try? JSONSerialization.data(
            withJSONObject: root, options: [.sortedKeys]
        ) else { return patchJSON }
        return String(decoding: encoded, as: UTF8.self)
    }

     
     
     
     
    static func renamingRulePolicy(
        in rule: String, from old: String, to new: String
    ) -> String {
        let modifiers: Set<String> = ["no-resolve", "src"]
        var parts = rule.components(separatedBy: ",")
        guard parts.count >= 2 else { return rule }
         
         
         
        if parts[0].trimmingCharacters(in: .whitespaces).uppercased() == "SUB-RULE" {
            return rule
        }
        var index = parts.count - 1
        while index > 0,
              modifiers.contains(
                parts[index].trimmingCharacters(in: .whitespaces).lowercased()
              ) {
            index -= 1
        }
        guard index > 0 else { return rule }
        let policy = parts[index].trimmingCharacters(in: .whitespaces)
        guard policy == old else { return rule }
         
        parts[index] = parts[index].replacingOccurrences(of: policy, with: new)
        return parts.joined(separator: ",")
    }
}
