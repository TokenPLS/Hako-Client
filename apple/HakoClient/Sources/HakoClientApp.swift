import Combine
import HakoClientUI
import SwiftUI
import UIKit
import WidgetKit

@main
struct HakoClientApp: App {
    init() {
         
         
        ConfigStoreSuspensionShield.install()
         
         
         
        HakoPerfBootstrap.install()
            Self.repairPersonalRulePlacement()
            MetricKitCollector.shared.start()
             
            BackgroundRefresh.register { await BackgroundRefresh.refreshDueProfiles() }
            BackgroundRefresh.schedule(earliest: BackgroundRefresh.nextEligibility())
             
            Task { await BackgroundRefresh.scanOnForegroundIfDue() }
    }

     
     
    private static func repairPersonalRulePlacement() {
        guard let container = HakoAppIdentifiers.appGroupContainer, let defaults = UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
        else { return }
        let working = container.appendingPathComponent("working", isDirectory: true)
        PersonalRulePlacementMigration.runIfNeeded(
            store: ProfileStore(
                fileURL: working.appendingPathComponent("store/profiles.json")
            ),
            defaults: defaults
        )
    }

    var body: some Scene {
        WindowGroup {

            AppShellView()

        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
struct DisclaimerView: View {

    var body: some View {
         
         
         
         
         
        List {
            Section {
                 
                 
                 
                 
                 
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.row
                ) {
                    Text(hako: .copy(Self.responsibility))
                    Text(hako: .copy(Self.noService))
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, HakoTheme.Spacing.tight)
            }
        }
        .listStyle(.insetGrouped)
        .hakoPageTitle("Disclaimer")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("about.disclaimer")
    }

    static let responsibility =
        "Clash is a network tool. You are responsible for making sure the way you use it complies with the laws that apply to you and with the terms of any service you connect through."
    static let noService =
        "Clash does not provide any proxy service and is not responsible for the third-party services you configure it with."
}

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase


    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var preferences = AppPreferencesModel()
    @StateObject private var vpn: VPNController
     
     
     
     
     
    @StateObject private var profiles: ProfilesViewModel
    @StateObject private var command = ClashCommandClient()
    @StateObject private var stats = StatsModel()
    @StateObject private var nodes = NodesModel()
    @StateObject private var networkQuality = NetworkQualityModel()
    @StateObject private var stun = STUNTestModel()
    @StateObject private var connections = ConnectionsModel()
    @StateObject private var proxyShare = ProxyShareModel()
    @StateObject private var profileImports = ProfileImportRouter()
    @State private var navigationState = HakoClientUI.AppleClientNavigationState()

    init() {
        let vpn = VPNController()
        _vpn = StateObject(wrappedValue: vpn)
        _profiles = StateObject(wrappedValue: ProfilesViewModel(vpn: vpn))
    }

     
     
     
    @State private var lastRouteNotedVPNStatus = ""
    @State private var profileCenterDestination: AppNavigationDestination?
     
     
     
     
     
    @State private var pendingSessionPage:
        HakoClientUI.HakoRootDestination?
     
     
    @State private var compactSessionPage:
        HakoClientUI.HakoRootDestination?
     
     
    @State private var railProxiesGroup: String?
    @State private var profileRefreshToken = 0
     
    @State private var isPickingProfile = false
    @State private var pendingOutboundMode: String?
     
     
    @State private var pickerSwitchFailure: ProfileSwitchAlertFailure?


    private let systemHandoff = HakoSystemHandoff()

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func probeSingleNodeIfRequested() async {


    }

    private func logFootprintIfRequested() async {


    }

    private func applySoftMemoryLimitIfRequested() async {


    }

     
     
     
     
     
    private func collectResidentProfilesIfRequested() async {




    }

    var body: some View {
        debugGateShell
            .task { await collectResidentProfilesIfRequested() }
            .task { await applySoftMemoryLimitIfRequested() }
            .task { await logFootprintIfRequested() }
            .task { await probeSingleNodeIfRequested() }
         
         
         
         
         
         
         
         
         
         
         
         
         
        .sheet(item: shellSheet, onDismiss: activeRuntimeDidChange) {
            shellSheetContent(for: $0)
                .hakoModalPresentation(.page)
        }
         
         
         
         
         
         
        .environment(\.locale, preferences.language.locale)
        .preferredColorScheme(preferences.themeMode.colorScheme)
        .tint(preferences.accent.color)
        .background(HakoTheme.canvas(pureBlack: preferences.pureBlack).ignoresSafeArea())
        .task {


            proxyShare.bind(command: command)
            stun.bind(command: command)
            vpn.legacySettingsMigration = vpn.migrateLegacyGlobalSettingsIfNeeded()
            await vpn.refresh()
            rebind()
            syncConnectionsForSelectedTab()
            proxyShare.updateAPIAvailability(command.isConnected)
            if command.isConnected {
                await proxyShare.refresh()
            }
            checkSharedImports()
            handlePendingSystemAction()


        }
        .onReceive(vpn.$status.removeDuplicates()) { status in
            handleVPNStatusTransition(status)
        }
         
         
         
        .onChange(of: vpn.hasLoadedStatus) { _ in
            publishVPNControlSnapshot(status: vpn.status)
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
        .onChange(of: command.selectionAnnouncements) { _ in
            guard command.isConnected else { return }
            Task { await nodes.refresh() }
        }
        .onChange(of: command.isConnected) { connected in
            syncConnectionsForSelectedTab(isConnected: connected)
            proxyShare.updateAPIAvailability(connected)
             
             
             
             
             
             
             
             
             
             
             
             
            if !command.isReopeningControlSession {
                Task { await nodes.refresh() }
            }
            if connected {
                Task { await proxyShare.refresh() }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didReceiveMemoryWarningNotification
            )
        ) { _ in
            Task { await nodes.cancelLatencyTests(reason: .memoryPressure) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hakoSystemActionQueued)) { _ in
            handlePendingSystemAction()
        }
        .onChange(of: navigationState.selectedRoot) { _ in
            syncConnectionsForSelectedTab()
        }
        .alert(
             
             
            profileImports.pendingConfirmation.map(
                ProfileImportRouter.confirmationIsLocalConfiguration
            ) == true
                ? Text("Add this configuration?")
                : Text("Add this subscription?"),
            isPresented: Binding(
                 
                 
                 
                 
                 
                 
                get: { profileImports.pendingConfirmation != nil && scenePhase == .active },
                 
                 
                 
                 
                 
                 
                 
                 
                set: { presented in
                     
                    if !presented, profileImports.pendingConfirmation != nil {
                        HakoLogStore.shared.append(
                            "install link alert torn down (state kept)  \(profileImports.pendingConfirmation ?? "")",
                            stream: .app, level: .warning)
                    }
                }
            )
        ) {
            Button("Add") {
                profileImports.acceptPendingConfirmation()
                 
                 
                 
                 
                 
                navigate(to: .profiles)
            }
            Button("Don't Add", role: .cancel) {
                profileImports.declinePendingConfirmation()
            }
        } message: {
             
             
             
             
             
            (profileImports.pendingConfirmation.map(
                ProfileImportRouter.confirmationIsLocalConfiguration
            ) == true
                ? Text("A link wants to add a configuration to Clash.\n\n")
                : Text("A link wants to add a subscription to Clash.\n\n"))
                + Text(verbatim: profileImports.pendingConfirmation.map {
                    ProfileImportRouter.confirmationText(for: $0)
                } ?? "")
        }
        .onChange(of: nodes.routeGeneration) { _ in
             
             
            guard command.isConnected else { return }
            Task { _ = await stats.checkEgressIP() }
        }
         
         
         
        .task {


        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                command.sync(vpnStatus: vpn.status)
                syncConnectionsForSelectedTab(isForeground: true)


                proxyShare.refreshAddresses()
                if command.isConnected {
                    Task { await proxyShare.refresh() }
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    Task { await command.refreshMetadata() }
                }
                checkSharedImports()
                handlePendingSystemAction()
                    Task { await BackgroundRefresh.scanOnForegroundIfDue() }
            } else if phase == .background, !false {
                connections.stop()
                Task { await nodes.cancelLatencyTests(reason: .backgrounded) }
                 
                 
                BackgroundRefresh.schedule(
                    earliest: BackgroundRefresh.nextEligibility()
                )
            }
        }
        .task {
             
             
            ProviderFirstLoadRetry.loadedRuleProvidersInCore = { [weak command] in
                await MainActor.run {
                    guard let command, command.isConnected else { return nil as ClashCommandClient? }
                    return command
                }.map { client in
                    Task { @MainActor in
                        let catalog = try? await client.providerRuntimeCatalog()
                        return Set(catalog?.ruleProviders.compactMap { name, provider in
                            provider.updatedAt == nil ? nil : name
                        } ?? [])
                    }
                }?.value ?? []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProviderFirstLoadRetry.didRefreshNotification)) { _ in
             
             
             
            let updates = ProviderFirstLoadRetry.takeRuntimeUpdates()
            guard !updates.isEmpty else { return }
            Task {
                for update in updates {
                    _ = await command.sideUpdateProvider(update)
                }
            }
        }
        .onOpenURL { url in
            if let route = HakoSystemRoute(url: url) {
                handleSystemRoute(route)
            } else {
                 
                 
                 
                 
                 
                 
                 
                profileImports.open(url)
            }
        }
    }

     
     
     
    @ViewBuilder
    private func shellSheetContent(for sheet: ShellSheet) -> some View {
            switch sheet.kind {
            case .profileCenter:
                ProfileCenterView(
                    profiles: profiles,
                    importRouter: profileImports,
                    initialDestination: profileCenterDestination ?? .profiles,
                    onActiveRuntimeChanged: activeRuntimeDidChange
                )
                .hakoPageSizedSheet()
            case .profilePicker:
                HakoFeatureNavigationContainer {
                    HakoProfilePickerCard(
                        items: profiles.profiles.map {
                            HakoClientUI.HakoProfilePickerItem(
                                id: $0.id,
                                label: $0.label,
                                isCurrent: $0.id == profiles.activeProfileID,
                                isSwitching: $0.id == profiles.busyProfileID
                            )
                        },
                        onPick: { pickProfile($0) },
                        onClose: { isPickingProfile = false }
                    )
                     
                     
                     
                    .hakoSheetPresentation()
                }
                .alert(
                    isPresented: Binding(
                        get: { pickerSwitchFailure != nil },
                        set: { if !$0 { pickerSwitchFailure = nil } }
                    ),
                    error: pickerSwitchFailure
                ) { _ in
                    Button("OK", role: .cancel) { pickerSwitchFailure = nil }
                } message: { failure in
                    Text(verbatim: failure.messageText)
                }
            case .runtimeInspector:
                HakoFeatureNavigationContainer {
                    compactRuntimeInspectorContent
                        .hakoToolbarUnlessInPanel {
                            ToolbarItem(placement: .cancellationAction) {
                                 
                                 
                                HakoSheetCloseButton {
                                    navigationState.navigate(to: .home)
                                }
                                .accessibilityIdentifier(
                                    "compact.runtime-inspector.done"
                                )
                            }
                        }
                }
            }
    }

    private var debugGateShell: some View {
        goldenFlowShell
    }


    private var goldenFlowShell: some View {
        Group {
            switch shellLayout {
            case .compactTabs:
                compactTabShell
            case .regularSidebar:
                regularSidebarShell
            }
        }
         
         
        .environment(\.hakoShellLayout, shellLayout)

         
         
         
        .onChange(of: shellLayout) { layout in
            switch layout {
            case .compactTabs:
                guard let handoff = AppShellLayoutSelector.compactHandoff(
                    for: navigationState.selectedRoot
                ) else { return }
                switch handoff {
                case .proxiesSheet: pendingSessionPage = .proxies
                case .rulesSheet: pendingSessionPage = .rules
                case .profileCenter: profileCenterDestination = .profiles
                }
            case .regularSidebar:
                 
                 
                 
                 
                guard let root = AppShellLayoutSelector.regularHandoff(
                    for: profileCenterDestination,
                    sessionPage: compactSessionPage
                ) else { return }
                profileCenterDestination = nil
                compactSessionPage = nil
                navigationState.selectRoot(root)
            }
        }
    }

    private var shellLayout: AppShellLayout {
        AppShellLayoutSelector.layout(
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            hasRegularHorizontalSize: horizontalSizeClass == .regular
        )
    }

    private var compactTabShell: some View {
        TabView(selection: appTabSelection) {
            homeRoot
            .tabItem {
                 
                 
                Label {
                    Text("Home")
                } icon: {
                    HakoSymbolImage(symbol: .catCircleFill)
                }
            }
            .tag(AppTab.home)

            utilitiesRoot(ownsNavigationContainer: true)
                .tabItem { Label("Utilities", systemImage: HakoSymbol.briefcaseCircleFill.name) }
                .tag(AppTab.utilities)

            moreRoot(ownsNavigationContainer: true)
            .tabItem { Label("More", systemImage: HakoSymbol.ellipsisCircleFill.name) }
            .tag(AppTab.more)
        }
        .accessibilityIdentifier("app.compact-tabs")
    }

    @ViewBuilder
    private var regularSidebarShell: some View {
        HakoClientUI.HakoRegularClientShell(
            navigationState: sharedRegularNavigationBinding,
            sidebarBehavior: .locked,
            background: HakoTheme.canvas,
            sidebarBackground: HakoTheme.surface
        ) { destination in
            HakoSymbolImage(
                symbol: destination.symbol,
                resizesToFit: true
            )
        } rootContent: { destination in
            regularRoot(for: destination)
        } destinationContent: { destination in
            regularDestination(for: destination)
        }
        .modifier(RegularSidebarTitleStyle())
    }

    private var sharedRegularNavigationBinding:
        Binding<HakoClientUI.AppleClientNavigationState>
    {
        $navigationState
    }

    @ViewBuilder
    private func regularRoot(
        for destination: HakoClientUI.HakoRootDestination
    ) -> some View {
        switch destination {
        case .home:
            homeRoot
         
         
         
        case .profiles:
            ProfileCenterView(
                profiles: profiles,
                importRouter: profileImports,
                initialDestination: .profiles,
                ownsNavigationContainer: false,
                onActiveRuntimeChanged: activeRuntimeDidChange
            )
         
         
         
        case .proxies:
            SessionProxiesRailRoot(
                vpn: vpn,
                command: command,
                nodes: nodes,
                profiles: profiles,
                profileRefreshToken: profileRefreshToken,
                avoidsLiveProviderStore: false,
                stagedGroup: $railProxiesGroup
            )
        case .rules:
            SessionRulesRailRoot(
                command: command,
                profiles: profiles,
                openProxiesGroup: { group in
                    railProxiesGroup = group
                    navigate(to: .proxies)
                }
            )
         
         
         
        case .connections:
            regularDestination(for: .utilities(.connections))
        case .requests:
            regularDestination(for: .utilities(.requests))
        case .logs:
            regularDestination(for: .utilities(.logs))
         
         
         
         
        case .utilities:
            utilitiesRoot(ownsNavigationContainer: false)
        case .more:
            moreRoot(ownsNavigationContainer: false)
        case .dns:
             
             
             
             
             
             
            regularDestination(for: .more(.dnsAndHosts))
        case .about:
            regularDestination(for: .more(.about))
        }
    }

    @ViewBuilder
    private func regularDestination(
        for destination: HakoClientUI.AppleClientDestination
    ) -> some View {
        switch destination {
        case .activeRules:
            ActiveRulesView(command: command)
        case .dnsQuery:
            DNSQueryView(command: command)
        case .utilities(let item):
            GoldenFlowUtilitiesDestinationAdapter(
                vpn: vpn,
                command: command,
                connections: connections,
                networkQuality: networkQuality,
                stun: stun,
                proxyShare: proxyShare,
                destination: item,
                usesRegularDetailLayout: true
            )
        case .more(let item):
            GoldenFlowMoreDestinationAdapter(
                vpn: vpn,
                command: command,
                preferences: preferences,
                destination: item,
                usesRegularDetailLayout: true
            )
        default:
             
             
             
             
            homeRoot
        }
    }

    private var homeRoot: some View {
        GoldenFlowHomeAdapter(
            vpn: vpn,
            command: command,
            nodes: nodes,
            stats: stats,
            profiles: profiles,
            profileRefreshToken: profileRefreshToken,
            pendingSessionPage: $pendingSessionPage,
            sessionPresentation: $compactSessionPage,
            pendingOutboundMode: $pendingOutboundMode,
            openProfiles: {
                 
                 
                if shellLayout == .regularSidebar {
                    isPickingProfile = true
                } else {
                    navigate(to: .profiles)
                }
            },
            openProxies: { navigate(to: .proxies) },
            openRules: { navigate(to: .rules) },
            openActiveRules: { navigate(to: .activeRules) },
            openLogs: { navigate(to: .utilities(.logs)) },
            openDNSQuery: { navigate(to: .dnsQuery) },
            rebind: rebind
        )
    }

    private func utilitiesRoot(ownsNavigationContainer: Bool) -> some View {
        GoldenFlowUtilitiesAdapter(
            vpn: vpn,
            command: command,
            connections: connections,
            networkQuality: networkQuality,
            stun: stun,
            proxyShare: proxyShare,
            destination: utilitiesDestinationSelection,
            ownsNavigationContainer: ownsNavigationContainer
        )
    }

    private func moreRoot(ownsNavigationContainer: Bool) -> some View {
        GoldenFlowMoreAdapter(
            vpn: vpn,
            command: command,
            preferences: preferences,
            destination: moreDestinationSelection,
            ownsNavigationContainer: ownsNavigationContainer,
            navigate: { navigate(to: $0) }
        )
    }

    private var appTabSelection: Binding<AppTab> {
        Binding(
            get: { Self.compactTab(for: navigationState.selectedRoot) },
            set: { tab in
                navigationState.selectRoot(Self.tabRoot(for: tab))
            }
        )
    }

     
     
     
     
     
     
    private static func compactTab(
        for root: HakoClientUI.HakoRootDestination
    ) -> AppTab {
        switch root {
        case .home, .proxies, .rules, .profiles: .home
        case .connections, .requests, .logs, .utilities: .utilities
        case .dns, .more, .about: .more
        }
    }

    private static func tabRoot(
        for tab: AppTab
    ) -> HakoClientUI.HakoRootDestination {
        switch tab {
        case .home: .home
        case .utilities: .utilities
        case .more: .more
        }
    }

    private var utilitiesDestinationSelection: Binding<AppNavigationDestination.UtilitiesDestination> {
        Binding(
            get: {
                guard case .utilities(let destination) = navigationState.destination else {
                    return .root
                }
                return destination
            },
            set: { destination in
                navigationState.navigate(
                    to: .utilities(destination)
                )
            }
        )
    }

    private var moreDestinationSelection: Binding<AppNavigationDestination.MoreDestination> {
        Binding(
            get: {
                guard case .more(let destination) = navigationState.destination else {
                    return .root
                }
                return destination
            },
            set: { destination in
                navigationState.navigate(to: .more(destination))
            }
        )
    }

     
     
     
     
     
     
     
    private enum ShellSheetKind {
        case profileCenter
        case profilePicker
        case runtimeInspector
    }

     
    private struct ShellSheet: Identifiable {
        let kind: ShellSheetKind
        var id: Int {
            switch kind {
            case .profileCenter: return 0
            case .profilePicker: return 1
            case .runtimeInspector: return 2
            }
        }
    }

    private var shellSheetKind: ShellSheetKind? {
        if profileCenterDestination != nil { return .profileCenter }
        if isPickingProfile { return .profilePicker }
        if compactRuntimeInspectorPresentation.wrappedValue { return .runtimeInspector }
        return nil
    }

     
     
    private var shellSheet: Binding<ShellSheet?> {
        Binding(
            get: { shellSheetKind.map(ShellSheet.init(kind:)) },
            set: { presented in
                guard presented == nil else { return }
                switch shellSheetKind {
                case .profileCenter: profileCenterDestination = nil
                case .profilePicker: isPickingProfile = false
                case .runtimeInspector: navigationState.navigate(to: .home)
                case .none: break
                }
            }
        )
    }

    private var profileCenterPresentation: Binding<Bool> {
        Binding(
            get: { profileCenterDestination != nil },
            set: { isPresented in
                guard !isPresented else { return }
                profileCenterDestination = nil
            }
        )
    }

    private var compactRuntimeInspectorPresentation: Binding<Bool> {
        Binding(
            get: {
                guard shellLayout == .compactTabs else {
                    return false
                }
                switch navigationState.destination {
                case .activeRules, .dnsQuery:
                    return true
                default:
                    return false
                }
            },
            set: { isPresented in
                guard !isPresented else {
                    return
                }
                navigationState.navigate(to: .home)
            }
        )
    }

    @ViewBuilder
    private var compactRuntimeInspectorContent: some View {
        switch navigationState.destination {
        case .activeRules:
            ActiveRulesView(command: command)
        case .dnsQuery:
            DNSQueryView(command: command)
        default:
            EmptyView()
        }
    }

    private func rebind() {
        HakoPerf.measure("shell.rebind") {
            command.bind(session: vpn.session)
            command.sync(vpnStatus: vpn.status)
            stats.bind(session: vpn.session, command: command)
            HakoPerf.measure("shell.rebind.nodes") {
                nodes.bind(command: command)
            }
        }
    }

    private func activeRuntimeDidChange() {
        profileRefreshToken &+= 1
         
         
        nodes.noteRouteChanged()
        Task {
            await nodes.refresh()
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func syncConnectionsForSelectedTab(
        isForeground: Bool? = nil,
        isConnected: Bool? = nil
    ) {
        if ConnectionsRecordingPolicy.shouldRecord(
            isForeground: isForeground ?? (scenePhase == .active),
            isConnected: isConnected ?? command.isConnected
        ) {
            connections.sync(true)
        } else {
            connections.stop()
        }
    }

    private func checkSharedImports() {
         
         
         
         
         
         
         
         
         
         
        let hadPendingImport = profileImports.pendingImport != nil
        profileImports.importSharedFiles()
        guard profileImports.pendingConfirmation == nil else { return }
        let newlyImported = profileImports.pendingImport != nil && !hadPendingImport
        if newlyImported || !profileImports.errorMessage.isEmpty {
            navigate(to: .profileImport)
        }
    }

    private func handlePendingSystemAction() {
        guard let route = systemHandoff.consume() else { return }
        HakoLogStore.shared.append("system handoff consumed -> \(String(describing: route))", stream: .app, level: .warning)
        handleSystemRoute(route)
    }

    private func handleSystemRoute(_ route: HakoSystemRoute) {
        navigate(to: route.navigationDestination)
        switch route {
        case .open:
            break
        case .vpn(let action):
            Task {
                 
                 
                 
                 
                 
                await vpn.ensureStatusLoaded()
                switch HakoSystemVPNPolicy.command(
                    for: action,
                    isActive: HakoSystemVPNPolicy.isActive(vpn.status)
                ) {
                case .start:
                    let started = await vpn.start(origin: .programmatic)
                    if !started {
                         
                         
                         
                         
                        await vpn.refreshLastDisconnectErrorAfterFailedStart()
                    }
                case .stop:
                    await vpn.stop(origin: .programmatic)
                case .unchanged:
                    break
                }
            }
        case .mode(let mode):
             
             
             
             
             
             
             
            let intent = ModeIntentClock.next()
            pendingOutboundMode = mode.rawValue
            Task {
                 
                 
                 
                await vpn.ensureStatusLoaded()
                if !HakoSystemVPNPolicy.isActive(vpn.status) { await vpn.start(origin: .programmatic) }
                rebind()
                for _ in 0..<100 where !command.isConnected {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                 
                 
                 
                 
                 
                 
                 
                var globalConfirmed = mode != .global
                if mode == .global {
                    for _ in 0..<20 {
                        let confirmed = await nodes.ensureGlobalProxySelection()
                        let verdict = GlobalModeConfirmation.verdict(
                            groupCount: nodes.groups.count,
                            selectionConfirmed: confirmed
                        )
                        if verdict != .notYetKnown {
                            globalConfirmed = verdict == .confirmed
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
                if mode == .global, !globalConfirmed {
                     
                     
                     
                     
                     
                     
                    return
                }
                guard ModeIntentClock.isCurrent(intent) else { return }
                await command.setMode(mode.rawValue)
            }
        }
    }

     
     
     
     
     
    private func pickProfile(_ id: String) {
        guard id != profiles.activeProfileID else {
            isPickingProfile = false
            return
        }
        guard let profile = profiles.profiles.first(where: { $0.id == id })
        else { return }
        Task {
            if await profiles.selectAndWait(profile) {
                activeRuntimeDidChange()
#if canImport(UIKit)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
#endif
                isPickingProfile = false
            } else if let failure = profiles.lastFailure {
                 
                 
                pickerSwitchFailure = ProfileSwitchAlertFailure(failure)
            }
        }
    }

    private func navigate(
        to destination: HakoClientUI.AppleClientDestination
    ) {
        AppShellNavigationRouter.navigate(
            to: destination,
            layout: shellLayout,
            navigationState: &navigationState,
            profileCenterDestination: &profileCenterDestination
        )
         
         
         
         
         
         
         
         
        if destination == .proxies, shellLayout == .compactTabs {
            pendingSessionPage = .proxies
        }
    }

     
     
     
     
     
     
     
    private func handleVPNStatusTransition(_ status: String) {
        command.sync(vpnStatus: status)
        publishVPNControlSnapshot(status: status)
         
         
         
         
         
         
         
         
         
         
         
         
         
        guard status == "connected" || status == "disconnected",
              status != lastRouteNotedVPNStatus else { return }
        lastRouteNotedVPNStatus = status
        nodes.noteRouteChanged()
    }

    private func publishVPNControlSnapshot(status: String) {
        guard let active = HakoSystemVPNPolicy.controlSnapshot(
            status: status,
            isLoaded: vpn.hasLoadedStatus
        ) else { return }
        systemHandoff.setVPNSnapshot(active: active)
         
         
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(
                ofKind: HakoSystemHandoff.controlKind
            )
        }
    }
}

 
 
 
 
 
 
private struct RegularSidebarTitleStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.toolbarTitleDisplayMode(.large)
        } else {
            content.navigationBarTitleDisplayMode(.large)
        }
    }
}
