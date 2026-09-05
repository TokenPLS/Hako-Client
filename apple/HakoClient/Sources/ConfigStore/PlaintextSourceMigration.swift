import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum PlaintextSourceMigration {
    struct Result: Equatable {
        var converted: [String] = []
        var skipped: [String] = []
         
         
         
         
        var registryWriteFailed = false
    }

     
    static func needsConversion(_ profile: Profile) -> Bool {
        profile.sourceCredentials?.isEmpty == false
            || profile.proxyCredentials?.isEmpty == false
            || profile.providerDefinitionCredentials?.isEmpty == false
    }

    @discardableResult
    static func run(
        profileStore: ProfileStore,
        workingDir: URL,
        credentials: CredentialStore
    ) -> Result {
        var result = Result()
        guard case .readable(let profiles) = profileStore.state() else {
             
             
            return result
        }
        var updated: [Profile] = []
        var changed = false

        for profile in profiles {
            guard needsConversion(profile) else {
                updated.append(profile)
                continue
            }
            switch convert(
                profile,
                workingDir: workingDir,
                credentials: credentials
            ) {
            case .success(let plain):
                updated.append(plain)
                result.converted.append(profile.id)
                changed = true
            case .failure:
                 
                 
                 
                 
                 
                 
                var stranded = profile
                if case .url = profile.source {
                    stranded.subscriptionETag = nil
                    stranded.subscriptionLastModified = nil
                    changed = true
                }
                updated.append(stranded)
                result.skipped.append(profile.id)
            }
        }

        if changed {
            do {
                try profileStore.save(updated)
            } catch {
                 
                 
                 
                 
                 
                 
                 
                result.skipped.append(contentsOf: result.converted)
                result.converted.removeAll()
                result.registryWriteFailed = true
                return result
            }
             
             
            for profile in profiles where result.converted.contains(profile.id) {
                try? ProxyCredentialVault.remove(
                    profile.proxyCredentials ?? [],
                    store: credentials
                )
                try? ProxyCredentialVault.remove(
                    profile.sourceCredentials ?? [],
                    store: credentials
                )
                try? ProviderDefinitionCredentialVault.remove(
                    profile.providerDefinitionCredentials ?? [],
                    store: credentials
                )
            }
        }
        return result
    }

    private static func convert(
        _ profile: Profile,
        workingDir: URL,
        credentials: CredentialStore
    ) -> Swift.Result<Profile, Error> {
        let sidecar = workingDir
            .appendingPathComponent("store/\(profile.id)/source.yaml")
        var plain = profile

        if let references = profile.sourceCredentials ?? profile.proxyCredentials,
           !references.isEmpty {
            guard let redacted = try? String(contentsOf: sidecar, encoding: .utf8) else {
                 
                 
                 
                return .failure(MigrationError.noSource(profile.id))
            }
            guard let hydrated = try? ProxyCredentialVault.inject(
                into: redacted,
                references: references,
                store: credentials
            ) else {
                return .failure(MigrationError.credentialsUnavailable(profile.id))
            }
            do {
                try Data(hydrated.utf8).write(
                    to: sidecar,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            } catch {
                return .failure(error)
            }
        }

        if let references = profile.providerDefinitionCredentials,
           !references.isEmpty,
           let source = profile.providerDefinitions, !source.isEmpty {
            var restored = ProfileProviderDefinitionSpec()
            for kind in ProfileProviderKind.allCases {
                let mutations = kind == .proxy
                    ? source.proxyProviders
                    : source.ruleProviders
                for mutation in mutations {
                    guard let definitionJSON = mutation.definitionJSON else {
                         
                        restored.deleteDefinition(named: mutation.name, kind: kind)
                        continue
                    }
                    guard let hydrated = try? ProviderDefinitionCredentialVault
                        .hydrateDefinition(
                            definitionJSON,
                            references: references.filter {
                                $0.providerKind == kind && $0.provider == mutation.name
                            },
                            store: credentials
                        ),
                        (try? restored.setDefinition(
                            hydrated,
                            named: mutation.name,
                            kind: kind
                        )) != nil
                    else {
                        return .failure(
                            MigrationError.credentialsUnavailable(profile.id)
                        )
                    }
                }
            }
            plain.providerDefinitions = restored.isEmpty ? nil : restored
        }

        plain.proxyCredentials = nil
        plain.sourceCredentials = nil
        plain.providerDefinitionCredentials = nil
        plain.sourceCredentialsRedacted = false
        return .success(plain)
    }

    enum MigrationError: LocalizedError, Equatable {
        case noSource(String)
        case credentialsUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .noSource(let id):
                return "\(id) has no stored source to put credentials back into."
            case .credentialsUnavailable(let id):
                return "\(id) is missing a saved credential, so it was left as it was."
            }
        }
    }
}
