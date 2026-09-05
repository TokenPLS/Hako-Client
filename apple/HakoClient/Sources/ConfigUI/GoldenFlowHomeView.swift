import Combine
import SwiftUI
import Hako
import HakoClientKit
import HakoClientUI

 
 
 
 
 
private struct OutboundModeRefusal {
    let title: String
    let message: String
     
     
     
    var offersNodeChoice: Bool = false

    static func saveFailed(
        mode: Profile.OutboundMode,
        error: Error
    ) -> OutboundModeRefusal {
        OutboundModeRefusal(
            title: "Mode Not Changed",
            message: """
                \(mode.rawValue.capitalized) mode could not be saved to this \
                profile: \(error.localizedDescription)
                """
        )
    }
}

 
 
 
 
 
private struct RuntimeConfigurationPresentation {
    let profileID: String
    let snapshot: ProfileFinalConfigurationSnapshot
    let sourceYAML: String?
    let comparisonYAML: String?
    let baseYAML: String?
    let includesBlockedRuleSets: Bool
}

 
 
private struct PreparedProxiesPresentation {
    let profileID: String
    let sourceModel: ProxiesOverviewModel
}

 
 
 
 
 
struct GoldenFlowHomeAdapter: View {
     
     
     
     
    @State private var startupExplanation: HakoStartupExplanation?
     
     
     
     
     
     
     
     
     
     
    @State private var unreadableRuleSets: [ProvidersModel.Row] = []
     
    @State private var billLines: [MemoryBillSection.Line] = []
     
    @State private var ruleSetItems: [MemoryTrimManageView.Item] = []
     
    @State private var providerLoadRows: [ProviderLoadDetailView.Row] = []
     
     
     
     
     
    @State private var coreLog: [String] = []
    @State private var strippedNotices: [String] = []
     
     
     
     
     
     
     
    @State private var geoNameCount: Int?

    @Environment(\.locale)
    private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.hakoShellLayout) private var shellLayout

    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var nodes: NodesModel
    @ObservedObject var stats: StatsModel
    let profileRefreshToken: Int
     
     
    @Binding var pendingSessionPage: HakoClientUI.HakoRootDestination?
    @Binding var pendingOutboundMode: String?
    let openProfiles: () -> Void
    let openProxies: () -> Void
    let openRules: () -> Void
    let openActiveRules: () -> Void
     
     
    let openLogs: () -> Void
    let openDNSQuery: () -> Void
    let rebind: () -> Void

     
     
     
     
     
     
    @ObservedObject private var profiles: ProfilesViewModel


    @State private var favoriteCards =
        HomeFavoriteCardPreferences().load()
    @State private var trafficOnlyProxy =
        TrafficStatisticsSettings.onlyProxy()
    @State private var lanAddress: String?
    @State private var editorDestination: HomeProfileEditorDestination?
    @State private var runtimeConfigurationProfile: Profile?
    @State private var runtimeConfigurationPresentation:
        RuntimeConfigurationPresentation?
    @State private var runtimeConfigurationPreparationGeneration: UInt64 = 0
    @State private var presentedConnectionIssue: HomeConnectionIssue?
     
     
     
     
    @State private var presentedHomeSnapshot: AppleClientSnapshot?
    @State private var configTally: ProfileConfigTally?
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var resourceCounts: HomeResourceCounts?
    @State private var rulesOverview: RulesOverviewModel?
    @State private var configuredMode: Profile.OutboundMode = .rule
     
     
     
    @State private var modeRefusal: OutboundModeRefusal?
    @State private var pendingProxiesGroup: String?
     
     
     
    @Binding private var sessionPresentation:
        HakoClientUI.HakoRootDestination?
    @State private var proxiesPreparationGeneration: UInt64 = 0
     
    private struct ProxiesPreparationKey: Hashable {
        let generation: UInt64
        let overrides: ProxyNodeOverrideSpec?
    }
    @State private var preparedProxiesPresentation:
        PreparedProxiesPresentation?

    init(
        vpn: VPNController,
        command: ClashCommandClient,
        nodes: NodesModel,
        stats: StatsModel,
        profiles: ProfilesViewModel,
        profileRefreshToken: Int,
        pendingSessionPage:
            Binding<HakoClientUI.HakoRootDestination?> = .constant(nil),
        sessionPresentation:
            Binding<HakoClientUI.HakoRootDestination?> = .constant(nil),
        pendingOutboundMode: Binding<String?> = .constant(nil),
        openProfiles: @escaping () -> Void,
        openProxies: @escaping () -> Void,
        openRules: @escaping () -> Void,
        openActiveRules: @escaping () -> Void,
        openLogs: @escaping () -> Void,
        openDNSQuery: @escaping () -> Void,
        rebind: @escaping () -> Void
    ) {
        self.vpn = vpn
        self.command = command
        self.nodes = nodes
        self.stats = stats
        self.profileRefreshToken = profileRefreshToken
        _pendingSessionPage = pendingSessionPage
        _sessionPresentation = sessionPresentation
        _pendingOutboundMode = pendingOutboundMode
        self.openProfiles = openProfiles
        self.openProxies = openProxies
        self.openRules = openRules
        self.openActiveRules = openActiveRules
        self.openLogs = openLogs
        self.openDNSQuery = openDNSQuery
        self.rebind = rebind
        self.profiles = profiles
    }

    var body: some View {


        let homeSnapshot = presentedHomeSnapshot ?? sharedSnapshot
        HakoClientUI.HakoHomeView(
            snapshot: homeSnapshot,
            actions: sharedActions,
            presentationClass: shellLayout == .regularSidebar
                ? .regularTouch
                : .compactTouch,
            palette: HakoClientUI.HakoProductPalette.hakoProduct,
            customizationPresentation: { content in
                AnyView(HomeCustomizationEditModePresenter(content: content))
            }
        ) { symbol in
            HakoSymbolImage(symbol: symbol)
        }
        .equatable()


        .task(id: profileRefreshToken) {
            profiles.load()
            recomputeConfiguredMode()
            recomputeTally()
             
             
             
             
             
             
            if command.isConnected,
               nodes.runtimeProviderCatalog.proxyProviders.isEmpty {
                await nodes.refresh()
            }
        }
         
         
         
         
        .onChange(of: command.isConnected) { _ in
            recomputeTally()
        }
        .onChange(of: editorDestination?.id) { destination in
            if destination == nil {
                presentedHomeSnapshot = nil
                recomputeTally()
                pendingProxiesGroup = nil
                proxiesPreparationGeneration &+= 1
                preparedProxiesPresentation = nil
            } else if presentedHomeSnapshot == nil {
                presentedHomeSnapshot = homeSnapshot
            }
            switch editorDestination {
            case .proxiesOverview: sessionPresentation = .proxies
            case .rulesOverview: sessionPresentation = .rules
            default: sessionPresentation = nil
            }
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
        .task(id: pendingSessionPage) {
            guard let page = pendingSessionPage else { return }
            pendingSessionPage = nil
            switch page {
            case .proxies: presentProxiesOverview()
            case .rules: presentRulesOverview()
            default: break
            }
        }
         
         
         
         
         
        .task(id: pendingOutboundMode) {
            guard let raw = pendingOutboundMode else { return }
            setOutboundMode(raw)
            pendingOutboundMode = nil
        }
        .onChange(of: currentProfile?.id) { _ in
            recomputeConfiguredMode()
        }
        .onChange(of: command.mode) { mode in
             
             
             
            recomputeConfiguredMode()
            guard command.isConnected,
                  mode.caseInsensitiveCompare("global") == .orderedSame else {
                return
            }
            Task {
                await enforceConnectedGlobalMode()
            }
        }
        .hakoProductModal(
            item: $editorDestination,
            role: .page
        ) { destination in
            HakoLazyView {
                editorSheet(destination)
            }
                .hakoPageSizedSheet()
                 
                 
                .onAppear { HakoPushClock.arrived() }
        }
        .sheet(
            item: $runtimeConfigurationProfile,
            onDismiss: {
                runtimeConfigurationPreparationGeneration &+= 1
                runtimeConfigurationPresentation = nil
            }
        ) { profile in
            if let presentation = runtimeConfigurationPresentation,
               presentation.profileID == profile.id {
                ProfileFinalConfigurationView(
                    title: "Final Configuration",
                    snapshot: presentation.snapshot,
                    sourceYAML: presentation.sourceYAML,
                    comparisonYAML: presentation.comparisonYAML,
                    baseYAML: presentation.baseYAML,
                    command: command,
                     
                     
                     
                     
                    blockedRuleSets: presentation.includesBlockedRuleSets
                        ? {
                            guard let container =
                                HakoAppIdentifiers.appGroupContainer else {
                                return []
                            }
                            let coreHome =
                                container.appendingPathComponent("working")
                            return ProviderCompileVerdicts
                                .load(coreHome: coreHome)
                                .blockedRuleProviders
                        }
                        : nil
                )
                .hakoModalPresentation(.page)
            } else {
                HomePreparationPlaceholder(
                    title: "Final Configuration",
                    accessibilityIdentifier: "final.preparing"
                )
                .task(id: runtimeConfigurationPreparationGeneration) {
                    await prepareRuntimeConfiguration(
                        for: profile,
                        generation: runtimeConfigurationPreparationGeneration
                    )
                }
                .hakoModalPresentation(.page)
            }
        }
        .task {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            guard Self.isStoppedStatus(vpn.status), vpn.lastStartFailed
            else { return }
            startupExplanation = command.readStartupExplanation()
            rebuildFailureCaptureIfNeeded()
        }
        .onChange(of: vpn.status) { status in
             
             
             
             
             
             
             
             
             
             
            if Self.startRetiresStartupExplanation(status) {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                command.clearStartupExplanation()
                guard presentedConnectionIssue == nil else { return }
                startupExplanation = nil
                unreadableRuleSets = []
                geoNameCount = nil
                coreLog = []
            strippedNotices = []
                billLines = []
                ruleSetItems = []
                providerLoadRows = []
                return
            }
            guard Self.isStoppedStatus(status) else { return }
             
             
             
             
             
             
             
            guard vpn.lastStartFailed else {
                command.clearStartupExplanation()
                startupExplanation = nil
                unreadableRuleSets = []
                geoNameCount = nil
                coreLog = []
                strippedNotices = []
                billLines = []
                ruleSetItems = []
                providerLoadRows = []
                return
            }
            startupExplanation = command.readStartupExplanation()
            if vpn.consumeUserInitiatedStop() {
                 
                 
                 
                 
                command.clearStartupExplanation()
                startupExplanation = nil
                unreadableRuleSets = []
                geoNameCount = nil
                coreLog = []
                strippedNotices = []
                billLines = []
                ruleSetItems = []
                providerLoadRows = []
                return
            }
            rebuildFailureCaptureIfNeeded()
        }
        .sheet(item: $presentedConnectionIssue) { issue in
             
             
             
            connectionIssueSheet(issue)
                .hakoModalPresentation(.form)
        }
        .alert(
            LocalizedStringKey(modeRefusal?.title ?? ""),
            isPresented: Binding(
                get: { modeRefusal != nil },
                set: { if !$0 { modeRefusal = nil } }
            ),
            presenting: modeRefusal
        ) { refusal in
            if refusal.offersNodeChoice {
                Button("Choose Node") {
                    pendingProxiesGroup = GlobalProxySelectionPolicy.groupName
                     
                     
                     
                     
                    if shellLayout == .regularSidebar {
                        openProxies()
                    } else {
                        presentProxiesOverview()
                    }
                }
            }
            Button("OK", role: .cancel) {}
        } message: { refusal in
            Text(hako: .copy(refusal.message))
        }
        .onChange(of: favoriteCards) { cards in
            HomeFavoriteCardPreferences().save(cards)
        }
    }

    @ViewBuilder
    private func editorSheet(
        _ destination: HomeProfileEditorDestination
    ) -> some View {
        switch destination {
        case .customNodes(let profile):
            CustomNodesView(
                profile: profile,
                sourceYAML: profiles.uiProjectedYAML(for: profile),
                loadDraft: {
                    try profiles.providerDefinitionsDraft(for: profile)
                },
                 
                 
                 
                prepareDraft: nil,
                saveDraft: {
                    try profiles.updateProviderDefinitions($0)
                },
                savePayload: {
                    try profiles.updateCustomNodePayload($0, for: profile.id)
                },
                applyEdits: {
                    profiles.applyProfileNow(profile.id)
                },
                isApplying: profiles.isActivating,
                renameNode: { try profiles.renameProxyNode(profileID: profile.id, from: $0, to: $1) },
            )
        case .proxySources(let profile):
            ProfileProviderDefinitionsView(
                profile: profile,
                kind: .proxy,
                load: {
                    try await profiles.providerDefinitionsDraftAsync(for: profile)
                },
                save: {
                    try profiles.updateProviderDefinitions($0)
                }
            )
        case .ruleSets(let profile):
            ProfileProviderDefinitionsView(
                profile: profile,
                kind: .rule,
                load: {
                    try await profiles.providerDefinitionsDraftAsync(for: profile)
                },
                save: {
                    try profiles.updateProviderDefinitions($0)
                }
            )
        case .network(let profile):
            ProfileNetworkSettingsView(
                profile: profile,
                 
                 
                sourceYAML: profiles.baseYAML(for: profile),
                udpFallbackGuardInput: { [profiles] in
                    await profiles.udpFallbackGuardInput(for: profile)
                }
            ) { draft in
                try profiles.updateNetwork(draft)
            }
        case .rules(let profile):
            ProfileRulesAdapter(
                profile: profile,
                sourceYAML: profiles.uiProjectedYAML(for: profile)
            ) { draft in
                try profiles.updateRules(draft)
            }
        case .rulesOverview(let profile):
            RulesOverviewHost(
                command: command,
                profiles: profiles,
                profile: profile,
                openProxiesGroup: { group in
                    pendingProxiesGroup = group
                    presentProxiesOverview(for: profile)
                }
            )
        case .proxiesOverview(let profile):
             
             
             
             
            let live = profiles.profiles.first { $0.id == profile.id } ?? profile
            Group {
                if let preparedProxiesPresentation,
                   preparedProxiesPresentation.profileID == live.id {
                    ProxiesOverviewHost(
                        vpn: vpn,
                        command: command,
                        nodes: nodes,
                        profiles: profiles,
                        isConnected: command.isConnected,
                        mode: command.mode,
                        profile: live,
                         
                         
                        sourceModel: preparedProxiesPresentation.sourceModel
                            .applying(selectedMap: live.selectedMap),
                         
                         
                         
                        initiallyExpandedGroup: pendingProxiesGroup
                    )
                } else {
                    HomePreparationPlaceholder(
                        title: "Proxies",
                        accessibilityIdentifier: "proxies.preparing"
                    )
                }
            }
             
             
             
             
             
             
            .task(id: ProxiesPreparationKey(
                generation: proxiesPreparationGeneration,
                overrides: live.proxyNodeOverrides
            )) {
                await prepareProxiesOverview(
                    for: live,
                    generation: proxiesPreparationGeneration
                )
            }
        case .proxyChains(let profile):
            ProfileProxyChainsView(
                profile: profile,
                rawYAML: profiles.runtimeSourceYAML(for: profile),
                save: {
                    try profiles.updateProxyChains($0)
                },
                 
                 
                 
                 
                measure: command.isConnected
                    ? { name in
                        let outcome = await command.urlTestQuietly(name: name)
                        return outcome.succeeded ? outcome.delay : 0
                    }
                    : nil,
                savePayloadDialers: { edits in
                    guard !edits.isEmpty else {
                        return
                    }
                    guard let latest = profiles.profiles.first(
                        where: { $0.id == profile.id }
                    ) else {
                        throw PipelineError.sourceUnavailable(
                            "the profile is no longer available"
                        )
                    }
                    var working =
                        try profiles.providerDefinitionsDraft(
                            for: latest
                        )
                    for edit in edits {
                        try working.setPayloadDialer(
                            provider: edit.provider,
                            node: edit.node,
                            dialerProxy: edit.dialerProxy
                        )
                    }
                    try profiles.updateProviderDefinitions(working)
                },
                openCustomNodes: {
                    editorDestination = .customNodes(profile)
                }
            )
        case .advanced(let profile):
            ProfileAdvancedOverridesView(
                profile: profile,
                sourceYAML: profiles.sourceYAML(for: profile),
                save: {
                    try profiles.updateAdvancedOverrides($0)
                }
            )
        case .additionalFields(let profile):
            ProfileAdditionalFieldsView(
                profile: profile,
                save: {
                    try profiles.updateAdvancedOverrides($0)
                }
            )
        }
    }

    private var currentProfile: Profile? {
        HomeProfileResolution.workingProfile(in: profiles)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private var selectedRoute: (name: String?, delay: Int?) {
        guard configuredMode == .global,
              let group = nodes.groups.first(
                  where: { $0.name == GlobalProxySelectionPolicy.groupName }
              )
        else {
            return (nil, nil)
        }
        let route =
            group.resolvedNow.isEmpty
                ? group.now
                : group.resolvedNow
        return (
            route.isEmpty ? nil : route,
            nodes.delays[route]
        )
    }

    @ViewBuilder
    private func connectionIssueSheet(
        _ issue: HakoHomeConnectionIssue
    ) -> some View {
        HomeConnectionIssueView(
            issue: issue,
            vpn: vpn,
            openLogs: openLogs,
            startupExplanation: startupExplanation,
            geoNameCount: geoNameCount,
            billLines: billLines,
            ruleSetItems: ruleSetItems,
            trimSpec: currentProfile?.memoryTrim ?? MemoryTrimSpec(),
            onSaveTrim: { spec in saveTrimAndRetry(spec) },
            dnsPolicyKeys: pricedDNS(MemoryTrimCensus.dnsPolicyKeys(
                sourceYAML: currentProfile.flatMap {
                    profiles.sourceYAML(for: $0)
                },
                effectiveYAML: MemoryTrimCensus.effectiveYAML(
                    container: HakoAppIdentifiers.appGroupContainer
                ),
                dropped: currentProfile?.memoryTrim?.droppedDNSPolicyKeys ?? []
            )),
            dnsFilterEntries: pricedDNS(MemoryTrimCensus.fakeIPFilterEntries(
                sourceYAML: currentProfile.flatMap {
                    profiles.sourceYAML(for: $0)
                },
                dropped: currentProfile?.memoryTrim?
                    .droppedFakeIPFilterEntries ?? []
            )),
            geoSiteItems: geoItems(kind: "GEOSITE"),
            geoIPItems: geoItems(kind: "GEOIP"),
            providerLoadRows: providerLoadRows,
            coreLog: coreLog,
            strippedNotices: strippedNotices,
            unreadableRuleSets: unreadableRuleSets
        )
        .onDisappear {
             
             
             
            guard issue.kind == .startupStopped else { return }
            command.clearStartupExplanation()
            startupExplanation = nil
            geoNameCount = nil
            coreLog = []
            strippedNotices = []
            billLines = []
            ruleSetItems = []
            providerLoadRows = []
             
             
             
             
             
            unreadableRuleSets = []
        }
    }

     
     
     
     
     
     
     
    private static let priceMemoryKey = "memory.trim.measured-prices"
     
     
     
    private static let peakPriceMemoryKey = "memory.trim.measured-peaks"

    private func buildRuleSetItems() -> [MemoryTrimManageView.Item] {
         
         
         
         
         
         
         
        var censusNote = ""
        defer {
            HakoLogStore.shared.append(censusNote, stream: .app, level: .info)
        }
         
         
         
        let defaults = GlobalConfig.appGroupDefaults
        var prices = (defaults.dictionary(
            forKey: Self.priceMemoryKey
        ) as? [String: Int64]) ?? [:]
         
         
         
         
         
         
        var peakPrices = (defaults.dictionary(
            forKey: Self.peakPriceMemoryKey
        ) as? [String: Int64]) ?? [:]
        var runPrices: [String: Int64] = [:]
        if let container = HakoAppIdentifiers.appGroupContainer,
           let text = try? String(
               contentsOf: container.appendingPathComponent(
                   MemorySampleLog.startupPhaseFileName
               ),
               encoding: .utf8
           )
        {
            for row in HakoMemoryLedger.lastRun(
                from: text.split(separator: "\n").map(String.init)
            ).rows where row.name.hasPrefix("apply:rule-provider:") {
                 
                 
                 
                 
                 
                let name = String(
                    row.name.dropFirst("apply:rule-provider:".count)
                )
                guard !name.isEmpty else { continue }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                let measured = row.peakSpendBytes
                guard measured > 0 else { continue }
                runPrices[name] = measured
                if row.peakBytes == nil {
                     
                     
                    prices[name] = min(prices[name] ?? .max, measured)
                } else {
                     
                     
                    peakPrices[name] = max(peakPrices[name] ?? 0, measured)
                }
            }
            defaults.set(prices, forKey: Self.priceMemoryKey)
            defaults.set(peakPrices, forKey: Self.peakPriceMemoryKey)
        }
         
         
         
         
        var estimates: [String: Int64] = [:]
        for (name, rp) in nodes.runtimeProviderCatalog.ruleProviders
            where rp.behavior?.lowercased() == "domain" && rp.ruleCount > 0
        {
            estimates[name] = Int64(rp.ruleCount) * 84
        }
         
         
         
         
        for (name, size) in MemoryTrimCensus.stagedFileSizes(
            kind: "rule-providers",
            container: HakoAppIdentifiers.appGroupContainer
        ) where estimates[name] == nil {
            estimates[name] = size
        }
        let items = MemoryTrimCensus.ruleProviders(
            sourceYAML: currentProfile.flatMap { profiles.sourceYAML(for: $0) },
             
             
             
             
             
             
            effectiveYAML: MemoryTrimCensus.effectiveYAML(
                container: HakoAppIdentifiers.appGroupContainer
            ),
            dropped: currentProfile?.memoryTrim?.droppedRuleProviders ?? [],
            prices: prices.merging(peakPrices) { _, peak in peak },
            runPrices: runPrices,
            estimates: estimates
        )
        censusNote = "ruleset-census total=\(items.count)"
            + " fromOverride=\(items.filter { $0.origin == .override }.count)"
        HakoLogStore.shared.append(
            "ruleset-items total=\(items.count) priced=\(items.filter { $0.measuredBytes != nil }.count) zero=\(items.filter { $0.measuredBytes == 0 }.count) run=\(runPrices.count) store=\(prices.count)",
            stream: .app, level: .info)
        return items
    }

    private func saveTrimAndRetry(_ spec: MemoryTrimSpec) {
        guard var profile = currentProfile else { return }
        profile.memoryTrim = spec.isEmpty ? nil : spec
        profiles.saveMemoryTrim(profile)
        Task {
            guard await profiles.selectAndWait(profile) else { return }
            await vpn.start(origin: .programmatic)
            rebind()
        }
    }

     
     
     
    static func memoryBill(
        ruleSetCensusCount: Int? = nil,
        ruleSetCensusBytes: Int64? = nil,
        dnsCensusCount: Int? = nil,
        providerCensusCount: Int? = nil,
        geoCensusCount: Int? = nil,
        geoCensusBytes: Int64? = nil
    ) -> [MemoryBillSection.Line] {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let text = try? String(
                  contentsOf: container.appendingPathComponent(
                      MemorySampleLog.startupPhaseFileName
                  ),
                  encoding: .utf8
              )
        else { return [] }
        let ledger = HakoMemoryLedger.lastRun(
            from: text.split(separator: "\n").map(String.init)
        )
        let lines = MemoryBillSection.lines(
            ledger: ledger,
            pressureFootprintBytes: CoreMemoryPressure.observed()?
                .footprintBytes,
            ruleSetCensusCount: ruleSetCensusCount,
            ruleSetCensusBytes: ruleSetCensusBytes,
            dnsCensusCount: dnsCensusCount,
            providerCensusCount: providerCensusCount,
            geoCensusCount: geoCensusCount,
            geoCensusBytes: geoCensusBytes
        )
        return lines
    }

     
     
     
     
     
     
    private func rebuildFailureCaptureIfNeeded() {
        guard billLines.isEmpty else { return }
        unreadableRuleSets = Self.unreadableRuleSets()
        geoNameCount = geoNameCount(for: startupExplanation)
        coreLog = CoreLogExcerpt.recent()
        strippedNotices = CoreLogExcerpt.strippedThisRun()
        ruleSetItems = buildRuleSetItems()
        let providerRows = providerLoad()
        providerLoadRows = providerRows
        let geoSite = geoItems(kind: "GEOSITE")
        let geoIP = geoItems(kind: "GEOIP")
        billLines = Self.memoryBill(
            ruleSetCensusCount: ruleSetItems.count,
            ruleSetCensusBytes: ruleSetItems
                .compactMap(\.measuredBytes).reduce(0, +),
            dnsCensusCount: dnsCensus().count,
            providerCensusCount: providerRows.count,
            geoCensusCount: geoSite.count + geoIP.count,
            geoCensusBytes: (geoSite + geoIP)
                .compactMap(\.1).reduce(0, +)
        )
    }

     
    private func geoItems(kind: String) -> [(String, Int64?)] {
        let yaml = currentProfile.flatMap { profiles.sourceYAML(for: $0) }
        let dropped = kind == "GEOIP"
            ? currentProfile?.memoryTrim?.droppedGeoIPRules ?? []
            : currentProfile?.memoryTrim?.droppedGeoSiteRules ?? []
        let container = HakoAppIdentifiers.appGroupContainer
        return MemoryTrimCensus.geoRuleNames(
            sourceYAML: yaml, kind: kind, dropped: dropped
        ).map {
            ($0, MemoryTrimCensus.geoArtifactBytes(
                kind: kind, name: $0, container: container))
        }
    }

     
    private func pricedDNS(_ entries: [String]) -> [(String, Int64?)] {
        let store = (GlobalConfig.appGroupDefaults.dictionary(
            forKey: Self.priceMemoryKey
        ) as? [String: Int64]) ?? [:]
        let container = HakoAppIdentifiers.appGroupContainer
        return entries.map {
            ($0, MemoryTrimCensus.dnsEntryBytes(
                $0, container: container, rulePrices: store
            ))
        }
    }

     
    private func dnsCensus() -> [String] {
        let yaml = currentProfile.flatMap { profiles.sourceYAML(for: $0) }
         
         
        let effective = MemoryTrimCensus.effectiveYAML(
            container: HakoAppIdentifiers.appGroupContainer
        )
        return MemoryTrimCensus.dnsPolicyKeys(
            sourceYAML: yaml,
            effectiveYAML: effective,
            dropped: currentProfile?.memoryTrim?.droppedDNSPolicyKeys ?? []
        ) + MemoryTrimCensus.fakeIPFilterEntries(
            sourceYAML: yaml,
            dropped: currentProfile?.memoryTrim?
                .droppedFakeIPFilterEntries ?? []
        )
    }

     
    private func providerCensusCount() -> Int {
         
         
        providerLoad().count
    }

     
     
    private func providerLoad() -> [ProviderLoadDetailView.Row] {
         
         
         
         
        let yaml = currentProfile.flatMap { profiles.sourceYAML(for: $0) }
        let subscriptions = MemoryTrimCensus.proxyProviderNames(
            sourceYAML: yaml
        )
        let groups = configTally?.groupNames ?? []
        var measured: [String: Int64] = [:]
        for row in Self.providerLoadRows() { measured[row.name] = row.bytes }
        let disk = MemoryTrimCensus.stagedFileSizes(
            kind: "proxy-providers",
            container: HakoAppIdentifiers.appGroupContainer
        )
        let subsSet = Set(subscriptions)
        return (subscriptions.sorted() + groups.sorted()).map { name in
            if let real = measured[name] {
                return ProviderLoadDetailView.Row(
                    name: name, bytes: real,
                    isSubscription: subsSet.contains(name)
                )
            }
             
            return ProviderLoadDetailView.Row(
                name: name, bytes: disk[name], isEstimate: disk[name] != nil,
                isSubscription: subsSet.contains(name)
            )
        }
    }

    static func providerLoadRows() -> [ProviderLoadDetailView.Row] {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let text = try? String(
                  contentsOf: container.appendingPathComponent(
                      MemorySampleLog.startupPhaseFileName
                  ),
                  encoding: .utf8
              )
        else { return [] }
        return HakoMemoryLedger.lastRun(
            from: text.split(separator: "\n").map(String.init)
        ).rows.compactMap { row in
            guard row.name.hasPrefix("apply:proxy-provider:") else {
                return nil
            }
             
             
             
             
            return ProviderLoadDetailView.Row(
                name: String(
                    row.name.dropFirst("apply:proxy-provider:".count)
                ),
                bytes: row.deltaBytes > 0 ? row.deltaBytes : nil
            )
        }
    }

     
     
     
     
     
    static func unreadableRuleSets() -> [ProvidersModel.Row] {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let store = try? ConfigResourceStore(containerURL: container),
              let providers = try? store.activeProvidersDirectory()
        else { return [] }
        return ProvidersModel.unreadableRuleSets(providersDir: providers)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func geoNameCount(for explanation: HakoStartupExplanation?) -> Int? {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let resource = explanation?.resource ?? ""
        let isGeoSite = resource.hasPrefix("geosite:")
        guard explanation != nil,
              resource.isEmpty || resource.hasPrefix("geoip:") || isGeoSite,
              let profile = currentProfile,
              let yaml = profiles.previewText(for: profile),
              !yaml.isEmpty
        else { return nil }
         
         
         
         
         
        let lines = (isGeoSite ? HakoGeoSiteCategoryLines(yaml) : HakoGeoIPCountryLines(yaml))
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        HakoLogStore.shared.append(
            "geo count: \(lines.count) \(isGeoSite ? "categories" : "countries") named",
            stream: .app
        )
        return lines.isEmpty ? nil : lines.count
    }

     
     
    static func isStoppedStatus(_ status: String) -> Bool {
        ["disconnected", "invalid", "unknown"].contains(
            Self.normalizedStatus(status)
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func startRetiresStartupExplanation(_ status: String) -> Bool {
        Self.normalizedStatus(status) == "connected"
    }

     
     
     
     
     
     
     
     
     
     
     
    static func stopMayBeExplained(
        status: String,
        lastStartFailed: Bool
    ) -> Bool {
        isStoppedStatus(status) && lastStartFailed
    }

    private static func normalizedStatus(_ status: String) -> String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

     
     
     
     
     
    private var connectionErrorMessage: String {
        let live = vpn.reportableLastError
        guard let startupExplanation else { return live }
         
         
         
         
         
         
         
         
         
         
         
        guard live.isEmpty || VPNDisconnectErrorPresentation
            .isProviderStoppedUnexpectedly(live)
        else { return live }
        return HakoCopy.string(for: startupExplanation.summary, locale: locale)
    }

    private var presentation: HomeConnectionPresentation {
        HomeConnectionPresenter.presentation(
            for: HomeConnectionFacts(
                activeProfileName: currentProfile?.label,
                vpnStatus: vpn.status,
                errorMessage: connectionErrorMessage,
                errorIsStartupStopped: vpn.reportableLastError.isEmpty
                    && startupExplanation != nil,
                allowsSystemVPNProfileReset:
                    vpn.systemVPNProfileResetAvailable,
                isSwitchingProxy: nodes.isSwitchingProxy,
                recoveryMode: .none,
                mode: configuredMode.rawValue,
                selectedProxyName: selectedRoute.name,
                selectedProxyDelayMilliseconds:
                    selectedRoute.delay
            )
        )
    }

    private var sharedSnapshot: AppleClientSnapshot {
         
         
         
         
        HakoPerf.measure("home.snapshot") { untimedSharedSnapshot }
    }

    private var untimedSharedSnapshot: AppleClientSnapshot {
         
         
         
        let timedProfile = HakoPerf.measure("home.s.profile") { currentProfile }
        let timedPresentation = HakoPerf.measure("home.s.presentation") {
            presentation
        }
        let timedProxyCount = HakoPerf.measure("home.s.proxyCount") {
            homeProxyCount
        }
        let timedProxyBreakdown = HakoPerf.measure("home.s.proxyBreakdown") {
            proxiesCardBreakdown
        }
        let timedRuleBreakdown = HakoPerf.measure("home.s.ruleBreakdown") {
            rulesCardBreakdown
        }
        let timedRuleTargets = HakoPerf.measure("home.s.ruleTargets") {
            rulesCardTargets
        }
        let timedEgress = HakoPerf.measure("home.s.egress") { egressSnapshot }
        let timedAdjustments = HakoPerf.measure("home.s.adjustments") {
            HomeAdjustmentModule.allCases.map {
                HakoHomeAdjustmentSnapshot(
                    module: $0,
                    summary: adjustmentSummary($0)
                )
            }
        }
        let timedTally = HakoPerf.measure("home.s.tally") { configTally }
        return AppleClientSnapshot(
            revision: UInt64(truncatingIfNeeded: profileRefreshToken),
            selectedProfile: timedProfile.flatMap {
                guard let identifier = try? HakoClientKit.Profile.ID($0.id)
                else {
                    return nil
                }
                return AppleClientProfileSnapshot(
                    id: identifier,
                    label: $0.label
                )
            },
            connection: AppleClientConnectionSnapshot(
                phase: appleConnectionPhase
            ),
            home: AppleClientHomeSnapshot(
                routing: AppleClientRoutingSnapshot(
                    mode:
                        AppleClientOutboundMode(
                            rawValue: configuredMode.rawValue
                        ) ?? .rule
                ),
                traffic: HakoClientUI.HakoPerfExperiment.freezesTrafficFigures
                    ? AppleClientTrafficSnapshot()
                    : AppleClientTrafficSnapshot(
                    uploadBytesPerSecond: command.traffic.upload,
                    downloadBytesPerSecond: command.traffic.download,
                    uploadTotalBytes: command.traffic.uploadTotal,
                    downloadTotalBytes: command.traffic.downloadTotal,
                     
                     
                     
                    uploadRatesBytesPerSecond:
                        command.traffic.uploadHistory,
                    downloadRatesBytesPerSecond:
                        command.traffic.downloadHistory,
                    coreStartedAtUnixSeconds:
                        command.runtimeDiagnostics?.startTimeUnix ?? 0
                ),
                proxyGroupCount: timedTally?.proxyGroups ?? 0,
                proxyCount: timedTally?.proxies ?? 0,
                ruleCount: timedTally?.rules ?? 0,
                connection: timedPresentation,
                initialSection:
                    false
                        ? .adjust
                        : .common,
                favoriteCards: favoriteCards,
                trafficScope:
                    trafficOnlyProxy ? .proxiedOnly : .allTraffic,
                proxies: HakoHomeDomainSnapshot(
                    count: timedProxyCount,
                    countUnit: "proxies",
                    breakdown: timedProxyBreakdown,
                    names: timedTally?.groupNames ?? []
                ),
                rules: HakoHomeDomainSnapshot(
                    count: timedTally?.rules,
                    countUnit: "rules",
                    breakdown: timedRuleBreakdown,
                    names: timedRuleTargets
                ),
                egress: timedEgress,
                lanAddress: lanAddress,
                adjustments: timedAdjustments,
                isProfileActionInFlight:
                    profiles.isActivationInFlight
            ),
            capabilities: AppleClientCapabilities([
                .home: .available,
                .outboundMode:
                    currentProfile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
            ])
        )
    }

    private var sharedActions: AppleClientActions {
        let home = AppleClientActions(capability: .home) { action in
            guard case .home(let command) = action else {
                return
            }
            perform(command)
        }
        let outbound = AppleClientActions(
            capability: .outboundMode
        ) { action in
            guard case .setOutboundMode(let mode) = action else {
                return
            }
            setOutboundMode(mode.rawValue)
        }
        return (
            try? AppleClientActions.composing([home, outbound])
        ) ?? .unavailable
    }

    private var appleConnectionPhase: AppleClientConnectionPhase {
        switch vpn.status.lowercased() {
        case "connected", "reasserting":
            .connected
        case "connecting":
            .preparing
        case "disconnecting":
            .disconnecting
        case "invalid", "unknown":
            .unavailable
        default:
            .disconnected
        }
    }

    private var egressSnapshot: HakoHomeEgressSnapshot {
         
         
         
         
        let connected = vpn.status == "connected"
        let address = stats.egressIP
        let hasResult =
            connected
            && !address.isEmpty
            && address != "—"
            && address != "checking…"
            && address != "VPN not connected"
            && !address.hasPrefix("error")
        let detail = [
            stats.egressCountryName,
            stats.egressISP,
        ]
        .filter { !$0.isEmpty && $0 != "—" }
        .joined(separator: " · ")
        return HakoHomeEgressSnapshot(
            address: hasResult ? address : nil,
            flag:
                hasResult
                    ? EgressLookupResult.flagEmoji(
                        countryCode: stats.egressCountryCode
                    )
                    : "",
            detail: hasResult ? detail : "",
            canRefresh: connected,
            isChecking: connected && address == "checking…"
        )
    }

    private func perform(_ command: HakoHomeCommand) {
        switch command {
        case .openProfiles:
            openProfiles()
        case .performPrimaryAction(let action):
            performPrimaryAction(action)
        case .showConnectionIssue:
            presentedConnectionIssue = presentation.issue
         
         
         
        case .openProxies:
            if shellLayout == .regularSidebar {
                openProxies()
            } else {
                presentProxiesOverview()
            }
        case .openRules:
            if shellLayout == .regularSidebar {
                openRules()
            } else {
                presentRulesOverview()
            }
        case .openAdjustment(let action):
            presentEditor(for: action)
        case .openRuntimeConfiguration:
            presentRuntimeConfiguration()
        case .setCards(let cards):
            favoriteCards = HakoHomeCatalog.normalized(cards)
        case .setTrafficScope(let scope):
            setTrafficOnlyProxy(scope == .proxiedOnly)
        case .refreshExternalIP:
            Task {
                await stats.checkEgressIP()
            }
        case .refreshLANIP:
            lanAddress = LANAddressInventory.current().first
        }
    }

     
     
     
     
    private func presentRuntimeConfiguration() {
        guard let profile = currentProfile else { return }
        runtimeConfigurationPreparationGeneration &+= 1
        runtimeConfigurationPresentation = nil
        runtimeConfigurationProfile = profile
    }

    private func prepareRuntimeConfiguration(
        for profile: Profile,
        generation requestedGeneration: UInt64
    ) async {
         
         
        await Task.yield()
        guard !Task.isCancelled,
              requestedGeneration == runtimeConfigurationPreparationGeneration
        else { return }
        let profileID = profile.id
        let includesBlockedRuleSets = profiles.activeProfileID == profileID
        let sourceYAML = profiles.capturedSourceText(for: profile)
        let comparisonYAML = profiles.sourceYAML(for: profile)
        let baseYAML = comparisonYAML.flatMap {
            RunningCoreDeviations.handedToCore(
                profile: profile,
                sidecarYAML: $0
            )
        }
        let effectiveYAML = profiles.previewText(for: profile)
        let began = DispatchTime.now().uptimeNanoseconds
        let snapshot = await Task.detached(priority: .userInitiated) {
            ProfileFinalConfigurationSnapshot.make(
                sourceYAML: sourceYAML,
                effectiveYAML: effectiveYAML
            )
        }.value
        guard !Task.isCancelled,
              requestedGeneration == runtimeConfigurationPreparationGeneration,
              runtimeConfigurationProfile?.id == profileID
        else { return }
        runtimeConfigurationPresentation = RuntimeConfigurationPresentation(
            profileID: profileID,
            snapshot: snapshot,
            sourceYAML: sourceYAML,
            comparisonYAML: comparisonYAML,
            baseYAML: baseYAML,
            includesBlockedRuleSets: includesBlockedRuleSets
        )
        HakoPerf.span(
            "final.prepare",
            milliseconds: Double(
                DispatchTime.now().uptimeNanoseconds - began
            ) / 1_000_000
        )
    }

    private func setTrafficOnlyProxy(_ enabled: Bool) {
        guard enabled != trafficOnlyProxy else {
            return
        }
        trafficOnlyProxy = enabled
        TrafficStatisticsSettings.setOnlyProxy(enabled)
        command.applyTrafficStatisticsPreference()
    }

     
     
     
     
     
     
     
     
     
     
    private var homeProxyCount: Int? {
        let inline = configTally?.proxies
         
         
         
         
         
         
        let fromDisk = subscriptionNodeTally
        let fromRuntime = nodes.runtimeProviderCatalog.proxyProviders.values
            .filter { !$0.isKernelInternal }
            .reduce(0) { $0 + $1.proxies.count }
        let subscription = fromDisk ?? fromRuntime
        guard subscription > 0 else { return inline }
        return (inline ?? 0) + subscription
    }

     
     
     
     
     
     
     
     
    @State private var subscriptionNodeTally: Int?

    private static func readSubscriptionNodeTally(
        store: ConfigResourceStore?
    ) -> Int? {
        guard let store,
              let directory = try? store.activeProvidersDirectory(),
              let catalog = ProviderCatalog.load(providersDir: directory)
        else { return nil }
        let total = catalog.entries
            .filter { $0.kind == "proxy" }
            .compactMap(\.count)
            .reduce(0, +)
        return total > 0 ? total : nil
    }

    private var proxiesCardBreakdown: String? {
        guard let tally = configTally else {
            return nil
        }
        var parts: [String] = []
        if tally.proxyGroups > 0 {
            parts.append(
                Self.countedNoun(
                    tally.proxyGroups,
                    "%d group",
                    "%d groups",
                    locale: locale
                )
            )
        }
        if tally.proxyProviders > 0 {
            parts.append(
                Self.countedNoun(
                    tally.proxyProviders,
                    "%d source",
                    "%d sources",
                    locale: locale
                )
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var rulesCardBreakdown: String? {
        guard let tally = configTally else {
            return nil
        }
        var parts: [String] = []
        if tally.ruleProviders > 0 {
            parts.append(
                Self.countedNoun(
                    tally.ruleProviders,
                    "%d set",
                    "%d sets",
                    locale: locale
                )
            )
        }
        if tally.subRules > 0 {
            parts.append(
                Self.countedNoun(
                    tally.subRules,
                    "%d sub-rule",
                    "%d sub-rules",
                    locale: locale
                )
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var rulesCardTargets: [String] {
        (rulesOverview?.buckets.prefix(3) ?? []).map {
            "\($0.target) \($0.rules.count)"
        }
    }

    private static func countedNoun(
        _ count: Int,
        _ singular: String,
        _ plural: String,
        locale: Locale
    ) -> String {
        HakoCopy.format(
            count == 1 ? singular : plural,
            locale: locale,
            count
        )
    }

    private func recomputeConfiguredMode() {
         
         
         
         
         
         
         
         
         
         
         
         
         
        if command.isConnected,
           let running = Profile.OutboundMode(rawValue: command.mode.lowercased()) {
            configuredMode = running
            return
        }
        guard let currentProfile else {
            configuredMode = .rule
            return
        }
        configuredMode = profiles.outboundMode(for: currentProfile)
    }

    private func setOutboundMode(_ rawValue: String) {
        guard let profile = currentProfile,
              let mode = Profile.OutboundMode(rawValue: rawValue)
        else {
            return
        }

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if OutboundModeSelection.changesNothing(
            requested: mode,
            stored: profiles.outboundMode(for: profile),
            running: command.isConnected ? command.mode : nil
        ) {
             
             
             
             
             
            ModeIntentClock.next()
            configuredMode = mode
            return
        }

        if mode == .global, command.isConnected {
            let intent = ModeIntentClock.next()
            let previousMode = configuredMode
             
             
            configuredMode = mode
            Task {
                guard await nodes.ensureGlobalProxySelection() else {
                     
                     
                     
                    guard ModeIntentClock.isCurrent(intent) else { return }
                    configuredMode = previousMode
                     
                     
                     
                     
                    modeRefusal = OutboundModeRefusal(
                        title: "Global Mode Unavailable",
                        message: GlobalProxySelectionPolicy.refusal(
                            groups: nodes.groups
                        )
                            ?? """
                            The core did not confirm a node for the GLOBAL \
                            group, so Global mode was not applied.
                            """,
                        offersNodeChoice: true
                    )
                    return
                }
                 
                 
                 
                 
                 
                 
                 
                guard ModeIntentClock.isCurrent(intent) else { return }
                do {
                    try profiles.updateOutboundMode(
                        profileID: profile.id,
                        mode: mode,
                        kernelCarriesTheChange: command.isConnected
                    )
                    guard await command.setMode(mode.rawValue) else {
                        repairAfterFailedModePatch(
                            profile: profile,
                            intent: intent
                        )
                        return
                    }
                } catch {
                    configuredMode = previousMode
                    recomputeConfiguredMode()
                    modeRefusal = .saveFailed(mode: mode, error: error)
                }
            }
            return
        }

        do {
            let intent = ModeIntentClock.next()
            try profiles.updateOutboundMode(
                profileID: profile.id,
                mode: mode,
                kernelCarriesTheChange: command.isConnected
            )
            configuredMode = mode
             
             
             
             
             
             
             
            if command.isConnected {
                Task {
                    guard await command.setMode(mode.rawValue) else {
                        repairAfterFailedModePatch(
                            profile: profile,
                            intent: intent
                        )
                        return
                    }
                }
            }
        } catch {
            recomputeConfiguredMode()
            modeRefusal = .saveFailed(mode: mode, error: error)
        }
    }

     
     
     
     
     
     
     
     
     
    private func repairAfterFailedModePatch(
        profile: Profile,
        intent: UInt64
    ) {
        guard ModeIntentClock.isCurrent(intent) else { return }
        let kernelMode = Profile.OutboundMode(
            rawValue: command.mode.lowercased()
        )
        do {
            if let kernelMode {
                try profiles.updateOutboundMode(
                    profileID: profile.id,
                    mode: kernelMode,
                    kernelCarriesTheChange: true
                )
            }
            recomputeConfiguredMode()
            modeRefusal = OutboundModeRefusal(
                title: "Mode Not Applied",
                message: "The running tunnel did not take the change, so nothing was changed."
            )
        } catch {
            recomputeConfiguredMode()
            modeRefusal = .saveFailed(mode: kernelMode ?? .rule, error: error)
        }
    }

     
     
     
     
    private func enforceConnectedGlobalMode() async {
         
         
         
        let observedIntent = ModeIntentClock.sequence
        let confirmed = await nodes.ensureGlobalProxySelection()
        guard ModeIntentClock.isCurrent(observedIntent) else { return }
        switch GlobalModeConfirmation.verdict(
            groupCount: nodes.groups.count,
            selectionConfirmed: confirmed
        ) {
        case .confirmed:
            return
        case .notYetKnown:
             
             
             
             
             
            return
        case .refused:
            break
        }
        if let profile = currentProfile {
            try? profiles.updateOutboundMode(
                profileID: profile.id,
                mode: .rule,
                kernelCarriesTheChange: command.isConnected
            )
        }
        configuredMode = .rule
        await command.setMode(Profile.OutboundMode.rule.rawValue)
    }

    private func presentEditor(
        for action: HakoHomeAdjustmentAction
    ) {
        HakoPushClock.tap()
        guard let currentProfile else {
            return
        }
        switch action {
        case .customNodes:
            editorDestination = .customNodes(currentProfile)
        case .proxyChains:
            editorDestination = .proxyChains(currentProfile)
        case .routingRules:
            editorDestination = .rules(currentProfile)
        case .connection:
            editorDestination = .network(currentProfile)
        case .proxySources:
            editorDestination = .proxySources(currentProfile)
        case .ruleSets:
            editorDestination = .ruleSets(currentProfile)
        case .advancedOverrides:
            editorDestination = .advanced(currentProfile)
        case .rawFields:
            editorDestination = .additionalFields(currentProfile)
        }
    }

    private func adjustmentSummary(
        _ module: HomeAdjustmentModule
    ) -> String {
        guard let profile = currentProfile else {
            return module.subtitle
        }
        switch module {
        case .nodes:
            let chains = profile.proxyChain?.assignments.count ?? 0
            return chains == 0
                ? module.subtitle
                : HakoCopy.format("%d proxy chains", locale: locale, chains)
        case .rules:
            let count = profile.override.appendRules.count
            return count == 0
                ? module.subtitle
                : HakoCopy.format("%d personal rules", locale: locale, count)
        case .network:
            let count =
                ProfileNetworkDraft(profile: profile)
                    .customizedProfileFieldCount
            return count == 0
                ? module.subtitle
                : HakoCopy.format(
                    "%d profile network settings",
                    locale: locale,
                    count
                )
        case .resources:
             
             
             
            guard let counts = resourceCounts, counts.hasResources else {
                return module.subtitle
            }
            if counts.providers > 0 {
                return HakoCopy.format(
                    "%d proxy sources · %d rule sets",
                    locale: locale,
                    counts.proxyProviders,
                    counts.ruleProviders
                )
            }
            return HakoCopy.format(
                "%d supporting files",
                locale: locale,
                counts.supportingFiles
            )
        case .advancedOverrides:
            switch profile.overwriteMode ?? .standard {
            case .standard:
                let count =
                    ProfileAdvancedOverridesDraft(profile: profile)
                        .rawPatchFieldCount
                return count == 0
                    ? HakoCopy.string("Visual settings only", locale: locale)
                    : HakoCopy.format(
                        "%d additional fields",
                        locale: locale,
                        count
                    )
            case .script:
                return profile.selectedScriptID == nil
                    ? HakoCopy.string("Choose a local script", locale: locale)
                    : HakoCopy.string("Local script selected", locale: locale)
            case .custom:
                let custom =
                    profile.customOverwrite ?? CustomOverwriteSpec()
                return HakoCopy.format(
                    "%d custom groups · %d rules",
                    locale: locale,
                    custom.proxyGroups.count,
                    custom.rules.count
                )
            }
        }
    }

    private func performPrimaryAction(
        _ action: HomePrimaryAction
    ) {
        switch action {
        case .openProfiles:
            openProfiles()
        case .connect, .retry:
            connectCurrentProfile()
        case .cancel:
            Task {
                 
                 
                 
                await vpn.stop(alongside: {
                    if profiles.busyProfileID != nil {
                        profiles.cancelActivation()
                    }
                })
            }
        case .disconnect:
            Task {
                await vpn.stop()
            }
        case .retryProxy:
            Task {
                await vpn.forceRestart()
                rebind()
            }
        case .none:
            break
        }
    }

    private func presentProxiesOverview() {
        guard let currentProfile else {
            return
        }
        presentProxiesOverview(for: currentProfile)
    }

    private func presentProxiesOverview(for profile: Profile) {
         
         
         
        sessionPresentation = .proxies
        proxiesPreparationGeneration &+= 1
        preparedProxiesPresentation = nil
        editorDestination = .proxiesOverview(profile)
    }

    private func prepareProxiesOverview(
        for profile: Profile,
        generation requestedGeneration: UInt64
    ) async {
        let sourceYAML = profiles.uiProjectedYAML(for: profile)
        let selectedMap = profile.selectedMap
        let preparedModel = await Task.detached(
            priority: .userInitiated
        ) {
            var providerNodes:
                [String: [ProxiesOverviewModel.Proxy]] = [:]
            if let container = HakoAppIdentifiers.appGroupContainer,
               let store = try? ConfigResourceStore(
                   containerURL: container
               ),
               let directory =
                   try? store.activeProvidersDirectory()
            {
                providerNodes = ProviderNodesLoader.load(
                    providersDir: directory
                )
            }
            return ProxiesOverviewModel.make(
                sourceYAML: sourceYAML,
                selectedMap: selectedMap,
                providerNodes: providerNodes
            )
        }.value
        guard !Task.isCancelled,
              requestedGeneration == proxiesPreparationGeneration,
              editorDestination?.id == "\(profile.id)|proxies-overview"
        else {
            return
        }
        preparedProxiesPresentation = PreparedProxiesPresentation(
            profileID: profile.id,
            sourceModel: preparedModel
        )
    }

    private func presentRulesOverview() {
        guard let currentProfile else {
            return
        }
        sessionPresentation = .rules
        editorDestination = .rulesOverview(currentProfile)
    }

    private func recomputeTally() {
         
         
         
         
         
         
         
         
        let projectionProfile = currentProfile
        let projectedCached = currentProfile.flatMap {
            profiles.cachedUIProjectedYAML(for: $0)
        }
        let projectionInputs = projectedCached == nil
            ? currentProfile.map { profiles.uiProjectionInputs(for: $0) }
            : nil
        let store = profiles.resourceStoreForHomeTally
         
         
         
        let profileForResources = currentProfile
        let resourceYAML = currentProfile.flatMap {
            profiles.sourceYAML(for: $0)
        }
         
         
         
        let cacheKey = currentProfile.map {
            HomeTallyCache.Key(profileID: $0.id, refreshToken: profileRefreshToken)
        }
        if let cacheKey, let cached = HomeTallyCache.shared.entry(for: cacheKey) {
            configTally = cached.tally
            rulesOverview = cached.rulesOverview
            subscriptionNodeTally = cached.subscriptionNodeTally
            resourceCounts = cached.resourceCounts
        }
        Task.detached(priority: .userInitiated) {
             
             
             
             
             
             
             
            if projectedCached == nil, let projectionInputs, let projectionProfile {
                let value = CustomNodesGroupMaterializer.projectForUI(
                    sourceYAML: projectionInputs.sourceYAML,
                    profile: projectionProfile
                )
                await MainActor.run {
                    profiles.rememberUIProjectedYAML(
                        value, key: projectionInputs.key, for: projectionProfile
                    )
                }
            }
            let (effective, tunnelRunning): (String?, Bool) = await MainActor.run {
                (projectionProfile.flatMap { profiles.effectiveYAML(for: $0) }, command.isConnected)
            }
            let tally = ProfileConfigTally.make(sourceYAML: effective, tunnelRunning: tunnelRunning)
            let overview = RulesOverviewModel.make(sourceYAML: effective)
            let subscription = Self.readSubscriptionNodeTally(store: store)
            let counts = HomeResourceCounts.make(
                profile: profileForResources,
                sourceYAML: resourceYAML
            )
            await MainActor.run {
                 
                 
                 
                if configTally != tally { configTally = tally }
                if rulesOverview?.fingerprint != overview.fingerprint {
                    rulesOverview = overview
                }
                if subscriptionNodeTally != subscription {
                    subscriptionNodeTally = subscription
                }
                if resourceCounts != counts { resourceCounts = counts }
                if let cacheKey {
                    HomeTallyCache.shared.store(
                        HomeTallyCache.Entry(
                            tally: tally,
                            rulesOverview: overview,
                            subscriptionNodeTally: subscription,
                            resourceCounts: counts
                        ),
                        for: cacheKey
                    )
                }
            }
        }
    }

    private func connectCurrentProfile() {
        guard let profile = currentProfile else {
            openProfiles()
            return
        }
        if profiles.activeProfileID == profile.id {
            Task {
                 
                 
                 
                 
                 
                 
                guard await profiles.selectAndWait(profile, force: true)
                else { return }
                await vpn.start()
                rebind()
            }
        } else {
            profiles.select(profile)
        }
    }
}

private enum HomeProfileEditorDestination: Identifiable {
    case rulesOverview(Profile)
    case proxiesOverview(Profile)
    case customNodes(Profile)
    case proxySources(Profile)
    case ruleSets(Profile)
    case network(Profile)
    case rules(Profile)
    case proxyChains(Profile)
    case advanced(Profile)
    case additionalFields(Profile)

    var id: String {
        switch self {
        case .customNodes(let profile):
            "\(profile.id)|custom-nodes"
        case .proxySources(let profile):
            "\(profile.id)|proxy-sources"
        case .ruleSets(let profile):
            "\(profile.id)|rule-sets"
        case .network(let profile):
            "\(profile.id)|network"
        case .rules(let profile):
            "\(profile.id)|rules"
        case .rulesOverview(let profile):
            "\(profile.id)|rules-overview"
        case .proxiesOverview(let profile):
            "\(profile.id)|proxies-overview"
        case .proxyChains(let profile):
            "\(profile.id)|proxy-chains"
        case .advanced(let profile):
            "\(profile.id)|advanced"
        case .additionalFields(let profile):
            "\(profile.id)|additional-fields"
        }
    }
}

private struct HomePreparationPlaceholder: View {
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        HakoSingleColumnNavigationContainer {
            HakoPageLoadingPlaceholder(title: .copy("Loading"))
                .accessibilityIdentifier(accessibilityIdentifier)
                .hakoPageTitle(.copy(title))
                .hakoToolbarUnlessInPanel {
                    ToolbarItem(placement: .cancellationAction) {
                        HakoSheetCloseButton { dismiss() }
                    }
                }
        }
        .hakoCapturesDismiss(dismiss)
    }
}


