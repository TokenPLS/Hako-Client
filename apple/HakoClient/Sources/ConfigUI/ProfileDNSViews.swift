import HakoClientUI
import SwiftUI

 
 
 
struct ProfileDNSSettingsAdapter: View {
    let profile: Profile
    var command: ClashCommandClient?
    var sourceYAML: String?
    var saveHosts: ((ProfileHostsDraft) throws -> Void)?
     
     
    var openDNSQuery: (() -> Void)?
    var ownsNavigationContainer = true
    let save: (ProfileDNSDraft) throws -> Void

    init(
        profile: Profile,
        command: ClashCommandClient? = nil,
        sourceYAML: String? = nil,
        saveHosts: ((ProfileHostsDraft) throws -> Void)? = nil,
        openDNSQuery: (() -> Void)? = nil,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileDNSDraft) throws -> Void
    ) {
        self.profile = profile
        self.command = command
        self.sourceYAML = sourceYAML
        self.saveHosts = saveHosts
        self.openDNSQuery = openDNSQuery
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
         
         
         
         
         
        _derived = State(initialValue: Self.cachedDerivation(for: Self.derivationKey(profile: profile, sourceYAML: sourceYAML)))
    }

     
     
     
     
     
     
    @State private var observed: [String: [String]] = [:]
     
     
     
     
     
     
     
    @State private var derived: DNSDerivation?

    struct DNSDerivation: Equatable {
        var hosts: [String: [String]]
        var domainRuleSets: [String]
        var inheritedFacts: ProfileSourceDNSFacts.Facts
         
         
         
         
         
         
        var inheritedBases: HakoDNSInheritedBases
         
         
         
         
         
        var platformRows: [HakoDNSManagementRow]?
        var platformFooter: String?
    }

     
     
     
     
     
    private var derivationKey: String {
        Self.derivationKey(profile: profile, sourceYAML: sourceYAML)
    }

    private nonisolated static func derivationKey(profile: Profile, sourceYAML: String?) -> String {
        "\(profile.id)|\(profile.override.patchJSON.count)|\(profile.override.patchJSON.hashValue)|\(sourceYAML?.count ?? 0)"
    }

     
     
     
     
     
     
     
     
     
    private static let derivationLock = NSLock()
    nonisolated(unsafe) private static var derivations: [(key: String, value: DNSDerivation)] = []

     
     
     
     
     
     
     
     
    nonisolated static func prewarm(
        profile: Profile, sourceYAML: String?, sidecar: String?
    ) async {
        let key = derivationKey(profile: profile, sourceYAML: sourceYAML)
        if cachedDerivation(for: key) != nil { return }
        let value = derive(
            profile: profile, sourceYAML: sourceYAML, sidecar: sidecar
        )
        remember(value, for: key)
    }

     
     
    nonisolated static func sidecarYAML(profileID: String) -> String? {
        guard let container = HakoAppIdentifiers.appGroupContainer
        else { return nil }
        let sidecar = container
            .appendingPathComponent("working/store/\(profileID)/source.yaml")
        return try? String(contentsOf: sidecar, encoding: .utf8)
    }

    nonisolated static func cachedDerivation(for key: String) -> DNSDerivation? {
        derivationLock.lock()
        defer { derivationLock.unlock() }
        return derivations.first { $0.key == key }?.value
    }

    private nonisolated static func remember(_ value: DNSDerivation, for key: String) {
        derivationLock.lock()
        defer { derivationLock.unlock() }
        derivations.removeAll { $0.key == key }
        derivations.insert((key, value), at: 0)
        if derivations.count > 3 { derivations.removeLast() }
    }

    @MainActor
    private func prepareDerivation() async {
        let key = derivationKey
        if let cached = Self.cachedDerivation(for: key) {
            if derived != cached { derived = cached }
            return
        }
        let profile = profile
        let sourceYAML = sourceYAML
        let sidecar = sidecarYAML(for: profile)
        let value = await Task.detached(priority: .userInitiated) {
            Self.derive(profile: profile, sourceYAML: sourceYAML, sidecar: sidecar)
        }.value
        if Task.isCancelled { return }
        Self.remember(value, for: key)
        derived = value
    }

     
     
     
     
     
    nonisolated static func derive(profile: Profile, sourceYAML: String?, sidecar: String?) -> DNSDerivation {
        let stages = sidecar.flatMap {
            try? ProfileRuntimeConfigBuilder.buildProductionStages(raw: $0, profile: profile, applyProxyChain: false)
        }
        let finished = stages.flatMap { try? $0.finished() }
        var bases = sourceYAML.map(HakoDNSInheritedBases.read(sourceYAML:)) ?? .none
        if let stages {
             
             
             
            bases.profileEnablesDNS = .profile(
                ProfileRuntimeConfigBuilder.hasEnabledOwnDNS(yaml: stages.afterClientTransforms)
            )
        }
        let report = finished.flatMap {
            try? ConfigTransforms.configDeviations(configContent: $0, targetProfile: hakoAppleRuntimeProfile.rawValue)
        }
         
         
         
        let platform = report.map { Self.platformRows(from: $0, locale: .current) }
        return DNSDerivation(
            hosts: ProfileHostsDraft(profile: profile).hosts,
            domainRuleSets: RulePolicyOptions.make(sourceYAML: sourceYAML).domainRuleSets,
            inheritedFacts: ProfileSourceDNSFacts.read(sourceYAML: finished ?? sidecar),
            inheritedBases: bases,
            platformRows: platform?.rows,
            platformFooter: platform?.footer
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func platformRows(
        from report: ConfigDeviationReport,
        locale: Locale = .current
    ) -> (rows: [HakoDNSManagementRow], footer: String?) {
        let dns = report.deviations.filter { $0.configKey == "dns" || $0.configKey.hasPrefix("dns.") }
        let rows = dns.map { deviation in
             
             
             
             
            HakoDNSManagementRow(
                title: deviation.title,
                value: DeviationPlainLanguage.scalar(deviation.effective(locale: locale))
                    ?? deviation.category.displayWord(
                        locale: locale, recoverable: deviation.recoverable
                    )
            )
        }
        var reasons: [String] = []
        for deviation in dns {
            let reason = deviation.reason(locale: locale)
            if !reason.isEmpty && !reasons.contains(reason) { reasons.append(reason) }
        }
        return (rows, reasons.isEmpty ? nil : reasons.joined(separator: " "))
    }

    @ViewBuilder
    var body: some View {
        if ownsNavigationContainer {
            HakoFeatureNavigationContainer {
                content
                    .hakoSheetPresentation()
            }
            .hakoStackNavigationViewStyle()
        } else {
            content
        }
    }

     
     
    private var observationKey: String {
        let hosts = mappedHosts
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.joined(separator: ","))" }
            .joined(separator: ";")
        return "\(command?.isConnected == true)|\(hosts)"
    }

     
     
    private var mappedHosts: [String: [String]] {
        derived?.hosts ?? [:]
    }

    private var content: some View {
        HakoClientUI.HakoDNSSettingsView(
            snapshot: snapshot,
            actions: actions,
            capabilities: capabilities
        ) {
            HakoSymbolImage(symbol: $0)
        } dnsQueryDestination: {
             
             
            if let command {
                DNSQueryView(command: command)
            }
        }
        .task(id: derivationKey) { await prepareDerivation() }
        .task(id: observationKey) {
             
             
            guard command?.isConnected == true, !mappedHosts.isEmpty else {
                observed = [:]
                return
            }
            observed = await Self.observeMappings(mappedHosts)
        }
         
         
         
        .environment(\.hakoDetailCanvas, HakoTheme.canvas)
    }

    private var snapshot: AppleClientSnapshot {
        let connected = command?.isConnected == true
        let hosts = (derived?.hosts ?? [:])
            .sorted { $0.key < $1.key }
            .map { entry -> HakoDNSLocalMapping in
                let answered = observed[entry.key]
                return HakoDNSLocalMapping(
                    domain: entry.key,
                    addresses: entry.value,
                    effect: answered.map { actual in
                        Self.presentable(
                            LocalMappingEffect.status(
                                expected: entry.value,
                                actual: actual,
                                tunnelIsRunning: connected,
                                hasUnappliedChanges: false
                            )
                        )
                    }
                )
            }
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: command?.isConnected == true
                    ? .connected
                    : .disconnected
            ),
            dns: HakoDNSSnapshot(
                 
                profileName: nil,
                draft: DNSOverrideDraft(
                    patchJSON: profile.override.patchJSON,
                    dnsOverridesProfiles:
                        profile.override.dnsOverridesProfiles ?? false
                ).sharedDraft,
                inherited: derived?.inheritedBases ?? .none,
                localMappings: hosts,
                localMappingsAvailable: saveHosts != nil,
                 
                 
                 
                 
                ruleSets: derived?.domainRuleSets ?? [],
                managementTitle: "iOS Management",
                 
                 
                 
                managementRows: derived?.platformRows ?? [
                    HakoDNSManagementRow(
                        title: "DNS service",
                        value: "Enabled by iOS"
                    ),
                    HakoDNSManagementRow(
                        title: "DNS listener",
                        value: "Managed inside VPN"
                    ),
                    HakoDNSManagementRow(
                        title: "Routing mark",
                        value: "Not used on iOS"
                    ),
                ],
                managementFooter:
                    derived?.platformFooter
                        ?? "Clash runs DNS inside the packet tunnel and removes raw listener settings.",
                selfCheckAvailable: command != nil,
                canQueryRuntime:
                    command?.isConnected == true
                        && openDNSQuery != nil
            ),
            capabilities: AppleClientCapabilities([
                .dns: .available,
            ])
        )
    }

    private var actions: AppleClientActions {
        AppleClientActions(capability: .dns) { action in
            guard case .dns(let command) = action else {
                throw AppleClientActionError.adapterFailure(.dns)
            }
            switch command {
            case .openDNSQuery:
                guard let openDNSQuery else {
                    throw AppleClientActionError.unavailable(
                        .dns,
                        .notProvidedByAdapter
                    )
                }
                openDNSQuery()
            case .saveSettings(let value):
                var source = DNSOverrideDraft(
                    patchJSON: profile.override.patchJSON,
                    dnsOverridesProfiles:
                        profile.override.dnsOverridesProfiles ?? false
                )
                source.apply(value)
                var draft = ProfileDNSDraft(profile: profile)
                draft.patchJSON = source.buildPatchJSON()
                draft.dnsOverridesProfiles = source.overrideDNS
                try save(draft)
            case .saveLocalMappings(let mappings):
                guard let saveHosts else {
                    throw AppleClientActionError.unavailable(
                        .dns,
                        .notProvidedByAdapter
                    )
                }
                var draft = ProfileHostsDraft(profile: profile)
                draft.hosts = Dictionary(
                    mappings.map {
                        ($0.domain, $0.addresses)
                    },
                    uniquingKeysWith: { _, latest in latest }
                )
                try saveHosts(draft)
            }
        }
    }

    private var capabilities: HakoDNSCapabilities {
        let commandBox = command.map(DNSCommandCapability.init)
        let selfCheck: HakoDNSCapabilities.SelfCheck?
        if let commandBox {
            selfCheck = {
                await DNSRuntimeSelfCheck.run(
                    using: commandBox.command
                )
            }
        } else {
            selfCheck = nil
        }
        return HakoDNSCapabilities(
            probe: {
                await DNSResolverReachability.shared.probe($0)
            },
             
             
             
             
            resolverSummary: { address in
                HakoPerf.measure("dns.summary") {
                    DNSResolverProbe.endpoint(for: address)?
                        .protocolLabel
                }
            },
            resolverRejectionReason: { address in
                HakoPerf.measure("dns.reject") {
                    DNSServerValidator.rejectionReason(address)
                }
            },
            bootstrapRejectionReason: { address in
                HakoPerf.measure("dns.bootstrap") {
                    DNSServerValidator
                        .defaultNameserverRejectionReason(address)
                }
            },
            isResolverTestable: {
                DNSResolverProbe.untestableReason(for: $0) == nil
            },
            loadGeoValues: { resource in
                await GeoCategoryCache.shared.categories(
                    for: resource == .geoIP
                        ? .geoip
                        : .geosite
                )
            },
            selfCheck: selfCheck,
            inherited: derived?.inheritedFacts.inherited ?? .none,
            ruleProviders: derived?.inheritedFacts.ruleProviders ?? .unknown
        )
    }


    private func sidecarYAML(for profile: Profile) -> String? {
        Self.sidecarYAML(profileID: profile.id)
    }
}

 
 
struct ProfileHostsAdapter: View {
    let profile: Profile
    let save: (ProfileHostsDraft) throws -> Void

    var body: some View {
        HakoFeatureNavigationContainer {
            HakoDNSLocalMappingsView(
                snapshot: snapshot,
                actions: actions
            ) {
                HakoSymbolImage(symbol: $0)
            }
        }
        .hakoStackNavigationViewStyle()
    }

    private var snapshot: AppleClientSnapshot {
        AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: .unavailable
            ),
            dns: HakoDNSSnapshot(
                 
                profileName: nil,
                localMappings: ProfileHostsDraft(
                    profile: profile
                ).hosts.sorted { $0.key < $1.key }.map {
                    HakoDNSLocalMapping(
                        domain: $0.key,
                        addresses: $0.value
                    )
                }
            ),
            capabilities: AppleClientCapabilities([
                .dns: .available,
            ])
        )
    }

    private var actions: AppleClientActions {
        AppleClientActions(capability: .dns) { action in
            guard case .dns(.saveLocalMappings(let mappings)) =
                action
            else {
                throw AppleClientActionError.adapterFailure(.dns)
            }
            var draft = ProfileHostsDraft(profile: profile)
            draft.hosts = Dictionary(
                mappings.map {
                    ($0.domain, $0.addresses)
                },
                uniquingKeysWith: { _, latest in latest }
            )
            try save(draft)
        }
    }
}

private final class DNSCommandCapability:
    @unchecked Sendable
{
    let command: ClashCommandClient

    init(_ command: ClashCommandClient) {
        self.command = command
    }
}

private enum ProfileDNSPreviewFixture {
    static let profile = Profile(
        id: "dns-preview",
        label: "Daily Profile",
        source: .clipboard,
        autoUpdate: false,
        updateIntervalHours: 12,
        subscriptionInfo: nil,
        selectedMap: [:],
        override: OverrideSpec(
            patchJSON:
                #"{"dns":{"enhanced-mode":"fake-ip"},"hosts":{"printer.lan":"192.168.1.10"}}"#
        ),
        activeRevision: nil,
        order: 0,
        lastUpdatedAt: nil
    )
}

extension ProfileDNSSettingsAdapter {
    static func presentable(
        _ status: LocalMappingEffect.Status
    ) -> HakoDNSLocalMappingEffect {
        switch status {
        case .inEffect: return .inEffect
        case .resolvesElsewhere(let actual): return .resolvesElsewhere(actual: actual)
        case .tunnelNotRunning: return .tunnelNotRunning
        case .notYetApplied: return .notYetApplied
        case .nameNotResolved: return .nameNotResolved
        }
    }

     
     
     
     
     
     
     
     
    static func observeMappings(
        _ hosts: [String: [String]]
    ) async -> [String: [String]] {
        await Task.detached(priority: .utility) { () -> [String: [String]] in
            var answers: [String: [String]] = [:]
            for (domain, expected) in hosts {
                var actual = LocalMappingEffect.systemAddresses(for: domain)
                let wanted = Set(expected)
                if Set(actual).isDisjoint(with: wanted) {
                    Thread.sleep(forTimeInterval: 1.0)
                    actual = LocalMappingEffect.systemAddresses(for: domain)
                }
                answers[domain] = actual
            }
            return answers
        }.value
    }
}
