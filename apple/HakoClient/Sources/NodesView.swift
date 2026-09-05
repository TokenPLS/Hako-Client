import HakoClientUI
import SwiftUI

struct NodesView: View {
    @ObservedObject var nodes: NodesModel
    @ObservedObject private var networkPath = NetworkPathObserver.shared
    @State private var testAllDecision: NetworkPathPolicyDecision?
    private let title: String

    init(nodes: NodesModel, title: String = "Nodes") {
        self.nodes = nodes
        self.title = title
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            NodesContent(
                 
                 
                groups: HakoPerf.measure("proxies.filter", detail: "groups=\(nodes.groups.count)") {
                    NodeInventory.filter(nodes.groups, query: nodes.query)
                },
                delays: nodes.delays,
                testingNames: nodes.testingNames,
                isTestingLatency: nodes.isTestingLatency,
                latencyCompletedCount: nodes.latencyCompletedCount,
                latencyTotalCount: nodes.latencyTotalCount,
                query: $nodes.query,
                unfoldedGroups: nodes.unfoldedGroups,
                currentGroupName: nodes.currentGroupName,
                select: { group, member in
                    Task { await nodes.select(group: group, name: member) }
                },
                setExpanded: nodes.setExpanded,
                setCurrentGroup: nodes.setCurrentGroup,
                test: { name in Task { await nodes.test(name) } },
                testGroup: { group in Task { await nodes.test(group: group) } },
                testAll: requestTestAll,
                refresh: { await nodes.refresh() }
            )
            .hakoPageTitle(.copy(title))
        }
        .hakoFrameWatch("proxies")
        .hakoStackNavigationViewStyle()
         
        .alert(
            LocalizedStringKey(testAllDecision?.title ?? ""),
            isPresented: Binding(
                get: { testAllDecision != nil },
                set: { if !$0 { testAllDecision = nil } }
            ),
            presenting: testAllDecision
        ) { decision in
            if decision.action == .confirm {
                Button("Test All", role: .destructive) { Task { await nodes.testAll() } }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { decision in
            Text(hako: .copy(decision.message))
        }
    }

    private func requestTestAll() {
        let decision = NetworkPathPolicy.fullTransfer(snapshot: networkPath.snapshot)
        switch decision.action {
        case .allow:
            Task { await nodes.testAll() }
        case .confirm, .block:
            testAllDecision = decision
        case .deferOperation:
            break
        }
    }
}

struct NodesContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let groups: [ProxyGroup]
    let delays: [String: Int]
    let testingNames: Set<String>
    let isTestingLatency: Bool
    let latencyCompletedCount: Int
    let latencyTotalCount: Int
    @Binding var query: String
    let unfoldedGroups: Set<String>
    let currentGroupName: String?
    let select: (String, String) -> Void
    let setExpanded: (Bool, String) -> Void
    let setCurrentGroup: (String) -> Void
    let test: (String) -> Void
    let testGroup: (ProxyGroup) -> Void
    let testAll: () -> Void
    let refresh: () async -> Void

    @State private var sort = ProxySort.load()
    @State private var presentation = NodePresentationSettings.load()
    @State private var showsDisplaySettings = false

    var body: some View {
        Group {
            if groups.isEmpty {
                HakoEmptyState(
                    title: query.isEmpty ? "No Proxy Groups" : "No Matching Nodes",
                    message: query.isEmpty
                        ? "Connect Clash, then pull to refresh the available routes."
                        : "Try a different group or node name.",
                    symbol: query.isEmpty ? .point3ConnectedTrianglepathDotted : .magnifyingglass
                )
            } else if presentation.browseStyle == .tabs {
                tabsContent
            } else {
                listContent
            }
        }
        .searchable(text: $query, prompt: "Search groups and nodes")
        .hakoToolbarUnlessInPanel {
             
             
             
             
             
             
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(ProxySort.allCases) { Text($0.title).tag($0) }
                    }
                     
                     
                     
                     
                     
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: HakoSymbol.arrowUpArrowDownCircle.name)
                }
                .accessibilityIdentifier("nodes.sort")
                .onChange(of: sort) { $0.save() }
                Button { showsDisplaySettings = true } label: {
                    Label("Display", systemImage: HakoSymbol.sliderHorizontal3.name)
                }
                .accessibilityIdentifier("nodes.display")
                Button(action: testAll) {
                    if isTestingLatency {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("\(latencyCompletedCount)/\(latencyTotalCount)")
                                .font(.caption.monospacedDigit())
                        }
                        .accessibilityLabel("Testing node latency \(latencyCompletedCount) of \(latencyTotalCount)")
                    } else {
                        Label("Test all", systemImage: HakoSymbol.boltHorizontalCircle.name)
                    }
                }
                .disabled(isTestingLatency || groups.isEmpty)
                .accessibilityIdentifier("nodes.testAll")
            }
        }
        .sheet(isPresented: $showsDisplaySettings) {
            NodeDisplaySettingsView(presentation: $presentation, sort: $sort)
                .hakoModalPresentation(.form)
        }
        .onChange(of: presentation) { $0.save() }
        .task { await refresh() }
    }

    private var listContent: some View {
        List {
            ForEach(groups) { group in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { !query.isEmpty || unfoldedGroups.contains(group.name) },
                            set: { setExpanded($0, group.name) }
                        )
                    ) {
                        ForEach(sortedMembers(in: group), id: \.self) { member in
                            NodeListRow(
                                group: group,
                                member: member,
                                type: group.memberTypes[member] ?? "?",
                                delay: delays[member],
                                isTesting: testingNames.contains(member),
                                presentation: presentation,
                                select: { if group.selectable { select(group.name, member) } },
                                test: { test(member) }
                            )
                        }
                    } label: {
                        NodeGroupHeader(
                            group: group,
                            iconStyle: presentation.iconStyle,
                            isTesting: group.members.contains { testingNames.contains($0) },
                            test: { testGroup(group) }
                        )
                    }
                } footer: {
                    Text(groupFooter(group))
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refresh() }
        .accessibilityIdentifier("nodes.list")
    }

    private var tabsContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    ForEach(groups) { group in
                        tabButton(for: group)
                    }
                }
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(.vertical, HakoTheme.Spacing.compact)
            }
            .accessibilityIdentifier("nodes.tabs")

            if let group = activeGroup {
                ScrollView {
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                        NodeGroupHeader(
                            group: group,
                            iconStyle: presentation.iconStyle,
                            isTesting: group.members.contains { testingNames.contains($0) },
                            test: { testGroup(group) }
                        )

                        HakoGlassEffectContainer(spacing: HakoTheme.Spacing.compact) {
                            LazyVGrid(columns: gridColumns, spacing: HakoTheme.Spacing.compact) {
                                ForEach(sortedMembers(in: group), id: \.self) { member in
                                    NodeCard(
                                        group: group,
                                        member: member,
                                        type: group.memberTypes[member] ?? "?",
                                        delay: delays[member],
                                        isTesting: testingNames.contains(member),
                                        presentation: presentation,
                                        select: { if group.selectable { select(group.name, member) } },
                                        test: { test(member) }
                                    )
                                }
                            }
                        }

                        Text(groupFooter(group))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, HakoTheme.Spacing.standard)
                    .padding(.bottom, HakoTheme.Spacing.section)
                }
                .refreshable { await refresh() }
                .accessibilityIdentifier("nodes.tabContent.\(group.name)")
            }
        }
    }

    private var activeGroup: ProxyGroup? {
        if let currentGroupName,
           let group = groups.first(where: { $0.name == currentGroupName }) {
            return group
        }
        return groups.first
    }

    private var gridColumns: [GridItem] {
        let minimum = dynamicTypeSize.isAccessibilitySize
            ? CGFloat(NodeDensity.loose.minimumCardWidth)
            : CGFloat(presentation.density.minimumCardWidth)
        return [GridItem(
            .adaptive(
                minimum: minimum,
                maximum: .infinity
            ),
            spacing: HakoTheme.Spacing.compact
        )]
    }

    @ViewBuilder
    private func tabButton(for group: ProxyGroup) -> some View {
        let selected = activeGroup?.name == group.name
        Button { setCurrentGroup(group.name) } label: {
            HStack(spacing: HakoTheme.Spacing.tight) {
                HakoSelectionMark(isSelected: selected)
                Text(group.name)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityIdentifier("nodes.tab.\(group.name)")
    }

    private func sortedMembers(in group: ProxyGroup) -> [String] {
        sort.apply(members: group.members, delays: delays)
    }

    private func groupFooter(_ group: ProxyGroup) -> String {
        guard group.selectable else { return "Managed automatically · resolved to \(group.resolvedNow)" }
        if group.now == group.resolvedNow { return "Selected: \(group.now)" }
        return "Selected: \(group.now) · resolved to \(group.resolvedNow)"
    }
}

private struct NodeDisplaySettingsView: View {
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Binding var presentation: NodePresentationSettings
    @Binding var sort: ProxySort

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section("Browse") {
                    Picker("Browse", selection: $presentation.browseStyle) {
                        ForEach(NodeBrowseStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("nodes.settings.browse")
                }

                Section("Layout") {
                    Picker("Density", selection: $presentation.density) {
                        ForEach(NodeDensity.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("nodes.settings.density")
                    Picker("Card", selection: $presentation.cardSize) {
                        ForEach(NodeCardSize.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("nodes.settings.card")
                    Picker("Type Icons", selection: $presentation.iconStyle) {
                        ForEach(NodeIconStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("nodes.settings.icons")
                }

                Section("Order") {
                    Picker("Sort", selection: $sort) {
                        ForEach(ProxySort.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("nodes.settings.sort")
                }
            }
            .hakoPageTitle("Node Display")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }
}

private struct NodeGroupHeader: View {
    let group: ProxyGroup
    let iconStyle: NodeIconStyle
    let isTesting: Bool
    let test: () -> Void

    var body: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            typeIcon
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                Text(group.name).font(.headline)
                Text(ProxyTypePresentation.title(for: group.type))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            Button(action: test) {
                if isTesting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: HakoSymbol.boltHorizontalCircle.name)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isTesting)
            .accessibilityLabel("Test \(group.name) group")
        }
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch iconStyle {
        case .none:
            EmptyView()
        case .standard:
            ProxyGroupIconView(address: group.iconURL, size: 34) {
                HakoIconWell(
                    symbol: ProxyTypePresentation.symbol(for: group.type),
                    tint: .blue
                )
            }
        case .iconOnly:
            ProxyGroupIconView(address: group.iconURL, size: 34) {
                Image(systemName: ProxyTypePresentation.symbol(for: group.type).name)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct NodeListRow: View {
    let group: ProxyGroup
    let member: String
    let type: String
    let delay: Int?
    let isTesting: Bool
    let presentation: NodePresentationSettings
    let select: () -> Void
    let test: () -> Void

    var body: some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Button(action: select) {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    selectionMark
                    memberIcon
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                        Text(member)
                            .foregroundStyle(.primary)
                            .lineLimit(presentation.cardSize == .minimal ? 1 : 2)
                        if presentation.cardSize == .expanded {
                            Text(ProxyTypePresentation.title(for: type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: HakoTheme.Spacing.compact)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!group.selectable)
            .accessibilityLabel(member)
            .accessibilityValue(member == group.now ? "Selected" : "")
            .accessibilityHint(group.selectable ? "Selects this node" : "Selected automatically")

            latencyButton
        }
        .padding(.vertical, CGFloat(presentation.density.rowPadding))
        .frame(
            minHeight: HakoClientUI.HakoTheme.Control.minimumHitTarget
        )
    }

    private var selectionMark: some View {
        HakoSelectionMark(isSelected: member == group.now)
    }

    @ViewBuilder
    private var memberIcon: some View {
        if presentation.iconStyle != .none {
            Image(systemName: ProxyTypePresentation.symbol(for: type).name)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }

    private var latencyButton: some View {
        Button(action: test) {
            if isTesting {
                ProgressView().controlSize(.small)
            } else {
                Text(delayLabel)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .buttonStyle(.borderless)
        .disabled(isTesting)
        .accessibilityLabel("Test latency for \(member), \(delayLabel)")
        .accessibilityValue(delayLabel)
        .accessibilityIdentifier("node.test.\(member)")
    }

    private var delayLabel: String {
        delay.map { $0 > 0 ? "\($0) ms" : "—" } ?? "—"
    }
}

private struct NodeCard: View {
    let group: ProxyGroup
    let member: String
    let type: String
    let delay: Int?
    let isTesting: Bool
    let presentation: NodePresentationSettings
    let select: () -> Void
    let test: () -> Void

    var body: some View {
        HakoOverviewCard {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                Button(action: select) {
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                        HStack(alignment: .top, spacing: HakoTheme.Spacing.compact) {
                            HakoSelectionMark(isSelected: member == group.now)
                            memberIcon
                            Text(member)
                                .font(.body.weight(member == group.now ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(presentation.cardSize == .minimal ? 1 : 2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }

                        if presentation.cardSize == .expanded {
                            Text(ProxyTypePresentation.title(for: type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!group.selectable)
                .accessibilityLabel(member)
                .accessibilityValue(member == group.now ? "Selected" : "")
                .accessibilityHint(group.selectable ? "Selects this node" : "Selected automatically")

                if presentation.cardSize != .minimal {
                    Divider()
                }

                Button(action: test) {
                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(delayLabel, systemImage: HakoSymbol.boltHorizontalCircle.name)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isTesting)
                .accessibilityLabel("Test latency for \(member), \(delayLabel)")
                .accessibilityValue(delayLabel)
                .accessibilityIdentifier("node.test.\(member)")
            }
        }
    }

    @ViewBuilder
    private var memberIcon: some View {
        if presentation.iconStyle != .none {
            Image(systemName: ProxyTypePresentation.symbol(for: type).name)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }

    private var delayLabel: String {
        delay.map { $0 > 0 ? "\($0) ms" : "—" } ?? "—"
    }
}


