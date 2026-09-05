import Foundation
import HakoClientUI

enum ProfileAdvancedOverridesError: LocalizedError, Equatable {
    case profileChanged
    case invalidRawPatch
    case scriptRequired
    case scriptUnavailable
    case invalidCustomConfiguration
     
     
    case validationFailed(reason: String?)

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its advanced overrides were being edited. Reopen the editor and try again."
        case .invalidRawPatch:
            return "The raw patch must be a JSON object. The previous configuration remains unchanged."
        case .scriptRequired:
            return "Choose a local script before using Script mode."
        case .scriptUnavailable:
            return "The selected script is no longer available. Choose another script and try again."
        case .invalidCustomConfiguration:
            return "The custom groups or rules are not valid. The previous configuration remains unchanged."
        case let .validationFailed(reason):
             
             
             
             
             
             
             
             
            guard let reason, !reason.isEmpty else {
                return "The generated configuration could not be validated. The previous configuration remains available."
            }
            return HakoCopy.format(
                "The generated configuration could not be validated: %@",
                locale: .current,
                reason
            )
        }
    }
}

 
 
 
 
 
 
struct ProfileAdvancedOverridesDraft: Equatable {
    let profileID: String
    var mode: Profile.OverwriteMode
    var rawPatchJSON: String
    var selectedScriptID: String?
    var customOverwrite: CustomOverwriteSpec

    init(profile: Profile) {
        profileID = profile.id
        mode = profile.overwriteMode ?? .standard
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if (try? Self.patchObject(profile.override.patchJSON)) != nil {
            rawPatchJSON = Self.prettyJSON(
                OverridePatch(patchJSON: profile.override.patchJSON)
                    .profileOwnedPatch
                    .patchJSON
            )
        } else {
            rawPatchJSON = Self.prettyJSON(profile.override.patchJSON)
        }
        selectedScriptID = profile.selectedScriptID
        customOverwrite = profile.customOverwrite ?? CustomOverwriteSpec()
    }

    var rawPatchFieldCount: Int {
        guard let object = try? Self.patchObject(rawPatchJSON) else { return 0 }
        return object.count
    }

    func applying(
        to profile: Profile,
        availableScriptIDs: Set<String>,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileAdvancedOverridesError.profileChanged
        }

        var settings = facade.snapshot(for: profile)
        settings.overwriteMode = mode
        settings.selectedScriptID = selectedScriptID
        settings.customOverwrite = customOverwrite

        switch mode {
        case .standard:
             
             
             
             
            var merged = OverridePatch(patchJSON: try Self.canonicalPatch(rawPatchJSON))
            merged.overlayTopLevelKeys(
                OverridePatch.globalRuntimeKeys,
                from: OverridePatch(patchJSON: profile.override.patchJSON)
            )
            settings.override.patchJSON = merged.patchJSON
        case .script:
            guard let selectedScriptID else {
                throw ProfileAdvancedOverridesError.scriptRequired
            }
            guard availableScriptIDs.contains(selectedScriptID) else {
                throw ProfileAdvancedOverridesError.scriptUnavailable
            }
        case .custom:
            do {
                try Self.validateCustom(customOverwrite)
            } catch {
                throw ProfileAdvancedOverridesError.invalidCustomConfiguration
            }
        }

        return facade.applying(settings, to: profile)
    }

    private static func validateCustom(_ value: CustomOverwriteSpec) throws {
        try value.validate()
         
         
        let names = value.proxyGroups.map(\.name)
        guard names.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(names).count == names.count else {
            throw ProfileAdvancedOverridesError.invalidCustomConfiguration
        }
    }

    private static func canonicalPatch(_ raw: String) throws -> String {
        do {
            let object = try patchObject(raw)
            guard !object.isEmpty else { return "" }
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw ProfileAdvancedOverridesError.invalidRawPatch
        }
    }

    private static func patchObject(_ raw: String) throws -> [String: Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
                as? [String: Any] else {
            throw ProfileAdvancedOverridesError.invalidRawPatch
        }
        return object
    }

    private static func prettyJSON(_ raw: String) -> String {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{}"
        }
        guard let object = try? patchObject(raw),
              let data = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ) else {
             
             
            return raw
        }
        return String(decoding: data, as: UTF8.self)
    }
}

enum ProfileRuntimeTrustError: LocalizedError, Equatable {
    case profileChanged
    case invalidLogLevel
    case invalidUserAgent
    case invalidGeositeMatcher
    case invalidFingerprint
    case invalidCertificate
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its runtime settings were being edited. Reopen the editor and try again."
        case .invalidLogLevel:
            return "Choose a supported log level, or use the profile default."
        case .invalidUserAgent:
            return "Enter a short, printable User-Agent, or use the profile default."
        case .invalidGeositeMatcher:
            return "Choose a supported GeoSite matcher, or use the profile default."
        case .invalidFingerprint:
            return "Each ClientHello fingerprint must be a short, printable value."
        case .invalidCertificate:
            return "Import public PEM certificates only. Private keys are never accepted here."
        case .validationFailed:
            return "The generated configuration could not be validated. The previous configuration remains available."
        }
    }
}

 
 
 
 
 
 
 
struct ProfileRuntimeTrustDraft: Equatable {
    static let supportedLogLevels = ["silent", "error", "warning", "info", "debug"]
    static let supportedGeositeMatchers = ["succinct", "mph", "hybrid"]
    static let serverTLSFields: Set<String> = [
        "certificate", "private-key", "client-auth-type", "client-auth-cert", "ech-key",
    ]

    let profileID: String
    let originalOverwriteMode: Profile.OverwriteMode
    var logLevel: String?
    var userAgent: String?
    var geositeMatcher: String?
    var clientFingerprints: [String]?
    var disableQUICGSO: ProfileBooleanOverride
    var disableQUICECN: ProfileBooleanOverride
    var enableIPv4ToIPv6Conversion: ProfileBooleanOverride
    var customTrustCertificates: [String]?
    let hasUnsupportedServerTLSFields: Bool

     
     
     
     
     
     
    var fakeIPPersistence: ProfileBooleanOverride

     
     
    private(set) var inherited: [String: InheritedBase] = [:]
    static let inheritedKeyPaths: [String] = [
        "experimental.quic-go-disable-gso",
        "experimental.quic-go-disable-ecn",
        "experimental.dialer-ip4p-convert",
         
         
         
         
         
        "profile.store-fake-ip",
    ]
    init(profile: Profile, sourceYAML: String?) {
        self.init(profile: profile)
        guard let sourceYAML else {
             
             
            markInheritedUnknown()
            return
        }
        let root = (try? ParsedProfileSource.root(of: sourceYAML)) ?? nil
        var map: [String: InheritedBase] = [:]
        for keyPath in Self.inheritedKeyPaths {
            map[keyPath] = root.map { InheritedBool.base(of: keyPath, inRoot: $0) } ?? .unset
        }
        inherited = map
        var texts: [String: InheritedTextBase] = [:]
        for keyPath in Self.inheritedTextKeyPaths {
            texts[keyPath] = root.map { InheritedText.base(ofText: keyPath, inRoot: $0) } ?? .unset
        }
        inheritedText = texts
    }
    func inheritedBase(_ keyPath: String) -> InheritedBase {
        inherited[keyPath] ?? .unknown
    }

    private mutating func markInheritedUnknown() {
        inherited = Dictionary(uniqueKeysWithValues: Self.inheritedKeyPaths.map { ($0, .unknown) })
        inheritedText = Dictionary(uniqueKeysWithValues: Self.inheritedTextKeyPaths.map { ($0, .unknown) })
    }

    private(set) var inheritedText: [String: InheritedTextBase] = [:]
    static let inheritedTextKeyPaths: [String] = ["log-level", "geosite-matcher"]
    func inheritedTextBase(_ keyPath: String) -> InheritedTextBase { inheritedText[keyPath] ?? .unknown }
    func textOverride(for keyPath: String) -> String? {
        switch keyPath {
        case "log-level": return logLevel
        case "geosite-matcher": return geositeMatcher
        default: return nil
        }
    }
    mutating func setTextOverride(_ value: String?, for keyPath: String) {
        switch keyPath {
        case "log-level": logLevel = value
        case "geosite-matcher": geositeMatcher = value
        default: break
        }
    }

    func overrideState(for keyPath: String) -> ProfileBooleanOverride {
        switch keyPath {
        case "experimental.quic-go-disable-gso": return disableQUICGSO
        case "experimental.quic-go-disable-ecn": return disableQUICECN
        case "experimental.dialer-ip4p-convert": return enableIPv4ToIPv6Conversion
        case "profile.store-fake-ip": return fakeIPPersistence
        default: return .profileDefault
        }
    }

    mutating func setOverrideState(_ value: ProfileBooleanOverride, for keyPath: String) {
        switch keyPath {
        case "experimental.quic-go-disable-gso": disableQUICGSO = value
        case "experimental.quic-go-disable-ecn": disableQUICECN = value
        case "experimental.dialer-ip4p-convert": enableIPv4ToIPv6Conversion = value
        case "profile.store-fake-ip": fakeIPPersistence = value
        default: break
        }
    }

     
     
    func hasOverrides(keyPaths: [String]) -> Bool {
        keyPaths.contains { overrideState(for: $0) != .profileDefault || textOverride(for: $0) != nil }
    }

     
     
    func clearingOverrides(keyPaths: [String]) -> Self {
        var copy = self
        for keyPath in keyPaths {
            copy.setOverrideState(.profileDefault, for: keyPath)
            copy.setTextOverride(nil, for: keyPath)
        }
        return copy
    }

    init(profile: Profile) {
        profileID = profile.id
        originalOverwriteMode = profile.overwriteMode ?? .standard
        let patch = OverridePatch(patchJSON: profile.override.patchJSON)
        logLevel = patch.logLevel
        userAgent = patch.globalUA
        geositeMatcher = patch.geositeMatcher
        fakeIPPersistence = ProfileBooleanOverride(
            patch.profileGet("store-fake-ip") as Bool?
        )
        clientFingerprints = patch.experimentalGet("fingerprints")
        disableQUICGSO = ProfileBooleanOverride(
            patch.experimentalGet("quic-go-disable-gso") as Bool?
        )
        disableQUICECN = ProfileBooleanOverride(
            patch.experimentalGet("quic-go-disable-ecn") as Bool?
        )
        enableIPv4ToIPv6Conversion = ProfileBooleanOverride(
            patch.experimentalGet("dialer-ip4p-convert") as Bool?
        )
        customTrustCertificates = patch.tlsGet("custom-certifactes")
        hasUnsupportedServerTLSFields = patch.tlsContainsAny(Self.serverTLSFields)
    }

    var customizedFieldCount: Int {
        (logLevel == nil ? 0 : 1)
            + (userAgent == nil ? 0 : 1)
            + (geositeMatcher == nil ? 0 : 1)
            + (fakeIPPersistence == .profileDefault ? 0 : 1)
            + (clientFingerprints == nil ? 0 : 1)
            + (disableQUICGSO == .profileDefault ? 0 : 1)
            + (disableQUICECN == .profileDefault ? 0 : 1)
            + (enableIPv4ToIPv6Conversion == .profileDefault ? 0 : 1)
            + (customTrustCertificates == nil ? 0 : 1)
    }

     
     
     
    func applyingGlobalRuntime(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileRuntimeTrustError.profileChanged
        }

        let normalizedLogLevel = logLevel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedLogLevel,
           !Self.supportedLogLevels.contains(normalizedLogLevel)
        {
            throw ProfileRuntimeTrustError.invalidLogLevel
        }
        let normalizedUserAgent = userAgent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedUserAgent,
           !normalizedUserAgent.isEmpty,
           ClientUserAgent.sanitized(normalizedUserAgent) == nil
        {
            throw ProfileRuntimeTrustError.invalidUserAgent
        }
        let normalizedGeositeMatcher = geositeMatcher?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let normalizedGeositeMatcher,
           !Self.supportedGeositeMatchers.contains(
               normalizedGeositeMatcher
           )
        {
            throw ProfileRuntimeTrustError.invalidGeositeMatcher
        }

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        patch.logLevel =
            normalizedLogLevel?.isEmpty == false
                ? normalizedLogLevel : nil
        patch.globalUA = ClientUserAgent.sanitized(
            normalizedUserAgent
        )
        patch.geositeMatcher =
            normalizedGeositeMatcher?.isEmpty == false
                ? normalizedGeositeMatcher : nil
        settings.override.patchJSON = patch.patchJSON
        return facade.applying(settings, to: profile)
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileRuntimeTrustError.profileChanged
        }

        let normalizedLogLevel = logLevel?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedLogLevel,
           !Self.supportedLogLevels.contains(normalizedLogLevel) {
            throw ProfileRuntimeTrustError.invalidLogLevel
        }
        let normalizedUserAgent = userAgent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedUserAgent,
           !normalizedUserAgent.isEmpty,
           ClientUserAgent.sanitized(normalizedUserAgent) == nil {
            throw ProfileRuntimeTrustError.invalidUserAgent
        }
        let normalizedGeositeMatcher = geositeMatcher?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let normalizedGeositeMatcher,
           !Self.supportedGeositeMatchers.contains(normalizedGeositeMatcher) {
            throw ProfileRuntimeTrustError.invalidGeositeMatcher
        }
        let normalizedFingerprints = try Self.normalizedFingerprints(clientFingerprints)
        let normalizedCertificates = try Self.normalizedCertificates(customTrustCertificates)

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        patch.logLevel = normalizedLogLevel?.isEmpty == false ? normalizedLogLevel : nil
        patch.globalUA = ClientUserAgent.sanitized(normalizedUserAgent)
        patch.geositeMatcher = normalizedGeositeMatcher?.isEmpty == false
            ? normalizedGeositeMatcher : nil
         
         
        patch.profileSet("store-fake-ip", fakeIPPersistence.boolValue)
        patch.experimentalSet("fingerprints", normalizedFingerprints)
        patch.experimentalSet("quic-go-disable-gso", disableQUICGSO.boolValue)
        patch.experimentalSet("quic-go-disable-ecn", disableQUICECN.boolValue)
        patch.experimentalSet(
            "dialer-ip4p-convert",
            enableIPv4ToIPv6Conversion.boolValue
        )
        patch.tlsSet("custom-certifactes", normalizedCertificates)
        settings.override.patchJSON = patch.patchJSON
         
         
        settings.overwriteMode = .standard
        return facade.applying(settings, to: profile)
    }

    static func fingerprintValidationMessage(_ candidate: String) -> String? {
        do {
            _ = try normalizedFingerprints([candidate])
            return nil
        } catch {
            return ProfileRuntimeTrustError.invalidFingerprint.localizedDescription
        }
    }

    static func normalizedCertificate(_ value: String) throws -> String {
        guard let certificate = try normalizedCertificates([value])?.first else {
            throw ProfileRuntimeTrustError.invalidCertificate
        }
        return certificate
    }

    private static func normalizedFingerprints(_ values: [String]?) throws -> [String]? {
        guard let values else { return nil }
        guard values.count <= 64 else {
            throw ProfileRuntimeTrustError.invalidFingerprint
        }
        var normalized: [String] = []
        for value in values {
            let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...128).contains(candidate.utf8.count),
                  candidate.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw ProfileRuntimeTrustError.invalidFingerprint
            }
            if !normalized.contains(candidate) { normalized.append(candidate) }
        }
        return normalized
    }

    private static func normalizedCertificates(_ values: [String]?) throws -> [String]? {
        guard let values else { return nil }
        guard values.count <= 32 else {
            throw ProfileRuntimeTrustError.invalidCertificate
        }
        var totalBytes = 0
        var normalized: [String] = []
        for value in values {
            let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            totalBytes += candidate.utf8.count
            guard candidate.utf8.count <= 256 * 1_024,
                  totalBytes <= 1_024 * 1_024,
                  candidate.contains("-----BEGIN CERTIFICATE-----"),
                  candidate.contains("-----END CERTIFICATE-----"),
                  !candidate.contains("PRIVATE KEY") else {
                throw ProfileRuntimeTrustError.invalidCertificate
            }
            normalized.append(candidate)
        }
        return normalized
    }
}
