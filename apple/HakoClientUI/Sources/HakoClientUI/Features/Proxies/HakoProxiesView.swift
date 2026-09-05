import Combine
import Foundation
import SwiftUI

 
 
 
 
 
 
 
struct HakoProxyAccordionRow: Identifiable {
    enum Kind: Equatable {
        case groupHeader
        case ungroupedHeader
        case memberSlice
        case showAll
        case divider
    }

    let id: String
    let kind: Kind
    let group: HakoProxyGroupSnapshot?
     
     
     
    let members: [HakoProxyMemberSnapshot]
    let range: Range<Int>?
    let revealKey: String?
    let totalCount: Int
}

 
 
 
 
 
 
 
 
enum HakoProxyMemberSlicePlan {
    static let chunkSize = 8

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func chunkSize(columns: Int) -> Int {
         
         
         
        if let fixed = HakoPlatformLayout.columnStableSliceLength {
            return fixed
        }
        let columns = max(columns, 1)
        let rows = max(Int((Double(chunkSize) / Double(columns)).rounded(.up)), 1)
        return rows * columns
    }

    static func make(count: Int, columns: Int = 1) -> [Range<Int>] {
        guard count > 0 else { return [] }
        let stripe = chunkSize(columns: columns)
        return stride(from: 0, to: count, by: stripe).map { start in
            start..<min(start + stripe, count)
        }
    }
}

enum HakoProxyAccordionPlan {

    static func make(
        groups: [HakoProxyGroupSnapshot],
        ungrouped: [HakoProxySnapshot],
        expanded: Set<String>,
        isSearching: Bool,
        revealedFullGroups: Set<String>,
         
         
         
        columns: Int = 1,
        renderCap: Int,
        memberOrder: (HakoProxyGroupSnapshot) -> [HakoProxyMemberSnapshot] = {
            $0.members
        }
    ) -> [HakoProxyAccordionRow] {
        var rows: [HakoProxyAccordionRow] = []
        rows.reserveCapacity(groups.count * 2 + 20)

        for (index, group) in groups.enumerated() {
            rows.append(
                HakoProxyAccordionRow(
                    id: "group.\(group.name)",
                    kind: .groupHeader,
                    group: group,
                    members: [],
                    range: nil,
                    revealKey: nil,
                    totalCount: group.members.count
                )
            )
            if HakoProxyBrowsing.showsMembers(
                of: group.name,
                expanded: expanded,
                isSearching: isSearching
            ) {
                let orderedMembers = memberOrder(group)
                appendMemberRows(
                    group: group,
                    members: orderedMembers,
                    revealKey: group.name,
                    memberCount: orderedMembers.count,
                    revealedFullGroups: revealedFullGroups,
                    renderCap: renderCap,
                    columns: columns,
                    rows: &rows
                )
            }
            if index != groups.count - 1 || !ungrouped.isEmpty {
                rows.append(
                    HakoProxyAccordionRow(
                        id: "group.\(group.name).divider",
                        kind: .divider,
                        group: nil,
                        members: [],
                        range: nil,
                        revealKey: nil,
                        totalCount: 0
                    )
                )
            }
        }

        if !ungrouped.isEmpty {
            let members = ungrouped.map {
                HakoProxyMemberSnapshot(name: $0.name, type: $0.type)
            }
            rows.append(
                HakoProxyAccordionRow(
                    id: "group.ungrouped",
                    kind: .ungroupedHeader,
                    group: nil,
                    members: members,
                    range: nil,
                    revealKey: nil,
                    totalCount: members.count
                )
            )
            if HakoProxyBrowsing.showsMembers(
                of: HakoProxyBrowsing.ungroupedKey,
                expanded: expanded,
                isSearching: isSearching
            ) {
                appendMemberRows(
                    group: nil,
                    members: members,
                    revealKey: HakoProxyBrowsing.ungroupedKey,
                    memberCount: members.count,
                    revealedFullGroups: revealedFullGroups,
                    renderCap: renderCap,
                    columns: columns,
                    rows: &rows
                )
            }
        }
        return rows
    }

    private static func appendMemberRows(
        group: HakoProxyGroupSnapshot?,
        members: [HakoProxyMemberSnapshot],
        revealKey: String,
        memberCount: Int,
        revealedFullGroups: Set<String>,
        renderCap: Int,
        columns: Int,
        rows: inout [HakoProxyAccordionRow]
    ) {
        let capped = !revealedFullGroups.contains(revealKey)
            && memberCount > renderCap
        let shownCount = capped ? renderCap : memberCount
        for range in HakoProxyMemberSlicePlan.make(
            count: shownCount, columns: columns
        ) {
            let prefix = group.map { "group.\($0.name)" } ?? "group.ungrouped"
            let slice = Array(members[range])
            rows.append(
                HakoProxyAccordionRow(
                    id: "\(prefix).members.\(range.lowerBound)",
                    kind: .memberSlice,
                    group: group,
                    members: slice,
                    range: slice.indices,
                    revealKey: revealKey,
                    totalCount: memberCount
                )
            )
        }
        if capped {
            let prefix = group.map { "group.\($0.name)" } ?? "group.ungrouped"
            rows.append(
                HakoProxyAccordionRow(
                    id: "\(prefix).show-all",
                    kind: .showAll,
                    group: group,
                    members: members,
                    range: nil,
                    revealKey: revealKey,
                    totalCount: memberCount
                )
            )
        }
    }
}

 
 
 
 
 
 
 
private struct ProxyIndexPreparationKey: Equatable {
    let groups: [HakoProxyGroupSnapshot]
    let latencyByName: [String: HakoProxyLatencyState]
    let isConnected: Bool
    let sort: HakoProxiesDisplayPreferences.Sort
     
     
     
     
    let orderingGroupNames: Set<String>

    init(
        proxies: HakoProxiesSnapshot,
        sort: HakoProxiesDisplayPreferences.Sort,
        orderingGroupNames: Set<String>
    ) {
        groups = proxies.groups
        latencyByName = proxies.latencyByName
        isConnected = proxies.isConnected
        self.sort = sort
        self.orderingGroupNames = orderingGroupNames
    }
}

@MainActor
private enum ProxyIndexPreparationCache {
    static let shared = HakoLastPreparation<
        ProxyIndexPreparationKey,
        ProxyDerivedIndex
    >()
}

 
 
 
 
 
 
public struct HakoProxiesView<Icon: View>: View, Equatable {

     
     
     
     
     
     
    nonisolated public static func == (a: Self, b: Self) -> Bool {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let p = a.snapshot.proxies, q = b.snapshot.proxies
        let dataEqual = p.groups == q.groups
            && p.searchableProxies == q.searchableProxies
            && p.providers == q.providers
            && p.ungrouped == q.ungrouped
             
             
             
             
             
             
             
             
             
            && p.latencyByName == q.latencyByName
        let sweepEqual = p.isConnected == q.isConnected
        let chromeEqual = p.displayPreferences == q.displayPreferences
            && p.catalogState == q.catalogState
            && p.canRefreshCatalog == q.canRefreshCatalog
            && p.canUnpinGroups == q.canUnpinGroups
             
             
             
             
             
            && p.browsingSuppressedByDirectMode == q.browsingSuppressedByDirectMode
        let equal = dataEqual && sweepEqual && chromeEqual
            && a.presentationClass == b.presentationClass
            && a.showsDismissControl == b.showsDismissControl
         
         
         
         
         
         
         
         
         
         
         
        Task { @MainActor in
            HakoPerf.count(equal ? "proxies.eq.hit" : "proxies.eq.miss")
            if !equal {
                let field: String
                if p.groups != q.groups { field = "groups" }
                else if p.searchableProxies != q.searchableProxies { field = "searchable" }
                else if p.providers != q.providers { field = "providers" }
                else if p.ungrouped != q.ungrouped { field = "ungrouped" }
                else if p.latencyByName != q.latencyByName { field = "latency" }
                else if p.isConnected != q.isConnected { field = "connected" }
                else if p.displayPreferences != q.displayPreferences { field = "prefs" }
                else if p.catalogState != q.catalogState { field = "catalog-state" }
                else if p.canRefreshCatalog != q.canRefreshCatalog { field = "can-refresh" }
                else if p.canUnpinGroups != q.canUnpinGroups { field = "can-unpin" }
                else { field = "other" }
                HakoPerf.count("proxies.eq.miss." + field)
            }
        }
        return equal
    }

    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let searchPlacement: SearchFieldPlacement
    private let palette: HakoProductPalette
    private let showsDismissControl: Bool
     
     
     
     
     
     
     
     
    private let latencyPulseSource: AnyPublisher<HakoLatencyPulse, Never>?

     
     
     
     
    private var latencyPulse: AnyPublisher<HakoLatencyPulse, Never>? {
         
         
         
        latencyPulseSource
    }

    @State private var pulseGate = HakoLatencyPulseGate()
    @Environment(\.hakoLatencyPulseGate) private var injectedPulseGate

     
     
    private var activePulseGate: HakoLatencyPulseGate {
        injectedPulseGate ?? pulseGate
    }
     
     
     
     
    private let latencyPulseSnapshot: (() -> HakoLatencyPulse)?
    private let icon: (HakoSymbol) -> Icon

    @Environment(\.dismiss) private var dismiss
    @Environment(\.hakoScrollToID) private var scrollToID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
     
     
     
     
     
    @Environment(\.hakoRegularRootSearchText) private var externalSearchText
    @Environment(\.hakoRegularRootFoldCommand) private var foldCommand
    @Environment(\.hakoRegularRootFoldStateSink) private var foldStateSink
    @Environment(\.hakoRegularRootOpenGroup) private var openGroupSignal
    @Environment(\.hakoRegularRootDisplayPreferences) private var displaySignal
    @State private var query = ""
     
     
     
     
    @State private var index = ProxyDerivedIndex.empty
     
     
     
     
     
    @State private var expandedProvider: String?
     
     
     
     
     
     
     
     
    @State private var gridColumnCount = 2
    @State private var expanded: Set<String> = []
     
     
     
     
     
    @State private var entryRoutine = HakoEntryRoutineBox()
     
     
     
     
     
    @State private var identityStamp = UUID()

     
     
     
    @State private var lastExpandedGroup: String?
     
     
    @State private var revealedFullGroups: Set<String> = []
    @State private var preferences: HakoProxiesDisplayPreferences
    @State private var showsDisplayOptions = false
     
     
     
     
    @State private var displayOptionsDraft = HakoProxiesDisplayDraftBox()
     
     
    @State private var pendingDisplayPreferences:
        HakoProxiesDisplayPreferences?
    @State private var selectedTab: String?
    @State private var offlineSelections: [String: String] = [:]
     
    @State private var choiceRefusal: HakoProxyChoiceRefusal?

    @MainActor
    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        searchPlacement: SearchFieldPlacement = .automatic,
        palette: HakoProductPalette,
        showsDismissControl: Bool = true,
        latencyPulse: AnyPublisher<HakoLatencyPulse, Never>? = nil,
        latencyPulseSnapshot: (() -> HakoLatencyPulse)? = nil,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.searchPlacement = searchPlacement
        self.palette = palette
        self.showsDismissControl = showsDismissControl
        self.latencyPulseSource = latencyPulse
        self.latencyPulseSnapshot = latencyPulseSnapshot
        self.icon = icon
        let initialPreferences = snapshot.proxies.displayPreferences
        let initialExpanded = HakoProxyBrowsing.groupsToOpenOnEntry(
             
             
             
             
            remembered: [],
            destination: snapshot.proxies.initiallyExpandedGroup
        )
        let initialOrderingGroupNames = Self.orderingGroupNames(
            groups: snapshot.proxies.groups,
            preferences: initialPreferences,
            expanded: initialExpanded,
            isSearching: false,
            selectedTab: nil
        )
        _preferences = State(initialValue: initialPreferences)
        _index = State(
            initialValue: ProxyIndexPreparationCache.shared.value(
                for: ProxyIndexPreparationKey(
                    proxies: snapshot.proxies,
                    sort: initialPreferences.sort,
                    orderingGroupNames: initialOrderingGroupNames
                )
            ) ?? .empty
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        _expanded = State(initialValue: initialExpanded)
    }

    @Environment(\.hakoHostedInRootPool) private var hostedInRootPool

    public var body: some View {
         
         
         
         
         
        let _ = HakoPerf.count(
            hostedInRootPool ? "proxies.body.pool" : "proxies.body.free"
        )
         
         
         
         
         
         
         
         
         
         
         
        if externalSearchText == nil {
            chromed
        } else {
            undecorated
        }
    }

    private var chromed: some View {
        undecorated
            .searchable(
                text: $query,
                placement: searchPlacement,
                prompt: Text("Search proxies")
            )
            .hakoToolbarUnlessInPanel { toolbarContent }
    }

    private var undecorated: some View {
        root
            .hakoContentHeading("Proxies")
            .sheet(
                isPresented: $showsDisplayOptions,
                onDismiss: commitDisplayOptions
            ) {
                HakoProxiesDisplayOptionsView(
                    preferences: displayOptionsDraft.value,
                    palette: palette,
                    onDraftChange: { value in
                        displayOptionsDraft.value = value
                    }
                )
                .hakoModalPresentation(.form)
            }
            .onAppear {
                applyInitialDestination()
            }
            .task(id: ProxyIndexPreparationKey(
                proxies: snapshot.proxies,
                sort: preferences.sort,
                orderingGroupNames: orderingGroupNames
            )) {
                await prepareIndex()
            }
            .task(id: DisplayCommitKey(
                value: pendingDisplayPreferences,
                canCommit: activePulseGate.isOpen
            )) {
                 
                 
                 
                 
                 
                if let pendingDisplayPreferences {
                    await prepareDisplayPreferences(pendingDisplayPreferences)
                }
            }
            .onChange(of: preferences) { value in
                HakoPerf.markDisplayPreferencesChange()
                send(.setDisplayPreferences(value))
            }
            .onChange(of: snapshot.proxies.displayPreferences) { value in
                if preferences != value {
                    preferences = value
                }
            }
            .onDisappear {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                HakoPerf.mark("proxies page disappears")
                send(.cancelLatency)
            }
            .onChange(of: foldCommand) { _ in
                 
                 
                 
                 
                toggleAllGroups()
            }
            .onChange(of: displaySignal) { signal in
                 
                 
                 
                 
                guard let value = signal.preferences else { return }
                applyDisplayPreferences(value)
            }
            .onChange(of: openGroupSignal) { signal in
                 
                 
                 
                 
                 
                 
                guard let name = signal.group else { return }
                expanded = [name]
                if selectedTab != name {
                    selectedTab = name
                }
                send(.setVisibleGroup(name: name))
                if let scrollToID {
                    HakoPerf.emit("proxies entry-scroll dest=\(name)")
                    DispatchQueue.main.async {
                        scrollToID(Self.groupAnchor(name))
                    }
                }
            }
            .onChange(of: hasExpandedGroups) { value in
                foldStateSink?(value)
            }
            .onAppear {
                foldStateSink?(hasExpandedGroups)
            }
            .accessibilityIdentifier("proxies.overview")
             
             
             
             
            .hakoFrameWatch("proxies-page")
            .environment(\.hakoDetailCanvas, palette.canvas)
    }

     
     
     
     
     
     
    @MainActor
    private func prepareIndex() async {
         
         
         
         
         
         
        guard activePulseGate.isOpen else { return }
        let proxies = snapshot.proxies
        let sort = preferences.sort
        let previous = index
        let groupNames = orderingGroupNames
        let key = ProxyIndexPreparationKey(
            proxies: proxies,
            sort: sort,
            orderingGroupNames: groupNames
        )
        let prepared = await ProxyIndexPreparationCache.shared.value(
            for: key
        ) {
            let began = DispatchTime.now().uptimeNanoseconds
            let value = await Task.detached(priority: .userInitiated) {
                ProxyDerivedIndex.build(
                    from: proxies,
                    sortedBy: sort,
                    reusing: previous,
                    freshDelayOrder: !proxies.isTestingLatency,
                    orderingGroupNames: groupNames
                )
            }.value
            HakoPerf.span(
                "proxies.index.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "groups=\(proxies.groups.count) ordered=\(groupNames.count)"
            )
            return value
        }
        guard !Task.isCancelled,
              key == ProxyIndexPreparationKey(
                proxies: snapshot.proxies,
                sort: preferences.sort,
                orderingGroupNames: orderingGroupNames
              ) else { return }
        index = prepared
    }

     
     
     
     
     
    private var orderingGroupNames: Set<String> {
        Self.orderingGroupNames(
            groups: browsedGroups,
            preferences: preferences,
            expanded: expanded,
            isSearching: isSearching,
            selectedTab: selectedTab
        )
    }

    private static func orderingGroupNames(
        groups: [HakoProxyGroupSnapshot],
        preferences: HakoProxiesDisplayPreferences,
        expanded: Set<String>,
        isSearching: Bool,
        selectedTab: String?
    ) -> Set<String> {
        if preferences.style == .tabs {
            if let selectedTab,
               groups.contains(where: { $0.name == selectedTab }) {
                return [selectedTab]
            }
            return groups.first.map { [$0.name] } ?? []
        }
        return Set(groups.lazy.filter {
            isSearching || expanded.contains($0.name)
        }.map(\.name))
    }

    private func applyDisplayPreferences(
        _ value: HakoProxiesDisplayPreferences
    ) {
        guard preferences != value else { return }
         
         
         
         
         
         
        pendingDisplayPreferences = value
    }

    private func beginDisplayOptions() {
        displayOptionsDraft.value = preferences
        showsDisplayOptions = true
    }

    private func commitDisplayOptions() {
        applyDisplayPreferences(displayOptionsDraft.value)
    }

    @MainActor
    private func prepareDisplayPreferences(
        _ value: HakoProxiesDisplayPreferences
    ) async {
         
         
        try? await Task.sleep(nanoseconds: 50_000_000)
        guard !Task.isCancelled,
              pendingDisplayPreferences == value else { return }

        let proxies = snapshot.proxies
        let groupNames = Self.orderingGroupNames(
            groups: browsedGroups,
            preferences: value,
            expanded: expanded,
            isSearching: isSearching,
            selectedTab: selectedTab
        )
        let previous = index
        let key = ProxyIndexPreparationKey(
            proxies: proxies,
            sort: value.sort,
            orderingGroupNames: groupNames
        )
        let prepared = await ProxyIndexPreparationCache.shared.value(
            for: key
        ) {
            let began = DispatchTime.now().uptimeNanoseconds
            let prepared = await Task.detached(priority: .userInitiated) {
                ProxyDerivedIndex.build(
                    from: proxies,
                    sortedBy: value.sort,
                    reusing: previous,
                    freshDelayOrder: !proxies.isTestingLatency,
                    orderingGroupNames: groupNames
                )
            }.value
            HakoPerf.span(
                "proxies.display.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail:
                    "groups=\(proxies.groups.count) ordered=\(groupNames.count) sort=\(value.sort.rawValue)"
            )
            return prepared
        }
        guard !Task.isCancelled,
              pendingDisplayPreferences == value else { return }
         
         
         
         
         
        guard activePulseGate.isOpen else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
             
             
             
             
             
            #if !os(macOS)
            revealedFullGroups.removeAll()
            #endif
            index = prepared
            preferences = value
            pendingDisplayPreferences = nil
        }
         
         
         
         
         
         
         
    }

     
     
    private struct DisplayCommitKey: Equatable {
        let value: HakoProxiesDisplayPreferences?
        let canCommit: Bool
    }

    private var root: some View {
         
         
         
         
         
        HakoProxiesBrowserHost {
            HakoProxiesSystemList(
                snapshot: snapshot,
                palette: palette,
                send: { send($0) },
                expanded: $expanded,
                query: effectiveQuery,
                memberOrder: { group in
                    index.renderingMembers(
                        in: group,
                        for: snapshot.proxies,
                        sortedBy: preferences.sort
                    )
                },
                latencyPulse: latencyPulseSource,
                latencyPulseSnapshot: latencyPulseSnapshot,
                density: HakoProxiesRowDensity.from(preferences),
                showsIconImages: preferences.groupIconImages,
                icon: icon,
                index: index,
                sort: preferences.sort,
                expandedValue: expanded
            )
             
            .equatable()
            .accessibilityIdentifier("proxies.product.root")
        } legacy: {
            legacyRoot
        }
    }

    private var legacyRoot: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "proxies.product.root",
             
             
             
             
             
             
            hostsSelfDrawnCards: true
        ) {
            if pendingDisplayPreferences != nil,
               HakoPlatformLayout.displayChangeSwapsToPlaceholder {
                HakoPageLoadingPlaceholder(title: .copy("Loading"))
                    .accessibilityIdentifier("proxies.display.applying")
            } else {
                catalogContent
            }
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch snapshot.proxies.effectiveCatalogState {
            case .disconnected:
                catalogStateCard(
                    title: "Connect to View Proxies",
                    message:
                        "The active connection supplies the current groups, nodes, and selections.",
                    symbol: .serverRack
                )
            case .loading:
                catalogStateCard(
                    title: "Loading Proxies",
                    message:
                        "Reading the current proxy catalog.",
                    symbol: .serverRack,
                    isLoading: true
                )
            case .failed(let message):
                catalogStateCard(
                    title: "Proxies Unavailable",
                    message: message,
                    symbol: .exclamationmarkTriangle
                )
            case .ready:
                browserSections
        }
    }

    private func catalogStateCard(
        title: String,
        message: String,
        symbol: HakoSymbol,
        isLoading: Bool = false
    ) -> some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            HakoEmptyState(
                title: title,
                message: message,
                isLoading: isLoading
            ) {
                icon(symbol)
            }
        }
        .accessibilityIdentifier(
            isLoading ? "proxies.state.loading" : "proxies.state.empty"
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
         
         
        HakoProxiesToolbar(
            showsDismissControl: showsDismissControl,
            hasExpandedGroups: hasExpandedGroups,
            canRefreshCatalog: snapshot.proxies.canRefreshCatalog == true,
            refreshDisabled:
                snapshot.proxies.effectiveCatalogState == .loading
                    || snapshot.proxies.isTestingLatency,
            preferences: $preferences,
            onDismiss: { dismiss() },
            onToggleFold: { toggleAllGroups() },
            onRefresh: { send(.refresh) },
            onShowDisplayOptions: beginDisplayOptions,
            isTestingLatency: snapshot.proxies.isTestingLatency,
            sweepDisabled: !snapshot.proxies.isConnected,
            sweepCompleted: snapshot.proxies.latencyCompletedCount,
            sweepTotal: snapshot.proxies.latencyTotalCount,
            sweepPulse: latencyPulseSource,
            onSweepStart: {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                send(.testAll(
                    visibleGroupNames: browsedGroups.map(\.name)
                ))
            },
            onSweepCancel: { send(.cancelLatency) },
            icon: icon
        )
    }

     
     
    private var effectiveQuery: String {
        externalSearchText ?? query
    }

     
     
     
    private var browsedGroups: [HakoProxyGroupSnapshot] {
        snapshot.proxies.groups(matching: effectiveQuery)
    }

    private var browsedUngrouped: [HakoProxySnapshot] {
        snapshot.proxies.ungroupedNodes(matching: effectiveQuery)
    }

    private var isSearching: Bool {
        !effectiveQuery
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var browserSections: some View {
        if !browsedGroups.isEmpty {
            groupsCard
        } else if snapshot.proxies.browsingSuppressedByDirectMode {
             
             
             
             
            directModeCard
        } else if isSearching {
            noMatchesCard
        } else if !snapshot.proxies.ungrouped.isEmpty {
            nodesCard
        } else if snapshot.proxies.providers.isEmpty {
            emptyCard
        }

        if !snapshot.proxies.providers.isEmpty {
            providersCard
        }
    }

    @ViewBuilder
    private var groupsCard: some View {
         
         
         
         
        HakoProductGroup(
            groupsTitle,
            palette: palette,
            trailing: { testAllButton }
        ) {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                if preferences.style == .tabs {
                    tabsBody
                } else {
                     
                     
                     
                     
                     
                     
                     
                    let rows = HakoProxyAccordionPlan.make(
                        groups: browsedGroups,
                        ungrouped: browsedUngrouped,
                        expanded: expanded,
                        isSearching: isSearching,
                        revealedFullGroups: revealedFullGroups,
                        columns: gridColumns.count,
                        renderCap: Self.memberRenderCap,
                         
                         
                         
                        memberOrder: { group in
                            index.renderingMembers(
                                in: group,
                                for: snapshot.proxies,
                                sortedBy: preferences.sort
                            )
                        }
                    )
                     
                     
                     
                     
                     
                     
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            accordionRow(row)
                        }
                    }
                    .modifier(HakoProxyGridColumnReader(
                columns: $gridColumnCount,
                layout: preferences.layout
            ))
                }
            }
        }
    }

    private var groupsTitle: HakoDisplayText {
         
         
        .format("Groups (%@)", [String(browsedGroups.count)])
    }

     
     
    private var headerControlHeight: CGFloat { 32 }

    private var providersTitle: HakoDisplayText {
         
         
         
         
         
         
        let failed = snapshot.proxies.providers.filter {
            $0.loadFailure != nil
        }.count
        guard failed > 0 else {
            return .format(
                "Sources (%@)", [String(snapshot.proxies.providers.count)]
            )
        }
         
         
        return .format(
            "Sources (%@ · %@ failed)",
            [String(snapshot.proxies.providers.count), String(failed)]
        )
    }

    private var testAllButton: some View {
        HakoSweepControl(
            isConnected: snapshot.proxies.isConnected,
            isTesting: snapshot.proxies.isTestingLatency,
            completed: snapshot.proxies.latencyCompletedCount,
            total: snapshot.proxies.latencyTotalCount,
            height: headerControlHeight,
            pulse: latencyPulse,
            onStart: {
                send(
                    .testAll(
                        visibleGroupNames: browsedGroups
                            .map(\.name)
                            .filter {
                                HakoProxyBrowsing.showsMembers(
                                    of: $0,
                                    expanded: expanded,
                                    isSearching: isSearching
                                )
                            }
                    )
                )
            },
            onCancel: { send(.cancelLatency) },
            icon: icon
        )
    }

     
     
     
    private static func groupAnchor(_ name: String) -> AnyHashable {
        HakoProxyBrowsing.groupAnchor(name)
    }

     
     
     
     
     
     
     
     
     
     
    private func groupSection(
        _ group: HakoProxyGroupSnapshot
    ) -> some View {
        let isOpen = HakoProxyBrowsing.showsMembers(
            of: group.name,
            expanded: expanded,
            isSearching: isSearching
        )
         
         
         
         
        let isTesting = HakoPerf.measure(
            "proxies.section.testing",
            detail: "group=\(group.name) members=\(group.members.count)"
        ) {
            group.members.contains {
                snapshot.proxies.latency(for: $0.name) == .testing
            }
        }
        let selection = visibleSelection(in: group)

        return HakoProxyGroupHeader(
            group: group,
            isOpen: isOpen,
            isTesting: isTesting,
            isConnected: snapshot.proxies.isConnected,
            currentSelection: selection,
            showsUnpin: snapshot.proxies.offersUnpin(for: group)
                && selection != nil,
            showsIconImages: preferences.groupIconImages,
            icon: icon,
            onToggle: { toggle(group) },
            onTestGroup: { send(.testGroup(name: group.name)) },
            onUnpin: { send(.unpin(group: group.name)) }
        )
        .equatable()
        .id("group.\(group.name)")
    }

    @ViewBuilder
    private func accordionRow(_ row: HakoProxyAccordionRow) -> some View {
        switch row.kind {
        case .groupHeader:
            if let group = row.group {
                groupSection(group)
                    .id(Self.groupAnchor(group.name))
            }
        case .ungroupedHeader:
            ungroupedHeader(count: row.totalCount)
                .id(Self.groupAnchor(HakoProxyBrowsing.ungroupedKey))
        case .memberSlice:
            accordionMemberSlice(row)
        case .showAll:
            if let revealKey = row.revealKey {
                showAllButton(
                    revealKey: revealKey,
                    totalCount: row.totalCount
                )
            }
        case .divider:
            Divider()
        }
    }

    private func ungroupedHeader(count: Int) -> some View {
        let isOpen = HakoProxyBrowsing.showsMembers(
            of: HakoProxyBrowsing.ungroupedKey,
            expanded: expanded,
            isSearching: isSearching
        )

        return HakoUngroupedHeaderRow(
            count: count,
            isOpen: isOpen,
            verticalPadding: HakoTheme.Spacing.row,
            icon: icon
        ) {
            applyFoldChange {
                if isOpen {
                    expanded.remove(HakoProxyBrowsing.ungroupedKey)
                } else {
                    expanded.insert(HakoProxyBrowsing.ungroupedKey)
                }
            }
        }
    }

    @ViewBuilder
    private var tabsBody: some View {
        let tabs = browsedGroups.map(\.name)
            + (browsedUngrouped.isEmpty ? [] : [HakoProxyBrowsing.ungroupedKey])
         
         
        let active = tabs.contains(selectedTab ?? "") ? selectedTab : tabs.first

        HStack(spacing: HakoTheme.Spacing.compact) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            select(tab: tab)
                        } label: {
                            Text(tabTitle(tab))
                                .font(
                                    .subheadline.weight(
                                        tab == active
                                            ? .semibold
                                            : .regular
                                    )
                                )
                                .foregroundStyle(
                                    tab == active ? Color.blue : Color.primary
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        tab == active
                                            ? Color.blue.opacity(0.12)
                                            : palette.raisedFill
                                    )
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        tab == active
                                            ? Color.blue.opacity(0.45)
                                            : .clear,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "proxies.tab.\(tabTitle(tab))"
                        )
                    }
                }
            }

             
             
             
             
             
            if tabs.count > 3 {
                Menu {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            select(tab: tab)
                        } label: {
                            if tab == active {
                                Label(tabTitle(tab), systemImage: "checkmark")
                            } else {
                                Text(tabTitle(tab))
                            }
                        }
                    }
                } label: {
                    icon(.chevronDown)
                }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                .menuIndicator(.hidden)
                .accessibilityLabel("All Groups")
                .accessibilityIdentifier("proxies.tab.all")
            }
        }

        if let active {
            if active == HakoProxyBrowsing.ungroupedKey {
                memberGrid(
                    members: browsedUngrouped.map {
                        HakoProxyMemberSnapshot(
                            name: $0.name,
                            type: $0.type
                        )
                    },
                    group: nil
                )
            } else if let group = browsedGroups.first(where: {
                $0.name == active
            }) {
                HStack(spacing: 6) {
                    Text(group.type)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let current = visibleSelection(in: group) {
                        HakoRegionalFlag.label("→ \(current)", pointSize: 12, relativeTo: .caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                memberGrid(group)
            }
        }
    }

    private func tabTitle(_ tab: String) -> String {
        tab == HakoProxyBrowsing.ungroupedKey ? "Ungrouped" : tab
    }

    private func select(tab: String) {
        selectedTab = tab
        send(
            .setVisibleGroup(
                name: tab == HakoProxyBrowsing.ungroupedKey ? nil : tab
            )
        )
    }

    private func memberGrid(
        _ group: HakoProxyGroupSnapshot
    ) -> some View {
        memberGrid(
            members: index.renderingMembers(
                in: group,
                for: snapshot.proxies,
                sortedBy: preferences.sort
            ),
            group: group
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private static var memberRenderCap: Int {
        HakoPlatformLayout.pageUsesSystemSettingsIdiom ? 56 : 120
    }

    @ViewBuilder
    private func accordionMemberSlice(
        _ row: HakoProxyAccordionRow
    ) -> some View {
        if let range = row.range {
            if let group = row.group {
                let end = min(range.upperBound, row.members.count)
                if range.lowerBound < end {
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        ForEach(row.members[range.lowerBound..<end]) { member in
                            memberCard(member, in: group)
                        }
                    }
                    .padding(.bottom, HakoTheme.Spacing.compact)
                }
            } else {
                let end = min(range.upperBound, row.members.count)
                if range.lowerBound < end {
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        ForEach(row.members[range.lowerBound..<end]) { member in
                            memberCard(member, in: nil)
                        }
                    }
                    .padding(.bottom, HakoTheme.Spacing.compact)
                }
            }
        }
    }

    private func showAllButton(
        revealKey: String,
        totalCount: Int
    ) -> some View {
        Button {
            revealedFullGroups.insert(revealKey)
        } label: {
            Text(hako: .format("Show all %@ nodes", ["\(totalCount)"]))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, HakoTheme.Spacing.row)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityIdentifier("proxies.showAll.\(revealKey)")
    }

    private func memberGrid(
        members: [HakoProxyMemberSnapshot],
        group: HakoProxyGroupSnapshot?
    ) -> some View {
        let revealKey = group?.name ?? HakoProxyBrowsing.ungroupedKey
        let capped = !revealedFullGroups.contains(revealKey)
            && members.count > Self.memberRenderCap
        let shown = capped
            ? Array(members.prefix(Self.memberRenderCap))
            : members
        return VStack(spacing: HakoTheme.Spacing.compact) {
            LazyVGrid(
                columns: gridColumns,
                spacing: HakoTheme.Spacing.compact
            ) {
                ForEach(shown) { member in
                    memberCard(member, in: group)
                }
            }
            if capped {
                Button {
                    revealedFullGroups.insert(revealKey)
                } label: {
                    Text(hako: .format(
                        "Show all %@ nodes",
                        ["\(members.count)"]
                    ))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HakoTheme.Spacing.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityIdentifier(
                    "proxies.showAll.\(revealKey)"
                )
            }
        }
        .modifier(HakoProxyGridColumnReader(
                columns: $gridColumnCount,
                layout: preferences.layout
            ))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            refusalCaption(for: group)
        }
    }

     
     
    @ViewBuilder
    private func memberCard(
        _ member: HakoProxyMemberSnapshot,
        in group: HakoProxyGroupSnapshot?
    ) -> some View {
        let _ = HakoPerf.count("proxies.card.make")
        HakoProxyMemberCard(
            member: member,
            detail: memberDetail(member),
            latency: pulseLatency(member) ?? memberLatency(member),
            failureCategory:
                snapshot.proxies.failureCategories[member.name] ?? "",
            isCurrent: group.flatMap(visibleSelection) == member.name,
            size: preferences.size,
            fill: palette.raisedFill,
            action: { choose(member, in: group) },
            inspect: HakoProxyBrowsing.inspects(member)
                ? { send(.inspectMember(name: member.name)) }
                : nil,
            pulse: latencyPulse,
            gate: activePulseGate
        )
        .equatable()
         
         
         
         
         
         
         
        .accessibilityIdentifier("proxies.member.\(member.name)")
    }

     
     
     
     
     
    private func pulseLatency(
        _ member: HakoProxyMemberSnapshot
    ) -> HakoProxyLatencyState? {
        guard let pulse = latencyPulseSnapshot?() else { return nil }
        let name = member.isGroup
            ? pulse.groupTerminals[member.name]
            : member.name
        guard let name else { return nil }
        if let result = pulse.results[name] { return result }
        if pulse.isTesting, pulse.testing.contains(name) { return .testing }
        return pulse.isTesting ? nil : .untested
    }

     
     
     
     
     
    private func choose(
        _ member: HakoProxyMemberSnapshot,
        in group: HakoProxyGroupSnapshot?
    ) {
        guard let group else { return }
        guard group.allowsMemberChoice else {
            if let reason = group.memberChoiceRefusal {
                choiceRefusal = HakoProxyChoiceRefusal(
                    group: group.name,
                    message: reason
                )
            }
            return
        }
        choiceRefusal = nil
        if !snapshot.proxies.isConnected {
            offlineSelections[group.name] = member.name
        }
        send(.select(group: group.name, member: member.name))
    }

    @ViewBuilder
    private func refusalCaption(
        for group: HakoProxyGroupSnapshot?
    ) -> some View {
        if let group, let refusal = choiceRefusal,
           refusal.group == group.name {
            Text(hako: .copy(refusal.message))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HakoTheme.Spacing.compact)
                .accessibilityIdentifier("proxies.refusal.\(group.name)")
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: HakoTheme.Spacing.compact
            ),
            count: gridColumnCount
        )
    }

    private var nodesCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                Label {
                    Text("Nodes (\(snapshot.proxies.ungrouped.count))")
                        .font(.headline)
                } icon: {
                    icon(.serverRack)
                        .foregroundStyle(.primary)
                }
                memberGrid(
                    members: snapshot.proxies.ungrouped.map {
                        HakoProxyMemberSnapshot(
                            name: $0.name,
                            type: $0.type
                        )
                    },
                    group: nil
                )
            }
            .padding(HakoTheme.Spacing.standard)
        }
    }

     
     
     
     
    @ViewBuilder
    private var providersCard: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
            HakoProductGroup(
                providersTitle,
                palette: palette
            ) {
                providerRows
            }
        } else {
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.standard
                ) {
                    Label {
                        Text(hako: providersTitle)
                            .font(.headline)
                    } icon: {
                        icon(.shippingbox)
                            .foregroundStyle(.primary)
                    }
                    providerRows
                }
                .padding(HakoTheme.Spacing.standard)
            }
        }
    }

     
    private var providerRows: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                VStack(spacing: 0) {
                    ForEach(snapshot.proxies.providers) { provider in
                        providerRow(
                            provider,
                            verticalInset: HakoTheme.Spacing.row
                        )
                        providerExpansion(provider)

                        if provider.id
                            != snapshot.proxies.providers.last?.id
                        {
                            Divider()
                        }
                    }
                }
            }
    }

     
     
     
     
     
    private func providerRow(
        _ provider: HakoProxyProviderSnapshot,
        verticalInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            providerRowLine(provider, verticalInset: verticalInset)
            if let failure = provider.loadFailure {
                 
                 
                 
                 
                 
                Label {
                    Text(failure)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    icon(.exclamationmarkTriangle)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityIdentifier(
                    "proxies.provider.loadFailure.\(provider.name)"
                )
            }
        }
    }

    private func providerRowLine(
        _ provider: HakoProxyProviderSnapshot,
        verticalInset: CGFloat
    ) -> some View {
        let canOpen = !(provider.nodes ?? []).isEmpty
        let isOpen = expandedProvider == provider.name
        return HStack(spacing: HakoTheme.Spacing.row) {
            HakoRegionalFlag.label(provider.name, pointSize: 17, relativeTo: .body)
                .font(.body.weight(.semibold))
            if canOpen {
                icon(.chevronDown)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            Spacer(minLength: 8)
            if let count = provider.nodeCount {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text(provider.type)
                .font(.caption)
                .foregroundStyle(.secondary)

             
             
             
            Button {
                send(.updateProvider(name: provider.name))
            } label: {
                icon(.arrowClockwise)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .disabled(!snapshot.proxies.isConnected)
            .accessibilityLabel("Update \(provider.name)")
            .accessibilityIdentifier(
                "proxies.provider.update.\(provider.name)"
            )
        }
        .padding(.vertical, verticalInset)
         
         
         
         
         
         
         
        .contentShape(Rectangle())
        .onTapGesture {
            guard canOpen else { return }
            expandedProvider = isOpen ? nil : provider.name
        }
        .accessibilityAddTraits(canOpen ? .isButton : [])
        .accessibilityValue(
            canOpen ? (isOpen ? "Expanded" : "Collapsed") : ""
        )
        .accessibilityIdentifier("proxies.provider.\(provider.name)")
    }

    @ViewBuilder
    private func providerExpansion(
        _ provider: HakoProxyProviderSnapshot
    ) -> some View {
        if expandedProvider == provider.name,
           let nodes = provider.nodes, !nodes.isEmpty {
             
             
             
             
             
             
             
            let slices = HakoProxyMemberSlicePlan.make(
                count: nodes.count,
                columns: gridColumns.count
            )
            VStack(spacing: HakoTheme.Spacing.compact) {
                ForEach(slices, id: \.lowerBound) { range in
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        ForEach(nodes[range]) { member in
                            memberCard(member, in: nil)
                        }
                    }
                }
            }
            .modifier(HakoProxyGridColumnReader(
                columns: $gridColumnCount,
                layout: preferences.layout
            ))
            .padding(.bottom, HakoTheme.Spacing.row)
            .hakoHeightProbe(
                "providers-expansion", count: nodes.count
            )
        }
    }

     
     
     
     
     
     
     
     
    private var directModeCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(spacing: HakoTheme.Spacing.compact) {
                 
                 
                icon(.arrowLeftAndRight)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Direct Mode")
                    .font(.headline)
                Text(
                    "This mode sends all traffic without a proxy, so proxy groups and nodes are not listed."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HakoTheme.Spacing.section)
            .padding(.horizontal, HakoTheme.Spacing.standard)
        }
        .accessibilityIdentifier("proxies.direct-mode-notice")
    }

    private var emptyCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(spacing: HakoTheme.Spacing.compact) {
                icon(.serverRack)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No Proxies")
                    .font(.headline)
                Text("This profile has no proxy groups or nodes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HakoTheme.Spacing.section)
            .padding(.horizontal, HakoTheme.Spacing.standard)
        }
    }

     
     
    private var noMatchesCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(spacing: HakoTheme.Spacing.row) {
                icon(.magnifyingglass)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No proxies match \u{201C}\(effectiveQuery)\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HakoTheme.Spacing.section)
            .padding(.horizontal, HakoTheme.Spacing.standard)
        }
        .accessibilityIdentifier("proxies.search.empty")
    }

     
    private var hasExpandedGroups: Bool {
        browsedGroups.contains { expanded.contains($0.name) }
            || expanded.contains(HakoProxyBrowsing.ungroupedKey)
    }

     
     
     
     
     
     
     
     
     
     
     
    private func toggleAllGroups() {
        let collapsing = hasExpandedGroups
        HakoPerf.markFoldAll(collapsing: collapsing)
        let affected = browsedGroups
            .map(\.name)
            .filter { expanded.contains($0) == collapsing }
         
         
         
         
         
         
         
        if collapsing {
             
             
            lastExpandedGroup = expanded.first
            expanded.removeAll()
            send(.setGroupsExpanded(names: affected, isExpanded: false))
        } else if let reopening = groupToReopen {
             
             
             
             
             
             
             
            expanded = [reopening]
            send(.setGroupExpanded(name: reopening, isExpanded: true))
        }
    }

     
     
     
     
    private var groupToReopen: String? {
        if let last = lastExpandedGroup,
           browsedGroups.contains(where: { $0.name == last }) {
            return last
        }
        return browsedGroups.first?.name
    }

    private func toggle(_ group: HakoProxyGroupSnapshot) {
        let wasOpen = expanded.contains(group.name)
        HakoPerf.markGroupFold(wasOpen: wasOpen)
         
         
         
         
         
         
        let closing = wasOpen ? [] : expanded.subtracting([group.name])
        applyFoldChange {
            if wasOpen {
                expanded.remove(group.name)
            } else {
                expanded = [group.name]
            }
        }
        if !closing.isEmpty {
            send(.setGroupsExpanded(names: Array(closing), isExpanded: false))
        }
        send(.setGroupExpanded(name: group.name, isExpanded: !wasOpen))
    }

     
     
     
     
     
     
     
     
    private func applyFoldChange(_ change: () -> Void) {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            change()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                change()
            }
        }
    }

    private func visibleSelection(
        in group: HakoProxyGroupSnapshot
    ) -> String? {
        if !snapshot.proxies.isConnected,
           let offlineSelection = offlineSelections[group.name]
        {
            return offlineSelection
        }
        return group.currentSelection
    }

    private func memberDetail(
        _ member: HakoProxyMemberSnapshot
    ) -> String {
        if index.source == snapshot.proxies, let detail = index.detail(for: member) {
            return detail
        }
        guard member.isGroup,
              let route = memberResolvedRoute(member) else {
            return member.type
        }
        return "\(member.type) → \(route)"
    }

    private func memberResolvedRoute(
        _ member: HakoProxyMemberSnapshot
    ) -> String? {
        snapshot.proxies.resolvedDisplayRoute(for: member)
    }


    private func memberLatency(
        _ member: HakoProxyMemberSnapshot
    ) -> HakoProxyLatencyState {
        if index.source == snapshot.proxies, let latency = index.latency(for: member) {
            return latency
        }
        return snapshot.proxies.displayedLatency(for: member)
    }

    private func applyInitialDestination() {
        HakoPerf.emit(
            "proxies entry-open expandedEmpty=\(expanded.isEmpty) id=\(identityStamp.uuidString.prefix(5))"
        )
         
         
         
         
         
         
         
         
         
        guard !entryRoutine.didApply else { return }
        entryRoutine.didApply = true
        let destination = snapshot.proxies.initiallyExpandedGroup
        if let destination, selectedTab != destination {
            selectedTab = destination
        }
         
         
        if let destination {
            send(.setVisibleGroup(name: destination))
        }
         
         
         
         
        if let destination, let scrollToID {
            HakoPerf.emit("proxies entry-scroll dest=\(destination)")
            DispatchQueue.main.async {
                scrollToID(Self.groupAnchor(destination))
            }
        }
    }

    private func send(_ command: HakoProxiesCommand) {
         
         
         
        HakoPerf.log.notice("proxies send \(String(describing: command), privacy: .public)")
        Task {
            do {
                try await actions.perform(
                    .proxies(command),
                    allowedBy: snapshot
                )
            } catch {
                HakoPerf.log.error("proxies command refused \(String(describing: command), privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}

private struct HakoProxyMemberCard: View, Equatable {
     
     
     
     
     
    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.member == b.member
            && a.detail == b.detail
            && a.latency == b.latency
            && a.failureCategory == b.failureCategory
            && a.isCurrent == b.isCurrent
            && a.size == b.size
            && a.fill == b.fill
            && (a.inspect == nil) == (b.inspect == nil)
    }

     
     
     
    var onTest: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let member: HakoProxyMemberSnapshot
    let detail: String
    let latency: HakoProxyLatencyState
     
     
     
     
     
     
    var failureCategory: String = ""
    let isCurrent: Bool
    let size: HakoProxiesDisplayPreferences.Size
    let fill: Color
    let action: () -> Void
     
     
     
    var inspect: (() -> Void)?

     
     
     
     
    let pulse: AnyPublisher<HakoLatencyPulse, Never>?
     
     
     
    var gate: HakoLatencyPulseGate?
    @State private var liveLatency: HakoProxyLatencyState?

    private var shownLatency: HakoProxyLatencyState { liveLatency ?? latency }

    var body: some View {
         
         
         
         
         
         
         
        ZStack(alignment: .bottomTrailing) {
        Button(action: action) {
            content
                .padding(.trailing, inspect == nil ? 0 : 24)
                .background(
                    RoundedRectangle(
                        cornerRadius: HakoTheme.Radius.control,
                        style: .continuous
                    )
                     
                     
                     
                     
                     
                     
                     
                     
                    .fill(isCurrent
                        ? AnyShapeStyle(.tint.opacity(0.16))
                        : AnyShapeStyle(fill))
                )
                .overlay(alignment: .leading) {
                     
                     
                     
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.tint)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .padding(.leading, 1)
                        .opacity(isCurrent ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "Selected" : "")
        .accessibilityIdentifier("proxies.member.\(member.name)")
        inspectButton
            .padding(.trailing, HakoTheme.Spacing.compact)
            .padding(.bottom, HakoTheme.Spacing.compact)
        }
        .onReceive(
            pulse ?? Empty<HakoLatencyPulse, Never>().eraseToAnyPublisher()
        ) { batch in
             
             
             
            guard gate?.isOpen ?? true else { return }
             
             
             
            let name = member.isGroup
                ? batch.groupTerminals[member.name]
                : member.name
            if let name {
                if !batch.isTesting {
                     
                     
                     
                     
                    liveLatency = batch.results[name] ?? .untested
                } else if let landed = batch.results[name] {
                    liveLatency = landed
                } else if batch.testing.contains(name) {
                    liveLatency = .testing
                }
            }
        }
    }

     
     
     
     
     
     
    @ViewBuilder
    private var inspectButton: some View {
        if let inspect {
            Button(action: inspect) {
                Image(systemName: HakoSymbol.infoCircle.rawValue)
                    .font(.body)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(HakoCopy.key("Node Details")))
            .accessibilityIdentifier("proxies.member.info.\(member.name)")
        }
    }

    @ViewBuilder
    private var chainLine: some View {
        if let entry = member.chainedThrough {
            HStack(spacing: 3) {
                Image(systemName: HakoSymbol.link.rawValue)
                    .font(.caption2)
                 
                 
                 
                 
                HakoRegionalFlag.label("\(entry) → \(member.name)", pointSize: 11, relativeTo: .caption2)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(HakoCopy.key("Enters through"))
            .accessibilityValue(entry)
        }
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityContent
        } else {
            switch size {
            case .standard:
                standardContent
            case .compact:
                compactContent
            case .minimal:
                minimalContent
            }
        }
    }

    private var accessibilityContent: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            HakoRegionalFlag.label(member.name, pointSize: 15, relativeTo: .subheadline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Text(hako: .copy(detail))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            chainLine
            HakoProxyLatencyIndicator(
                state: shownLatency,
                failureCategory: failureCategory
            )
        }
        .padding(HakoTheme.Spacing.row)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var standardContent: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HakoRegionalFlag.label(member.name, pointSize: 15, relativeTo: .subheadline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(hako: .copy(detail))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    HakoProxyLatencyIndicator(
                        state: shownLatency,
                        failureCategory: failureCategory,
                        onTest: onTest
                    )
                }
                chainLine
            }
        }
        .padding(HakoTheme.Spacing.row)
         
         
         
         
        .frame(
            maxWidth: .infinity,
            minHeight: 64,
            alignment: .topLeading
        )
    }

    private var compactContent: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                HakoRegionalFlag.label(member.name, pointSize: 13, relativeTo: .footnote)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Text(hako: .copy(detail))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    HakoProxyLatencyIndicator(
                        state: shownLatency,
                        failureCategory: failureCategory,
                        onTest: onTest
                    )
                }
            }
        }
        .padding(HakoTheme.Spacing.compact)
        .frame(
            maxWidth: .infinity,
            minHeight: 48,
            alignment: .topLeading
        )
    }

    private var minimalContent: some View {
        HStack(spacing: 4) {
            HakoRegionalFlag.label(member.name, pointSize: 12, relativeTo: .caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 2)
            HakoProxyLatencyIndicator(
                state: shownLatency,
                failureCategory: failureCategory,
                usesDot: true
            )
        }
        .padding(.horizontal, HakoTheme.Spacing.compact)
        .padding(.vertical, 6)
         
         
        .frame(
            maxWidth: .infinity,
            minHeight: 30,
            alignment: .leading
        )
    }
}

private struct HakoProxyLatencyIndicator: View {
    let state: HakoProxyLatencyState
     
     
    var failureCategory: String = ""
    var usesDot = false
     
     
    var onTest: (() -> Void)?

     
     
     
     
     
     
     
     
     
    private static let slotHeight: CGFloat = 16

    var body: some View {
        Group {
            if let onTest,
               HakoProxyLatencyAffordance.of(state) != .inProgress {
                Button(action: onTest) { indicator }
                    .buttonStyle(.borderless)
            } else {
                indicator
            }
        }
         
         
         
         
        .fixedSize(horizontal: true, vertical: false)
        .frame(
            minHeight: Self.slotHeight,
            maxHeight: Self.slotHeight,
            alignment: .trailing
        )
        .layoutPriority(1)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .untested:
             
             
            Image(systemName: HakoSymbol.bolt.rawValue)
                .font(.caption2)
                .foregroundStyle(.tint)
                .accessibilityLabel("Test latency")
        case .testing:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Testing latency")
        case .measured(let milliseconds):
            if usesDot {
                latencyDot(color: color(milliseconds))
                    .accessibilityLabel("\(milliseconds)ms")
            } else {
                Text("\(milliseconds)ms")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color(milliseconds))
            }
        case .failed, .timedOut:
             
             
             
             
             
             
             
             
            status(
                .copy(HakoProbeFailureCopy.badge(
                    for: state == .timedOut ? "timeout" : failureCategory
                )),
                color: .red
            )
        }
    }

    private func status(_ title: HakoDisplayText, color: Color) -> some View {
        Group {
            if usesDot {
                latencyDot(color: color)
                    .accessibilityLabel(Text(hako: title))
            } else {
                Text(hako: title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            }
        }
    }

    private func latencyDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func color(_ milliseconds: Int) -> Color {
        if milliseconds < 800 { return .green }
        if milliseconds < 1_600 { return .yellow }
        return .orange
    }
}


 
 
 
 
 
 
 
 
 
 
 
 
private final class HakoEntryRoutineBox {
    var didApply = false
}

 
 
 
 
 
 
 
private final class HakoProxiesDisplayDraftBox {
    var value = HakoProxiesDisplayPreferences()
}

private struct HakoProxyGroupHeader<Icon: View>: View, Equatable {
    let group: HakoProxyGroupSnapshot
    let isOpen: Bool
    let isTesting: Bool
    let isConnected: Bool
    let currentSelection: String?
    let showsUnpin: Bool
     
     
     
    let showsIconImages: Bool
    let icon: (HakoSymbol) -> Icon
    let onToggle: () -> Void
    let onTestGroup: () -> Void
    let onUnpin: () -> Void

    nonisolated static func == (a: Self, b: Self) -> Bool {
        HakoPerf.count("proxies.header.eq")
        return a.group == b.group
            && a.isOpen == b.isOpen
            && a.isTesting == b.isTesting
            && a.isConnected == b.isConnected
            && a.currentSelection == b.currentSelection
            && a.showsUnpin == b.showsUnpin
             
             
             
             
             
            && a.showsIconImages == b.showsIconImages
    }

     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var groupIcon: some View {
        switch HakoProxyGroupIconKind.of(group.icon) {
        case .emoji(let text):
            Text(text)
                .font(.body)
                .accessibilityHidden(true)
        case .symbol(let symbol):
            icon(symbol)
                .font(.body)
                .foregroundStyle(.secondary)
        case .remote where !showsIconImages:
             
             
             
            EmptyView()
        case .remote:
             
             
             
            ProxyGroupIconView(
                address: group.icon,
                size: HakoTheme.Layout.proxyGroupIconSize
            ) {
                RoundedRectangle(
                    cornerRadius: HakoTheme.Layout.proxyGroupIconCornerRadius,
                    style: .continuous
                )
                .fill(.quaternary)
                .frame(
                    width: HakoTheme.Layout.proxyGroupIconSize,
                    height: HakoTheme.Layout.proxyGroupIconSize
                )
                .accessibilityHidden(true)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: HakoTheme.Layout.proxyGroupIconCornerRadius,
                    style: .continuous
                )
            )
        case .unrecognized, .none:
            EmptyView()
        }
    }

    var body: some View {
        HakoPerf.count("proxies.section.make")
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(
                    alignment: .center,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    Button {
                        onToggle()
                    } label: {
                        HStack(
                            alignment: .center,
                            spacing: HakoTheme.Spacing.compact
                        ) {
                            groupIcon
                            HakoRegionalFlag.label(group.name, pointSize: 17, relativeTo: .body)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: HakoTheme.Spacing.compact)
                            Text("\(group.members.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(
                                    minWidth: 28,
                                    alignment: .trailing
                                )
                                .accessibilityLabel(
                                    Text(hako: .format(
                                        "%@ members",
                                        ["\(group.members.count)"]
                                    ))
                                )
                            icon(.chevronDown)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(
                                    .degrees(isOpen ? 180 : 0)
                                )
                                .frame(width: 20)
                        }
                        .frame(minHeight: HakoTheme.Control.pointerRowTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "proxies.group.\(group.name)"
                    )
                    .accessibilityValue(isOpen ? "Expanded" : "Collapsed")

                    Button {
                        onTestGroup()
                    } label: {
                        Group {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                icon(.boltHorizontalCircle)
                            }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(
                             
                             
                            width: HakoTheme.Control.pointerRowTarget,
                            height: HakoTheme.Control.pointerRowTarget
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isConnected || isTesting)
                    .accessibilityLabel(
                        Text(hako: .format(
                            "Test all proxies in %@",
                            [group.name]
                        ))
                    )
                    .accessibilityHint(
                        isConnected
                            ? "Measures proxy latency"
                            : "Connect before testing latency"
                    )
                    .accessibilityIdentifier(
                        "proxies.testGroup.\(group.name)"
                    )
                }

                HStack(spacing: 6) {
                    Text(group.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     
                     
                     
                     
                    if showsUnpin {
                        Button("Unfix") {
                            onUnpin()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                         
                         
                         
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("proxies.unfix.\(group.name)")
                    }
                    if let current = currentSelection {
                        Text("→")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        HakoRegionalFlag.label(current, pointSize: 12, relativeTo: .caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, HakoTheme.Spacing.compact)
        }
    }
}

private struct HakoProxiesDisplayOptionsView: View {
     
     
     
     
    @State private var preferences: HakoProxiesDisplayPreferences
    let palette: HakoProductPalette
    let onDraftChange: (HakoProxiesDisplayPreferences) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        preferences: HakoProxiesDisplayPreferences,
        palette: HakoProductPalette,
        onDraftChange: @escaping (HakoProxiesDisplayPreferences) -> Void
    ) {
        _preferences = State(initialValue: preferences)
        self.palette = palette
        self.onDraftChange = onDraftChange
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            content
        }
        .accessibilityIdentifier("proxies.display.sheet")
        .onChange(of: preferences) { _ in
            onDraftChange(preferences)
        }
    }

    private var content: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "proxies.display.content"
        ) {
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.standard
                ) {
                     
                     
                     
                    labeled("Icons") {
                        Picker(
                            "Icons",
                            selection: $preferences.groupIconImages
                        ) {
                            Text("Off").tag(false)
                            Text("Show").tag(true)
                        }
                        .accessibilityIdentifier(
                            "proxies.display.groupIconImages"
                        )
                    }
                     
                     
                     
                     
                     
                     
                    if HakoPlatformLayout.proxiesDisplayOptionsUseListAxes {
                        listAxes
                    } else {
                        cardAxes
                    }
                }
                .padding(HakoTheme.Spacing.standard)
            }
        }
        .hakoPageTitle("Display Options")
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                HakoSheetCloseButton {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var listAxes: some View {
        labeled("Sort") {
            Picker("Sort", selection: $preferences.sort) {
                Text("Default").tag(
                    HakoProxiesDisplayPreferences.Sort.standard
                )
                Text("Delay").tag(
                    HakoProxiesDisplayPreferences.Sort.delay
                )
                Text("Name").tag(
                    HakoProxiesDisplayPreferences.Sort.name
                )
            }
                .accessibilityIdentifier("proxies.display.sort.sheet")
        }
        labeled("Rows") {
            Picker(
                "Rows",
                selection: Binding(
                    get: {
                        HakoProxiesRowDensity.from(preferences)
                    },
                    set: { density in
                         
                         
                         
                        preferences.size =
                            density == .standard ? .standard : .compact
                    }
                )
            ) {
                Text("Standard").tag(HakoProxiesRowDensity.standard)
                Text("Compact").tag(HakoProxiesRowDensity.compact)
            }
                .accessibilityIdentifier("proxies.display.size.sheet")
        }
    }

    @ViewBuilder
    private var cardAxes: some View {
        labeled("Style") {
            Picker("Style", selection: $preferences.style) {
                Text("List").tag(
                    HakoProxiesDisplayPreferences.Style.list
                )
                Text("Tabs").tag(
                    HakoProxiesDisplayPreferences.Style.tabs
                )
            }
                .accessibilityIdentifier("proxies.display.style")
        }
        labeled("Sort") {
            Picker("Sort", selection: $preferences.sort) {
                Text("Default").tag(
                    HakoProxiesDisplayPreferences.Sort.standard
                )
                Text("Delay").tag(
                    HakoProxiesDisplayPreferences.Sort.delay
                )
                Text("Name").tag(
                    HakoProxiesDisplayPreferences.Sort.name
                )
            }
                .accessibilityIdentifier("proxies.display.sort.sheet")
        }
        labeled("Layout") {
            Picker(
                "Layout",
                selection: $preferences.layout
            ) {
                Text("Loose").tag(
                    HakoProxiesDisplayPreferences.Layout.loose
                )
                Text("Compact").tag(
                    HakoProxiesDisplayPreferences.Layout.compact
                )
            }
                .accessibilityIdentifier("proxies.display.layout.sheet")
        }
        labeled("Size") {
            Picker("Size", selection: $preferences.size) {
                Text("Standard").tag(
                    HakoProxiesDisplayPreferences.Size.standard
                )
                Text("Compact").tag(
                    HakoProxiesDisplayPreferences.Size.compact
                )
                Text("Minimal").tag(
                    HakoProxiesDisplayPreferences.Size.minimal
                )
            }
                .accessibilityIdentifier("proxies.display.size.sheet")
        }
    }

    private func labeled<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            Text(hako: .copy(title))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoProxyColumnAdoption {
    private(set) var columns: Int
    private var pending: Int?

    init(columns: Int) {
        self.columns = columns
    }

    mutating func measured(_ value: Int, frozen: Bool) -> Int? {
        guard !frozen else {
            pending = value
            return nil
        }
        pending = nil
        guard value != columns else { return nil }
        columns = value
        return value
    }

    mutating func resizeEnded() -> Int? {
        guard let landed = pending else { return nil }
        pending = nil
        guard landed != columns else { return nil }
        columns = landed
        return landed
    }
}

 
 
 
private struct HakoLiveResizeFreezeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    public var hakoLiveResizeFreeze: Bool {
        get { self[HakoLiveResizeFreezeKey.self] }
        set { self[HakoLiveResizeFreezeKey.self] = newValue }
    }
}

private struct HakoProxyGridColumnReader: ViewModifier {
    @Binding var columns: Int
    let layout: HakoProxiesDisplayPreferences.Layout
    @Environment(\.hakoLiveResizeFreeze) private var frozen
    @Environment(\.hakoLatencyPulseGate) private var pulseGate
    @State private var adoption: HakoProxyColumnAdoption?

    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, tvOS 18, *) {
             
             
             
             
             
            content.onGeometryChange(for: Int.self) { proxy in
                HakoProxyBrowsing.columnCount(
                    availableWidth: proxy.size.width,
                    layout: layout
                )
            } action: { measured in
                 
                 
                 
                 
                 
                 
                guard pulseGate?.isOpen ?? true else { return }
                var machine = adoption ?? HakoProxyColumnAdoption(columns: columns)
                if let adopt = machine.measured(measured, frozen: frozen) {
                    columns = adopt
                }
                adoption = machine
            }
            .onChange(of: frozen) { isFrozen in
                guard !isFrozen, var machine = adoption else { return }
                if let adopt = machine.resizeEnded() {
                    columns = adopt
                }
                adoption = machine
            }
        } else {
            content
        }
    }
}

 
private struct HakoProxyChoiceRefusal: Equatable {
    let group: String
    let message: String
}

 
 
 
 
 
 
 
 
public struct HakoLatencyPulse: Equatable, Sendable {
     
    public let results: [String: HakoProxyLatencyState]
     
    public let testing: Set<String>
     
     
     
     
     
    public let groupTerminals: [String: String]
    public let completed: Int
    public let total: Int
    public let isTesting: Bool

    public init(
        results: [String: HakoProxyLatencyState],
        testing: Set<String>,
        groupTerminals: [String: String] = [:],
        completed: Int,
        total: Int,
        isTesting: Bool
    ) {
        self.results = results
        self.testing = testing
        self.groupTerminals = groupTerminals
        self.completed = completed
        self.total = total
        self.isTesting = isTesting
    }
}

 
 
 
 
 
 
 
 
 
struct ProxyDerivedIndex: Equatable {
    static let empty = ProxyDerivedIndex(
        source: nil, latencyByKey: [:], detailByKey: [:], sortedMembers: [:],
        membershipSignature: 0)

     
     
    let source: HakoProxiesSnapshot?
    private let latencyByKey: [String: HakoProxyLatencyState]
    private let detailByKey: [String: String]
    fileprivate let sortedMembers: [String: [HakoProxyMemberSnapshot]]
     
     
    fileprivate let membershipSignature: Int

    private init(
        source: HakoProxiesSnapshot?,
        latencyByKey: [String: HakoProxyLatencyState],
        detailByKey: [String: String],
        sortedMembers: [String: [HakoProxyMemberSnapshot]],
        membershipSignature: Int
    ) {
        self.source = source
        self.latencyByKey = latencyByKey
        self.detailByKey = detailByKey
        self.sortedMembers = sortedMembers
        self.membershipSignature = membershipSignature
    }

    private static func key(_ member: HakoProxyMemberSnapshot) -> String {
        (member.isGroup ? "g:" : "p:") + member.name
    }

    func latency(for member: HakoProxyMemberSnapshot) -> HakoProxyLatencyState? {
        latencyByKey[Self.key(member)]
    }

    func detail(for member: HakoProxyMemberSnapshot) -> String? {
        detailByKey[Self.key(member)]
    }

    func members(
        in group: HakoProxyGroupSnapshot,
        sortedBy sort: HakoProxiesDisplayPreferences.Sort
    ) -> [HakoProxyMemberSnapshot]? {
        sort == .standard
            ? group.members
            : sortedMembers["\(sort.rawValue):\(group.name)"]
    }

     
     
     
    func renderingMembers(
        in group: HakoProxyGroupSnapshot,
        for proxies: HakoProxiesSnapshot,
        sortedBy sort: HakoProxiesDisplayPreferences.Sort
    ) -> [HakoProxyMemberSnapshot] {
         
         
        guard let source else { return group.members }
        if Self.hasSameAnswers(source, proxies) {
            return members(in: group, sortedBy: sort) ?? group.members
        }
         
         
         
         
         
         
         
         
        if membershipSignature == Self.membershipSignature(of: proxies),
           let ordered = members(in: group, sortedBy: sort) {
            return ordered
        }
        return group.members
    }

     
     
     
    private static func hasSameAnswers(
        _ lhs: HakoProxiesSnapshot,
        _ rhs: HakoProxiesSnapshot
    ) -> Bool {
        lhs.groups == rhs.groups
            && lhs.latencyByName == rhs.latencyByName
            && lhs.isConnected == rhs.isConnected
    }

     
     
     
    static func membershipSignature(of proxies: HakoProxiesSnapshot) -> Int {
        var hasher = Hasher()
        for group in proxies.groups {
            hasher.combine(group.name)
            for member in group.members {
                hasher.combine(member.name)
            }
        }
        return hasher.finalize()
    }

     
     
     
     
     
     
     
     
     
    static func build(
        from proxies: HakoProxiesSnapshot,
        sortedBy sort: HakoProxiesDisplayPreferences.Sort = .delay,
        reusing previous: ProxyDerivedIndex? = nil,
        freshDelayOrder: Bool = false,
        orderingGroupNames: Set<String>? = nil
    ) -> ProxyDerivedIndex {
        var latencyByKey: [String: HakoProxyLatencyState] = [:]
        var detailByKey: [String: String] = [:]
        var sorted: [String: [HakoProxyMemberSnapshot]] = [:]
        let signature = membershipSignature(of: proxies)
        let reusableNameOrder =
            previous?.membershipSignature == signature ? previous : nil
        if let reusableNameOrder {
             
             
             
            sorted = reusableNameOrder.sortedMembers
        }
        for group in proxies.groups where
            orderingGroupNames?.contains(group.name) != false
        {
            for member in group.members {
                let memberKey = key(member)
                if latencyByKey[memberKey] == nil {
                    latencyByKey[memberKey] = proxies.displayedLatency(for: member)
                }
                if detailByKey[memberKey] == nil {
                    detailByKey[memberKey] = detail(of: member, in: proxies)
                }
            }
        }
         
         
         
        for group in proxies.groups where
            orderingGroupNames?.contains(group.name) != false
        {
            let nameKey = "\(HakoProxiesDisplayPreferences.Sort.name.rawValue):\(group.name)"
            if sort == .name {
                if let carried = reusableNameOrder?.sortedMembers[nameKey] {
                    sorted[nameKey] = carried
                } else {
                    sorted[nameKey] = group.members.enumerated().sorted {
                        let comparison = $0.element.name
                            .localizedStandardCompare($1.element.name)
                        return comparison == .orderedSame
                            ? $0.offset < $1.offset
                            : comparison == .orderedAscending
                    }.map(\.element)
                }
            }
            if sort == .delay {
                let delayOrderKey =
                    "\(HakoProxiesDisplayPreferences.Sort.delay.rawValue):\(group.name)"
                 
                 
                 
                 
                 
                 
                 
                if !freshDelayOrder,
                   let carried = reusableNameOrder?.sortedMembers[delayOrderKey] {
                    sorted[delayOrderKey] = carried
                } else {
                    sorted[delayOrderKey] =
                        group.members.enumerated().sorted {
                            delayKey(latencyByKey[key($0.element)] ?? .untested, offset: $0.offset)
                                < delayKey(latencyByKey[key($1.element)] ?? .untested, offset: $1.offset)
                        }.map(\.element)
                }
            }
        }
        return ProxyDerivedIndex(
            source: proxies,
            latencyByKey: latencyByKey,
            detailByKey: detailByKey,
            sortedMembers: sorted,
            membershipSignature: signature
        )
    }

     
     
    private static func delayKey(
        _ latency: HakoProxyLatencyState, offset: Int
    ) -> (Int, Int, Int) {
        switch latency {
        case .measured(let milliseconds): return (0, milliseconds, offset)
        case .testing: return (1, 0, offset)
        case .untested: return (2, 0, offset)
        case .failed: return (3, 0, offset)
        case .timedOut: return (4, 0, offset)
        }
    }

    private static func detail(
        of member: HakoProxyMemberSnapshot, in proxies: HakoProxiesSnapshot
    ) -> String {
        guard member.isGroup,
              let route = proxies.resolvedDisplayRoute(for: member) else {
            return member.type
        }
        return "\(member.type) → \(route)"
    }
}

 
 
 
 
 
 
 
private struct HakoSweepControl<Icon: View>: View {
    let isConnected: Bool
    let height: CGFloat
    let pulse: AnyPublisher<HakoLatencyPulse, Never>?
    let onStart: () -> Void
    let onCancel: () -> Void
    let icon: (HakoSymbol) -> Icon

    @State private var isTesting: Bool
    @State private var completed: Int
    @State private var total: Int

    init(
        isConnected: Bool,
        isTesting: Bool,
        completed: Int,
        total: Int,
        height: CGFloat,
        pulse: AnyPublisher<HakoLatencyPulse, Never>?,
        onStart: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.isConnected = isConnected
        self.height = height
        self.pulse = pulse
        self.onStart = onStart
        self.onCancel = onCancel
        self.icon = icon
        _isTesting = State(initialValue: isTesting)
        _completed = State(initialValue: completed)
        _total = State(initialValue: total)
    }

    var body: some View {
        Button {
            if isTesting {
                isTesting = false
                onCancel()
            } else {
                isTesting = true
                completed = 0
                onStart()
            }
        } label: {
            Group {
                if isTesting {
                    HStack(spacing: 6) {
                        icon(.xmarkCircle)
                         
                         
                        Text(hako: .format(
                            "Stop %@",
                            ["\(completed)/\(total)"]
                        ))
                        .monospacedDigit()
                    }
                    .accessibilityLabel(
                        "Stop proxy latency test, \(completed) of \(total) complete"
                    )
                } else {
                    Label {
                        Text("Test All")
                    } icon: {
                        icon(.boltHorizontalCircle)
                    }
                }
            }
            .font(.subheadline.weight(.medium))
            .frame(
                minWidth: 68,
                minHeight: height,
                maxHeight: height
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isConnected)
        .accessibilityHint(
            isConnected
                ? "Measures proxy latency"
                : "Connect before testing latency"
        )
        .accessibilityIdentifier(
            isTesting ? "proxies.testAll.cancel" : "proxies.testAll"
        )
        .onReceive(
            pulse ?? Empty<HakoLatencyPulse, Never>().eraseToAnyPublisher()
        ) { batch in
            isTesting = batch.isTesting
            completed = batch.completed
            total = batch.total
        }
    }
}
