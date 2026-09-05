import Foundation

 
 
 
 
 
 
enum IOSExternalResourceSection: String, Codable, Hashable {
    case proxy
    case proxyProvider
    case ruleProvider
}

enum IOSExternalResourceDisposition: String, Codable, Hashable {
    case publicFileOrInline
    case secretFileOrInline
    case secretInlineOnly
    case managedRuntimeState
    case fileProviderUnavailable
    case bundleArchiveMember
}

enum IOSExternalResourceConfidentiality: String, Codable, Hashable {
    case publicData
    case secret
    case runtimeState
}

struct IOSExternalResourceCapability: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let section: IOSExternalResourceSection
    let proxyTypes: [String]
    let fieldPath: [String]
    let disposition: IOSExternalResourceDisposition
    let confidentiality: IOSExternalResourceConfidentiality
}

enum IOSExternalResourceSource: String, Codable, Hashable {
    case subscription
    case localFile
    case clipboard
}

enum IOSExternalResourceResolution: String, Codable, Hashable {
    case localImportRequired
    case subscriptionCannotReadFile
    case managedRuntimeStateRequired
    case fileProviderUnavailable
    case bundleArchiveRequired
}

 
 
struct IOSExternalResourceFinding: LocalizedError, Codable, Equatable, Hashable {
    let capabilityID: String
    let section: IOSExternalResourceSection
    let fieldPath: [String]
    let resolution: IOSExternalResourceResolution
    let confidentiality: IOSExternalResourceConfidentiality

    var errorDescription: String? {
        let field = fieldPath.joined(separator: ".")
        switch resolution {
        case .localImportRequired:
            return "The local profile references a file for \(field). Import that resource with the configuration, or put its contents inline."
        case .subscriptionCannotReadFile:
            return "This profile references a device file for \(field). Subscriptions and pasted configurations cannot read arbitrary device paths; put the value inline or use a local file import."
        case .managedRuntimeStateRequired:
            return "The \(field) value is runtime state. Hako must manage a private profile-scoped location instead of using an arbitrary path."
        case .fileProviderUnavailable:
            return "External file providers are not available in an imported iOS profile. Use an HTTPS or inline provider."
        case .bundleArchiveRequired:
            return "The rule provider references a member of the rule bundle archive. Clash must materialize the matching bundle before activation."
        }
    }
}

 
 
struct IOSExternalResourceRequirement {
    let capability: IOSExternalResourceCapability
    let proxyName: String
    let rawValue: String
     
     
     
     
    var expectedFormat: String? = nil
}

enum IOSExternalResourceCatalog {
    private static let tlsClientProxyTypes = [
        "anytls", "gost-relay", "http", "hysteria", "hysteria2",
        "socks5", "trojan", "trusttunnel", "tuic", "vless", "vmess",
    ]

    static let entries: [IOSExternalResourceCapability] = [
        capability(
            "proxy.tls.certificate", types: tlsClientProxyTypes,
            path: ["certificate"], disposition: .publicFileOrInline,
            confidentiality: .publicData
        ),
        capability(
            "proxy.tls.private-key", types: tlsClientProxyTypes,
            path: ["private-key"], disposition: .secretFileOrInline,
            confidentiality: .secret
        ),
        capability(
            "proxy.hysteria2.realm.certificate", types: ["hysteria2"],
            path: ["realm-opts", "certificate"], disposition: .publicFileOrInline,
            confidentiality: .publicData
        ),
        capability(
            "proxy.hysteria2.realm.private-key", types: ["hysteria2"],
            path: ["realm-opts", "private-key"], disposition: .secretFileOrInline,
            confidentiality: .secret
        ),
        capability(
            "proxy.vless.download.certificate", types: ["vless"],
            path: ["download-settings", "certificate"], disposition: .publicFileOrInline,
            confidentiality: .publicData
        ),
        capability(
            "proxy.vless.download.private-key", types: ["vless"],
            path: ["download-settings", "private-key"], disposition: .secretFileOrInline,
            confidentiality: .secret
        ),
        capability(
            "proxy.shadowsocks.plugin.certificate", types: ["ss"],
            path: ["plugin-opts", "certificate"], disposition: .publicFileOrInline,
            confidentiality: .publicData
        ),
        capability(
            "proxy.shadowsocks.plugin.private-key", types: ["ss"],
            path: ["plugin-opts", "private-key"], disposition: .secretFileOrInline,
            confidentiality: .secret
        ),
        capability(
            "proxy.snell.obfs.certificate", types: ["snell"],
            path: ["obfs-opts", "certificate"], disposition: .publicFileOrInline,
            confidentiality: .publicData
        ),
        capability(
            "proxy.snell.obfs.private-key", types: ["snell"],
            path: ["obfs-opts", "private-key"], disposition: .secretFileOrInline,
            confidentiality: .secret
        ),
        capability(
            "proxy.ssh.private-key", types: ["ssh"], path: ["private-key"],
            disposition: .secretFileOrInline, confidentiality: .secret
        ),
        capability(
            "proxy.openvpn.ca", types: ["openvpn"], path: ["ca"],
            disposition: .publicFileOrInline, confidentiality: .publicData
        ),
        capability(
            "proxy.openvpn.cert", types: ["openvpn"], path: ["cert"],
            disposition: .publicFileOrInline, confidentiality: .publicData
        ),
        capability(
            "proxy.openvpn.key", types: ["openvpn"], path: ["key"],
            disposition: .secretFileOrInline, confidentiality: .secret
        ),
        capability(
            "proxy.openvpn.tls-crypt", types: ["openvpn"], path: ["tls-crypt"],
            disposition: .secretFileOrInline, confidentiality: .secret
        ),
        capability(
            "proxy.wireguard.private-key", types: ["wireguard"], path: ["private-key"],
            disposition: .secretInlineOnly, confidentiality: .secret
        ),
        capability(
            "proxy.masque.private-key", types: ["masque"], path: ["private-key"],
            disposition: .secretInlineOnly, confidentiality: .secret
        ),
        capability(
            "proxy.tailscale.auth-key", types: ["tailscale"], path: ["auth-key"],
            disposition: .secretInlineOnly, confidentiality: .secret
        ),
        capability(
            "proxy.tailscale.state-dir", types: ["tailscale"], path: ["state-dir"],
            disposition: .managedRuntimeState, confidentiality: .runtimeState
        ),
        IOSExternalResourceCapability(
            id: "proxy-provider.file.path", section: .proxyProvider,
            proxyTypes: [], fieldPath: ["path"],
            disposition: .publicFileOrInline, confidentiality: .publicData
        ),
        IOSExternalResourceCapability(
            id: "rule-provider.file.path", section: .ruleProvider,
            proxyTypes: [], fieldPath: ["path"],
            disposition: .publicFileOrInline, confidentiality: .publicData
        ),
        IOSExternalResourceCapability(
            id: "rule-provider.path-in-bundle", section: .ruleProvider,
            proxyTypes: [], fieldPath: ["path-in-bundle"],
            disposition: .bundleArchiveMember, confidentiality: .publicData
        ),
    ]

    static func inspect(
        root: [String: Any],
        source: IOSExternalResourceSource
    ) -> [IOSExternalResourceFinding] {
        var findings: [IOSExternalResourceFinding] = []
        for requirement in requirements(root: root) {
            switch requirement.capability.disposition {
            case .publicFileOrInline, .secretFileOrInline:
                findings.append(finding(
                    requirement.capability,
                    resolution: source == .localFile
                        ? .localImportRequired
                        : .subscriptionCannotReadFile
                ))
            case .managedRuntimeState:
                findings.append(finding(
                    requirement.capability,
                    resolution: .managedRuntimeStateRequired
                ))
            case .secretInlineOnly, .fileProviderUnavailable, .bundleArchiveMember:
                continue
            }
        }
        findings.append(contentsOf: inspectProviders(
            root["proxy-providers"], section: .proxyProvider, source: source
        ))
        findings.append(contentsOf: inspectProviders(
            root["rule-providers"], section: .ruleProvider, source: source
        ))
        return findings
    }

    static func requirements(root: [String: Any]) -> [IOSExternalResourceRequirement] {
        let proxies = root["proxies"] as? [[String: Any]] ?? []
        var requirements: [IOSExternalResourceRequirement] = []
        for proxy in proxies {
            guard let rawType = proxy["type"] as? String,
                  let proxyName = proxy["name"] as? String,
                  !proxyName.isEmpty else { continue }
            let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            for entry in entries where entry.section == .proxy
                    && entry.proxyTypes.contains(type) {
                guard let raw = value(at: entry.fieldPath, in: proxy) as? String,
                      !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                switch entry.disposition {
                case .publicFileOrInline, .secretFileOrInline:
                    guard !isInlineResource(raw, capability: entry) else { continue }
                    requirements.append(IOSExternalResourceRequirement(
                        capability: entry,
                        proxyName: proxyName,
                        rawValue: raw
                    ))
                case .managedRuntimeState:
                    requirements.append(IOSExternalResourceRequirement(
                        capability: entry,
                        proxyName: proxyName,
                        rawValue: raw
                    ))
                case .secretInlineOnly, .fileProviderUnavailable, .bundleArchiveMember:
                    continue
                }
            }
        }
        requirements.append(contentsOf: providerRequirements(
            root["proxy-providers"],
            section: .proxyProvider
        ))
        requirements.append(contentsOf: providerRequirements(
            root["rule-providers"],
            section: .ruleProvider
        ))
        return requirements
    }

    private static func inspectProviders(
        _ raw: Any?,
        section: IOSExternalResourceSection,
        source: IOSExternalResourceSource
    ) -> [IOSExternalResourceFinding] {
        guard let providers = raw as? [String: Any] else { return [] }
        var findings: [IOSExternalResourceFinding] = []
        for name in providers.keys.sorted() {
            guard let provider = providers[name] as? [String: Any] else { continue }
            let type = (provider["type"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if type == "file", let path = provider["path"] as? String,
               !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let entry = entries.first(where: {
                   $0.section == section && $0.fieldPath == ["path"]
               }) {
                findings.append(finding(
                    entry,
                    resolution: source == .localFile
                        ? .localImportRequired
                        : .subscriptionCannotReadFile
                ))
            }
             
             
             
             
             
             
             
        }
        return findings
    }

    private static func providerRequirements(
        _ raw: Any?,
        section: IOSExternalResourceSection
    ) -> [IOSExternalResourceRequirement] {
        guard let providers = raw as? [String: Any],
              let capability = entries.first(where: {
                  $0.section == section && $0.fieldPath == ["path"]
              }) else { return [] }
        return providers.keys.sorted().compactMap { name in
            guard let provider = providers[name] as? [String: Any],
                  (provider["type"] as? String)?.lowercased() == "file",
                  let path = provider["path"] as? String,
                  !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return IOSExternalResourceRequirement(
                capability: capability,
                proxyName: name,
                rawValue: path,
                expectedFormat: (provider["format"] as? String)?.lowercased()
            )
        }
    }

    private static func capability(
        _ id: String,
        types: [String],
        path: [String],
        disposition: IOSExternalResourceDisposition,
        confidentiality: IOSExternalResourceConfidentiality
    ) -> IOSExternalResourceCapability {
        IOSExternalResourceCapability(
            id: id,
            section: .proxy,
            proxyTypes: types.sorted(),
            fieldPath: path,
            disposition: disposition,
            confidentiality: confidentiality
        )
    }

    private static func finding(
        _ capability: IOSExternalResourceCapability,
        resolution: IOSExternalResourceResolution
    ) -> IOSExternalResourceFinding {
        IOSExternalResourceFinding(
            capabilityID: capability.id,
            section: capability.section,
            fieldPath: capability.fieldPath,
            resolution: resolution,
            confidentiality: capability.confidentiality
        )
    }

    static func value(at path: [String], in root: Any) -> Any? {
        var current: Any = root
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else { return nil }
            current = next
        }
        return current
    }

    static func set(_ value: Any, at path: [String], in root: inout Any) -> Bool {
        guard let head = path.first else { return false }
        if path.count == 1 {
            guard var dictionary = root as? [String: Any] else { return false }
            dictionary[head] = value
            root = dictionary
            return true
        }
        guard var dictionary = root as? [String: Any],
              var child = dictionary[head],
              set(value, at: Array(path.dropFirst()), in: &child) else { return false }
        dictionary[head] = child
        root = dictionary
        return true
    }

    private static func isInlineResource(
        _ value: String,
        capability: IOSExternalResourceCapability
    ) -> Bool {
        let normalized = value.uppercased()
        if capability.confidentiality == .publicData {
            return normalized.contains("-----BEGIN CERTIFICATE-----")
        }
        return normalized.contains("PRIVATE KEY-----")
            || normalized.contains("OPENVPN STATIC KEY V1")
    }
}
