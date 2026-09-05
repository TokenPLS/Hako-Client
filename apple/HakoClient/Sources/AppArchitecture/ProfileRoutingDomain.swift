import Foundation
import HakoClientUI
import Network

enum ProfileRoutingDraftError: LocalizedError, Equatable {
    case profileChanged
    case invalidRoutePrefix
    case invalidIPv6Prefix
    case invalidLoopbackAddress
    case invalidRouteSetName
    case invalidTimeout

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its routing settings were being edited. Reopen the editor and try again."
        case .invalidRoutePrefix:
            return "Included and excluded routes must use valid IPv4 or IPv6 CIDR notation."
        case .invalidIPv6Prefix:
            return "Tunnel IPv6 addresses must use valid IPv6 CIDR notation."
        case .invalidLoopbackAddress:
            return "Loopback addresses must be valid IPv4 or IPv6 addresses without a prefix length."
        case .invalidRouteSetName:
            return "Rule-set routes must reference a non-empty IP-CIDR rule provider name."
        case .invalidTimeout:
            return "UDP and ICMP timeouts must be zero or a positive number of seconds, or empty to use the profile default."
        }
    }
}

 
 
 
struct ProfileStringListOverride: Equatable {
    var isOverridden: Bool
    var values: [String]

    init(isOverridden: Bool = false, values: [String] = []) {
        self.isOverridden = isOverridden
        self.values = values
    }

    init(_ value: [String]?) {
        isOverridden = value != nil
        values = value ?? []
    }

    func apply(key: String, to patch: inout OverridePatch) {
        patch.tunSet(key, isOverridden ? values : nil as [String]?)
    }
}

 
 
 
struct ProfileRoutePresetDraft: Equatable {
    let profileID: String
    var preset: RoutePreset
    var customIncludedRoutes: [String]
    var excludedRoutes: ProfileStringListOverride
    var includedRouteSets: ProfileStringListOverride
    var excludedRouteSets: ProfileStringListOverride
    var ipv6Addresses: ProfileStringListOverride
    var loopbackAddresses: ProfileStringListOverride
    var strictRoute: ProfileBooleanOverride
    var endpointIndependentNAT: ProfileBooleanOverride
    var udpTimeoutSeconds: String
    var icmpTimeoutSeconds: String

     
     
    private(set) var inherited: [String: InheritedBase] = [:]
    static let inheritedKeyPaths: [String] = [
        "tun.strict-route", "tun.endpoint-independent-nat",
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
        var lists: [String: InheritedListBase] = [:]
        for keyPath in Self.inheritedListKeyPaths {
            lists[keyPath] = root.map { InheritedList.base(ofList: keyPath, inRoot: $0) } ?? .unset
        }
        inheritedLists = lists
        var numbers: [String: InheritedNumberBase] = [:]
        for keyPath in Self.inheritedNumberKeyPaths {
            numbers[keyPath] = root.map { InheritedNumber.base(ofNumber: keyPath, inRoot: $0) } ?? .unset
        }
        inheritedNumbers = numbers
    }
    func inheritedBase(_ keyPath: String) -> InheritedBase {
        inherited[keyPath] ?? .unknown
    }

     
     
     
     
     
    private mutating func markInheritedUnknown() {
        inherited = Dictionary(uniqueKeysWithValues: Self.inheritedKeyPaths.map { ($0, .unknown) })
        inheritedLists = Dictionary(uniqueKeysWithValues: Self.inheritedListKeyPaths.map { ($0, .unknown) })
        inheritedNumbers = Dictionary(uniqueKeysWithValues: Self.inheritedNumberKeyPaths.map { ($0, .unknown) })
    }

    func overrideState(for keyPath: String) -> ProfileBooleanOverride {
        switch keyPath {
        case "tun.strict-route": return strictRoute
        case "tun.endpoint-independent-nat": return endpointIndependentNAT
        default: return .profileDefault
        }
    }

    mutating func setOverrideState(_ value: ProfileBooleanOverride, for keyPath: String) {
        switch keyPath {
        case "tun.strict-route": strictRoute = value
        case "tun.endpoint-independent-nat": endpointIndependentNAT = value
        default: break
        }
    }

     
     
    func hasOverrides(keyPaths: [String]) -> Bool {
        keyPaths.contains { overrideState(for: $0) != .profileDefault }
    }

     
     
    func clearingOverrides(keyPaths: [String]) -> Self {
        var copy = self
        for keyPath in keyPaths { copy.setOverrideState(.profileDefault, for: keyPath) }
        return copy
    }

     
     
    private(set) var inheritedLists: [String: InheritedListBase] = [:]
    static let inheritedListKeyPaths: [String] = [
        "tun.route-address",
        "tun.route-exclude-address", "tun.route-address-set",
        "tun.route-exclude-address-set", "tun.inet6-address",
        "tun.loopback-address",
    ]
     
     
     
    private(set) var inheritedNumbers: [String: InheritedNumberBase] = [:]
    static let inheritedNumberKeyPaths: [String] = ["tun.udp-timeout"]
    func inheritedNumberBase(_ keyPath: String) -> InheritedNumberBase {
        inheritedNumbers[keyPath] ?? .unset
    }
    func inheritedListBase(_ keyPath: String) -> InheritedListBase {
        inheritedLists[keyPath] ?? .unset
    }

     
     
    func listOverrideState(for keyPath: String) -> ProfileStringListOverride {
        switch keyPath {
        case "tun.route-address":
             
            switch preset {
            case .subscription: return ProfileStringListOverride()
            case .bypassPrivate: return ProfileStringListOverride(isOverridden: true, values: RoutePreset.bypassPrivateRouteAddress)
            case .custom: return ProfileStringListOverride(isOverridden: true, values: customIncludedRoutes)
            }
        case "tun.route-exclude-address": return excludedRoutes
        case "tun.route-address-set": return includedRouteSets
        case "tun.route-exclude-address-set": return excludedRouteSets
        case "tun.inet6-address": return ipv6Addresses
        case "tun.loopback-address": return loopbackAddresses
        default: return ProfileStringListOverride()
        }
    }

    mutating func setListOverrideState(_ value: ProfileStringListOverride, for keyPath: String) {
        switch keyPath {
        case "tun.route-address":
            if value.isOverridden {
                customIncludedRoutes = value.values
                preset = .custom(count: value.values.count)
            } else {
                customIncludedRoutes = []
                preset = .subscription
            }
        case "tun.route-exclude-address": excludedRoutes = value
        case "tun.route-address-set": includedRouteSets = value
        case "tun.route-exclude-address-set": excludedRouteSets = value
        case "tun.inet6-address": ipv6Addresses = value
        case "tun.loopback-address": loopbackAddresses = value
        default: break
        }
    }

     
    func hasListOverrides(keyPaths: [String]) -> Bool {
        keyPaths.contains { listOverrideState(for: $0).isOverridden }
    }

     
    func clearingListOverrides(keyPaths: [String]) -> Self {
        var copy = self
        for keyPath in keyPaths { copy.setListOverrideState(ProfileStringListOverride(), for: keyPath) }
        return copy
    }

    init(profile: Profile) {
        profileID = profile.id
        let patch = OverridePatch(patchJSON: profile.override.patchJSON)
        preset = RoutePreset.detect(in: patch)
        customIncludedRoutes = patch.tunGet("route-address") ?? []
        excludedRoutes = ProfileStringListOverride(
            patch.tunGet("route-exclude-address") as [String]?
        )
        includedRouteSets = ProfileStringListOverride(
            patch.tunGet("route-address-set") as [String]?
        )
        excludedRouteSets = ProfileStringListOverride(
            patch.tunGet("route-exclude-address-set") as [String]?
        )
        ipv6Addresses = ProfileStringListOverride(
            patch.tunGet("inet6-address") as [String]?
        )
        loopbackAddresses = ProfileStringListOverride(
            patch.tunGet("loopback-address") as [String]?
        )
        strictRoute = ProfileBooleanOverride(patch.tunGet("strict-route") as Bool?)
        endpointIndependentNAT = ProfileBooleanOverride(
            patch.tunGet("endpoint-independent-nat") as Bool?
        )
        udpTimeoutSeconds = Self.timeoutText(patch.tunGet("udp-timeout") as Int?)
        icmpTimeoutSeconds = Self.timeoutText(patch.tunGet("icmp-timeout") as Int?)
    }

    var customizedFieldCount: Int {
        var count = 0
        if preset != .subscription { count += 1 }
        count += [
            excludedRoutes, includedRouteSets, excludedRouteSets,
            ipv6Addresses, loopbackAddresses,
        ].filter(\.isOverridden).count
        count += [strictRoute, endpointIndependentNAT]
            .filter { $0 != .profileDefault }.count
        if !udpTimeoutSeconds.isEmpty { count += 1 }
        if !icmpTimeoutSeconds.isEmpty { count += 1 }
        return count
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileRoutingDraftError.profileChanged
        }

        if case .custom = preset,
           !customIncludedRoutes.allSatisfy(Self.isValidRoutePrefix) {
            throw ProfileRoutingDraftError.invalidRoutePrefix
        }
        if excludedRoutes.isOverridden,
           !excludedRoutes.values.allSatisfy(Self.isValidRoutePrefix) {
            throw ProfileRoutingDraftError.invalidRoutePrefix
        }
        if ipv6Addresses.isOverridden,
           !ipv6Addresses.values.allSatisfy(Self.isValidIPv6Prefix) {
            throw ProfileRoutingDraftError.invalidIPv6Prefix
        }
        if loopbackAddresses.isOverridden,
           !loopbackAddresses.values.allSatisfy(Self.isValidIPAddress) {
            throw ProfileRoutingDraftError.invalidLoopbackAddress
        }
        if [includedRouteSets, excludedRouteSets].contains(where: {
            $0.isOverridden && !$0.values.allSatisfy(Self.isValidRouteSetName)
        }) {
            throw ProfileRoutingDraftError.invalidRouteSetName
        }
        let udpTimeout = try Self.parseTimeout(udpTimeoutSeconds)
        let icmpTimeout = try Self.parseTimeout(icmpTimeoutSeconds)

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        switch preset {
        case .subscription, .bypassPrivate:
            preset.apply(to: &patch)
        case .custom:
            patch.tunSet("route-address", customIncludedRoutes)
        }
        excludedRoutes.apply(key: "route-exclude-address", to: &patch)
        includedRouteSets.apply(key: "route-address-set", to: &patch)
        excludedRouteSets.apply(key: "route-exclude-address-set", to: &patch)
        ipv6Addresses.apply(key: "inet6-address", to: &patch)
        loopbackAddresses.apply(key: "loopback-address", to: &patch)
        patch.tunSet("strict-route", strictRoute.boolValue)
        patch.tunSet("endpoint-independent-nat", endpointIndependentNAT.boolValue)
        patch.tunSet("udp-timeout", udpTimeout)
        patch.tunSet("icmp-timeout", icmpTimeout)
        settings.override.patchJSON = patch.patchJSON
        return facade.applying(settings, to: profile)
    }

    static func isValidRoutePrefix(_ value: String) -> Bool {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, let prefixLength = Int(pieces[1]) else { return false }
        let address = String(pieces[0])
        if IPv4Address(address) != nil { return (0...32).contains(prefixLength) }
        if IPv6Address(address) != nil { return (0...128).contains(prefixLength) }
        return false
    }

    static func isValidIPv6Prefix(_ value: String) -> Bool {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2,
              let prefixLength = Int(pieces[1]),
              IPv6Address(String(pieces[0])) != nil else { return false }
        return (0...128).contains(prefixLength)
    }

    static func isValidIPAddress(_ value: String) -> Bool {
        IPv4Address(value) != nil || IPv6Address(value) != nil
    }

    static func isValidRouteSetName(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func timeoutText(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private static func parseTimeout(_ value: String) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let seconds = Int(trimmed), seconds >= 0 else {
            throw ProfileRoutingDraftError.invalidTimeout
        }
        return seconds
    }
}

 
 
 
struct ProfileProxyChainDraft: Equatable {
    let profileID: String
    var proxyChain: ProxyChainSpec
    var legacyRelayMigrations: [LegacyRelayMigration]

    init(profile: Profile) {
        profileID = profile.id
        proxyChain = profile.proxyChain ?? ProxyChainSpec()
        legacyRelayMigrations = profile.legacyRelayMigrations ?? []
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileRoutingDraftError.profileChanged
        }

        var settings = facade.snapshot(for: profile)
        settings.proxyChain = proxyChain.isEmpty ? nil : proxyChain
        settings.legacyRelayMigrations = legacyRelayMigrations.isEmpty
            ? nil
            : legacyRelayMigrations
        return facade.applying(settings, to: profile)
    }

    func removesLegacyRelayConfirmation(
        requiredBy error: LegacyRelayMigrationError,
        from profile: Profile
    ) -> Bool {
        guard case let .confirmationRequired(group, members, _) = error else {
            return false
        }
        let previous = profile.legacyRelayMigrations ?? []
        return previous.contains {
            $0.groupName == group && $0.members == members
        } && !legacyRelayMigrations.contains {
            $0.groupName == group && $0.members == members
        }
    }
}
