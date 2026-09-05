import HakoClientUI
import SwiftUI

 
 
 
 
private enum ClientSettingsDoor: String, Identifiable {
    case udpFallback
    var id: String { rawValue }
}

struct ClientSettingsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var doorSelection: ClientSettingsDoor?

    private var udpFallbackDestination: some View {
        UDPFallbackSettingsView(
            policy: Binding(
                get: { udpFallback },
                set: { newValue in
                     
                     
                    if let newValue { udpFallback = newValue }
                }
            ),
            offersInherit: false,
            overallPolicy: udpFallback,
             
             
             
             
            profileOverride: activeProfileUDPFallback,
            guardInput: activeProfileUDPFallbackGuardInput
        )
        .onChange(of: udpFallback) {
            UDPFallbackSettings.setPolicy($0)
            restageRuntime()
        }
    }

    @ObservedObject var command: ClashCommandClient
     
     
     
     
     
    var activeProfileUDPFallback: UDPFallbackPolicy?
     
     
     
     
     
     
     
     
     
    var activeProfileUDPFallbackGuardInput: () async -> ConfigTransforms.UDPFallbackGuardInput? = { nil }
     
     
     
     
     
    var restageRuntime: () -> Void = {}
    @State private var testURLText = DelayTestSettings.url()
    @FocusState private var editingURL: Bool
    @State private var rejected = false
    @State private var autoClose = NodeSwitchSettings.autoCloseOnSwitch()
    @State private var udpFallback = UDPFallbackSettings.policy()
    @State private var userAgentPreset = ClientUserAgent.preset()
    @AppStorage(
        TrafficStatisticsSettings.key,
        store: TrafficStatisticsSettings.appGroupDefaults
    ) private var onlyProxyTraffic = false
    @AppStorage(
        NetworkPathPolicySettings.allowExpensiveUpdatesKey,
        store: GlobalConfig.appGroupDefaults
    ) private var allowExpensiveUpdates = true
    @AppStorage(
        NetworkPathPolicySettings.allowConstrainedUpdatesKey,
        store: GlobalConfig.appGroupDefaults
    ) private var allowConstrainedUpdates = true

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                Toggle("Close connections on node switch", isOn: $autoClose)
                    .accessibilityIdentifier("client.close-connections-on-switch")
                    .onChange(of: autoClose) { NodeSwitchSettings.setAutoCloseOnSwitch($0) }
            } footer: {
                Text("Moves live traffic to the newly selected node immediately.")
            }

            Section {
                HakoDoorLink(ClientSettingsDoor.udpFallback, selection: $doorSelection) {
                    udpFallbackDestination
                } label: {
                     
                     
                    HStack {
                        Text(hako: .copy("UDP Fallback"))
                        Spacer()
                        Text(hako: .copy(udpFallbackSummary))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("client.udpFallback")
            } footer: {
                Text(hako: .copy("HTTP and HTTPS proxies have no UDP transport. Without this, matched traffic the outbound cannot carry falls through every rule and leaves over DIRECT with your own address."))
            }

            Section {
                Toggle("Count proxy traffic only", isOn: $onlyProxyTraffic)
                    .onChange(of: onlyProxyTraffic) { _ in
                        command.applyTrafficStatisticsPreference()
                    }
                    .accessibilityIdentifier("client.onlyProxyTraffic")
            } header: {
                Text("Traffic Statistics")
            } footer: {
                Text("Off shows all traffic. On hides traffic sent directly to the internet (final outbound DIRECT), so dashboard numbers reflect proxy use. The VPN stays connected while Clash refreshes statistics.")
            }

            Section {
                Toggle("Allow metered automatic updates", isOn: $allowExpensiveUpdates)
                    .accessibilityIdentifier("client.path.allowExpensiveUpdates")
                Toggle("Allow Low Data automatic updates", isOn: $allowConstrainedUpdates)
                    .accessibilityIdentifier("client.path.allowConstrainedUpdates")
            } header: {
                Text("Automatic Updates")
            } footer: {
                Text("Subscriptions and resources update on their own schedule over any connection. Turn one off to hold updates back on that kind of network.")
            }

            Section {
                Picker("Subscription Compatibility", selection: $userAgentPreset) {
                    ForEach(ClientUserAgent.Preset.allCases) { preset in
                        Text(hako: .copy(preset.label)).tag(preset)
                    }
                }
                .onChange(of: userAgentPreset) {
                    ClientUserAgent.save(preset: $0)
                }
                .accessibilityIdentifier("client.user-agent-preset")
            } header: {
                Text("Download Identity")
            } footer: {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                Text("The app sends this when it downloads a subscription or a provider, unless an override sets global-ua. Clash is recommended; FlClash is a compatibility fallback for panels that negotiate by client name.")
            }

            Section {
                hakoPromptField(
                    DelayTestSettings.defaultURL,
                    text: $testURLText
                )
                    .accessibilityIdentifier("client.delay-test-url")
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(save)
                    .focused($editingURL)
                if rejected {
                    HakoStatusMessage(
                        text: .copy("HTTPS URL with a host required; leave empty for the default."),
                        kind: .error
                    )
                }
            } header: {
                Text("Delay test URL")
            } footer: {
                Text("Used by node delay tests. Empty resets to the default endpoint.")
            }
        }
        
        .hakoDoorPresenter(
            selection: $doorSelection,
            title: { _ in "UDP Fallback" }
        ) { _ in
            udpFallbackDestination
        }
        .hakoPageTitle("Client Settings")
        .toolbar {
             
             
             
            ToolbarItem(placement: .confirmationAction) {
                if !insideProductModal {
                    if editingURL || testURLText != DelayTestSettings.url() {
                        Button("Save") {
                            save()
                            editingURL = false
                        }
                        .accessibilityIdentifier("client-settings.save")
                    }
                }
            }
        }
        .onDisappear(perform: save)
         
         
         
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                 
                 
                 
                HakoModalActionBar(primaryTitle: "Save",
                    primaryDisabled: testURLText == DelayTestSettings.url(),
                    onPrimary: save)
            }
        }
    }

    private func save() {
        rejected = !DelayTestSettings.setURL(testURLText)
        if !rejected { testURLText = DelayTestSettings.url() }
    }

     
    private var udpFallbackSummary: String {
        switch udpFallback {
        case .quic: "Reject QUIC"
        case .quicAllPorts: "Reject QUIC on 443 and 80"
        case .allUDP: "Reject all fallthrough UDP"
        case .off: "Off"
        }
    }

}
