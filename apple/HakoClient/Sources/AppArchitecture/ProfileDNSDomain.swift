import Foundation

enum ProfileDNSDraftError: LocalizedError, Equatable {
    case profileChanged
    case invalidLocalMapping

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its DNS settings were being edited. Reopen the editor and try again."
        case .invalidLocalMapping:
            return "Every local mapping needs a domain and an address."
        }
    }
}

 
 
 
 
struct ProfileDNSDraft: Equatable {
    let profileID: String
    var patchJSON: String
     
     
    var dnsOverridesProfiles: Bool?

    init(profile: Profile) {
        profileID = profile.id
        dnsOverridesProfiles = profile.override.dnsOverridesProfiles
        patchJSON = profile.override.patchJSON
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileDNSDraftError.profileChanged
        }

        var settings = facade.snapshot(for: profile)
        var latestPatch = OverridePatch(patchJSON: settings.override.patchJSON)
        latestPatch.replaceDNS(with: OverridePatch(patchJSON: patchJSON))
        settings.override.patchJSON = latestPatch.patchJSON
        return facade.applying(settings, to: profile)
    }
}

 
 
 
struct ProfileHostsDraft: Equatable {
    let profileID: String
     
     
     
    var hosts: [String: [String]]

    init(profile: Profile) {
        profileID = profile.id
        hosts = Self.read(OverridePatch(patchJSON: profile.override.patchJSON).hosts)
    }

    private static func read(_ raw: [String: Any]?) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (domain, value) in raw ?? [:] {
            if let single = value as? String {
                result[domain] = [single]
            } else if let many = value as? [String] {
                result[domain] = many
            }
        }
        return result
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileDNSDraftError.profileChanged
        }

        var normalized: [String: Any] = [:]
        for (rawDomain, rawAddresses) in hosts {
            let domain = rawDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            let addresses = rawAddresses
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !domain.isEmpty, !addresses.isEmpty, normalized[domain] == nil else {
                throw ProfileDNSDraftError.invalidLocalMapping
            }
            normalized[domain] = addresses.count == 1 ? addresses[0] : addresses
        }

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        patch.hosts = normalized
        settings.override.patchJSON = patch.patchJSON
        return facade.applying(settings, to: profile)
    }
}
