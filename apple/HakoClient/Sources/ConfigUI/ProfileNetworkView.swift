import HakoClientUI
import SwiftUI

 
struct ProfileNetworkSettingsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
     
     
     
    @Environment(\.locale) private var locale
    let save: (ProfileNetworkDraft) throws -> Void

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileNetworkDraft
     
     
     
    @State private var openedWith: ProfileNetworkDraft
    @State private var timePortText: String
    @State private var timeIntervalText: String
    @State private var error = ""
    private let profileName: String
    private let ownsNavigationContainer: Bool
     
     
     
    private let udpFallbackGuardInput: () async -> ConfigTransforms.UDPFallbackGuardInput?
     
     
    private let profileForDeviations: Profile
    @State private var deviations: ConfigDeviationReport?

    init(
        profile: Profile,
        sourceYAML: String? = nil,
        ownsNavigationContainer: Bool = true,
        udpFallbackGuardInput: @escaping () async -> ConfigTransforms.UDPFallbackGuardInput? = { nil },
        save: @escaping (ProfileNetworkDraft) throws -> Void
    ) {
        let draft = ProfileNetworkDraft(profile: profile, sourceYAML: sourceYAML)
        self.save = save
        profileForDeviations = profile
        profileName = profile.label
        self.ownsNavigationContainer = ownsNavigationContainer
        self.udpFallbackGuardInput = udpFallbackGuardInput
        _draft = State(initialValue: draft)
        _openedWith = State(initialValue: draft)
        _timePortText = State(initialValue: draft.timePort.map(String.init) ?? "")
        _timeIntervalText = State(
            initialValue: draft.timeIntervalMinutes.map(String.init) ?? ""
        )
    }

    @ViewBuilder
    private var udpFallbackDestination: some View {
#if os(macOS)
        HakoDeferredDraftHost(source: $draft.udpFallbackPolicy) { policy in
            UDPFallbackSettingsView(
                policy: policy,
                offersInherit: true,
                overallPolicy: UDPFallbackSettings.policy(),
                guardInput: udpFallbackGuardInput
            )
        }
#else
        UDPFallbackSettingsView(
            policy: $draft.udpFallbackPolicy,
            offersInherit: true,
            overallPolicy: UDPFallbackSettings.policy(),
            guardInput: udpFallbackGuardInput
        )
#endif
    }

     
    @State private var sectionSelection: ProfileNetworkRoute?

     
     
     
    @ViewBuilder
    private func sectionRow<RowLabel: View>(
        _ route: ProfileNetworkRoute,
        @ViewBuilder label: () -> RowLabel
    ) -> some View {
#if os(macOS)
        Button {
            sectionSelection = route
        } label: {
             
             
             
            HStack(spacing: 6) {
                label()
                Image(systemName: HakoSymbol.chevronForward.rawValue)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
#else
        HakoStableNavigationLink(value: route) {
            routeDestination(route)
        } label: {
            label()
        }
#endif
    }

    private func modalTitle(for route: ProfileNetworkRoute) -> String {
        switch route {
        case .sniffer: "Sniffer"
        case .udpFallback: "UDP Fallback"
        case .ntp: "NTP"
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: ProfileNetworkRoute) -> some View {
        switch route {
        case .sniffer:
            ProfileSnifferSettingsView(draft: $draft)
        case .udpFallback:
            udpFallbackDestination
        case .ntp:
            ProfileNTPSettingsView(
                draft: $draft,
                portText: $timePortText,
                intervalText: $timeIntervalText
            )
        }
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            HakoMacSettingsFormContainer {
                Section {
                    HakoProfileContextHeader(
                        profileName: profileName,
                        message:
                            "Sniffer and NTP belong to this profile. App-wide network behavior is under More > Core Settings."
                    ) {
                        HakoSymbolImage(symbol: .profileClipboard)
                    }
                }

                Section {
                    sectionRow(.sniffer) {
                        DNSHubRow(title: "Sniffer",
                                  detail: "Finds the domain behind each connection before rules run",
                                  value: snifferSummary)
                    }
                    .accessibilityIdentifier("profile-network.traffic-recognition")
                } footer: {
                    Text(
                        "Sniffer discovers domains before this profile's rules are evaluated."
                    )
                }

                Section {
                    sectionRow(.udpFallback) {
                         
                         
                        DNSHubRow(
                            title: "UDP Fallback",
                            detail: "",
                            value: udpFallbackSummary
                        )
                    }
                    .accessibilityIdentifier("profile-network.udp-fallback")
                } footer: {
                    Text(
                        "Overrides the client setting for this profile only. Useful when every line in one subscription carries UDP."
                    )
                }

                Section {
                    sectionRow(.ntp) {
                        DNSHubRow(title: "NTP",
                                  detail: "Trusted time for protocol handshakes",
                                  value: ntpSummary)
                    }
                    .accessibilityIdentifier("profile-network.time-synchronization")
                }

                if !error.isEmpty {
                    Section {
                        HakoStatusMessage(text: .copy(error), kind: .error)
                    }
                }
            }
            
            .hakoPageTitle("Profile Network")
             
             
             
             
             
             
             
             
            .hakoStableNavigationDestination(for: ProfileNetworkRoute.self) { route in
                routeDestination(route)
            }
            .hakoFeaturePresentation(
                ownsNavigationContainer: ownsNavigationContainer
            )
#if os(macOS)
             
             
             
             
            .hakoProductModal(item: $sectionSelection, role: .form) { route in
                HakoFeatureNavigationContainer {
                     
                     
                     
                     
                     
                     
                    routeDestination(route)
                         
                         
                         
                        .hakoRegistersDeparture(
                            isDirty: draft != openedWith,
                            save: { completion in
                                persist()
                                completion(true)
                            },
                            discard: { draft = openedWith }
                        )
                        .hakoProductModalRoot(title: modalTitle(for: route))
                }
                .hakoPageSizedSheet()
            }
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if ownsNavigationContainer {
                        Button("Cancel") { closePage() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                     
                     
                    if !insideProductModal {
                        HakoSaveButton { persist() }
                            .accessibilityIdentifier("profile-network.save")
                    }
                }
            }
            ConfigDeviationSection(
                report: deviations,
                fields: RunningCoreDeviations.fields(
                    for: [.trafficRecognition, .timeSynchronization]
                ),
                identifierPrefix: "profile-network.deviation"
            )
        }
        .task(id: RunningCoreDeviations.taskKey(for: profileForDeviations)) {
            let profile = profileForDeviations
             
             
             
             
            let derived = await Task.detached(priority: .userInitiated) {
                () -> (ConfigDeviationReport?, Set<String>?, String?) in
                let sidecar = RunningCoreDeviations.sidecarYAML(for: profile)
                let finished = sidecar.flatMap {
                    try? ProfileRuntimeConfigBuilder.buildProductionStages(
                        raw: $0, profile: profile, applyProxyChain: false
                    ).finished()
                }
                let report = finished.flatMap {
                    try? ConfigTransforms.configDeviations(
                        configContent: $0, targetProfile: hakoAppleRuntimeProfile.rawValue
                    )
                }
                return (
                    report,
                    finished.map(ProfileNetworkDraft.sniffProtocols(in:)),
                    RunningCoreDeviations.baseDocument(profile: profile, sidecarYAML: sidecar)
                )
            }.value
            deviations = derived.0
            draft.mergedDocumentSniffProtocols = derived.1
             
             
             
            if let base = derived.2 { draft.reseedInheritedBases(fromBaseDocument: base) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                 
                HakoModalActionBar(primaryTitle: "Save",
                    primaryDisabled: draft == openedWith,
                    onPrimary: persist)
            }
        }
         
         
         
        .hakoPageProbe("profile-network")
        .accessibilityIdentifier("profile-network.screen")
        .hakoCapturesDismiss(dismiss)
    }

     
     
    private var udpFallbackSummary: String {
        let key: String
        switch draft.udpFallbackPolicy {
         
         
        case .none:
            return HakoCopy.string(
                for: .formatCopy("Same as overall (%@)", [udpFallbackTitle(UDPFallbackSettings.policy())]),
                locale: locale
            )
        case .quic: key = "Reject QUIC"
        case .quicAllPorts: key = "Reject QUIC on 443 and 80"
        case .allUDP: key = "Reject all fallthrough UDP"
        case .off: key = "Off"
        }
        return HakoCopy.string(key, locale: locale)
    }

     
     
    private func udpFallbackTitle(_ policy: UDPFallbackPolicy) -> String {
        switch policy {
        case .quic: "Reject QUIC"
        case .quicAllPorts: "Reject QUIC on 443 and 80"
        case .allUDP: "Reject all fallthrough UDP"
        case .off: "Off"
        }
    }

    private var snifferSummary: String {
         
         
        let resolved = InheritedBool(
            base: draft.inheritedBase("sniffer.enable"),
            override: draft.trafficRecognition.boolValue,
            upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.enable")
        )
        let state = HakoCopy.string(resolved.primaryTitle.rawValue, locale: locale)
        let details = draft.customizedSnifferFieldCount
         
        return details == 0
            ? state
            : HakoCopy.format("%@ · %d modified", locale: locale, state, details)
    }

    private var ntpSummary: String {
        let count = (draft.timeSynchronization == .profileDefault ? 0 : 1)
            + (draft.timeServer == nil ? 0 : 1)
            + (timePortText.isEmpty ? 0 : 1)
            + (timeIntervalText.isEmpty ? 0 : 1)
            + (draft.timeDialerProxy == nil ? 0 : 1)
         
         
         
         
        return count == 0
            ? HakoCopy.string("Following the profile", locale: locale)
            : HakoCopy.format("%d overriding the profile", locale: locale, count)
    }

    private func persist() {
        do {
            draft.timePort = try Self.positiveNumber(
                timePortText,
                invalid: .invalidTimePort
            )
            draft.timeIntervalMinutes = try Self.positiveNumber(
                timeIntervalText,
                invalid: .invalidTimeInterval
            )
            try save(draft)
            closePage()
        } catch let bounded as ProfileNetworkDraftError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Network settings could not be saved. The previous configuration is still available."
        }
    }

    private static func positiveNumber(
        _ text: String,
        invalid error: ProfileNetworkDraftError
    ) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value > 0 else { throw error }
        return value
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}

 
 
 
 
 
 
 
 
private enum CoreBehaviorDoor: String, Identifiable {
    case keepAlive
    var id: String { rawValue }
}

struct GlobalCoreBehaviorSettingsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @State private var doorSelection: CoreBehaviorDoor?

    private var keepAliveDestination: some View {
        GlobalKeepAliveSettingsView(
            draft: $network,
            idleText: $keepAliveIdleText,
            intervalText: $keepAliveIntervalText,
            deviations: deviations
        )
    }

    let save:
        (ProfileNetworkDraft, ProfileRuntimeTrustDraft) throws -> Void

     
     
    private let profile: Profile
    @State private var deviations: ConfigDeviationReport?

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var network: ProfileNetworkDraft
    @State private var runtime: ProfileRuntimeTrustDraft
    @State private var keepAliveIdleText: String
    @State private var keepAliveIntervalText: String
    @State private var userAgentPreset = ClientUserAgent.preset()
    @State private var error = ""

     
     
     
     
     
     
     
     
    @State private var certificateStore: String
     
     
    @State private var promotionNoticeCount: Int =
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup)?
            .integer(forKey: FlClashRuntimeConfig.promotionNoticeKey) ?? 0
    @State private var storedCertificateStore: String

     
     
     
     
     
     
     
     
    @Environment(\.locale) private var locale
    @State private var storedNetwork: ProfileNetworkDraft
    @State private var storedRuntime: ProfileRuntimeTrustDraft
    @State private var storedKeepAliveIdleText: String
    @State private var storedKeepAliveIntervalText: String
    @State private var storedUserAgentPreset: ClientUserAgent.Preset

     
     
     
    private var hasUnsavedChanges: Bool {
         
         
         
         
         
        runtime.userAgent != nil
            || network != storedNetwork
            || runtime != storedRuntime
            || keepAliveIdleText != storedKeepAliveIdleText
            || keepAliveIntervalText != storedKeepAliveIntervalText
            || userAgentPreset != storedUserAgentPreset
            || certificateStore != storedCertificateStore
    }

    private static func currentCertificateStore() -> String {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup)?
            .string(forKey: CertificateStorePolicy.defaultsKey)
            ?? CertificateStorePolicy.platform
    }

    init(
        profile: Profile,
        sourceYAML: String? = nil,
        save: @escaping (
            ProfileNetworkDraft,
            ProfileRuntimeTrustDraft
        ) throws -> Void
    ) {
        self.profile = profile
        let network = ProfileNetworkDraft(profile: profile, sourceYAML: sourceYAML)
        let runtime = ProfileRuntimeTrustDraft(profile: profile, sourceYAML: sourceYAML)
        let idleText = network.keepAliveIdleSeconds.map(String.init) ?? ""
        let intervalText =
            network.keepAliveIntervalSeconds.map(String.init) ?? ""
        _storedNetwork = State(initialValue: network)
        _storedRuntime = State(initialValue: runtime)
        _storedKeepAliveIdleText = State(initialValue: idleText)
        _storedKeepAliveIntervalText = State(initialValue: intervalText)
        _storedUserAgentPreset = State(initialValue: ClientUserAgent.preset())
        let store = Self.currentCertificateStore()
        _certificateStore = State(initialValue: store)
        _storedCertificateStore = State(initialValue: store)
        self.save = save
        _network = State(initialValue: network)
        _runtime = State(initialValue: runtime)
        _keepAliveIdleText = State(initialValue: idleText)
        _keepAliveIntervalText = State(initialValue: intervalText)
    }

     
     
     
    private var fakeIPPersistenceState: InheritedBool {
        InheritedBool(
            base: runtime.inheritedBase("profile.store-fake-ip"),
            override: runtime.fakeIPPersistence.boolValue,
            upstreamDefault: UpstreamBoolDefault.pinned(for: "profile.store-fake-ip")
        )
    }

    private var logLevelState: InheritedText {
        InheritedText(base: runtime.inheritedTextBase("log-level"), override: runtime.logLevel,
                      upstreamDefault: UpstreamTextDefault.pinned(for: "log-level"))
    }
    private var geositeMatcherState: InheritedText {
        InheritedText(base: runtime.inheritedTextBase("geosite-matcher"), override: runtime.geositeMatcher,
                      upstreamDefault: UpstreamTextDefault.pinned(for: "geosite-matcher"))
    }

     
     
    private static let pageKeyPaths = ["ipv6", "unified-delay", "tcp-concurrent"]

     
     
     
     
     
     
     
    private var restoreDefaults: (() -> Void)? {
        guard network.hasOverrides(keyPaths: Self.pageKeyPaths) else { return nil }
        return { network = network.clearingOverrides(keyPaths: Self.pageKeyPaths) }
    }

    var body: some View {
         
         
         
         
         
         
        HakoMacSettingsFormContainer(
            restoreDefaults: restoreDefaults,
            scopeFooter: .copy("These settings apply to every profile.")
        ) {
             
             
             
             
             
             
            if promotionNoticeCount > 0 {
                Section {
                    Text(hako: .format(
                        "These settings now apply to every profile. %@ values set on other profiles were replaced by the profile that was active.",
                        [String(promotionNoticeCount)]
                    ))
                    .accessibilityIdentifier("global-core.promotion-notice")
                    Button {
                        UserDefaults(suiteName: HakoAppIdentifiers.appGroup)?
                            .removeObject(forKey: FlClashRuntimeConfig.promotionNoticeKey)
                        promotionNoticeCount = 0
                    } label: {
                        Text(HakoCopy.key("OK"))
                    }
                    .accessibilityIdentifier("global-core.promotion-notice.dismiss")
                }
            }
            Section {
                DNSFieldRows.overrideMenuRow(
                    "IPv6",
                    $network.ipv6,
                    inherited: network.inheritedBase("ipv6"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "ipv6"),
                    identifier: "global-core.ipv6"
                )
                DNSFieldRows.overrideMenuRow(
                    "Unified delay",
                    $network.unifiedDelay,
                    inherited: network.inheritedBase("unified-delay"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "unified-delay"),
                    identifier: "global-core.unified-delay"
                )
                DNSFieldRows.overrideMenuRow(
                    "TCP concurrent",
                    $network.concurrentTCP,
                    inherited: network.inheritedBase("tcp-concurrent"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "tcp-concurrent"),
                    identifier: "global-core.tcp-concurrent"
                )
                HakoDoorLink(CoreBehaviorDoor.keepAlive, selection: $doorSelection) {
                    keepAliveDestination
                } label: {
                    DNSHubRow(
                        title: "TCP Keep Alive",
                        detail: "Battery-relevant on mobile",
                        value: keepAliveSummary
                    )
                }
                .accessibilityIdentifier("global-core.keep-alive")
            } header: {
                Text("Connection")
            } footer: {
                Text(
                    "TCP concurrent keeps the first address that answers. Unified delay is on by default in this app so latency results are comparable across protocols; the core's own default is off, and a profile that sets unified-delay explicitly is honoured."
                )
            }

            Section {
                DNSFieldRows.menuRow(
                    title: "Log level",
                    value: logLevelState.primaryTitle,
                    subtitle: logLevelState.sourceLine,
                    identifier: "global-core.log-level"
                ) {
                    Picker("Log level", selection: $runtime.logLevel) {
                        Text(hako: logLevelState.followTitle).tag(String?.none)
                        ForEach(
                            ProfileRuntimeTrustDraft.supportedLogLevels,
                            id: \.self
                        ) {
                            Text(verbatim: $0).tag(Optional($0))
                        }
                    }
                }

                 
                 
                 
                 
                DNSFieldRows.menuRow(
                    title: "User-Agent",
                    value: .copy(userAgentPreset.label),
                    identifier: "global-core.user-agent"
                ) {
                    Picker("User-Agent", selection: $userAgentPreset) {
                        ForEach(ClientUserAgent.Preset.allCases) { preset in
                            Text(hako: .copy(preset.label)).tag(preset)
                        }
                    }
                }

                DNSFieldRows.menuRow(
                    title: "GeoSite matcher",
                    value: geositeMatcherState.primaryTitle,
                    subtitle: geositeMatcherState.sourceLine,
                    identifier: "global-core.geosite-matcher"
                ) {
                    Picker(
                        "GeoSite matcher",
                        selection: $runtime.geositeMatcher
                    ) {
                        Text(hako: geositeMatcherState.followTitle).tag(String?.none)
                        ForEach(
                            ProfileRuntimeTrustDraft
                                .supportedGeositeMatchers,
                            id: \.self
                        ) {
                            Text(verbatim: $0).tag(Optional($0))
                        }
                    }
                }
            } header: {
                Text("Runtime")
            } footer: {
                Text(
                    "These choices do not alter any imported profile."
                )
            }

             
             
             
            Section {
                DNSFieldRows.menuRow(
                    title: "Fake-IP persistence",
                    value: fakeIPPersistenceState.primaryTitle,
                    subtitle: fakeIPPersistenceState.sourceLine,
                    identifier: "global-core.store-fake-ip"
                ) {
                    Picker("Fake-IP persistence", selection: $runtime.fakeIPPersistence) {
                        Text(hako: fakeIPPersistenceState.followTitle).tag(ProfileBooleanOverride.profileDefault)
                        Text(hako: .copy("On")).tag(ProfileBooleanOverride.enabled)
                        Text(hako: .copy("Off")).tag(ProfileBooleanOverride.disabled)
                    }
                }
                DNSFieldRows.overrideMenuRow(
                    "Disable QUIC GSO",
                    $runtime.disableQUICGSO,
                    inherited: runtime.inheritedBase("experimental.quic-go-disable-gso"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "experimental.quic-go-disable-gso"),
                    identifier: "global-core.disable-gso"
                )
                DNSFieldRows.overrideMenuRow(
                    "Disable QUIC ECN",
                    $runtime.disableQUICECN,
                    inherited: runtime.inheritedBase("experimental.quic-go-disable-ecn"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "experimental.quic-go-disable-ecn"),
                    identifier: "global-core.disable-ecn"
                )
                DNSFieldRows.overrideMenuRow(
                    "IPv4-to-IPv6 Dialer Conversion",
                    $runtime.enableIPv4ToIPv6Conversion,
                    inherited: runtime.inheritedBase("experimental.dialer-ip4p-convert"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "experimental.dialer-ip4p-convert"),
                    identifier: "global-core.ip4p"
                )
            } header: {
                Text("Compatibility")
            } footer: {
                Text(
                    "Fake-IP persistence is on by default in this app, so Fake-IP mappings survive a tunnel restart; the core's own default is off. Change the QUIC and IPv4/IPv6 rows only to diagnose a known compatibility problem; turning them off takes effect the next time Clash starts."
                )
            }

            Section {
                DNSFieldRows.menuRow(
                    title: "Certificate store",
                    value: .copy(
                        CertificateStorePolicy.title(for: certificateStore)
                    ),
                    identifier: "global-core.certificate-store"
                ) {
                    Picker("Certificate store", selection: $certificateStore) {
                        ForEach(
                            [CertificateStorePolicy.platform]
                                + CertificateStorePolicy.selectable,
                            id: \.self
                        ) { value in
                            Text(
                                hako: .copy(
                                    CertificateStorePolicy.title(for: value)
                                )
                            )
                            .tag(value)
                        }
                    }
                }
            } header: {
                Text("Trust")
            } footer: {
                Text(
                    hako: .copy(
                        CertificateStorePolicy.detail(for: certificateStore)
                    )
                )
            }

             
             
             
             
            ConfigDeviationSection(
                report: deviations,
                fields: RunningCoreDeviations.fields(
                    for: [.advancedRuntime, .advancedTrust, .automaticRuntimeAdaptations]
                ),
                identifierPrefix: "global-core.deviation"
            )

            if !error.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }
            }
        }
        .task(id: RunningCoreDeviations.taskKey(for: profile)) {
            let profile = profile
            let locale = locale
            deviations = await Task.detached(priority: .userInitiated) {
                RunningCoreDeviations.report(
                    profile: profile,
                    sidecarYAML: RunningCoreDeviations.sidecarYAML(for: profile),
                    locale: locale
                )
            }.value
        }
        .hakoDoorPresenter(
            selection: $doorSelection,
            title: { _ in "TCP Keep Alive" }
        ) { _ in
            keepAliveDestination
        }
        .hakoPageTitle("Core Behavior")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                 
                if !insideProductModal {
                    HakoSaveButton { persist() }
                        .disabled(!hasUnsavedChanges)
                        .accessibilityIdentifier("global-core.save")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                 
                 
                 
                HakoModalActionBar(
                    primaryTitle: "Save",
                    primaryDisabled: !hasUnsavedChanges,
                    onPrimary: persist
                )
            }
        }
         
         
         
        .hakoPageProbe("global-core")
        .accessibilityIdentifier("global-core.screen")
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
    private var keepAliveSummary: String {
        let count =
            (network.disableKeepAlive == .profileDefault ? 0 : 1)
            + (keepAliveIdleText.isEmpty ? 0 : 1)
            + (keepAliveIntervalText.isEmpty ? 0 : 1)
        return count == 0
            ? HakoCopy.string("Following the profile", locale: locale)
            : HakoCopy.format("%d overriding the profile", locale: locale, count)
    }

    private func persist() {
        do {
            network.keepAliveIdleSeconds = try Self.seconds(
                keepAliveIdleText,
                invalid: .invalidKeepAliveIdle
            )
            network.keepAliveIntervalSeconds = try Self.seconds(
                keepAliveIntervalText,
                invalid: .invalidKeepAliveInterval
            )
             
             
             
            runtime.userAgent = nil
            try save(network, runtime)
            ClientUserAgent.save(preset: userAgentPreset)
             
             
             
            UserDefaults(suiteName: HakoAppIdentifiers.appGroup)?.set(
                certificateStore,
                forKey: CertificateStorePolicy.defaultsKey
            )
            storedCertificateStore = certificateStore
            closePage()
        } catch let bounded as ProfileNetworkDraftError {
            error = bounded.localizedDescription
        } catch let bounded as ProfileRuntimeTrustError {
            error = bounded.localizedDescription
        } catch {
            self.error =
                "Core behavior could not be saved. The previous configuration remains available."
        }
    }

    private static func seconds(
        _ text: String,
        invalid error: ProfileNetworkDraftError
    ) throws -> Int? {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value >= 0 else {
            throw error
        }
        return value
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}

 
 
private struct GlobalKeepAliveSettingsView: View {
    @Binding var draft: ProfileNetworkDraft
    @Binding var idleText: String
    @Binding var intervalText: String
     
     
     
    var deviations: ConfigDeviationReport?

    private static let keyPaths = ["disable-keep-alive", "keep-alive-idle", "keep-alive-interval"]

     
     
    private var restoreDefaults: (() -> Void)? {
        guard draft.hasOverrides(keyPaths: Self.keyPaths) || !idleText.isEmpty || !intervalText.isEmpty
        else { return nil }
        return {
            draft = draft.clearingOverrides(keyPaths: Self.keyPaths)
            idleText = ""
            intervalText = ""
        }
    }

    var body: some View {
         
        HakoMacSettingsFormContainer(
            restoreDefaults: restoreDefaults,
            scopeFooter: .copy("These settings apply to every profile.")
        ) {
            Section {
                DNSFieldRows.overrideMenuRow(
                    "Disable keep-alive",
                    $draft.disableKeepAlive,
                    inherited: draft.inheritedBase("disable-keep-alive"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "disable-keep-alive"),
                    identifier: "global-core.disable-keep-alive"
                )
                numberRow(
                    "Idle before probing",
                    text: $idleText,
                    inherited: draft.inheritedNumberBase("keep-alive-idle"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "keep-alive-idle"),
                    suffix: "sec",
                    identifier: "global-core.keep-alive-idle"
                )
                numberRow(
                    "Probe interval",
                    text: $intervalText,
                    inherited: draft.inheritedNumberBase("keep-alive-interval"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "keep-alive-interval"),
                    suffix: "sec",
                    identifier: "global-core.keep-alive-interval"
                )
            } footer: {
                Text(
                    "Changing these can cut battery drain on mobile. Zero asks the system for its default."
                )
            }

            ConfigDeviationSection(
                report: deviations,
                fields: ["keep-alive-idle", "keep-alive-interval", "disable-keep-alive"],
                identifierPrefix: "global-core.keep-alive.deviation"
            )
        }
        
        .hakoPageTitle("TCP Keep Alive")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("global-core.keep-alive.screen")
    }
}

 
 
private struct ProfileNTPSettingsView: View {
    @Binding var draft: ProfileNetworkDraft
    @Binding var portText: String
    @Binding var intervalText: String

    var body: some View {
#if os(macOS)
         
         
         
        ProfileNTPDeferredHost(
            draft: $draft,
            portText: $portText,
            intervalText: $intervalText
        )
#else
        ProfileNTPSettingsBody(
            draft: $draft,
            portText: $portText,
            intervalText: $intervalText
        )
#endif
    }
}

#if os(macOS)
private struct ProfileNTPDeferredHost: View {
    @Binding var draft: ProfileNetworkDraft
    @Binding var portText: String
    @Binding var intervalText: String
    @State private var localDraft: ProfileNetworkDraft
    @State private var localPort: String
    @State private var localInterval: String

    init(
        draft: Binding<ProfileNetworkDraft>,
        portText: Binding<String>,
        intervalText: Binding<String>
    ) {
        _draft = draft
        _portText = portText
        _intervalText = intervalText
        _localDraft = State(initialValue: draft.wrappedValue)
        _localPort = State(initialValue: portText.wrappedValue)
        _localInterval = State(initialValue: intervalText.wrappedValue)
    }

    var body: some View {
        ProfileNTPSettingsBody(
            draft: $localDraft,
            portText: $localPort,
            intervalText: $localInterval
        )
        .onDisappear {
            draft = localDraft
            portText = localPort
            intervalText = localInterval
        }
    }
}
#endif

private struct ProfileNTPSettingsBody: View {
    @Binding var draft: ProfileNetworkDraft
    @Binding var portText: String
    @Binding var intervalText: String

    private static let keyPaths = ["ntp.enable", "ntp.server", "ntp.port", "ntp.interval", "ntp.dialer-proxy"]

    private var restoreDefaults: (() -> Void)? {
        guard draft.hasOverrides(keyPaths: Self.keyPaths) || !portText.isEmpty || !intervalText.isEmpty
        else { return nil }
        return {
            draft = draft.clearingOverrides(keyPaths: Self.keyPaths)
            portText = ""
            intervalText = ""
        }
    }

    var body: some View {
         
        HakoMacSettingsFormContainer(
            restoreDefaults: restoreDefaults,
            scopeFooter: .copy("These settings apply to this profile only.")
        ) {
            Section {
                DNSFieldRows.overrideMenuRow(
                    "NTP",
                    $draft.timeSynchronization,
                    inherited: draft.inheritedBase("ntp.enable"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "ntp.enable"),
                    identifier: "profile-network.time.enabled"
                )
                optionalTextRow(
                    "Server",
                    value: $draft.timeServer,
                    inherited: draft.inheritedTextBase("ntp.server"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "ntp.server"),
                    identifier: "profile-network.time.server"
                )
                numberRow(
                    "Port",
                    text: $portText,
                    inherited: draft.inheritedNumberBase("ntp.port"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "ntp.port"),
                    suffix: nil,
                    identifier: "profile-network.time.port"
                )
                numberRow(
                    "Sync every",
                    text: $intervalText,
                    inherited: draft.inheritedNumberBase("ntp.interval"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "ntp.interval"),
                    suffix: "min",
                    identifier: "profile-network.time.interval"
                )
            } footer: {
                Text("Core applies the measured offset to protocol handshakes only.")
            }

            Section {
                optionalTextRow(
                    "Route",
                    value: $draft.timeDialerProxy,
                    inherited: draft.inheritedTextBase("ntp.dialer-proxy"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "ntp.dialer-proxy"),
                    identifier: "profile-network.time.route"
                )
            } footer: {
                Text("NTP dials its server directly, before rules — Route forces it through a named group or node instead.")
            }

            Section {
                OverviewValueRow(title: "System clock", value: "Never changed")
                    .accessibilityLabel(Text(HakoCopy.key("System clock")))
                    .accessibilityValue(Text(HakoCopy.key("Never changed")))
                    .accessibilityIdentifier("profile-network.time.write-system")
            } footer: {
                Text("The system does not grant that right.")
            }
        }
        
        .hakoPageTitle("NTP")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("profile-network.time.screen")
    }
}

 
 
 
 
 
 
 
 
 
 
private struct ProfileSnifferSettingsView: View {
    @Binding var draft: ProfileNetworkDraft

    var body: some View {
#if os(macOS)
        HakoDeferredDraftHost(source: $draft) { local in
            ProfileSnifferSettingsBody(draft: local)
        }
#else
        ProfileSnifferSettingsBody(draft: $draft)
#endif
    }
}

private struct ProfileSnifferSettingsBody: View {
     
     
     
    @Environment(\.locale) private var locale
    @Binding var draft: ProfileNetworkDraft

     
     
     
    private var overallOverrideDestination: Bool {
        InheritedBool(
            base: draft.inheritedBase("sniffer.override-destination"),
            override: draft.overrideDestination.boolValue,
            upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.override-destination")
        ).resolved
    }

    private static let keyPaths = [
        "sniffer.enable", "sniffer.force-dns-mapping", "sniffer.parse-pure-ip", "sniffer.override-destination",
    ]

    private var restoreDefaults: (() -> Void)? {
        guard draft.hasOverrides(keyPaths: Self.keyPaths) else { return nil }
        return { draft = draft.clearingOverrides(keyPaths: Self.keyPaths) }
    }

    var body: some View {
         
        HakoMacSettingsFormContainer(
            restoreDefaults: restoreDefaults,
            scopeFooter: .copy("These settings apply to this profile only.")
        ) {
            Section {
                DNSFieldRows.overrideMenuRow(
                    "Sniffer",
                    $draft.trafficRecognition,
                    inherited: draft.inheritedBase("sniffer.enable"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.enable"),
                    identifier: "profile-network.sniffer.enable"
                )
            } footer: {
                Text("Finds the real domain, so rules match names instead of bare IPs.")
            }

            Section {
                DNSFieldRows.overrideMenuRow(
                    "Sniff DNS-mapped traffic",
                    $draft.forceDNSMapping,
                    inherited: draft.inheritedBase("sniffer.force-dns-mapping"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.force-dns-mapping"),
                    identifier: "profile-network.sniffer.force-dns-mapping"
                )
                DNSFieldRows.overrideMenuRow(
                    "Sniff pure-IP traffic",
                    $draft.parsePureIP,
                    inherited: draft.inheritedBase("sniffer.parse-pure-ip"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.parse-pure-ip"),
                    identifier: "profile-network.sniffer.parse-pure-ip"
                )
                DNSFieldRows.overrideMenuRow(
                    "Dial the sniffed domain",
                    $draft.overrideDestination,
                    inherited: draft.inheritedBase("sniffer.override-destination"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.override-destination"),
                    identifier: "profile-network.sniffer.override-destination"
                )
            } footer: {
                Text("Dialing the sniffed domain hands the outbound the name, not the IP it arrived with.")
            }

            protocolSection(
                title: "HTTP",
                draft: $draft.http,
                defaultPorts: "80, 8080-8880",
                builtInPorts: "80",
                identifierFragment: "http"
            )
            protocolSection(
                title: "TLS",
                draft: $draft.tls,
                defaultPorts: "443, 8443",
                builtInPorts: "443",
                identifierFragment: "tls"
            )
            protocolSection(
                title: "QUIC",
                draft: $draft.quic,
                defaultPorts: "443",
                builtInPorts: "443",
                identifierFragment: "quic"
            )

            Section {
                listRow(
                    "Always sniff · Domain",
                    items: $draft.forceDomains,
                    itemTitle: "Domain",
                    noun: "patterns",
                    placeholder: "+.example.com",
                    footer: "Wildcards work: +.example.com covers every name under it.",
                    identifier: "profile-network.sniffer.force-domains"
                )
                listRow(
                    "Never sniff · Domain",
                    items: $draft.skipDomains,
                    itemTitle: "Domain",
                    noun: "patterns",
                    placeholder: "+.private.example",
                    footer: "Wildcards work: +.example.com covers every name under it.",
                    identifier: "profile-network.sniffer.skip-domains"
                )
                listRow(
                    "Never sniff · Source range",
                    items: $draft.skipSourceAddresses,
                    itemTitle: "Address",
                    noun: "ranges",
                    placeholder: "192.0.2.0/24",
                    footer: "Connections from these addresses are never sniffed.",
                    validate: addressPrefixError,
                    identifier: "profile-network.sniffer.skip-source-addresses"
                )
                listRow(
                    "Never sniff · Destination range",
                    items: $draft.skipDestinationAddresses,
                    itemTitle: "Address",
                    noun: "ranges",
                    placeholder: "2001:db8::/32",
                    footer: "Connections to these addresses are never sniffed.",
                    validate: addressPrefixError,
                    identifier: "profile-network.sniffer.skip-destination-addresses"
                )
            }

            Section {
                StringListEditor(
                    items: $draft.legacySniffing,
                    itemTitle: "Protocol",
                    placeholder: "tls",
                    validate: ProfileNetworkDraft.snifferProtocolError,
                    identifier: "profile-network.sniffer.legacy-protocols"
                )
                StringListEditor(
                    items: $draft.legacyPortWhitelist,
                    itemTitle: "Port",
                    placeholder: "443",
                    validate: portError,
                    identifier: "profile-network.sniffer.legacy-ports"
                )
            } header: {
                Text("Legacy Compatibility")
            } footer: {
                 
                 
                 
                 
                if draft.modernSniffIsInPlay {
                    Text("Not in effect: the per-protocol settings above are in use.")
                } else if !draft.legacyPortWhitelist.isEmpty, draft.legacySniffing.isEmpty {
                    Text("Ports apply only to the protocols listed above them; with no protocol listed they are not in effect.")
                } else {
                    Text("Kept so older profiles round-trip safely; new profiles use the sections above.")
                }
            }
        }
        
        .hakoPageTitle("Sniffer")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("profile-network.sniffer.screen")
    }

    @ViewBuilder
    private func protocolSection(
        title: String,
        draft: Binding<ProfileSnifferProtocolDraft>,
         
         
         
         
        defaultPorts: String,
         
         
         
         
         
         
        builtInPorts: String,
         
         
        identifierFragment: String
    ) -> some View {
        Section {
            HakoRoutedViewLink {
                 
                 
                 
                HakoDeferredDraftHost(source: draft.ports) { items in
                    SnifferListPage(
                        title: "\(title) Ports",
                        items: items,
                        itemTitle: "Port",
                        placeholder: defaultPorts,
                        footer: HakoCopy.string(
                            for: .formatCopy(
                                "Leave empty and %@ sniffs only port %@. Listing ports here replaces that, it does not add to it.",
                                [title, builtInPorts]
                            ),
                            locale: locale
                        ),
                        validate: portError,
                        identifier: "profile-network.sniffer.\(identifierFragment).ports"
                    )
                }
            } label: {
                DNSHubRow(
                    title: "Ports",
                    detail: "",
                     
                     
                     
                     
                    value: draft.ports.wrappedValue.isEmpty
                        ? HakoCopy.string(
                            for: .formatCopy("%@ · Core default", [builtInPorts]),
                            locale: locale
                        )
                        : draft.ports.wrappedValue.joined(separator: ", ")
                )
            }
            .accessibilityIdentifier("profile-network.sniffer.\(identifierFragment).ports.row")
            DNSFieldRows.overrideMenuRow(
                "Dial the sniffed domain",
                draft.overrideDestination,
                 
                 
                inherited: .overall(overallOverrideDestination),
                upstreamDefault: UpstreamBoolDefault.value(for: "sniffer.override-destination"),
                identifier: "profile-network.sniffer.\(identifierFragment).override-destination"
            )
        } header: {
            Text(hako: .copy(title))
        }
    }

    private func listRow(
        _ title: String,
        items: Binding<[String]>,
        itemTitle: String,
        noun: String,
        placeholder: String,
        footer: String,
        validate: ((String) -> String?)? = nil,
        identifier: String
    ) -> some View {
        HakoRoutedViewLink {
            HakoDeferredDraftHost(source: items) { local in
                SnifferListPage(
                    title: title,
                    items: local,
                    itemTitle: itemTitle,
                    placeholder: placeholder,
                    footer: footer,
                    validate: validate,
                    identifier: identifier
                )
            }
        } label: {
            DNSHubRow(title: title,
                      detail: "",
                      value: items.wrappedValue.isEmpty
                          ? nil
                          : "\(items.wrappedValue.count) \(noun)")
        }
        .accessibilityIdentifier("\(identifier).row")
    }

    private func portError(_ value: String) -> String? {
        ProfileNetworkDraft.isValidPortToken(value)
            ? nil
            : "Use a port from 1 to 65535, or a valid range such as 8080-8880."
    }

    private func addressPrefixError(_ value: String) -> String? {
        ProfileNetworkDraft.isValidAddressPrefix(value)
            ? nil
            : "Use IPv4 or IPv6 CIDR notation, such as 192.0.2.0/24."
    }
}

 
 
private struct SnifferListPage: View {
    let title: String
    @Binding var items: [String]
    let itemTitle: String
    let placeholder: String
    let footer: String
    var validate: ((String) -> String?)?
    let identifier: String

    var body: some View {
        Form {
            Section {
                StringListEditor(
                    items: $items,
                    itemTitle: itemTitle,
                    placeholder: placeholder,
                    validate: validate,
                    identifier: identifier
                )
            } footer: {
                Text(HakoCopy.key(footer))
            }
        }
        .navigationTitle(HakoCopy.key(title))
        .hakoDetailPageInsets()
        .accessibilityIdentifier("\(identifier).screen")
    }
}

 
 
 
 
 
 
private func numberRow(
    _ title: String,
    text: Binding<String>,
    inherited: InheritedNumberBase,
    upstreamDefault: PinnedDefault<Int>,
    suffix: String?,
    identifier: String
) -> some View {
    let typed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let state = InheritedNumber(base: inherited, override: Int(typed), upstreamDefault: upstreamDefault)
    return HakoFieldRow(
        title,
        hint: state.emptyHint,
        text: text,
        monospaced: true,
        suffix: suffix,
        subtitle: state.sourceLine
    )
    .keyboardType(.numberPad)
    .accessibilityIdentifier(identifier)
}

private func optionalTextRow(
    _ title: String,
    value: Binding<String?>,
    inherited: InheritedTextBase,
    upstreamDefault: PinnedDefault<String>,
    identifier: String
) -> some View {
    let state = InheritedText(base: inherited, override: value.wrappedValue, upstreamDefault: upstreamDefault)
    return HakoFieldRow(
        title,
        hint: state.emptyHint,
        text: Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.isEmpty ? nil : $0 }
        ),
        monospaced: true,
        subtitle: state.sourceLine
    )
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .accessibilityIdentifier(identifier)
}

 
 
 
 
 
 
 
enum ProfileNetworkRoute: Hashable, Identifiable {
    case sniffer
    case udpFallback
    case ntp

    var id: Self { self }
}
