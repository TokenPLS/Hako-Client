import HakoClientUI
import Foundation
import SwiftUI

enum OverviewWidget: String, CaseIterable, Identifiable {
    case traffic
    case routing
    case egress
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traffic: return "Live Traffic"
        case .routing: return "Outbound Mode"
        case .egress: return "Egress"
        case .runtime: return "Runtime"
        }
    }

    var symbol: HakoSymbol {
        switch self {
        case .traffic: return .waveformPathEcg
        case .routing: return .arrowTriangleBranch
        case .egress: return .network
        case .runtime: return .cpu
        }
    }
}

struct DashboardLayoutStore {
    static let defaultWidgets = OverviewWidget.allCases
    private static let key = "dashboard.widgets"
    let defaults: UserDefaults

    init(defaults: UserDefaults = GlobalConfig.appGroupDefaults) {
        self.defaults = defaults
    }

    func load() -> [OverviewWidget] {
        guard defaults.object(forKey: Self.key) != nil else {
            return Self.defaultWidgets
        }
        let rawValues = defaults.stringArray(forKey: Self.key) ?? []
        var seen = Set<OverviewWidget>()
        return rawValues.compactMap(OverviewWidget.init(rawValue:)).filter {
            seen.insert($0).inserted
        }
    }

    func save(_ widgets: [OverviewWidget]) {
        var seen = Set<OverviewWidget>()
        defaults.set(widgets.filter { seen.insert($0).inserted }.map(\.rawValue),
                     forKey: Self.key)
    }
}

struct DashboardCustomizationView: View {
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Binding var widgets: [OverviewWidget]
    let persist: ([OverviewWidget]) -> Void

    private var available: [OverviewWidget] {
        OverviewWidget.allCases.filter { !widgets.contains($0) }
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            List {
                Section {
                    if widgets.isEmpty {
                        Text("No optional cards. The Connection card always stays on Overview.")
                            .foregroundStyle(.secondary)
                    }
                     
                     
                     
                     
                     
                     
                    ForEach(widgets) { widget in
                        HStack(spacing: HakoTheme.Spacing.row) {
                            Label { Text(hako: .copy(widget.title)) } icon: { Image(systemName: widget.symbol.name).accessibilityHidden(true) }
                                .accessibilityIdentifier("dashboard.card.\(widget.rawValue)")
                            Spacer(minLength: HakoTheme.Spacing.row)
                            Button {
                                remove(widget)
                            } label: {
                                Image(systemName: HakoSymbol.xmarkCircle.name)
                                    .frame(
                                        width: HakoClientUI.HakoTheme.Control
                                            .minimumHitTarget,
                                        height: HakoClientUI.HakoTheme.Control
                                            .minimumHitTarget
                                    )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Remove \(widget.title)")
                            .accessibilityIdentifier("dashboard.remove.\(widget.rawValue)")
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                } header: {
                    Text("Shown Cards")
                } footer: {
                    Text("Use Edit to drag cards into the order shown on Overview.")
                }

                if !available.isEmpty {
                    Section("Available Cards") {
                        ForEach(available) { widget in
                            Button {
                                add(widget)
                            } label: {
                                Label("Add \(widget.title)", systemImage: HakoSymbol.plus.name)
                            }
                            .accessibilityIdentifier("dashboard.add.\(widget.rawValue)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .hakoPageTitle("Customize Dashboard")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) { EditButton() }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }

    private func add(_ widget: OverviewWidget) {
        guard !widgets.contains(widget) else { return }
        widgets.append(widget)
        persist(widgets)
    }

    private func remove(_ widget: OverviewWidget) {
        widgets.removeAll { $0 == widget }
        persist(widgets)
    }

    private func move(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        persist(widgets)
    }

    private func delete(at offsets: IndexSet) {
        widgets.remove(atOffsets: offsets)
        persist(widgets)
    }
}

struct OverviewContent: View {
    let snapshot: OverviewSnapshot
    let actions: OverviewActions
    let widgets: [OverviewWidget]
    @ObservedObject var proxyShare: ProxyShareModel

    private var connection: ConnectionPresentation {
        ConnectionPresentation(status: snapshot.connectionStatus)
    }

    var body: some View {
        ScrollView {
            HakoGlassEffectContainer(spacing: HakoTheme.Spacing.section) {
                LazyVStack(spacing: HakoTheme.Spacing.section) {
                    ConnectionCard(
                        connection: connection,
                        start: actions.start,
                        stop: actions.stop
                    )

                    if !snapshot.errorMessage.isEmpty {
                        OverviewErrorCard(message: snapshot.errorMessage)
                    }
                    if !snapshot.noticeMessage.isEmpty {
                        OverviewNoticeCard(message: snapshot.noticeMessage)
                    }

                    ForEach(widgets) { widget in
                        dashboardWidget(widget)
                    }

                    OverviewMoreSettingsCard(proxyShare: proxyShare)
                }
            }
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .padding(.vertical, HakoTheme.Spacing.section)
        }
        .background(HakoTheme.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func dashboardWidget(_ widget: OverviewWidget) -> some View {
        switch widget {
        case .traffic:
            TrafficCard(traffic: snapshot.traffic)
        case .routing:
            RoutingCard(routing: snapshot.routing, setMode: actions.setMode)
        case .egress:
            EgressCard(egress: snapshot.egress, checkEgress: actions.checkEgress)
        case .runtime:
            RuntimeCard(runtime: snapshot.runtime, collectGarbage: actions.collectGarbage)
        }
    }
}
