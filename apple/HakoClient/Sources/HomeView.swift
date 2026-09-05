import Hako
import HakoClientUI
import SwiftUI

struct HomeView: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var stats: StatsModel
    @ObservedObject var proxyShare: ProxyShareModel
    let rebind: () -> Void
    @State private var dashboardWidgets = DashboardLayoutStore().load()
    @State private var showsDashboardCustomization = false
    @State private var confirmsCoreRestart = false

    private var snapshot: OverviewSnapshot {
        OverviewSnapshot(
            connectionStatus: vpn.status,
            errorMessage: vpn.lastError.isEmpty ? command.lastError : vpn.lastError,
            noticeMessage: vpn.configurationNotice,
            traffic: OverviewTrafficSnapshot(
                upload: command.traffic.upload,
                download: command.traffic.download,
                uploadTotal: command.traffic.uploadTotal,
                downloadTotal: command.traffic.downloadTotal
            ),
            routing: OverviewRoutingSnapshot(
                mode: command.mode,
                configurationStrictRoute: vpn.configurationStrictRoute,
                configuredIncludedRouteCount: vpn.configuredIncludedRouteCount,
                configuredExcludedRouteCount: vpn.configuredExcludedRouteCount,
                deviceCommunicationBypass: vpn.routingPolicy.excludeDeviceCommunication,
                needsApply: vpn.routingPolicyNeedsApply
            ),
            egress: OverviewEgressSnapshot(
                address: stats.egressIP,
                provider: stats.egressISP,
                countryName: stats.egressCountryName,
                countryCode: stats.egressCountryCode
            ),
            runtime: OverviewRuntimeSnapshot(
                coreVersion: HakoVersion(),
                memoryMB: Double(command.memoryBytes) / 1_048_576,
                diagnostics: command.runtimeDiagnostics,
                previousOOMEvidence: command.previousOOMEvidence,
                isCollectingMemory: command.isCollectingMemory,
                memoryActionMessage: command.memoryActionMessage
            )
        )
    }

    private var actions: OverviewActions {
        OverviewActions(
            start: startVPN,
            stop: stopVPN,
            setMode: setMode,
            applyRoutingPolicy: applyRoutingPolicy,
            checkEgress: checkEgress,
            collectGarbage: collectGarbage
        )
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            OverviewContent(
                snapshot: snapshot,
                actions: actions,
                widgets: dashboardWidgets,
                proxyShare: proxyShare
            )
            .hakoPageTitle("Clash")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showsDashboardCustomization = true
                        } label: {
                            Label("Customize Dashboard", systemImage: HakoSymbol.sliderHorizontal3.name)
                        }
                        .accessibilityIdentifier("overview.dashboard.customize")

                        Button {
                            confirmsCoreRestart = true
                        } label: {
                            Label("Restart VPN Core", systemImage: HakoSymbol.arrowTriangle2Circlepath.name)
                        }
                        .disabled(!isVPNActive)
                        .accessibilityIdentifier("overview.core.restart")
                    } label: {
                        Image(systemName: HakoSymbol.ellipsisCircle.name)
                    }
                    .accessibilityLabel("Overview options")
                    .accessibilityIdentifier("overview.dashboard.menu")
                }
            }
            .sheet(isPresented: $showsDashboardCustomization) {
                DashboardCustomizationView(widgets: $dashboardWidgets) { widgets in
                    DashboardLayoutStore().save(widgets)
                }
                .hakoModalPresentation(.form)
            }
            .confirmationDialog(
                "Restart VPN Core?",
                isPresented: $confirmsCoreRestart,
                titleVisibility: .visible
            ) {
                Button("Restart", role: .destructive) { forceRestartCore() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The VPN will disconnect briefly while the system restarts the packet tunnel.")
            }
        }
        .hakoStackNavigationViewStyle()
    }

    private func startVPN() {
        Task {
            await vpn.start()
            rebind()
        }
    }

    private func stopVPN() {
        Task { await vpn.stop() }
    }

    private func setMode(_ mode: String) {
        Task { await command.setMode(mode) }
    }

    private func applyRoutingPolicy() {
        Task {
            await vpn.applyRoutingPolicy(reconnectIfNeeded: true)
            rebind()
        }
    }

    private func checkEgress() {
        Task { await stats.checkEgressIP() }
    }

    private func collectGarbage() {
        Task { await command.requestGarbageCollection() }
    }

    private var isVPNActive: Bool {
        ["connected", "connecting", "reasserting"].contains(vpn.status.lowercased())
    }

    private func forceRestartCore() {
        Task {
            await vpn.forceRestart()
            rebind()
        }
    }
}

struct OverviewSnapshot {
    let connectionStatus: String
    let errorMessage: String
    let noticeMessage: String
    let traffic: OverviewTrafficSnapshot
    let routing: OverviewRoutingSnapshot
    let egress: OverviewEgressSnapshot
    let runtime: OverviewRuntimeSnapshot
}

struct OverviewTrafficSnapshot {
    let upload: Int64
    let download: Int64
    let uploadTotal: Int64
    let downloadTotal: Int64
}

struct OverviewRoutingSnapshot {
    let mode: String
    let configurationStrictRoute: Bool
    let configuredIncludedRouteCount: Int
    let configuredExcludedRouteCount: Int
    let deviceCommunicationBypass: Bool
    let needsApply: Bool

    var disclosure: String {
        "strict-route is applied to the Apple VPN profile as enforceRoutes and requires reconnecting when it changes."
    }
}

struct OverviewEgressSnapshot {
    let address: String
    let provider: String
    let countryName: String
    let countryCode: String

    var isChecking: Bool { address == "checking…" }

    var countryDisplay: String {
        let flag = EgressLookupResult.flagEmoji(countryCode: countryCode)
        let code = countryCode.isEmpty ? "" : " (\(countryCode))"
        let country = countryName.isEmpty ? "—" : countryName
        return [flag, country + code].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct OverviewRuntimeSnapshot {
    let coreVersion: String
    let memoryMB: Double
    let diagnostics: HakoRuntimeDiagnostics?
    let previousOOMEvidence: HakoOOMEvidence?
    let isCollectingMemory: Bool
    let memoryActionMessage: String
}

struct OverviewActions {
    let start: () -> Void
    let stop: () -> Void
    let setMode: (String) -> Void
    let applyRoutingPolicy: () -> Void
    let checkEgress: () -> Void
    let collectGarbage: () -> Void
}


