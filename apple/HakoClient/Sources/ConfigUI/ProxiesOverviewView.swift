import Combine
import HakoClientUI
import SwiftUI

struct ProxiesRuntimeFacts {
    var delays: [String: Int] = [:]
     
     
     
     
    var failureReasons: [String: String] = [:]
    var nowByGroup: [String: String] = [:]
    var resolvedNowByGroup: [String: String] = [:]
     
     
     
    var catalog: [ProxyGroup] = []
     
    var runtimeNodes: [ProxiesOverviewModel.Proxy] = []
     
    var providerCatalog = ProviderRuntimeCatalog.empty
     
     
     
    var isAuthoritative = false

    static let none = ProxiesRuntimeFacts()


}

typealias ProxiesDisplayPreferences =
    HakoProxiesDisplayPreferences

extension HakoProxiesDisplayPreferences {
    static let key = "proxies.display.v1"

    static func load(
        defaults: UserDefaults = .standard
    ) -> HakoProxiesDisplayPreferences {
        guard let raw =
                defaults.dictionary(forKey: key)
                    as? [String: String] else {
            return HakoProxiesDisplayPreferences()
        }
        return HakoProxiesDisplayPreferences(
            style: raw["style"].flatMap(Style.init(rawValue:))
                ?? .list,
            sort: raw["sort"].flatMap(Sort.init(rawValue:))
                ?? .standard,
            layout: raw["layout"].flatMap(Layout.init(rawValue:))
                ?? .loose,
            size: raw["size"].flatMap(Size.init(rawValue:))
                ?? .standard,
             
             
            groupIconImages: raw["groupIconImages"] == "true"
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(
            [
                "style": style.rawValue,
                "sort": sort.rawValue,
                "layout": layout.rawValue,
                "size": size.rawValue,
                "groupIconImages": groupIconImages ? "true" : "false",
            ],
            forKey: Self.key
        )
    }

    static func uiTestOverride()
        -> HakoProxiesDisplayPreferences?
    {

        return nil

    }
}

 
 
 
 
 
struct ProxiesOverviewAdapter: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @ObservedObject private var networkPath =
        NetworkPathObserver.shared

    private let sourceModel: ProxiesOverviewModel
    private let runtime: ProxiesRuntimeFacts
     
     
     
     
     
     
    private let outboundMode: ProxyBrowsingVisibility.Mode
    private let isConnected: Bool
    private let testingNames: Set<String>
    private let isTestingLatency: Bool
     
    private let sweepEvents: AnyPublisher<LatencySweepBatch, Never>?
    private let latencyCompletedCount: Int
    private let latencyTotalCount: Int
    private let testAll: (() -> Void)?
    private let testGroup: ((String) -> Void)?
    private let switchSelection: ((String, String) -> Void)?
    private let setVisibleGroup: ((String?) -> Void)?
    private let updateProvider: ((String) -> Void)?
     
     
    private let setGroupExpanded: ((String, Bool) -> Void)?
    private let setGroupsExpanded: (([String], Bool) -> Void)?
    private let cancelLatency: (() -> Void)?
     
     
     
     
    private let refreshCatalog: (() -> Void)?
     
    private let unpinGroup: ((String) -> Void)?
     
    private let actionRefusals: [String: String]
     
    private let testMember: ((String) -> Void)?
     
    private let editMember: ((String) -> Void)?
    private let inspectMember: ((String) -> Void)?
    private let initiallyExpandedGroup: String?
     
     
     
    private let rememberedExpandedGroups: Set<String>

    @State private var preferences:
        HakoProxiesDisplayPreferences
    @State private var testAllDecision:
        NetworkPathPolicyDecision?
     
     
     
     
     
     
    @State private var frozenSweep: FrozenSweep?
    @StateObject private var pulseHub = LatencyPulseHub()
     
     
     
     
    @State private var projections = ProxiesProjectionMemo()

     
     
     
     
    @Environment(\.hakoLatencyPulseGate) private var latencyPulseGate

     
     
     
     
    private var isActiveRoot: Bool {
        latencyPulseGate?.isOpen ?? true
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var hiddenHold = SnapshotHold()

    final class SnapshotHold {
        var value: AppleClientSnapshot?
         
         
        var key: ProxiesSweepSnapshotHold.Key?
    }

    struct FrozenSweep: Equatable {
        let latency: [String: HakoProxyLatencyState]
         
         
         
        let failureCategories: [String: String]
        let completed: Int
        let total: Int
    }

     
     
     
     
     
     
     
     
     
    @MainActor
    final class LatencyPulseHub: ObservableObject {
        private let subject: CurrentValueSubject<HakoLatencyPulse, Never>
        private var accumulatedResults: [String: HakoProxyLatencyState] = [:]
        private var accumulatedGroupTerminals: [String: String] = [:]
        private var wasTesting = false
         
         
        let publisher: AnyPublisher<HakoLatencyPulse, Never>

         
         
         
         
         
         
         
         
        var current: HakoLatencyPulse { subject.value }

        init() {
            let initial = HakoLatencyPulse(
                results: [:],
                testing: [],
                completed: 0,
                total: 0,
                isTesting: false
            )
            subject = CurrentValueSubject(initial)
            publisher = subject.eraseToAnyPublisher()
        }

        func send(_ pulse: HakoLatencyPulse) {
            if pulse.isTesting, !wasTesting {
                accumulatedResults = pulse.results
                accumulatedGroupTerminals = pulse.groupTerminals
            } else {
                accumulatedResults.merge(pulse.results) { _, fresh in fresh }
                accumulatedGroupTerminals.merge(pulse.groupTerminals) {
                    _, fresh in fresh
                }
            }
            wasTesting = pulse.isTesting
            let replay = HakoLatencyPulse(
                results: accumulatedResults,
                testing: pulse.testing,
                groupTerminals: accumulatedGroupTerminals,
                completed: pulse.completed,
                total: pulse.total,
                isTesting: pulse.isTesting
            )
            subject.send(replay)
        }

         
         
         
         
         
         
        func replaceIdle(_ pulse: HakoLatencyPulse) {
            precondition(!pulse.isTesting)
            wasTesting = false
            accumulatedResults = pulse.results
            accumulatedGroupTerminals = pulse.groupTerminals
            subject.send(pulse)
        }
    }

    init(
        sourceModel: ProxiesOverviewModel,
        outboundMode: ProxyBrowsingVisibility.Mode,
        runtime: ProxiesRuntimeFacts = .none,
        isConnected: Bool = false,
        testingNames: Set<String> = [],
        isTestingLatency: Bool = false,
        sweepEvents: AnyPublisher<LatencySweepBatch, Never>? = nil,
        latencyCompletedCount: Int = 0,
        latencyTotalCount: Int = 0,
        testAll: (() -> Void)? = nil,
        testGroup: ((String) -> Void)? = nil,
        switchSelection: ((String, String) -> Void)? = nil,
        setVisibleGroup: ((String?) -> Void)? = nil,
        updateProvider: ((String) -> Void)? = nil,
        setGroupExpanded: ((String, Bool) -> Void)? = nil,
        setGroupsExpanded: (([String], Bool) -> Void)? = nil,
        cancelLatency: (() -> Void)? = nil,
        refreshCatalog: (() -> Void)? = nil,
        unpinGroup: ((String) -> Void)? = nil,
        actionRefusals: [String: String] = [:],
        testMember: ((String) -> Void)? = nil,
        editMember: ((String) -> Void)? = nil,
        inspectMember: ((String) -> Void)? = nil,
        initiallyExpandedGroup: String? = nil,
        rememberedExpandedGroups: Set<String> = [],
        ownsNavigationContainer: Bool = true
    ) {
        self.ownsNavigationContainer = ownsNavigationContainer
        self.sourceModel = sourceModel
        self.runtime = runtime
        self.outboundMode = outboundMode
        self.isConnected = isConnected
        self.testingNames = testingNames
        self.isTestingLatency = isTestingLatency
        self.sweepEvents = sweepEvents
        self.latencyCompletedCount = latencyCompletedCount
        self.latencyTotalCount = latencyTotalCount
        self.testAll = testAll
        self.testGroup = testGroup
        self.switchSelection = switchSelection
        self.setVisibleGroup = setVisibleGroup
        self.updateProvider = updateProvider
        self.setGroupExpanded = setGroupExpanded
        self.setGroupsExpanded = setGroupsExpanded
        self.cancelLatency = cancelLatency
        self.refreshCatalog = refreshCatalog
        self.unpinGroup = unpinGroup
        self.actionRefusals = actionRefusals
        self.testMember = testMember
        self.editMember = editMember
        self.inspectMember = inspectMember
        self.initiallyExpandedGroup = initiallyExpandedGroup
        self.rememberedExpandedGroups = rememberedExpandedGroups
        _preferences = State(
            initialValue:
                HakoProxiesDisplayPreferences.uiTestOverride()
                ?? HakoProxiesDisplayPreferences.load()
        )
    }

     
     
     
     
     
    private let ownsNavigationContainer: Bool

    var body: some View {
         
         
         
         
         
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            page
        }
         
         
         
         
         
        .alert(
            LocalizedStringKey(testAllDecision?.title ?? ""),
            isPresented: Binding(
                get: { testAllDecision != nil },
                set: { if !$0 { testAllDecision = nil } }
            ),
            presenting: testAllDecision
        ) { decision in
            if decision.action == .confirm {
                Button("Test All", role: .destructive) { testAll?() }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { decision in
            Text(hako: .copy(decision.message))
        }
    }

    @ViewBuilder
    private var page: some View {
        let browser = HakoClientUI.HakoProxiesView(
            snapshot: sharedSnapshot,
            actions: sharedActions,
            presentationClass:
                horizontalSizeClass == .regular
                    ? .regularTouch
                    : .compactTouch,
            palette: HakoClientUI.HakoProductPalette.hakoProduct,
            showsDismissControl: ownsNavigationContainer,
            latencyPulse: pulseHub.publisher,
            latencyPulseSnapshot: { pulseHub.current }
        ) { symbol in
            HakoSymbolImage(symbol: symbol)
        }
         
         
         
         
         
         
         
         
         
        let live = browser
            .equatable()
            .onAppear { reseedLatencyPulseForEntry() }
            .onChange(of: isTestingLatency) { testing in
                if testing {
                    frozenSweep = FrozenSweep(
                        latency: latencyStates,
                        failureCategories: effectiveRuntime.failureReasons,
                        completed: latencyCompletedCount,
                        total: latencyTotalCount
                    )
                    pulseHub.send(currentPulse(isTesting: true))
                } else {
                    frozenSweep = nil
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    if sweepEvents == nil {
                        pulseHub.replaceIdle(currentPulse(isTesting: false))
                    }
                }
            }
            .onChange(of: latencyStates) { states in
                guard !isTestingLatency else { return }
                pulseHub.replaceIdle(currentPulse(
                    results: states,
                    isTesting: false
                ))
            }
            .onReceive(
                sweepEvents
                    ?? Empty<LatencySweepBatch, Never>().eraseToAnyPublisher()
            ) { batch in
                 
                 
                pulseHub.send(HakoLatencyPulse(
                    results: batch.results.reduce(into: [:]) { states, entry in
                        states[entry.key] = ProxiesLatencyMapping.state(
                            delay: entry.value,
                            category: effectiveRuntime.failureReasons[entry.key] ?? ""
                        )
                    },
                    testing: batch.testing,
                    groupTerminals: batch.groupTerminals,
                    completed: batch.completed,
                    total: batch.total,
                    isTesting: !batch.finished
                ))
            }
        if ownsNavigationContainer {
            live.hakoSheetPresentation()
        } else {
            live
        }
    }

     
     
     
     
     
     
     
    private func reseedLatencyPulseForEntry() {
        HakoPerf.emit(
            "proxies latency reseed results=\(latencyStates.count) testing=\(isTestingLatency)"
        )
        let pulse = currentPulse(isTesting: isTestingLatency)
        if isTestingLatency {
            if frozenSweep == nil {
                frozenSweep = FrozenSweep(
                    latency: latencyStates,
                    failureCategories: effectiveRuntime.failureReasons,
                    completed: latencyCompletedCount,
                    total: latencyTotalCount
                )
            }
            pulseHub.send(pulse)
        } else {
            frozenSweep = nil
            pulseHub.replaceIdle(pulse)
        }
    }

    private func currentPulse(
        results: [String: HakoProxyLatencyState]? = nil,
        isTesting: Bool
    ) -> HakoLatencyPulse {
        HakoLatencyPulse(
            results: results ?? latencyStates,
            testing: testingNames,
            groupTerminals: effectiveRuntime.resolvedNowByGroup,
            completed: latencyCompletedCount,
            total: latencyTotalCount,
            isTesting: isTesting
        )
    }

    private var effectiveRuntime: ProxiesRuntimeFacts {


        return runtime
    }

     
     
     
     
     
     
     
     
     
     
    private var composedGroups: [ProxiesOverviewModel.Group] {
        HakoPerf.measure("proxies.compose.groups") {
            ProxyBrowsingVisibility.groups(
                ProxiesRuntimeCatalogComposer.groups(
                    source: sourceModel.groups,
                    runtime: effectiveRuntime.catalog,
                    isConnected: isConnected
                ),
                mode: outboundMode,
                name: \.name,
                isHidden: \.hidden
            )
        }
    }

    private var sharedSnapshot: AppleClientSnapshot {
         
         
         
         
         
         
         
         
         
         
         
         
        if !isActiveRoot, let held = hiddenHold.value {
            HakoPerf.count("proxies.snapshot.skipped-hidden")
            return held
        }
        let holdKey = sweepHoldKey
        if let held = hiddenHold.value,
           ProxiesSweepSnapshotHold.servesHeld(
               isSweeping: frozenSweep != nil,
               held: hiddenHold.key,
               current: holdKey
           ) {
            HakoPerf.count("proxies.snapshot.skipped-sweep")
            return held
        }
        let began = DispatchTime.now().uptimeNanoseconds
        let snapshot = builtSharedSnapshot
        let elapsed =
            Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
        HakoPerf.span(
            "proxies.snapshot",
            milliseconds: elapsed,
            detail: "groups=\(snapshot.proxies.groups.count)"
        )
        hiddenHold.value = snapshot
        hiddenHold.key = holdKey
        return snapshot
    }

     
     
     
     
    private var sweepHoldKey: ProxiesSweepSnapshotHold.Key {
        ProxiesSweepSnapshotHold.Key(
            preferences: preferences,
            outboundModeToken: String(describing: outboundMode),
            isConnected: isConnected,
            nowByGroup: effectiveRuntime.nowByGroup,
            resolvedNowByGroup: effectiveRuntime.resolvedNowByGroup,
            groupCount: sourceModel.groups.count
                + effectiveRuntime.catalog.count,
            ungroupedCount: sourceModel.ungrouped.count
                + effectiveRuntime.runtimeNodes.count
        )
    }

     
     
     
     
     
     
     
     
     
     
    private var builtSharedSnapshot: AppleClientSnapshot {
        let groupsKey = ProxiesProjectionMemo.GroupsKey(
            outboundMode: outboundMode,
            source: sourceModel.groups,
            runtimeCatalog: effectiveRuntime.catalog,
            nowByGroup: effectiveRuntime.nowByGroup,
            resolvedNowByGroup: effectiveRuntime.resolvedNowByGroup,
            isConnected: isConnected
        )
        let groups = HakoPerf.measure("proxies.snapshot.groups") {
            projections.groups(groupsKey) {
            composedGroups.map { group in
                HakoProxyGroupSnapshot(
                    name: group.name,
                    type: group.type,
                    members: projections.members(of: group),
                    configuredSelection:
                        group.configuredSelection,
                    runtimeSelection:
                        isConnected
                            ? effectiveRuntime
                                .nowByGroup[group.name]
                            : nil,
                    resolvedRuntimeRoute:
                        isConnected
                            ? effectiveRuntime
                                .resolvedNowByGroup[group.name]
                            : nil,
                    icon: group.icon
                )
            }
            }
        }
        let searchable = HakoPerf.measure("proxies.snapshot.searchable") {
            ProxiesRuntimeCatalogComposer.searchableProxies(
                source: sourceModel.proxies,
                runtime: effectiveRuntime.runtimeNodes,
                isConnected: isConnected,
                runtimeIsAuthoritative: effectiveRuntime.isAuthoritative
            ).map {
                HakoProxySnapshot(
                    name: $0.name,
                    type: $0.type
                )
            }
        }
        let providers = HakoPerf.measure("proxies.snapshot.providers") {
            ProxiesRuntimeCatalogComposer.providers(
                source: sourceModel.providers,
                runtime: effectiveRuntime.providerCatalog,
                isConnected: isConnected
            ).map { provider in
                HakoProxyProviderSnapshot(
                    name: provider.name,
                    type: provider.type,
                    nodeCount: provider.nodeCount,
                     
                     
                     
                    nodes: effectiveRuntime.providerCatalog
                        .proxyProviders[provider.name]?
                        .proxies.map {
                            HakoProxyMemberSnapshot(
                                name: $0.name,
                                type: $0.type ?? ""
                            )
                        },
                    loadFailure: provider.loadFailure
                )
            }
        }
        let ungroupedKey = ProxiesProjectionMemo.UngroupedKey(
            outboundMode: outboundMode,
            source: sourceModel.ungrouped,
            runtimeNodes: effectiveRuntime.runtimeNodes,
            runtimeGroups: effectiveRuntime.catalog,
            isConnected: isConnected,
            runtimeIsAuthoritative: effectiveRuntime.isAuthoritative
        )
        let ungrouped = HakoPerf.measure("proxies.snapshot.ungrouped") {
            projections.ungrouped(ungroupedKey) {
                ProxyBrowsingVisibility.standaloneNodes(
                    ProxiesRuntimeCatalogComposer.ungrouped(
                        source: sourceModel.ungrouped,
                        runtimeNodes: effectiveRuntime.runtimeNodes,
                        runtimeGroups: effectiveRuntime.catalog,
                        isConnected: isConnected,
                        runtimeIsAuthoritative: effectiveRuntime.isAuthoritative
                    ).map {
                        HakoProxySnapshot(
                            name: $0.name,
                            type: $0.type
                        )
                    },
                    mode: outboundMode
                )
            }
        }
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: isConnected
                    ? .connected
                    : .disconnected
            ),
            proxies: HakoProxiesSnapshot(
                groups: groups,
                searchableProxies: searchable,
                providers: providers,
                ungrouped: ungrouped,
                 
                 
                browsingSuppressedByDirectMode: outboundMode == .direct,
                latencyByName: frozenSweep?.latency ?? latencyStates,
                 
                 
                 
                 
                failureCategories: frozenSweep?.failureCategories
                    ?? effectiveRuntime.failureReasons,
                isConnected: isConnected,
                isTestingLatency: frozenSweep != nil || isTestingLatency,
                latencyCompletedCount: frozenSweep?.completed ?? latencyCompletedCount,
                latencyTotalCount: frozenSweep?.total ?? latencyTotalCount,
                initiallyExpandedGroup:
                    initiallyExpandedGroup,
                rememberedExpandedGroups: rememberedExpandedGroups,
                displayPreferences: preferences
            ,
                canRefreshCatalog: refreshCatalog != nil,
                 
                 
                 
                 
                canUnpinGroups: unpinGroup != nil,
                actionRefusals: actionRefusals
            ),
            capabilities: AppleClientCapabilities([
                .proxies: .available,
            ])
        )
    }

    private var latencyStates:
        [String: HakoProxyLatencyState]
    {
        var values: [String: HakoProxyLatencyState] = [:]
        for (name, value) in effectiveRuntime.delays {
            values[name] = ProxiesLatencyMapping.state(
                delay: value,
                category: effectiveRuntime.failureReasons[name] ?? ""
            )
        }
        for name in testingNames {
            values[name] = .testing
        }
        return values
    }

    private var sharedActions: AppleClientActions {
        AppleClientActions(capability: .proxies) { action in
            guard case .proxies(let command) = action else {
                return
            }
             
             
            HakoLogStore.shared.append(
                "proxies command  \(String(describing: command))",
                stream: .app
            )
            switch command {
            case .refresh:
                refreshCatalog?()
            case .testAll:
                requestTestAll()
            case .testGroup(let name):
                testGroup?(name)
            case .testMember(let name):
                testMember?(name)
            case .editMember(let name):
                editMember?(name)
            case .inspectMember(let name):
                inspectMember?(name)
            case .unpin(let group):
                unpinGroup?(group)
            case .select(let group, let member):
                switchSelection?(group, member)
            case .setDisplayPreferences(let updated):
                preferences = updated
                updated.save()
            case .setVisibleGroup(let name):
                setVisibleGroup?(name)
            case .updateProvider(let name):
                updateProvider?(name)
            case .setGroupExpanded(let name, let isExpanded):
                setGroupExpanded?(name, isExpanded)
            case .setGroupsExpanded(let names, let isExpanded):
                if let setGroupsExpanded {
                    setGroupsExpanded(names, isExpanded)
                } else {
                     
                     
                    for name in names {
                        setGroupExpanded?(name, isExpanded)
                    }
                }
            case .cancelLatency:
                cancelLatency?()
            }
        }
    }

    private func requestTestAll() {
        let decision = NetworkPathPolicy.fullTransfer(
            snapshot: networkPath.snapshot
        )
        switch decision.action {
        case .allow:
            testAll?()
        case .confirm, .block:
            testAllDecision = decision
        case .deferOperation:
            break
        }
    }
}

 
 
 
 
 
 
 
 
 
 
enum ProxiesLatencyMapping {
    static func state(delay: Int, category: String) -> HakoProxyLatencyState {
        if delay > 0 { return .measured(milliseconds: delay) }
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "timeout" ? .timedOut : .failed
    }
}
