import Foundation

enum ProfileRulesDraftError: LocalizedError, Equatable {
    case profileChanged
    case unsupportedRule
    case duplicateRule

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its rules were being edited. Reopen the editor and try again."
        case .unsupportedRule:
            return "One or more rules cannot be matched safely on iOS."
        case .duplicateRule:
            return "Each personal rule must be unique."
        }
    }
}

 
 
 
struct ProfileRulesDraft: Equatable {
    let profileID: String
    var rules: [String]
    var prependRules: Bool
     
     
    var disabledRules: Set<String>
     
    var comments: [String: String]

    init(profile: Profile) {
        profileID = profile.id
        rules = profile.override.appendRules
        prependRules = profile.override.prependRules
        disabledRules = Set(profile.override.disabledAppendRules ?? [])
        comments = profile.override.appendRuleComments ?? [:]
    }

     
     
    mutating func replaceRule(at index: Int, with newRule: String) {
        guard rules.indices.contains(index) else { return }
        let oldRule = rules[index]
        rules[index] = newRule
        guard oldRule != newRule else { return }
        if disabledRules.remove(oldRule) != nil {
            disabledRules.insert(newRule)
        }
        if let note = comments.removeValue(forKey: oldRule) {
            comments[newRule] = note
        }
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileRulesDraftError.profileChanged
        }
        guard rules.allSatisfy({
            OverrideRuleValidator.isAllowed($0)
        }) else {
            throw ProfileRulesDraftError.unsupportedRule
        }
        guard Set(rules).count == rules.count else {
            throw ProfileRulesDraftError.duplicateRule
        }

        var settings = facade.snapshot(for: profile)
        settings.override.appendRules = rules
        settings.override.prependRules = prependRules
         
        let kept = disabledRules.intersection(rules)
        settings.override.disabledAppendRules = kept.isEmpty
            ? nil : rules.filter { kept.contains($0) }
        let keptComments = comments.filter { rules.contains($0.key) && !$0.value.isEmpty }
        settings.override.appendRuleComments = keptComments.isEmpty ? nil : keptComments
        return facade.applying(settings, to: profile)
    }
}

enum ProfileSettingsRestageAction: Equatable {
    case persistOnly
    case restageOnly
    case restageAndApply
}

 
 
 
enum ProfileSelectionRuntimePolicy {
    static func shouldApplyToTunnel(vpnStatus: String) -> Bool {
        let status = vpnStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ["connecting", "connected", "reasserting"].contains(status)
    }
}

 
 
enum ProfileSettingsRestagePolicy {
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func action(
        profileID: String,
        activeProfileID: String?,
        vpnStatus: String,
        runtimeAlreadyCarriesChange: Bool = false
    ) -> ProfileSettingsRestageAction {
        guard profileID == activeProfileID else { return .persistOnly }
        let status = vpnStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard ["connected", "reasserting"].contains(status) else {
            return .restageOnly
        }
        return runtimeAlreadyCarriesChange ? .restageOnly : .restageAndApply
    }
}
