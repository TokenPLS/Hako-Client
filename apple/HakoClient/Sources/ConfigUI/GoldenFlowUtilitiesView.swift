import SwiftUI
import HakoClientUI

 
 
 
 
 
struct GoldenFlowUtilitiesAdapter: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.hakoShellLayout) private var shellLayout
     
     
     
     
     
    @Environment(\.locale) private var locale

    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var connections: ConnectionsModel
    @ObservedObject var networkQuality: NetworkQualityModel
    @ObservedObject var stun: STUNTestModel
    @ObservedObject var proxyShare: ProxyShareModel
    @Binding var destination:
        AppNavigationDestination.UtilitiesDestination
    var ownsNavigationContainer = true


    var body: some View {
        Group {
            if ownsNavigationContainer {
                HakoFeatureNavigationContainer {
                    sharedRoot
                        .hakoPageTitle("Utilities")
                }
                .hakoStackNavigationViewStyle()
            } else {
                sharedRoot
            }
        }
        .environment(
            \.hakoUsesRegularDetailLayout,
            !ownsNavigationContainer
        )
    }

    private var sharedRoot: some View {
        HakoClientUI.HakoUtilitiesView(
            snapshot: sharedSnapshot,
            destination: $destination,
            presentationClass:
                shellLayout == .regularSidebar
                    ? .regularTouch
                    : .compactTouch,
            palette: productPalette,
             
             
             
            omitting: shellLayout == .regularSidebar
                ? HakoUtilitiesCatalog.regularHubExcludes
                : [],
            icon: { symbol in
                HakoSymbolImage(symbol: symbol)
            },
            destinationContent: { item in
                GoldenFlowUtilitiesDestinationAdapter(
                    vpn: vpn,
                    command: command,
                    connections: connections,
                    networkQuality: networkQuality,
                    stun: stun,
                    proxyShare: proxyShare,
                    destination: item,
                    usesRegularDetailLayout:
                        !ownsNavigationContainer
                )
            }
        )
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        HakoClientUI.HakoProductPalette.hakoProduct
    }

    private var sharedSnapshot: AppleClientSnapshot {
        AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: command.isConnected
                    ? .connected
                    : .disconnected
            ),
            utilities: HakoUtilitiesSnapshot(
                nativeAPIConnected: command.isConnected,
                activeConnectionCount:
                    connections.activeConnectionCount,
                requestCount: connections.requestLog.count,
                logCount: command.logs.count,
                isRecordingLogs: HakoLogSettings.isRecording(
                    from: GlobalConfig.appGroupDefaults
                ),
                logRetentionTitle: HakoCopy.string(
                    HakoLogSettings.retention(
                        from: GlobalConfig.appGroupDefaults
                    ).title,
                    locale: locale
                ),
                providerCount: nil,
                networkQualitySummary: networkQuality.summary,
                stunSummary: stun.summary,
                proxyShareStatus: proxyShare.phase.title,
                proxyShareEnabled: proxyShare.status.enabled
            )
        )
    }

}

 
 
 
 
 
struct GoldenFlowUtilitiesDestinationAdapter: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var connections: ConnectionsModel
    @ObservedObject var networkQuality: NetworkQualityModel
    @ObservedObject var stun: STUNTestModel
    @ObservedObject var proxyShare: ProxyShareModel
    let destination:
        AppNavigationDestination.UtilitiesDestination
    var usesRegularDetailLayout: Bool
    var loadsPersistedLogs = true

    var body: some View {
         
         
        pageBody
            .hakoPageTitle(.copy(destination.title))
    }

    @ViewBuilder
    private var pageBody: some View {
        Group {
            switch destination {
            case .root:
                EmptyView()
            case .connections:
                ConnectionsView(
                    model: connections,
                    command: command,
                    autoStart: false
                )
            case .requests:
                RequestsView(model: connections)
            case .logs:
                LogsDestinationView(
                    command: command,
                    loadsPersistedLogs: loadsPersistedLogs
                )
            case .networkQuality:
                NetworkQualityView(model: networkQuality)
            case .stun:
                STUNTestView(model: stun)
            case .proxyShare:
                ProxyShareView(model: proxyShare)
            case .runtime:
                RuntimeDetailView(
                    command: command,
                    usesRegularDetailLayout:
                        usesRegularDetailLayout,
                    restart: { Task { await vpn.forceRestart() } }
                )
            case .providers:
                 
                 
                 
                 
                 
                 
                ProvidersView(vpn: vpn, command: command)
            case .diagnosticsInbox:
                MetricKitInboxView()
            }
        }
        .environment(
            \.hakoUsesRegularDetailLayout,
            usesRegularDetailLayout
        )
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct LogsDestinationView: View {
     
     
     
     
     
     
     
    let command: ClashCommandClient
    let loadsPersistedLogs: Bool
    @State private var survived: [String] = []
    @State private var liveLogs: [String] = []
    @State private var isConnected = false

    var body: some View {
        LogsContent(
            lines: HakoLogSettings.isRecording(
                from: GlobalConfig.appGroupDefaults
            )
                ? survived + liveLogs
                : survived,
            isConnected: isConnected,
            clear: {
                command.clearLogs()
                 
                 
                 
                 
                 
                 
                survived = []
            }
        )
         
         
        .onReceive(command.$logs) { liveLogs = $0 }
        .onReceive(command.$isConnected) { isConnected = $0 }
        .task {
            guard loadsPersistedLogs else {
                survived = []
                return
            }
            survived = await Task.detached(priority: .userInitiated) {
                HakoLogStore.shared.mergedTail()
            }.value
        }
    }
}


