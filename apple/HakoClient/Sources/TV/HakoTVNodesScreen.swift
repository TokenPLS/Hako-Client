import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVNodesScreen: View {
    @Binding var state: HakoTVProductState
     
     
     
    var onPin: ((_ member: String, _ group: String) -> Void)?
     
     
    var onTestAll: ((HakoProxyGroupSnapshot) -> Void)?
     
    var onTest: ((HakoProxyMemberSnapshot) -> Void)?

    @State private var shownGroupName: String?

     
    private var visibleGroups: [HakoProxyGroupSnapshot] {
        Self.visibleGroups(state.proxyGroups, mode: state.outboundMode)
    }

    private var shownGroup: HakoProxyGroupSnapshot? {
        visibleGroups.first { $0.name == shownGroupName } ?? visibleGroups.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
             
             
             
             
             
             
             
             
             
             
             
            if vacancy != .directMode {
                groups
                    .frame(maxWidth: 520)
            }
            grid
                .focusSection()
        }
    }

    private var vacancy: Vacancy? {
        Self.vacancy(mode: state.outboundMode, visibleGroups: visibleGroups)
    }

     

    private var groups: some View {
        List {
            Section("Policy groups") {
                ForEach(visibleGroups) { group in
                    Button {
                        shownGroupName = group.name
                    } label: {
                        LabeledContent {
                            Text(group.currentSelection ?? "—")
                        } label: {
                            Text(group.name)
                            Text(group.type)
                        }
                    }
                     
                     
                     
                     
                    .onHakoTVFocus { shownGroupName = group.name }
                    .accessibilityIdentifier("tvos.nodes.group.\(group.name)")
                }
            }
        }
        .listStyle(.grouped)
        .safeAreaPadding(.horizontal, 44)
    }

     

    @ViewBuilder
    private var grid: some View {
        if let group = shownGroup {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Self.header(for: group))
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 20)
                    if Self.offersTestAll(for: group) {
                         
                         
                         
                         
                         
                        Button {
                            onTestAll?(group)
                        } label: {
                            Text(Self.testAllTitle(isTesting: Self.isTesting(group, state: state)))
                                .font(.caption)
                        }
                        .accessibilityIdentifier("tvos.nodes.test-all")
                    }
                }
                if let refusal = group.memberChoiceRefusal {
                     
                    Text(refusal.localizedForTelevision)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: Self.columnCount(for: group)),
                        alignment: .leading,
                        spacing: 20
                    ) {
                        ForEach(group.members) { member in
                            cell(member, in: group)
                        }
                    }
                     
                     
                     
                     
                     
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            switch vacancy {
            case .directMode:
                directModeNotice
            case .noGroups, .none:
                Text("No policy groups in this configuration")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

     
     
     
     
     
     
    private var directModeNotice: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: HakoSymbol.arrowLeftAndRight.rawValue)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Direct Mode")
                .font(.title3)
            Text("This mode sends all traffic without a proxy, so proxy groups and nodes are not listed.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("tvos.nodes.direct-mode-notice")
    }

    private func cell(_ member: HakoProxyMemberSnapshot, in group: HakoProxyGroupSnapshot) -> some View {
        let inUse = group.currentSelection == member.name
        return Button {
            if let onPin {
                onPin(member.name, group.name)
            } else {
                Self.select(member: member.name, in: group.name, state: &state)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                     
                     
                     
                     
                     
                    Text(member.name)
                        .font(Self.nameFont)
                        .lineLimit(Self.nameLineLimit)
                        .minimumScaleFactor(Self.nameMinimumScale)
                        .multilineTextAlignment(.leading)
                    if inUse {
                        Image(systemName: HakoSymbol.checkmark.rawValue)
                            .font(Self.nameFont)
                            .accessibilityLabel("In use")
                    }
                }
                HStack {
                    Text(member.type)
                        .font(Self.detailFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    Text(Self.latencyLabel(
                        state.latency[member.name] ?? .untested,
                        failureCategory: state.failureReasons[member.name] ?? ""
                    ))
                        .font(Self.detailFont.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .accessibilityIdentifier("tvos.nodes.member.\(member.name)")
        .accessibilityAddTraits(inUse ? .isSelected : [])
         
         
         
         
         
         
         
         
        .contextMenu {
            if let onTest {
                Button(Self.testOneTitle) { onTest(member) }
            }
        }
    }

     

     
     
     
     
     
     
    static let nameFont: Font = .body
    static let detailFont: Font = .caption

     
    static let nameLineLimit = 2

     
     
     
    static let nameMinimumScale: CGFloat = 0.8

     
     
     
     
     
     
     
    static let longNameThreshold = 48

     
     
     
     
     
    static func columnCount(for group: HakoProxyGroupSnapshot) -> Int {
        let longest = group.members.map(\.name.count).max() ?? 0
        return longest > longNameThreshold ? 2 : 3
    }

     
    enum Vacancy: Equatable {
         
         
        case directMode
         
        case noGroups
    }

     
     
     
     
     
     
     
     
     
    static func visibleGroups(
        _ groups: [HakoProxyGroupSnapshot],
        mode: HakoTVOutboundMode
    ) -> [HakoProxyGroupSnapshot] {
        ProxyBrowsingVisibility.groups(
            groups,
            mode: .init(coreValue: mode.kernelToken),
            name: { $0.name },
            isHidden: { _ in false }
        )
    }

     
     
     
     
     
     
    static func vacancy(
        mode: HakoTVOutboundMode,
        visibleGroups: [HakoProxyGroupSnapshot]
    ) -> Vacancy? {
        if mode == .direct { return .directMode }
        return visibleGroups.isEmpty ? .noGroups : nil
    }

    static func select(member: String, in groupName: String, state: inout HakoTVProductState) {
        state.pin(member: member, in: groupName)
    }

     
     
    static func header(for group: HakoProxyGroupSnapshot) -> String {
        let count = group.members.count
        return count == 1
            ? String(localized: "\(group.name) · 1 node · \(group.type)")
            : String(localized: "\(group.name) · \(count) nodes · \(group.type)")
    }

     
     
    static var testOneTitle: String { String(localized: "Test") }

     
     
     
    static func testAllTitle(isTesting: Bool) -> String {
        isTesting ? String(localized: "Testing…") : String(localized: "Test all")
    }

     
     
     
     
    static func offersTestAll(for group: HakoProxyGroupSnapshot) -> Bool {
        !group.members.isEmpty
    }

    static func isTesting(_ group: HakoProxyGroupSnapshot, state: HakoTVProductState) -> Bool {
        group.members.contains { state.latency[$0.name] == .testing }
    }

     
     
     
     
     
     
    static func beginTesting(_ group: HakoProxyGroupSnapshot, state: inout HakoTVProductState) {
        for member in group.members {
            state.latency[member.name] = .testing
        }
    }

     
     
     
     
     
     
     
    static func record(delay: Int, for member: String, state: inout HakoTVProductState) {
        state.latency[member] = HakoProxyLatencyState.measured(milliseconds: delay).normalized
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func merge(
        polled: [String: HakoProxyLatencyState],
        over current: [String: HakoProxyLatencyState],
        sweeping: Set<String>
    ) -> [String: HakoProxyLatencyState] {
        guard !sweeping.isEmpty else { return polled }
        var merged = polled
        for name in sweeping {
            merged[name] = current[name]
        }
        return merged
    }

     
     
    static func latencyLabel(
        _ state: HakoProxyLatencyState,
        failureCategory: String = ""
    ) -> String {
        switch state {
        case .measured(let milliseconds): String(localized: "\(milliseconds) ms")
        case .untested: "—"
        case .testing: "…"
         
         
         
        case .failed, .timedOut:
            String(
                localized: String.LocalizationValue(
                    HakoProbeFailureCopy.badge(
                        for: state == .timedOut ? "timeout" : failureCategory
                    )
                )
            )
        }
    }
}
