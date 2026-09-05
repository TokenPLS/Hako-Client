import SwiftUI
import HakoClientUI

 
 
 
 
 
struct GoldenFlowMoreAdapter: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.hakoShellLayout) private var shellLayout

    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var preferences: AppPreferencesModel
    @Binding var destination:
        AppNavigationDestination.MoreDestination
    var ownsNavigationContainer = true
     
     
    var navigate: (AppNavigationDestination) -> Void = { _ in }
    @State private var attention: LegacySettingsAttention?

    var body: some View {
        Group {
            if ownsNavigationContainer {
                HakoFeatureNavigationContainer {
                    sharedRoot
                        .hakoPageTitle("More")
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
        .onAppear { refreshAttention() }
        .onChange(of: vpn.legacySettingsMigration) { _ in refreshAttention() }
    }

    private var workingDirectory: URL? {
        HakoAppIdentifiers.appGroupContainer?.appendingPathComponent("working", isDirectory: true)
    }

     
     
    private func refreshAttention() {
        guard let result = vpn.legacySettingsMigration, let workingDirectory else {
            attention = nil
            return
        }
        let profiles = ProfileStore(
            fileURL: workingDirectory.appendingPathComponent("store/profiles.json")
        ).load()
        attention = LegacySettingsAttention.make(from: result, profiles: profiles)
    }

     
     
     
    private func performAttention(actionID: String) {
        guard let attention,
              let action = attention.actions.first(where: { $0.id == actionID })
        else { return }
        switch action.resolution {
        case .openProfile(let id):
            navigate(id.map { .profileDetail(id: $0) } ?? .profiles)
        case .openScripts:
             
             
            navigate(.profiles)
        default:
            guard let workingDirectory else { return }
            if let fresh = LegacySettingsResolver.perform(
                action.resolution,
                attentionID: attention.id,
                workingDirectory: workingDirectory
            ) {
                vpn.legacySettingsMigration = fresh
            }
            refreshAttention()
        }
    }

    private var sharedRoot: some View {
        HakoClientUI.HakoMoreView(
            snapshot: sharedSnapshot,
            destination: $destination,
            presentationClass:
                shellLayout == .regularSidebar
                    ? .regularTouch
                    : .compactTouch,
            palette: productPalette,
             
             
             
            omitting: shellLayout == .regularSidebar
                ? HakoMoreCatalog.regularHubExcludes
                : [],
            attentionAction: performAttention(actionID:),
            icon: { symbol in
                HakoSymbolImage(symbol: symbol)
            },
            destinationContent: { item in
                GoldenFlowMoreDestinationAdapter(
                    vpn: vpn,
                    command: command,
                    preferences: preferences,
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
        let onDemand = OnDemandSettings.configuration()
        let info = AppBuildInfo.current()
         
         
        let tunnelIncludeAllNetworks = vpn.tunnelSettings.includeAllNetworks
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: command.isConnected
                    ? .connected
                    : .disconnected
            ),
            more: HakoMoreSnapshot(
                onDemandEnabled: onDemand.enabled,
                onDemandRuleCount: onDemand.rules.count,
                dnsOnlyActive:
                    NetworkOperatingModeStore().current == .dnsOnly,
                tunnelIncludeAllNetworks: tunnelIncludeAllNetworks,
                showsDeveloperDestination:
                    showsDeveloperDestination,
                about: HakoAboutSnapshot(
                    appVersion: info.appVersion,
                     
                    buildNumber: info.buildNumber,
                    sourceRevision: info.sourceRevision,
                    coreVersion: info.coreVersion
                ),
                attention: attention?.snapshot
            )
        )
    }

    private var showsDeveloperDestination: Bool {

        false

    }

    private var developerModeBinding: Binding<Bool>? {

        nil

    }

}

 
struct GoldenFlowMoreDestinationAdapter: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var preferences: AppPreferencesModel
    let destination: AppNavigationDestination.MoreDestination
    var usesRegularDetailLayout: Bool
    @StateObject private var profiles: ProfilesViewModel
    @State private var showsDNSQuery = false

    init(
        vpn: VPNController,
        command: ClashCommandClient,
        preferences: AppPreferencesModel,
        destination: AppNavigationDestination.MoreDestination,
        usesRegularDetailLayout: Bool
    ) {
        self.vpn = vpn
        self.command = command
        self.preferences = preferences
        self.destination = destination
        self.usesRegularDetailLayout = usesRegularDetailLayout
        _profiles = StateObject(
            wrappedValue: ProfilesViewModel(vpn: vpn)
        )
    }

    private var sharedSnapshot: AppleClientSnapshot {
        let info = AppBuildInfo.current()
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: command.isConnected
                    ? .connected
                    : .disconnected
            ),
            more: HakoMoreSnapshot(
                showsDeveloperDestination:
                    showsDeveloperDestination,
                about: HakoAboutSnapshot(
                    appVersion: info.appVersion,
                     
                    buildNumber: info.buildNumber,
                    sourceRevision: info.sourceRevision,
                    coreVersion: info.coreVersion
                ),
                 
                 
                 
                 
                overrideCounts: OverrideEntryCount.moreCounts(
                    in: settingsProfile?.override.patchJSON ?? ""
                )
            )
        )
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        HakoClientUI.HakoProductPalette.hakoProduct
    }

    private var showsDeveloperDestination: Bool {

        false

    }

    private var developerModeBinding: Binding<Bool>? {

        nil

    }

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
            case .geoResources:
                ResourcesView()
            case .backupRestore:
                BackupRestoreView()
            case .onDemand:
                OnDemandConfigView(
                    vpn: vpn,
                    usesRegularDetailLayout:
                        usesRegularDetailLayout
                )
            case .tunnel:
#if os(iOS)
                TunnelSettingsView(vpn: vpn)
#else
                 
                 
                 
                 
                HakoMacTunnelSettingsView(vpn: vpn)
#endif
            case .systemIntegrations:
                SystemIntegrationsView()
            case .dnsOnly:
                DNSOnlySettingsView(vpn: vpn)
            case .dnsAndHosts:
                if let profile = settingsProfile {
                    ProfileDNSSettingsAdapter(
                        profile: profile,
                        command: command,
                        sourceYAML:
                            sourceProfile.flatMap {
                                profiles.uiProjectedYAML(for: $0)
                            },
                        saveHosts: {
                            try profiles.updateHosts($0)
                        },
                        openDNSQuery: {
                            showsDNSQuery = true
                        },
                        ownsNavigationContainer: false,
                        save: {
                            try profiles.updateDNS($0)
                        }
                    )
                } else {
                    loadingCoreSettings
                }
            case .tunnelAndRoutes:
                if let profile = settingsProfile {
                    ProfileRoutePresetView(
                        profile: profile,
                        sourceYAML: profiles.baseYAML(for: profile),
                        ownsNavigationContainer: false
                    ) {
                        try profiles.updateRoutePreset($0)
                    }
                } else {
                    loadingCoreSettings
                }
            case .coreBehavior:
                if let profile = settingsProfile {
                    GlobalCoreBehaviorSettingsView(
                        profile: profile,
                        sourceYAML: profiles.baseYAML(for: profile)
                    ) { network, runtime in
                        try profiles.updateGlobalCoreBehavior(
                            network: network,
                            runtime: runtime
                        )
                    }
                } else {
                    loadingCoreSettings
                }
            case .clientSettings:
                let guardProfile = settingsProfile
                ClientSettingsView(
                    command: command,
                    activeProfileUDPFallback: guardProfile?.udpFallbackPolicy,
                    activeProfileUDPFallbackGuardInput: { [profiles] in
                        guard let guardProfile else { return nil }
                        return await profiles.udpFallbackGuardInput(for: guardProfile)
                    }
                ) {
                    profiles.restageForClientRuntimeSetting()
                }
            case .appearance:
                AppearanceSettingsView(
                    preferences: preferences,
                    usesRegularDetailLayout:
                        usesRegularDetailLayout
                )
            case .about:
                HakoClientUI.HakoAboutView(
                    snapshot: sharedSnapshot.more.about,
                    palette: productPalette,
                    developerMode: developerModeBinding,
                    legal: {
                         
                         
                         
                         
                        if AppStoreReviewLink.isConfigured {
                            Button {
                                AppStoreReviewLink.requestReview()
                            } label: {
                                HakoDestinationRow(
                                    title: "Rate Clash on the App Store",
                                    symbol: .starFill,
                                    tint: .yellow
                                )
                            }
                            .buttonStyle(.borderless)
                        .tint(.primary)
                            .accessibilityIdentifier("about.rate")
                        }
                        HakoRoutedViewLink {
                            AcknowledgementsView()
                        } label: {
                            HakoDestinationRow(
                                title: "Acknowledgements",
                                symbol: .docTextMagnifyingglass,
                                tint: .blue
                            )
                        }
                        .accessibilityIdentifier("about.acknowledgements")
                         
                         
                         
                         
                         
                         
                         
                         
                        Link(
                            destination: URL(
                                string: "https://clash.md/terms"
                            )!
                        ) {
                            HakoDestinationRow(
                                title: "Terms of Use",
                                symbol: .docTextMagnifyingglass,
                                tint: .blue,
                                linksOut: true
                            )
                        }
                        .buttonStyle(.borderless)
                        .tint(.primary)
                        .accessibilityIdentifier("about.terms")
                        Link(
                            destination: URL(
                                string: "https://clash.md/privacy"
                            )!
                        ) {
                            HakoDestinationRow(
                                title: "Privacy Policy",
                                symbol: .docTextMagnifyingglass,
                                tint: .blue,
                                linksOut: true
                            )
                        }
                        .buttonStyle(.borderless)
                        .tint(.primary)
                        .accessibilityIdentifier("about.privacy")
                    },
                    icon: { symbol in
                        HakoSymbolImage(symbol: symbol)
                    },
                    componentLogo: { component in
                        Image(
                            component == .hakoCore
                                ? "hako.core.logo"
                                : "mihomo.logo"
                        )
                        .resizable()
                        .scaledToFit()
                    }
                )
                .hakoInsetGroupedListStyle()
            case .developer:

                EmptyView()

            }
        }
        .environment(
            \.hakoUsesRegularDetailLayout,
            usesRegularDetailLayout
        )
        .task {
            profiles.load()
        }
        .sheet(isPresented: $showsDNSQuery) {
            HakoFeatureNavigationContainer {
                DNSQueryView(command: command)
            }
            .hakoModalPresentation(.page)
        }
    }

    private var sourceProfile: Profile? {
        if let activeProfileID = profiles.activeProfileID,
           let active = profiles.profiles.first(
               where: { $0.id == activeProfileID }
           )
        {
            return active
        }
        return profiles.profiles.first
    }

    private var settingsProfile: Profile? {
        sourceProfile.map {
            profiles.settingsProfile(for: $0)
        }
    }

    private var loadingCoreSettings: some View {
        VStack(spacing: HakoTheme.Spacing.standard) {
            ProgressView()
            Text("Loading Core Settings…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("more.core-settings.loading")
    }

     
     
     
     
     
     
     
}

struct SystemIntegrationAvailability: Equatable, Sendable {
    let shortcutsAvailable: Bool
    let controlsAvailable: Bool

    init(shortcutsAvailable: Bool, controlsAvailable: Bool) {
        self.shortcutsAvailable = shortcutsAvailable
        self.controlsAvailable = controlsAvailable
    }

    init(operatingSystemVersion: OperatingSystemVersion) {
        shortcutsAvailable =
            operatingSystemVersion.majorVersion >= 16
        controlsAvailable =
            operatingSystemVersion.majorVersion >= 18
    }

    static var current: Self {
        SystemIntegrationAvailability(
            operatingSystemVersion:
                ProcessInfo.processInfo.operatingSystemVersion
        )
    }
}

private struct SystemIntegrationsView: View {
    private let availability =
        SystemIntegrationAvailability.current

    var body: some View {
        HakoMacSettingsContainer {
            Section {
                availabilityRow(
                    title: "App Shortcuts",
                    available: availability.shortcutsAvailable,
                     
                     
                     
                    requirement: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                        ? "Requires macOS 13 or later"
                        : "Requires iOS 16 or later"
                )
                if availability.shortcutsAvailable {
                    Label(
                        "Start or stop Clash",
                        systemImage: HakoSymbol.power.name
                    )
                    Label(
                        "Change routing mode",
                        systemImage:
                            HakoSymbol.arrowTriangleBranch.name
                    )
                    Label(
                        "Import configuration files",
                        systemImage:
                            HakoSymbol.squareAndArrowDown.name
                    )
                }
            } header: {
                Text("Shortcuts & Siri")
            } footer: {
                Text(
                    "Open the Shortcuts app and search for Clash to add these actions to an automation or Siri phrase."
                )
            }

            Section {
                availabilityRow(
                    title: "Clash VPN Control",
                    available: availability.controlsAvailable,
                    requirement: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                        ? "Requires macOS 15 or later"
                        : "Requires iOS 18 or later"
                )
            } header: {
                Text("Control Center")
            } footer: {
                Text(
                    "In Control Center, tap Add a Control and choose Clash VPN to connect or disconnect after authentication."
                )
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Shortcuts & Controls")
    }

    private func availabilityRow(
        title: String,
        available: Bool,
        requirement: String
    ) -> some View {
        HStack {
            Text(hako: .copy(title))
            Spacer(minLength: HakoTheme.Spacing.standard)
            Text(available ? "Available" : requirement)
                .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}


