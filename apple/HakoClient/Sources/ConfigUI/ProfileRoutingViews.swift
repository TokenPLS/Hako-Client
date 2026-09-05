import SwiftUI
import HakoClientUI

private enum ProfileRoutingDestination: String, Identifiable {
    case coverage
    case rules
    case chains

    var id: String { rawValue }
}

 
 

private enum ProfileRouteCoverageMode: Hashable {
    case profileDefault
    case bypassPrivate
    case custom
}

struct ProfileRoutePresetView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
     
     
    @State private var routingDoor: HakoDoorPayload?

    let profile: Profile
    var ownsNavigationContainer: Bool
    let save: (ProfileRoutePresetDraft) throws -> Void

    @Environment(\.locale) private var locale
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileRoutePresetDraft
     
     
     
    @State private var openedWith: ProfileRoutePresetDraft
    @State private var error = ""
     
     
     
    @State private var deviations: ConfigDeviationReport?

    init(
        profile: Profile,
        sourceYAML: String? = nil,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileRoutePresetDraft) throws -> Void
    ) {
        self.profile = profile
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
        let seed = ProfileRoutePresetDraft(profile: profile, sourceYAML: sourceYAML)
        _draft = State(initialValue: seed)
        _openedWith = State(initialValue: seed)
    }

    var body: some View {
        Group {
            if ownsNavigationContainer {
                HakoFeatureNavigationContainer {
                    content
                        .hakoSheetPresentation()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { closePage() }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                 
                                 
                                 
                                 
                                if !insideProductModal { saveButton }
                            }
                        }
                }
                .hakoStackNavigationViewStyle()
            } else {
                content
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                             
                            if !insideProductModal { saveButton }
                        }
                    }
            }
        }
        .hakoCapturesDismiss(dismiss)
    }

    private var content: some View {
         
         
         
        HakoMacSettingsFormContainer(
            restoreDefaults: restoreDefaults,
            scopeFooter: .copy("These settings apply to every profile.")
        ) {
            Section {
                DNSFieldRows.menuRow(
                    title: "Coverage",
                    value: coverageTitle(coverageMode.wrappedValue),
                    subtitle: coverageSource.sourceLine,
                    identifier: "profile-route-preset.choice"
                ) {
                    Picker("Coverage", selection: coverageMode) {
                        Text(hako: coverageSource.followTitle).tag(ProfileRouteCoverageMode.profileDefault)
                        Text("Bypass Private Networks").tag(ProfileRouteCoverageMode.bypassPrivate)
                        Text("Custom").tag(ProfileRouteCoverageMode.custom)
                    }
                }

                if coverageMode.wrappedValue == .custom {
                    StringListEditor(
                        items: $draft.customIncludedRoutes,
                        itemTitle: "Address",
                        placeholder: "0.0.0.0/0",
                        validate: routePrefixError,
                        identifier: "profile-route-preset.included-route.add"
                    )
                    .onChange(of: draft.customIncludedRoutes) { routes in
                        draft.preset = .custom(count: routes.count)
                    }
                }
            } footer: {
                Text(hako: .copy(routeFooter))
            }

            Section {
                routeDestination(
                    title: "Excluded Routes",
                    summary: listSummary(draft.excludedRoutes, noun: "routes"),
                    identifier: "profile-route-preset.exclusions"
                ) {
                    ProfileRouteExcludedRoutesView(routes: $draft.excludedRoutes, inheritedRoutes: draft.inheritedListBase("tun.route-exclude-address"))
                }

                routeDestination(
                    title: "Rule-Set Routes",
                    summary: ruleSetSummary,
                    identifier: "profile-route-preset.rule-sets"
                ) {
                    ProfileRouteRuleSetsView(
                        included: $draft.includedRouteSets,
                        excluded: $draft.excludedRouteSets,
                        inheritedIncluded: draft.inheritedListBase("tun.route-address-set"),
                        inheritedExcluded: draft.inheritedListBase("tun.route-exclude-address-set")
                    )
                }

                routeDestination(
                    title: "Tunnel Addresses",
                    summary: addressSummary,
                    identifier: "profile-route-preset.addresses"
                ) {
                    ProfileTunnelAddressesView(
                        ipv6Addresses: $draft.ipv6Addresses,
                        loopbackAddresses: $draft.loopbackAddresses,
                        inheritedIPv6: draft.inheritedListBase("tun.inet6-address"),
                        inheritedLoopback: draft.inheritedListBase("tun.loopback-address")
                    )
                }

                routeDestination(
                    title: "Routing Behavior",
                    summary: behaviorSummary,
                    identifier: "profile-route-preset.behavior"
                ) {
                    ProfileRouteBehaviorView(draft: $draft)
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("These overrides apply to the generated runtime only. The imported profile remains unchanged.")
            }

            Section {
                Label {
                    Text("Saving applies tunnel and route settings to every profile and may restart the active tunnel.")
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.footnote : .footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: HakoSymbol.checkmarkShieldFill.name)
                        .foregroundStyle(.green)
                }
            }

            ConfigDeviationSection(
                report: deviations,
                fields: RunningCoreDeviations.fields(for: [.tunnelAndAddressing]),
                identifierPrefix: "profile-route-preset.deviation"
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
        .hakoDoorPresenter(payload: $routingDoor)
        .hakoPageTitle("Tunnel & Routes")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(
                    primaryTitle: "Save",
                    primaryDisabled: draft == openedWith,
                     
                     
                     
                    primaryHint: draft == openedWith
                        ? "Change something to save it."
                        : nil,
                    onPrimary: persist
                )
            }
        }
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoPageProbe("profile-route-preset")
        .accessibilityIdentifier("profile-route-preset.screen")
    }

    private var saveButton: some View {
        HakoSaveButton { persist() }
             
             
             
             
            .disabled(draft == openedWith)
            .accessibilityIdentifier("profile-route-preset.save")
    }

    private var coverageMode: Binding<ProfileRouteCoverageMode> {
        Binding {
            switch draft.preset {
            case .subscription: return .profileDefault
            case .bypassPrivate: return .bypassPrivate
            case .custom: return .custom
            }
        } set: { mode in
            switch mode {
            case .profileDefault:
                draft.preset = .subscription
            case .bypassPrivate:
                draft.preset = .bypassPrivate
            case .custom:
                draft.preset = .custom(count: draft.customIncludedRoutes.count)
            }
        }
    }

     
     
     
     
    private var coverageSource: InheritedList {
        InheritedList(
            base: draft.inheritedListBase("tun.route-address"),
            override: draft.listOverrideState(for: "tun.route-address").isOverridden
                ? draft.customIncludedRoutes : nil,
            upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-address")
        )
    }

    private func coverageTitle(
        _ mode: ProfileRouteCoverageMode
    ) -> HakoDisplayText {
        switch mode {
        case .profileDefault: return "Source default"
        case .bypassPrivate: return "Bypass Private Networks"
        case .custom: return "Custom"
        }
    }

    private func routeDestination<Destination: View>(
        title: String,
        summary: String,
        identifier: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
         
         
         
         
        let destination = destination()
        return HakoPayloadDoorLink(
            id: identifier,
            title: title,
            selection: $routingDoor
        ) {
            destination
        } label: {
             
             
             
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                HakoMacNavigationRowLabel(
                    .copy(title),
                    subtitle: .copy(summary)
                )
            } else {
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    Text(hako: .copy(title))
                        .foregroundStyle(.primary)
                    Text(hako: .copy(summary))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func listSummary(_ value: ProfileStringListOverride, noun: String) -> String {
        value.isOverridden ? "Override · \(value.values.count) \(noun)" : "Source default"
    }

    private var ruleSetSummary: String {
        let overrides = [draft.includedRouteSets, draft.excludedRouteSets]
            .filter(\.isOverridden)
        guard !overrides.isEmpty else { return "Source default" }
        return "\(overrides.count) lists customized · \(overrides.reduce(0) { $0 + $1.values.count }) providers"
    }

    private var addressSummary: String {
        let overrides = [draft.ipv6Addresses, draft.loopbackAddresses]
            .filter(\.isOverridden)
        guard !overrides.isEmpty else { return "Source default" }
        return "\(overrides.count) lists customized · \(overrides.reduce(0) { $0 + $1.values.count }) addresses"
    }

    private var behaviorSummary: String {
        var count = [draft.strictRoute, draft.endpointIndependentNAT]
            .filter { $0 != .profileDefault }.count
        if !draft.udpTimeoutSeconds.isEmpty { count += 1 }
        if !draft.icmpTimeoutSeconds.isEmpty { count += 1 }
        return count == 0 ? "Source default" : "\(count) settings customized"
    }

    private var routeFooter: String {
        switch draft.preset {
        case .subscription:
            return "Use each profile source's route coverage."
        case .bypassPrivate:
            return "Keep private and local networks outside the VPN while routing public addresses through Clash."
        case .custom:
            return "Add the IPv4 and IPv6 prefixes that should enter Clash. Swipe a prefix to remove it."
        }
    }

    private func routePrefixError(_ value: String) -> String? {
        ProfileRoutePresetDraft.isValidRoutePrefix(value)
            ? nil
            : "Use IPv4 or IPv6 CIDR notation, such as 192.0.2.0/24."
    }

     
     
     
     
     
    private var restoreDefaults: (() -> Void)? {
        let booleans = ProfileRoutePresetDraft.inheritedKeyPaths
        let lists = ProfileRoutePresetDraft.inheritedListKeyPaths
        guard draft.hasOverrides(keyPaths: booleans) || draft.hasListOverrides(keyPaths: lists) else {
            return nil
        }
        return {
            draft = draft.clearingOverrides(keyPaths: booleans)
                .clearingListOverrides(keyPaths: lists)
        }
    }

    private func persist() {
        do {
            try save(draft)
            closePage()
        } catch let bounded as ProfileRoutingDraftError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Route coverage could not be saved. The previous configuration is still available."
        }
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}

private struct ProfileRouteExcludedRoutesView: View {
    @Binding var routes: ProfileStringListOverride
    let inheritedRoutes: InheritedListBase

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                sourcePicker("Excluded Routes", value: $routes, inherited: inheritedRoutes, upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-exclude-address"))
            } footer: {
                Text("Override with an empty list to clear exclusions supplied by the profile.")
            }

            InheritedEntriesSection(
                title: "Excluded Routes",
                state: listState($routes.wrappedValue, inherited: inheritedRoutes,
                                 upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-exclude-address")),
                identifier: "profile-route-inherited.route-exclude-address"
            )

            if routes.isOverridden {
                Section {
                    StringListEditor(
                        items: $routes.values,
                        itemTitle: "Address",
                        placeholder: "192.168.0.0/16",
                        validate: routePrefixError,
                        identifier: "profile-route-preset.excluded-route.add"
                    )
                } header: {
                    Text("Routes Kept Outside Clash")
                }
            }
        }
        
        .hakoPageTitle("Excluded Routes")
    }

    private func routePrefixError(_ value: String) -> String? {
        ProfileRoutePresetDraft.isValidRoutePrefix(value)
            ? nil
            : "Use IPv4 or IPv6 CIDR notation, such as 192.168.0.0/16."
    }
}

private struct ProfileRouteRuleSetsView: View {
    @Binding var included: ProfileStringListOverride
    @Binding var excluded: ProfileStringListOverride
    let inheritedIncluded: InheritedListBase
    let inheritedExcluded: InheritedListBase

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                sourcePicker("Included Rule Sets", value: $included, inherited: inheritedIncluded, upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-address-set"))
                if included.isOverridden {
                    StringListEditor(
                        items: $included.values,
                        itemTitle: "Rule Set",
                        placeholder: "private-ipcidr",
                        validate: ruleSetError,
                        identifier: "profile-route-preset.included-rule-set.add"
                    )
                }
                InheritedEntriesSection(
                    title: "Included Rule Sets",
                    state: listState($included.wrappedValue, inherited: inheritedIncluded,
                                     upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-address-set")),
                    identifier: "profile-route-inherited.route-address-set"
                )

            } header: {
                Text("Routes Entering Clash")
            }

            Section {
                sourcePicker("Excluded Rule Sets", value: $excluded, inherited: inheritedExcluded, upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-exclude-address-set"))
                if excluded.isOverridden {
                    StringListEditor(
                        items: $excluded.values,
                        itemTitle: "Rule Set",
                        placeholder: "local-ipcidr",
                        validate: ruleSetError,
                        identifier: "profile-route-preset.excluded-rule-set.add"
                    )
                }
                InheritedEntriesSection(
                    title: "Excluded Rule Sets",
                    state: listState($excluded.wrappedValue, inherited: inheritedExcluded,
                                     upstreamDefault: UpstreamListDefault.pinned(for: "tun.route-exclude-address-set")),
                    identifier: "profile-route-inherited.route-exclude-address-set"
                )
            } header: {
                Text("Routes Kept Outside Clash")
            } footer: {
                Text("Use IP-CIDR rule-provider names from this profile. Clash resolves them before starting the Network Extension.")
            }
        }
        
        .hakoPageTitle("Rule-Set Routes")
    }

    private func ruleSetError(_ value: String) -> String? {
        ProfileRoutePresetDraft.isValidRouteSetName(value)
            ? nil
            : "Enter an IP-CIDR rule-provider name."
    }
}

private struct ProfileTunnelAddressesView: View {
    @Binding var ipv6Addresses: ProfileStringListOverride
    @Binding var loopbackAddresses: ProfileStringListOverride
    let inheritedIPv6: InheritedListBase
    let inheritedLoopback: InheritedListBase

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                sourcePicker("Tunnel IPv6 Addresses", value: $ipv6Addresses, inherited: inheritedIPv6, upstreamDefault: UpstreamListDefault.pinned(for: "tun.inet6-address"))
                if ipv6Addresses.isOverridden {
                    StringListEditor(
                        items: $ipv6Addresses.values,
                        itemTitle: "Address",
                        placeholder: "fdfe:dcba:9876::1/126",
                        validate: ipv6PrefixError,
                        identifier: "profile-route-preset.ipv6-address.add"
                    )
                }
                InheritedEntriesSection(
                    title: "Tunnel IPv6 Addresses",
                    state: listState($ipv6Addresses.wrappedValue, inherited: inheritedIPv6,
                                     upstreamDefault: UpstreamListDefault.pinned(for: "tun.inet6-address")),
                    identifier: "profile-route-inherited.inet6-address"
                )
            } footer: {
                Text("Use an IPv6 prefix assigned to the tunnel. Leave this at the profile default unless the profile documents a required value.")
            }

            Section {
                sourcePicker("Loopback Addresses", value: $loopbackAddresses, inherited: inheritedLoopback, upstreamDefault: UpstreamListDefault.pinned(for: "tun.loopback-address"))
                 
                 
                 
                if loopbackAddresses.isOverridden {
                    StringListEditor(
                        items: $loopbackAddresses.values,
                        itemTitle: "Address",
                        placeholder: "10.0.0.1",
                        validate: ipAddressError,
                        identifier: "profile-route-preset.loopback-address.add"
                    )
                }
                InheritedEntriesSection(
                    title: "Loopback Addresses",
                    state: listState($loopbackAddresses.wrappedValue, inherited: inheritedLoopback,
                                     upstreamDefault: UpstreamListDefault.pinned(for: "tun.loopback-address")),
                    identifier: "profile-route-inherited.loopback-address"
                )
            } footer: {
                Text("Enter plain IPv4 or IPv6 addresses without a prefix length.")
            }
        }
        
        .hakoPageTitle("Tunnel Addresses")
    }

    private func ipv6PrefixError(_ value: String) -> String? {
        ProfileRoutePresetDraft.isValidIPv6Prefix(value)
            ? nil
            : "Use IPv6 CIDR notation, such as fd00::1/126."
    }

    private func ipAddressError(_ value: String) -> String? {
        ProfileRoutePresetDraft.isValidIPAddress(value)
            ? nil
            : "Use a plain IPv4 or IPv6 address without a prefix length."
    }
}

private struct ProfileRouteBehaviorView: View {
    @Binding var draft: ProfileRoutePresetDraft

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                DNSFieldRows.overrideMenuRow(
                    "Strict Route Enforcement",
                    $draft.strictRoute,
                    inherited: draft.inheritedBase("tun.strict-route"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "tun.strict-route"),
                    identifier: "profile-route-preset.strict-route"
                )
                DNSFieldRows.overrideMenuRow(
                    "Endpoint-Independent NAT",
                    $draft.endpointIndependentNAT,
                    inherited: draft.inheritedBase("tun.endpoint-independent-nat"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "tun.endpoint-independent-nat"),
                    identifier: "profile-route-preset.endpoint-independent-nat"
                )
            } header: {
                Text("Routing")
            } footer: {
                Text("Strict routing prevents traffic from escaping the selected tunnel routes. Endpoint-independent NAT changes UDP endpoint mapping behavior.")
            }

            Section {
                timeoutField(
                    "UDP Session Timeout",
                    text: $draft.udpTimeoutSeconds,
                    inherited: draft.inheritedNumberBase("tun.udp-timeout"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "tun.udp-timeout"),
                    identifier: "profile-route-preset.udp-timeout"
                )
                 
                 
                 
                 
                 
                 
                 
                 
                OverviewValueRow(title: "ICMP Session Timeout", value: "Answered in the tunnel")
                    .accessibilityIdentifier("profile-route-preset.icmp-timeout")
            } header: {
                Text("Session Timeouts")
            } footer: {
                Text("UDP: leave empty to follow the profile, or enter seconds. Zero means the default, not zero seconds. ICMP is answered inside the tunnel.")
            }
        }
        
        .hakoPageTitle("Routing Behavior")
    }


    private func timeoutField(
        _ title: String,
        text: Binding<String>,
        inherited: InheritedNumberBase,
        upstreamDefault: PinnedDefault<Int>,
        identifier: String
    ) -> some View {
         
         
         
         
        let state = InheritedNumber(
            base: inherited,
            override: Int(text.wrappedValue.trimmingCharacters(in: .whitespaces)),
            upstreamDefault: upstreamDefault
        )
        return VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline) {
            Text(hako: .copy(title))
            Spacer(minLength: HakoTheme.Spacing.standard)
             
             
            hakoPromptField(state.emptyHint, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 130)
                .accessibilityIdentifier(identifier)
            if !text.wrappedValue.isEmpty {
                Text("sec")
                    .foregroundStyle(.secondary)
            }
        }
        Text(hako: state.sourceLine)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

 
 
 
private func listState(
    _ value: ProfileStringListOverride,
    inherited: InheritedListBase,
    upstreamDefault: PinnedDefault<[String]>
) -> InheritedList {
    listState(override: value.isOverridden ? value.values : nil,
              inherited: inherited, upstreamDefault: upstreamDefault)
}

 
 
 
private func sourcePicker(
    _ title: String,
    value: Binding<ProfileStringListOverride>,
    inherited: InheritedListBase,
    upstreamDefault: PinnedDefault<[String]>
) -> some View {
    let state = listState(value.wrappedValue, inherited: inherited, upstreamDefault: upstreamDefault)
    return DNSFieldRows.menuRow(
        title: title,
        value: state.primaryTitle,
        subtitle: state.sourceLine,
        identifier: "profile-route-source.\(title)"
    ) {
        Picker(title, selection: value.isOverridden) {
            Text(hako: state.followTitle).tag(false)
            Text("Override").tag(true)
        }
    }
}

struct ProfileProxyChainsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    let profile: Profile
    let ownsNavigationContainer: Bool
    let save: (ProfileProxyChainDraft) throws -> Void
    let savePayloadDialers: (([ProxyPayloadDialerEdit]) throws -> Void)?
     
     
     
    var openCustomNodes: (() -> Void)?
     
     
     
    let measure: ((String) async -> Int?)?

     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileProxyChainDraft
    @State private var error = ""
     
     
    @State private var openedWith: ProfileProxyChainDraft?

    @State private var payloadEdits: [ProxyPayloadDialerEdit] = []
    @State private var preparation: ProfileProxyChainPreparation?
    private let rawYAML: String?

    init(
        profile: Profile,
        rawYAML: String?,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileProxyChainDraft) throws -> Void,
        measure: ((String) async -> Int?)? = nil,
        savePayloadDialers: (([ProxyPayloadDialerEdit]) throws -> Void)? = nil,
        openCustomNodes: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
        self.savePayloadDialers = savePayloadDialers
        self.measure = measure
        self.openCustomNodes = openCustomNodes
        self.rawYAML = rawYAML
        _draft = State(initialValue: ProfileProxyChainDraft(profile: profile))
        _preparation = State(initialValue: nil)
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            Group {
                if let preparation {
                    ProfileProxyChainEditor(
                        preparation: preparation,
                        spec: $draft.proxyChain,
                        legacyRelayMigrations: $draft.legacyRelayMigrations,
                        saveError: error,
                        payloadEdits: $payloadEdits,
                        measure: measure,
                        openCustomNodes: openCustomNodes,
                        profileName: profile.label
                    )
                } else {
                    HakoAsyncLoadingView()
                }
            }
            .hakoFeaturePresentation(
                ownsNavigationContainer: ownsNavigationContainer
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if ownsNavigationContainer {
                        Button("Cancel") { closePage() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        HakoSaveButton { persist() }
                            .accessibilityIdentifier("profile-proxy-chains.save")
                    }
                }
            }
        }
        .task(id: PreparationKey(profile: profile, rawYAML: rawYAML)) {
            await prepare()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(
                    primaryTitle: "Save",
                    primaryDisabled: draft == (openedWith ?? draft) && payloadEdits.isEmpty,
                    primaryHint: draft == (openedWith ?? draft) && payloadEdits.isEmpty
                        ? "Change something to save it."
                        : nil,
                    onPrimary: persist
                )
            }
        }
         
         
         
         
         
        .hakoRegistersDeparture(
             
             
             
             
            isDirty: openedWith.map { draft != $0 } ?? false
                || !payloadEdits.isEmpty,
            save: { completion in
                persist()
                completion(true)
            },
            discard: {
                if let openedWith { draft = openedWith }
                payloadEdits = []
            }
        )
        .hakoPageProbe("profile-proxy-chains")
        .accessibilityIdentifier("profile-proxy-chains.screen")
        .hakoCapturesDismiss(dismiss)
        .onAppear { if openedWith == nil { openedWith = draft } }
    }

    struct PreparationKey: Equatable {
        let profile: Profile
        let rawYAML: String?
    }

     
     
     
     
     
     
    @MainActor
    static let lastPreparation =
        HakoLastPreparation<PreparationKey, ProfileProxyChainPreparation>()

    @MainActor
    static func prewarm(profile: Profile, rawYAML: String?) async {
        _ = await prepared(profile: profile, rawYAML: rawYAML)
    }

    @MainActor
    private static func prepared(
        profile: Profile, rawYAML: String?
    ) async -> ProfileProxyChainPreparation {
        let key = PreparationKey(profile: profile, rawYAML: rawYAML)
        return await lastPreparation.value(for: key) {
            let began = DispatchTime.now().uptimeNanoseconds
            let made = await Task.detached(priority: .userInitiated) {
                ProfileProxyChainPreparation.make(
                    profile: profile,
                    rawYAML: rawYAML
                )
            }.value
            HakoPerf.span(
                "chains.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "yamlBytes=\(rawYAML?.utf8.count ?? 0)"
            )
            return made
        }
    }

    @MainActor
    private func prepare() async {
        guard preparation == nil else { return }
        preparation = await Self.prepared(profile: profile, rawYAML: rawYAML)
    }

    private func persist() {
        do {
             
             
            if !payloadEdits.isEmpty {
                guard let savePayloadDialers else {
                    throw ProfileProviderDefinitionError.missingDefinition
                }
                try savePayloadDialers(payloadEdits)
                payloadEdits = []
            }
            try save(draft)
            closePage()
        } catch let bounded as ProfileRoutingDraftError {
            error = bounded.localizedDescription
        } catch let bounded as ProxyChainError {
            error = bounded.localizedDescription
        } catch let bounded as LegacyRelayMigrationError {
            error = bounded.localizedDescription
        } catch let bounded as PipelineError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Proxy chains could not be saved. The previous configuration is still available."
        }
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}
