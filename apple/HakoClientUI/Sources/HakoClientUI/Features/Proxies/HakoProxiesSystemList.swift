import Combine
import SwiftUI
import HakoClientKit

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoProxiesSystemList<Icon: View>: View {
    let snapshot: AppleClientSnapshot
     
     
     
    @State private var choiceRefusal: HakoProxyChoiceRefusalNote?
    let palette: HakoProductPalette
     
    let send: (HakoProxiesCommand) -> Void
    @Binding var expanded: Set<String>
    let query: String
     
     
    let memberOrder: (HakoProxyGroupSnapshot) -> [HakoProxyMemberSnapshot]
    let latencyPulse: AnyPublisher<HakoLatencyPulse, Never>?
    let latencyPulseSnapshot: (() -> HakoLatencyPulse)?
    let density: HakoProxiesRowDensity
     
     
    let showsIconImages: Bool
    let icon: (HakoSymbol) -> Icon
     
     
    var index: ProxyDerivedIndex = .empty
    var sort: HakoProxiesDisplayPreferences.Sort = .standard
     
     
     
    var expandedValue: Set<String> = []

    private var browsedGroups: [HakoProxyGroupSnapshot] {
        snapshot.proxies.groups(matching: query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
         
         
        let _ = HakoPerf.count("proxies.list.body")
        return listBody
    }

    private var listBody: some View {
        List {
            switch snapshot.proxies.effectiveCatalogState {
            case .disconnected:
                stateRow(
                    title: "Connect to View Proxies",
                    message: "The active connection supplies the current groups, nodes, and selections.",
                    symbol: .serverRack,
                    identifier: "proxies.state.empty"
                )
            case .loading:
                stateRow(
                    title: "Loading Proxies",
                    message: "Reading the current proxy catalog.",
                    symbol: .serverRack,
                    identifier: "proxies.state.loading",
                    isLoading: true
                )
            case .failed(let message):
                stateRow(
                    title: "Proxies Unavailable",
                    message: message,
                    symbol: .exclamationmarkTriangle,
                    identifier: "proxies.state.empty"
                )
            case .ready:
                readySections
            }

            if !snapshot.proxies.providers.isEmpty {
                providersSection
            }
        }
    }

     

    @ViewBuilder
    private var readySections: some View {
        if browsedGroups.isEmpty {
            if snapshot.proxies.browsingSuppressedByDirectMode {
                Section {
                    HakoEmptyState(
                        title: "Direct Mode",
                        message:
                            "This mode sends all traffic without a proxy, so proxy groups and nodes are not listed.",
                        isLoading: false
                    ) {
                        icon(.arrowRight)
                    }
                    .accessibilityIdentifier("proxies.direct-mode-notice")
                }
            } else if isSearching {
                Section {
                    Text("No proxies match \u{201C}\(query)\u{201D}")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("proxies.search.empty")
                }
            } else if snapshot.proxies.providers.isEmpty {
                stateRow(
                    title: "No Proxies",
                    message: "This profile has no proxy groups or nodes.",
                    symbol: .serverRack,
                    identifier: "proxies.state.empty"
                )
            }
        } else {
            ForEach(browsedGroups) { group in
                groupSection(group)
            }
            if !snapshot.proxies.ungroupedNodes(matching: query).isEmpty {
                ungroupedSection
            }
        }
    }

    private func groupSection(_ group: HakoProxyGroupSnapshot) -> some View {
         
         
         
        let isOpen = isSearching || expanded.contains(group.name)
        let toggle = {
            if expanded.contains(group.name) {
                expanded.remove(group.name)
                send(.setGroupExpanded(name: group.name, isExpanded: false))
            } else {
                expanded.insert(group.name)
                send(.setGroupExpanded(name: group.name, isExpanded: true))
                send(.setVisibleGroup(name: group.name))
            }
        }
        let header = { (drawsDisclosure: Bool) in
            HakoProxyGroupHeaderRow(
                group: group,
                isOpen: isOpen,
                canTest: snapshot.proxies.isConnected,
                showsIconImages: showsIconImages,
                drawsDisclosure: drawsDisclosure,
                icon: { AnyView(icon($0)) },
                latencyPulse: latencyPulse,
                toggle: toggle,
                test: { send(.testGroup(name: group.name)) },
                showsUnpin: snapshot.proxies.offersUnpin(for: group),
                unpin: { send(.unpin(group: group.name)) }
            )
            .equatable()
        }
         
         
         
         
         
        return Section {
            header(true)
             
             
             
             
            if let message = snapshot.proxies.actionRefusals[group.name]
                ?? (choiceRefusal?.group == group.name ? choiceRefusal?.message : nil) {
                Text(hako: .copy(message))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("proxies.refusal.\(group.name)")
            }
            if isOpen {
                memberRows(group)
            }
        }
    }

    @ViewBuilder
    private func memberRows(_ group: HakoProxyGroupSnapshot) -> some View {
        let current = group.currentSelection
         
         
         
        ForEach(memberOrder(group)) { member in
            HakoProxyMemberListRow(
                row: HakoProxyFrozenRow(
                    name: member.name,
                    type: member.type,
                    chainedThrough: member.chainedThrough,
                    groupName: group.name
                ),
                initialLatency: snapshot.proxies
                    .displayedLatency(for: member).normalized,
                failureCategory:
                    snapshot.proxies.failureCategories[member.name] ?? "",
                isCurrent: member.name == current,
                canTest: snapshot.proxies.isConnected,
                density: density,
                latencyPulse: latencyPulse,
                latencyPulseSnapshot: latencyPulseSnapshot,
                select: {
                     
                     
                     
                    guard group.allowsMemberChoice else {
                        if let reason = group.memberChoiceRefusal {
                            choiceRefusal = HakoProxyChoiceRefusalNote(group: group.name, message: reason)
                        }
                        return
                    }
                    choiceRefusal = nil
                    send(.select(group: group.name, member: member.name))
                },
                editNode: member.isGroup
                    ? nil
                    : { send(.editMember(name: member.name)) },
                testNode: member.isGroup
                    ? nil
                    : { send(.testMember(name: member.name)) },
                inspectNode: HakoProxyBrowsing.inspects(member)
                    ? { send(.inspectMember(name: member.name)) }
                    : nil
            )
            .equatable()
        }
    }

    private var ungroupedSection: some View {
        let nodes = snapshot.proxies.ungroupedNodes(matching: query)
        let isOpen = HakoProxyBrowsing.showsMembers(
            of: HakoProxyBrowsing.ungroupedKey,
            expanded: expanded,
            isSearching: isSearching
        )
        return Section {
             
             
             
            HakoUngroupedHeaderRow(
                count: snapshot.proxies.ungrouped.count,
                isOpen: isOpen,
                icon: icon
            ) {
                if expanded.contains(HakoProxyBrowsing.ungroupedKey) {
                    expanded.remove(HakoProxyBrowsing.ungroupedKey)
                    send(.setGroupExpanded(name: HakoProxyBrowsing.ungroupedKey, isExpanded: false))
                } else {
                    expanded.insert(HakoProxyBrowsing.ungroupedKey)
                    send(.setGroupExpanded(name: HakoProxyBrowsing.ungroupedKey, isExpanded: true))
                }
            }
            if isOpen {
                 
                 
                ForEach(nodes) { node in
                    HakoProxyMemberListRow(
                        row: HakoProxyFrozenRow(
                            name: node.name,
                            type: node.type,
                            chainedThrough: nil,
                            groupName: nil
                        ),
                        initialLatency: .untested,
                        failureCategory: "",
                        isCurrent: false,
                        canTest: snapshot.proxies.isConnected,
                        density: density,
                        latencyPulse: latencyPulse,
                        latencyPulseSnapshot: latencyPulseSnapshot,
                        select: nil,
                        editNode: { send(.editMember(name: node.name)) },
                        testNode: { send(.testMember(name: node.name)) },
                        inspectNode: HakoProxyBrowsing.inspects(
                            HakoProxyMemberSnapshot(name: node.name, type: node.type)
                        )
                            ? { send(.inspectMember(name: node.name)) }
                            : nil
                    )
                    .equatable()
                }
            }
        }
    }

     

    private var providersSection: some View {
        Section {
            ForEach(snapshot.proxies.providers) { provider in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        HakoRegionalFlag.label(provider.name, pointSize: 17, relativeTo: .body)
                            .font(.body.weight(.semibold))
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
                .accessibilityIdentifier("proxies.provider.\(provider.name)")
            }
        } header: {
            Text(hako: providersTitle)
        }
    }

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

     

    private func stateRow(
        title: String,
        message: String,
        symbol: HakoSymbol,
        identifier: String,
        isLoading: Bool = false
    ) -> some View {
        Section {
            HakoEmptyState(
                title: title,
                message: message,
                isLoading: isLoading
            ) {
                icon(symbol)
            }
            .accessibilityIdentifier(identifier)
        }
    }
}

 
 
 
public enum HakoProxiesRowDensity: String, Sendable {
     
    case standard
     
    case compact

     
     
     
    public static func from(
        _ preferences: HakoProxiesDisplayPreferences
    ) -> HakoProxiesRowDensity {
        switch preferences.size {
        case .standard: return .standard
        case .compact, .minimal: return .compact
        }
    }
}

 
 
 
struct HakoProxyFrozenRow: Equatable, Identifiable {
    var id: String { name }
    let name: String
    let type: String
    let chainedThrough: String?
    let groupName: String?
}

 
 
 
 
struct HakoProxyMemberListRow: View, Equatable {
    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.row == b.row
            && a.initialLatency == b.initialLatency
             
             
             
            && a.failureCategory == b.failureCategory
            && a.isCurrent == b.isCurrent
            && a.canTest == b.canTest
            && a.density == b.density
    }

    let row: HakoProxyFrozenRow
    let initialLatency: HakoProxyLatencyState
     
     
     
     
     
    let failureCategory: String

    let isCurrent: Bool
    let canTest: Bool
    let density: HakoProxiesRowDensity
    let latencyPulse: AnyPublisher<HakoLatencyPulse, Never>?
    let latencyPulseSnapshot: (() -> HakoLatencyPulse)?
    let select: (() -> Void)?
    let editNode: (() -> Void)?
    let testNode: (() -> Void)?
     
     
    let inspectNode: (() -> Void)?

    @State private var liveLatency: HakoProxyLatencyState?

    private var shownLatency: HakoProxyLatencyState {
        liveLatency ?? initialLatency
    }

    var body: some View {
        let _ = HakoPerf.count("proxies.list.row")
         
         
         
        return HStack(spacing: HakoTheme.Spacing.row) {
    Button {
                select?()
            } label: {
                HStack(spacing: HakoTheme.Spacing.row) {
                     
                     
                     
                    Image(systemName: HakoSymbol.checkmark.rawValue)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                        .opacity(isCurrent ? 1 : 0)
                        .frame(width: 18)
                        .accessibilityHidden(!isCurrent)
                    if density == .standard {
                        VStack(alignment: .leading, spacing: 2) {
                            HakoRegionalFlag.label(row.name, pointSize: 17, relativeTo: .body)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            subtitle
                        }
                    } else {
                        HakoRegionalFlag.label(row.name, pointSize: 17, relativeTo: .body)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                     
                     
                    if let testNode {
                        Button(action: testNode) { latencyBadge }
                            .buttonStyle(.plain)
                            .disabled(!canTest)
                    } else {
                        latencyBadge
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(select == nil)
            .accessibilityElement(children: .combine)
            .accessibilityValue(isCurrent ? "Selected" : "")
            .accessibilityIdentifier("proxies.member.\(row.name)")
            .contextMenu {
                if let editNode {
                    Button { editNode() } label: {
                        Label {
                            Text(HakoCopy.key("Edit Node"))
                        } icon: {
                            Image(systemName: HakoSymbol.pencil.rawValue)
                        }
                    }
                }
            }
            .onAppear {
                 
                 
                 
                if liveLatency == nil, let latest = latencyPulseSnapshot?() {
                    apply(latest)
                }
            }
            .onReceive(
                latencyPulse
                    ?? Empty<HakoLatencyPulse, Never>().eraseToAnyPublisher()
            ) { batch in
                apply(batch)
            }
            if let inspectNode {
                Button(action: inspectNode) {
                    Image(systemName: HakoSymbol.infoCircle.rawValue)
                        .font(.body)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(HakoCopy.key("Node Details")))
                .accessibilityIdentifier("proxies.member.info.\(row.name)")
            }
        }
    }

    private func apply(_ batch: HakoLatencyPulse) {
        if !batch.isTesting {
            if let landed = batch.results[row.name] {
                liveLatency = landed
            } else if liveLatency == .testing {
                liveLatency = .untested
            }
        } else if let landed = batch.results[row.name] {
            liveLatency = landed
        } else if batch.testing.contains(row.name) {
            liveLatency = .testing
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let entry = row.chainedThrough {
            HakoRegionalFlag.label("\(entry) → \(row.name)", pointSize: 11, relativeTo: .caption2)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        } else {
            Text(hako: .verbatim(row.type.uppercased()))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var latencyBadge: some View {
         
         
         
         
         
         
        switch shownLatency {
        case .untested:
            Image(systemName: HakoSymbol.bolt.rawValue)
                .font(.caption2)
                 
                 
                .foregroundStyle(canTest ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityLabel("Test latency")
        case .testing:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Testing latency")
        case .measured(let milliseconds):
            Text(hako: .verbatim("\(milliseconds)ms"))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                 
                 
                .foregroundStyle(
                    shownLatency.tier == .fast
                        ? Color.green
                        : shownLatency.tier == .slow ? .yellow : .orange
                )
        case .failed, .timedOut:
             
             
             
             
             
             
             
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .accessibilityLabel(
                    Text(hako: .copy(HakoProbeFailureCopy.badge(
                        for: shownLatency == .timedOut
                            ? "timeout"
                            : failureCategory
                    )))
                )
        }
    }
}

struct HakoProxyGroupHeaderRow: View, Equatable {
    nonisolated static func == (a: Self, b: Self) -> Bool {
         
         
         
         
         
         
        a.group == b.group && a.isOpen == b.isOpen && a.canTest == b.canTest
            && a.showsIconImages == b.showsIconImages
            && a.drawsDisclosure == b.drawsDisclosure
            && a.showsUnpin == b.showsUnpin
    }

    let group: HakoProxyGroupSnapshot
    let isOpen: Bool
     
     
     
    let canTest: Bool
    let showsIconImages: Bool
     
     
    let drawsDisclosure: Bool
    let icon: (HakoSymbol) -> AnyView
    let latencyPulse: AnyPublisher<HakoLatencyPulse, Never>?
    let toggle: () -> Void
    let test: () -> Void
     
     
     
     
    let showsUnpin: Bool
    let unpin: () -> Void

     
     
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

    @State private var liveLatency: HakoProxyLatencyState?

    var body: some View {
        let _ = HakoPerf.count("proxies.list.header")
        return HStack(spacing: 8) {
            Button(action: toggle) {
                HStack(spacing: HakoTheme.Spacing.row) {
                     
                     
                     
                     
                     
                    groupIcon
                    VStack(alignment: .leading, spacing: 2) {
                        HakoRegionalFlag.label(group.name, pointSize: 17, relativeTo: .body)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 4) {
                            Text(hako: .verbatim(group.type.uppercased()))
                            if let now = group.currentSelection {
                                HakoRegionalFlag.label("· \(now)", pointSize: 11, relativeTo: .caption2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("proxies.group.\(group.name)")

             
             
             
            if showsUnpin {
                Button(action: unpin) {
                    Text("Unfix")
                        .font(.caption.weight(.semibold))
                        .frame(height: 44)
                        .contentShape(Rectangle().inset(by: -8))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("proxies.unfix.\(group.name)")
            }

             
             
             
             
             
             
            Button(action: test) {
                Group {
                    if liveLatency == .testing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: HakoSymbol.bolt.rawValue)
                             
                             
                            .font(.footnote.weight(.semibold))
                    }
                }
                 
                 
                 
                .frame(width: 28, height: 44)
                .contentShape(Rectangle().inset(by: -8))
            }
            .buttonStyle(.borderless)
            .disabled(!canTest)
            .accessibilityLabel("Test \(group.name)")
            .accessibilityIdentifier("proxies.testGroup.\(group.name)")

             
             
             
            Button(action: toggle) {
                HStack(spacing: 4) {
                     
                     
                     
                     
                    Text(hako: .verbatim("000"))
                        .font(.caption)
                        .monospacedDigit()
                        .hidden()
                        .overlay(alignment: .trailing) {
                            Text(hako: .verbatim(
                                group.members.count > 999 ? "999+" : "\(group.members.count)"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                        }
                    if drawsDisclosure {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .onReceive(
            latencyPulse
                ?? Empty<HakoLatencyPulse, Never>().eraseToAnyPublisher()
        ) { batch in
            guard let terminal = batch.groupTerminals[group.name] else {
                if !batch.isTesting { liveLatency = nil }
                return
            }
            if let landed = batch.results[terminal] {
                liveLatency = landed
            } else if batch.testing.contains(terminal) {
                liveLatency = .testing
            } else if !batch.isTesting {
                liveLatency = nil
            }
        }
    }
}

 
struct HakoProxyChoiceRefusalNote: Equatable {
    let group: String
    let message: String
}

 
 
 
 
 
 
 
 
 
 
 
 
extension HakoProxiesSystemList: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        let equal = a.snapshot.proxies == b.snapshot.proxies
            && a.snapshot.connection == b.snapshot.connection
            && a.expandedValue == b.expandedValue
            && a.query == b.query
            && a.density == b.density
            && a.showsIconImages == b.showsIconImages
            && a.palette == b.palette
            && a.index == b.index
            && a.sort == b.sort
        HakoPerf.count(equal ? "proxies.list.eq.hit" : "proxies.list.eq.miss")
        return equal
    }
}

