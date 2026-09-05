import Foundation
import HakoClientUI
import Network

enum ProfileBooleanOverride: String, CaseIterable, Identifiable, Equatable {
    case profileDefault
    case enabled
    case disabled

    var id: Self { self }

    init(_ value: Bool?) {
        switch value {
        case .some(true): self = .enabled
        case .some(false): self = .disabled
        case .none: self = .profileDefault
        }
    }

    var boolValue: Bool? {
        switch self {
        case .profileDefault: return nil
        case .enabled: return true
        case .disabled: return false
        }
    }
}

enum ProfileNetworkDraftError: LocalizedError, Equatable {
    case profileChanged
    case invalidKeepAliveIdle
    case invalidKeepAliveInterval
    case invalidSnifferPort(String)
    case invalidAddressPrefix
    case invalidTimeServer
    case invalidTimePort
    case invalidTimeInterval
    case invalidTimeRoute

    var errorDescription: String? {
        switch self {
        case .profileChanged:
            return "This profile changed while its network settings were being edited. Reopen the editor and try again."
        case .invalidKeepAliveIdle:
            return "Keep-Alive idle time must be zero or a positive number of seconds, or empty to use the profile default."
        case .invalidKeepAliveInterval:
            return "Keep-Alive interval must be zero or a positive number of seconds, or empty to use the profile default."
        case .invalidSnifferPort:
            return "Each traffic-recognition port must be between 1 and 65535, optionally written as a valid range."
        case .invalidAddressPrefix:
            return "Skipped source and destination addresses must use valid IPv4 or IPv6 CIDR notation."
        case .invalidTimeServer:
            return "Enter a hostname or IP address for the time server, or leave it empty to use the profile default."
        case .invalidTimePort:
            return "The time server port must be between 1 and 65535, or empty to use the profile default."
        case .invalidTimeInterval:
            return "The time check interval must be a positive number of minutes, or empty to use the profile default."
        case .invalidTimeRoute:
            return "The time service route must be a short, printable policy group or node name."
        }
    }
}

struct ProfileSnifferProtocolDraft: Equatable {
    var ports: [String]
    var overrideDestination: ProfileBooleanOverride

    init(
        ports: [String] = [],
        overrideDestination: ProfileBooleanOverride = .profileDefault
    ) {
        self.ports = ports
        self.overrideDestination = overrideDestination
    }
}

 
 
 
struct ProfileNetworkDraft: Equatable {
    let profileID: String
    var trafficRecognition: ProfileBooleanOverride
    var forceDNSMapping: ProfileBooleanOverride
    var parsePureIP: ProfileBooleanOverride
    var overrideDestination: ProfileBooleanOverride
    var quic: ProfileSnifferProtocolDraft
    var tls: ProfileSnifferProtocolDraft
    var http: ProfileSnifferProtocolDraft
    var forceDomains: [String]
    var skipSourceAddresses: [String]
    var skipDestinationAddresses: [String]
    var skipDomains: [String]
    var legacySniffing: [String]
    var legacyPortWhitelist: [String]
    var ipv6: ProfileBooleanOverride
    var unifiedDelay: ProfileBooleanOverride
    var concurrentTCP: ProfileBooleanOverride
    var disableKeepAlive: ProfileBooleanOverride
    var keepAliveIdleSeconds: Int?
    var keepAliveIntervalSeconds: Int?
    var timeSynchronization: ProfileBooleanOverride
    var timeServer: String?
    var timePort: Int?
    var timeIntervalMinutes: Int?
    var timeDialerProxy: String?
     
     
     
     
    var udpFallbackPolicy: UDPFallbackPolicy?

     
     
    let timeWritesSystemClock = false

     
     
     
     
     
     
     
    private(set) var inherited: [String: InheritedBase] = [:]

     
     
     
     
    static let inheritedKeyPaths: [String] = [
        "ipv6", "unified-delay", "tcp-concurrent", "disable-keep-alive",
        "ntp.enable",
        "sniffer.enable", "sniffer.force-dns-mapping",
        "sniffer.parse-pure-ip", "sniffer.override-destination",
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
        var numbers: [String: InheritedNumberBase] = [:]
        for keyPath in Self.inheritedNumberKeyPaths {
            numbers[keyPath] = root.map { InheritedNumber.base(ofNumber: keyPath, inRoot: $0) } ?? .unset
        }
        inheritedNumber = numbers
        var lists: [String: InheritedListBase] = [:]
        for keyPath in Self.inheritedListKeyPaths {
            lists[keyPath] = root.map { InheritedList.base(ofList: keyPath, inRoot: $0) } ?? .unset
        }
        inheritedList = lists
        inheritedSniffProtocols = root.map(Self.sniffProtocols(inRoot:)) ?? []
    }

     
     
     
     
     
     
     
     
    static let supportedSnifferProtocols = ["TLS", "HTTP", "QUIC"]

     
    static func snifferProtocolError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard supportedSnifferProtocols.contains(trimmed.uppercased()) else {
            return "Use TLS, HTTP or QUIC. Any other name stops the whole profile from starting."
        }
        return nil
    }

     
     
    static func sniffProtocols(in yaml: String) -> Set<String> {
        guard let root = (try? ParsedProfileSource.root(of: yaml)) ?? nil else { return [] }
        return sniffProtocols(inRoot: root)
    }

    static func sniffProtocols(inRoot root: [String: Any]) -> Set<String> {
        guard let sniffer = root["sniffer"] as? [String: Any],
              let sniff = sniffer["sniff"] as? [String: Any]
        else { return [] }
        return Set(sniff.keys.map { $0.uppercased() })
    }

     
     
     
     
     
     
     
     
     
    mutating func reseedInheritedBases(fromBaseDocument yaml: String) {
        let root = (try? ParsedProfileSource.root(of: yaml)) ?? nil
        guard let root else { return }
        for keyPath in Self.inheritedKeyPaths {
            inherited[keyPath] = InheritedBool.base(of: keyPath, inRoot: root)
        }
        for keyPath in Self.inheritedTextKeyPaths {
            inheritedText[keyPath] = InheritedText.base(ofText: keyPath, inRoot: root)
        }
        for keyPath in Self.inheritedNumberKeyPaths {
            inheritedNumber[keyPath] = InheritedNumber.base(ofNumber: keyPath, inRoot: root)
        }
        for keyPath in Self.inheritedListKeyPaths {
            inheritedList[keyPath] = InheritedList.base(ofList: keyPath, inRoot: root)
        }
        inheritedSniffProtocols = Self.sniffProtocols(inRoot: root)
    }

    func inheritedBase(_ keyPath: String) -> InheritedBase {
        inherited[keyPath] ?? .unknown
    }

    private mutating func markInheritedUnknown() {
        inherited = Dictionary(uniqueKeysWithValues: Self.inheritedKeyPaths.map { ($0, .unknown) })
        inheritedText = Dictionary(uniqueKeysWithValues: Self.inheritedTextKeyPaths.map { ($0, .unknown) })
        inheritedNumber = Dictionary(uniqueKeysWithValues: Self.inheritedNumberKeyPaths.map { ($0, .unknown) })
        inheritedList = Dictionary(uniqueKeysWithValues: Self.inheritedListKeyPaths.map { ($0, .unknown) })
    }

     

    private(set) var inheritedText: [String: InheritedTextBase] = [:]
    private(set) var inheritedNumber: [String: InheritedNumberBase] = [:]
    static let inheritedTextKeyPaths: [String] = ["ntp.server", "ntp.dialer-proxy"]
    static let inheritedNumberKeyPaths: [String] = [
        "keep-alive-idle", "keep-alive-interval", "ntp.port", "ntp.interval",
    ]
     
     
     
    static let inheritedListKeyPaths: [String] = [
        "sniffer.force-domain", "sniffer.skip-domain",
        "sniffer.skip-src-address", "sniffer.skip-dst-address",
        "sniffer.port-whitelist", "sniffer.sniffing",
    ]
    private(set) var inheritedList: [String: InheritedListBase] = [:]
    func inheritedListBase(_ keyPath: String) -> InheritedListBase { inheritedList[keyPath] ?? .unknown }

     
     
     
     
    private(set) var inheritedSniffProtocols: Set<String> = []

     
     
     
     
     
     
     
     
     
     
     
     
    var mergedDocumentSniffProtocols: Set<String>?

     
     
    var mergedSniffProtocols: Set<String> {
        var keys = mergedDocumentSniffProtocols ?? inheritedSniffProtocols
        if !quic.ports.isEmpty || quic.overrideDestination != .profileDefault { keys.insert("QUIC") }
        if !tls.ports.isEmpty || tls.overrideDestination != .profileDefault { keys.insert("TLS") }
        if !http.ports.isEmpty || http.overrideDestination != .profileDefault { keys.insert("HTTP") }
        return keys
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var modernSniffIsInPlay: Bool { !mergedSniffProtocols.isEmpty }

     
    func legacyKeyIsLive(_ keyPath: String) -> Bool {
        guard !modernSniffIsInPlay else { return false }
        switch keyPath {
        case "sniffer.sniffing": return true
         
         
        case "sniffer.port-whitelist": return !legacySniffing.isEmpty
        default: return true
        }
    }

    func listOverride(for keyPath: String) -> [String]? {
        let entries: [String]
        switch keyPath {
        case "sniffer.force-domain": entries = forceDomains
        case "sniffer.skip-domain": entries = skipDomains
        case "sniffer.skip-src-address": entries = skipSourceAddresses
        case "sniffer.skip-dst-address": entries = skipDestinationAddresses
        case "sniffer.port-whitelist": entries = legacyPortWhitelist
        case "sniffer.sniffing": entries = legacySniffing
        default: return nil
        }
        return entries.isEmpty ? nil : entries
    }

    mutating func setListOverride(_ value: [String]?, for keyPath: String) {
        let entries = value ?? []
        switch keyPath {
        case "sniffer.force-domain": forceDomains = entries
        case "sniffer.skip-domain": skipDomains = entries
        case "sniffer.skip-src-address": skipSourceAddresses = entries
        case "sniffer.skip-dst-address": skipDestinationAddresses = entries
        case "sniffer.port-whitelist": legacyPortWhitelist = entries
        case "sniffer.sniffing": legacySniffing = entries
        default: break
        }
    }
    func inheritedTextBase(_ keyPath: String) -> InheritedTextBase { inheritedText[keyPath] ?? .unknown }
    func inheritedNumberBase(_ keyPath: String) -> InheritedNumberBase { inheritedNumber[keyPath] ?? .unknown }

    func textOverride(for keyPath: String) -> String? {
        switch keyPath {
        case "ntp.server": return timeServer
        case "ntp.dialer-proxy": return timeDialerProxy
        default: return nil
        }
    }
    mutating func setTextOverride(_ value: String?, for keyPath: String) {
        switch keyPath {
        case "ntp.server": timeServer = value
        case "ntp.dialer-proxy": timeDialerProxy = value
        default: break
        }
    }
    func numberOverride(for keyPath: String) -> Int? {
        switch keyPath {
        case "keep-alive-idle": return keepAliveIdleSeconds
        case "keep-alive-interval": return keepAliveIntervalSeconds
        case "ntp.port": return timePort
        case "ntp.interval": return timeIntervalMinutes
        default: return nil
        }
    }
    mutating func setNumberOverride(_ value: Int?, for keyPath: String) {
        switch keyPath {
        case "keep-alive-idle": keepAliveIdleSeconds = value
        case "keep-alive-interval": keepAliveIntervalSeconds = value
        case "ntp.port": timePort = value
        case "ntp.interval": timeIntervalMinutes = value
        default: break
        }
    }

     
     

    func overrideState(for keyPath: String) -> ProfileBooleanOverride {
        switch keyPath {
        case "ipv6": return ipv6
        case "unified-delay": return unifiedDelay
        case "tcp-concurrent": return concurrentTCP
        case "disable-keep-alive": return disableKeepAlive
        case "ntp.enable": return timeSynchronization
        case "sniffer.enable": return trafficRecognition
        case "sniffer.force-dns-mapping": return forceDNSMapping
        case "sniffer.parse-pure-ip": return parsePureIP
        case "sniffer.override-destination": return overrideDestination
        default: return .profileDefault
        }
    }

    mutating func setOverrideState(_ value: ProfileBooleanOverride, for keyPath: String) {
        switch keyPath {
        case "ipv6": ipv6 = value
        case "unified-delay": unifiedDelay = value
        case "tcp-concurrent": concurrentTCP = value
        case "disable-keep-alive": disableKeepAlive = value
        case "ntp.enable": timeSynchronization = value
        case "sniffer.enable": trafficRecognition = value
        case "sniffer.force-dns-mapping": forceDNSMapping = value
        case "sniffer.parse-pure-ip": parsePureIP = value
        case "sniffer.override-destination": overrideDestination = value
        default: break
        }
    }

     
     
    func hasOverrides(keyPaths: [String]) -> Bool {
        keyPaths.contains {
            overrideState(for: $0) != .profileDefault
                || textOverride(for: $0) != nil
                || numberOverride(for: $0) != nil
        }
    }

     
     
    func clearingOverrides(keyPaths: [String]) -> Self {
        var copy = self
        for keyPath in keyPaths {
            copy.setOverrideState(.profileDefault, for: keyPath)
            copy.setTextOverride(nil, for: keyPath)
            copy.setNumberOverride(nil, for: keyPath)
        }
        return copy
    }

    init(profile: Profile) {
        profileID = profile.id
        udpFallbackPolicy = profile.udpFallbackPolicy
        let patch = OverridePatch(patchJSON: profile.override.patchJSON)
        trafficRecognition = ProfileBooleanOverride(patch.snifferEnabled)
        forceDNSMapping = ProfileBooleanOverride(patch.snifferGet("force-dns-mapping") as Bool?)
        parsePureIP = ProfileBooleanOverride(patch.snifferGet("parse-pure-ip") as Bool?)
        overrideDestination = ProfileBooleanOverride(patch.snifferGet("override-destination") as Bool?)
        quic = Self.protocolDraft("QUIC", patch: patch)
        tls = Self.protocolDraft("TLS", patch: patch)
        http = Self.protocolDraft("HTTP", patch: patch)
        forceDomains = patch.snifferGet("force-domain") ?? []
        skipSourceAddresses = patch.snifferGet("skip-src-address") ?? []
        skipDestinationAddresses = patch.snifferGet("skip-dst-address") ?? []
        skipDomains = patch.snifferGet("skip-domain") ?? []
        legacySniffing = patch.snifferGet("sniffing") ?? []
        legacyPortWhitelist = patch.snifferGet("port-whitelist") ?? []
        ipv6 = ProfileBooleanOverride(patch.ipv6)
        unifiedDelay = ProfileBooleanOverride(patch.unifiedDelay)
        concurrentTCP = ProfileBooleanOverride(patch.tcpConcurrent)
        disableKeepAlive = ProfileBooleanOverride(patch.disableKeepAlive)
        keepAliveIdleSeconds = patch.keepAliveIdle
        keepAliveIntervalSeconds = patch.keepAliveInterval
        timeSynchronization = ProfileBooleanOverride(patch.ntpGet("enable") as Bool?)
        timeServer = patch.ntpGet("server")
        timePort = patch.ntpGet("port")
        timeIntervalMinutes = patch.ntpGet("interval")
        timeDialerProxy = patch.ntpGet("dialer-proxy")
    }

    var customizedFieldCount: Int {
        [
            trafficRecognition, forceDNSMapping, parsePureIP,
            overrideDestination, ipv6, unifiedDelay, concurrentTCP,
            disableKeepAlive,
            quic.overrideDestination, tls.overrideDestination,
            http.overrideDestination,
        ]
            .filter { $0 != .profileDefault }.count
            + (keepAliveIdleSeconds == nil ? 0 : 1)
            + (keepAliveIntervalSeconds == nil ? 0 : 1)
            + (timeSynchronization == .profileDefault ? 0 : 1)
            + (timeServer == nil ? 0 : 1)
            + (timePort == nil ? 0 : 1)
            + (timeIntervalMinutes == nil ? 0 : 1)
            + (timeDialerProxy == nil ? 0 : 1)
            + [
                quic.ports, tls.ports, http.ports, forceDomains,
                skipSourceAddresses, skipDestinationAddresses, skipDomains,
                legacySniffing, legacyPortWhitelist,
            ].filter { !$0.isEmpty }.count
    }

    var customizedSnifferFieldCount: Int {
        [
            trafficRecognition, forceDNSMapping, parsePureIP,
            overrideDestination, quic.overrideDestination,
            tls.overrideDestination, http.overrideDestination,
        ].filter { $0 != .profileDefault }.count
            + [
                quic.ports, tls.ports, http.ports, forceDomains,
                skipSourceAddresses, skipDestinationAddresses, skipDomains,
                legacySniffing, legacyPortWhitelist,
            ].filter { !$0.isEmpty }.count
    }

    var customizedProfileFieldCount: Int {
        customizedSnifferFieldCount
            + (timeSynchronization == .profileDefault ? 0 : 1)
            + (timeServer == nil ? 0 : 1)
            + (timePort == nil ? 0 : 1)
            + (timeIntervalMinutes == nil ? 0 : 1)
            + (timeDialerProxy == nil ? 0 : 1)
    }

     
     
     
    func applyingGlobalRuntime(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileNetworkDraftError.profileChanged
        }
        if let keepAliveIdleSeconds, keepAliveIdleSeconds < 0 {
            throw ProfileNetworkDraftError.invalidKeepAliveIdle
        }
        if let keepAliveIntervalSeconds, keepAliveIntervalSeconds < 0 {
            throw ProfileNetworkDraftError.invalidKeepAliveInterval
        }

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        patch.ipv6 = ipv6.boolValue
        patch.unifiedDelay = unifiedDelay.boolValue
        patch.tcpConcurrent = concurrentTCP.boolValue
        patch.disableKeepAlive = disableKeepAlive.boolValue
        patch.keepAliveIdle = keepAliveIdleSeconds
        patch.keepAliveInterval = keepAliveIntervalSeconds
        settings.override.patchJSON = patch.patchJSON
        return facade.applying(settings, to: profile)
    }

    func applying(
        to profile: Profile,
        facade: ProfileSettingsAccessing = ProfileSettingsFacade()
    ) throws -> Profile {
        guard profile.id == profileID else {
            throw ProfileNetworkDraftError.profileChanged
        }
        if let keepAliveIdleSeconds, keepAliveIdleSeconds < 0 {
            throw ProfileNetworkDraftError.invalidKeepAliveIdle
        }
        if let keepAliveIntervalSeconds, keepAliveIntervalSeconds < 0 {
            throw ProfileNetworkDraftError.invalidKeepAliveInterval
        }
        for token in quic.ports + tls.ports + http.ports + legacyPortWhitelist {
            guard Self.isValidPortToken(token) else {
                throw ProfileNetworkDraftError.invalidSnifferPort(token)
            }
        }
        guard (skipSourceAddresses + skipDestinationAddresses)
            .allSatisfy(Self.isValidAddressPrefix) else {
            throw ProfileNetworkDraftError.invalidAddressPrefix
        }
        let normalizedTimeServer = timeServer?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTimeServer,
           !normalizedTimeServer.isEmpty,
           !Self.isValidTimeServer(normalizedTimeServer) {
            throw ProfileNetworkDraftError.invalidTimeServer
        }
        if let timePort, !(1...65_535).contains(timePort) {
            throw ProfileNetworkDraftError.invalidTimePort
        }
        if let timeIntervalMinutes, timeIntervalMinutes <= 0 {
            throw ProfileNetworkDraftError.invalidTimeInterval
        }
        let normalizedTimeRoute = timeDialerProxy?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTimeRoute,
           !normalizedTimeRoute.isEmpty,
           !Self.isValidTimeRoute(normalizedTimeRoute) {
            throw ProfileNetworkDraftError.invalidTimeRoute
        }

        var settings = facade.snapshot(for: profile)
        var patch = OverridePatch(patchJSON: settings.override.patchJSON)
        patch.snifferEnabled = trafficRecognition.boolValue
        patch.snifferSet("force-dns-mapping", forceDNSMapping.boolValue)
        patch.snifferSet("parse-pure-ip", parsePureIP.boolValue)
        patch.snifferSet("override-destination", overrideDestination.boolValue)
        Self.apply(quic, protocolID: "QUIC", patch: &patch)
        Self.apply(tls, protocolID: "TLS", patch: &patch)
        Self.apply(http, protocolID: "HTTP", patch: &patch)
        patch.snifferSet("force-domain", forceDomains.isEmpty ? nil : forceDomains)
        patch.snifferSet("skip-src-address", skipSourceAddresses.isEmpty ? nil : skipSourceAddresses)
        patch.snifferSet("skip-dst-address", skipDestinationAddresses.isEmpty ? nil : skipDestinationAddresses)
        patch.snifferSet("skip-domain", skipDomains.isEmpty ? nil : skipDomains)
        patch.snifferSet("sniffing", legacySniffing.isEmpty ? nil : legacySniffing)
        patch.snifferSet("port-whitelist", legacyPortWhitelist.isEmpty ? nil : legacyPortWhitelist)
        patch.ipv6 = ipv6.boolValue
        patch.unifiedDelay = unifiedDelay.boolValue
        patch.tcpConcurrent = concurrentTCP.boolValue
        patch.disableKeepAlive = disableKeepAlive.boolValue
        patch.keepAliveIdle = keepAliveIdleSeconds
        patch.keepAliveInterval = keepAliveIntervalSeconds
        patch.ntpSet("enable", timeSynchronization.boolValue)
        patch.ntpSet(
            "server",
            normalizedTimeServer?.isEmpty == false ? normalizedTimeServer : nil
        )
        patch.ntpSet("port", timePort)
        patch.ntpSet("interval", timeIntervalMinutes)
        patch.ntpSet(
            "dialer-proxy",
            normalizedTimeRoute?.isEmpty == false ? normalizedTimeRoute : nil
        )
         
         
        patch.ntpSet("write-to-system", nil as Bool?)
        settings.override.patchJSON = patch.patchJSON
         
         
        var updated = facade.applying(settings, to: profile)
        updated.udpFallbackPolicy = udpFallbackPolicy
        return updated
    }

    private static func protocolDraft(
        _ protocolID: String,
        patch: OverridePatch
    ) -> ProfileSnifferProtocolDraft {
        ProfileSnifferProtocolDraft(
            ports: patch.snifferProtocolGet(protocolID, key: "ports") ?? [],
            overrideDestination: ProfileBooleanOverride(
                patch.snifferProtocolGet(protocolID, key: "override-destination") as Bool?
            )
        )
    }

    private static func apply(
        _ draft: ProfileSnifferProtocolDraft,
        protocolID: String,
        patch: inout OverridePatch
    ) {
        patch.snifferProtocolSet(protocolID, key: "ports", draft.ports.isEmpty ? nil : draft.ports)
        patch.snifferProtocolSet(
            protocolID,
            key: "override-destination",
            draft.overrideDestination.boolValue
        )
    }

    static func isValidPortToken(_ value: String) -> Bool {
        let pieces = value.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(pieces.count),
              let first = Int(pieces[0]), (1...65_535).contains(first) else {
            return false
        }
        guard pieces.count == 2 else { return true }
        guard let last = Int(pieces[1]), (first...65_535).contains(last) else {
            return false
        }
        return true
    }

    static func isValidAddressPrefix(_ value: String) -> Bool {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, let prefixLength = Int(pieces[1]) else { return false }
        let address = String(pieces[0])
        if IPv4Address(address) != nil {
            return (0...32).contains(prefixLength)
        }
        if IPv6Address(address) != nil {
            return (0...128).contains(prefixLength)
        }
        return false
    }

    static func isValidTimeServer(_ value: String) -> Bool {
        guard (1...253).contains(value.utf8.count),
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.whitespacesAndNewlines.contains($0)
                      && !CharacterSet.controlCharacters.contains($0)
              }),
              !value.contains("/") else {
            return false
        }
        if IPv4Address(value) != nil || IPv6Address(value) != nil { return true }
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        return !labels.isEmpty && labels.allSatisfy { label in
            guard (1...63).contains(label.utf8.count),
                  label.first != "-", label.last != "-" else { return false }
            return label.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-"
            }
        }
    }

    static func isValidTimeRoute(_ value: String) -> Bool {
        (1...256).contains(value.utf8.count)
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}
