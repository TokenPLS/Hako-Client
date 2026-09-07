import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
struct TunnelSettingsView: View {
    @ObservedObject var vpn: VPNController
    @State private var draft = VPNTunnelSettings()
    @State private var hasLoaded = false
    @State private var isApplying = false
    @State private var error = ""

    private var enforceRoutesEffective: Bool {
        draft.enforceRoutes || vpn.configurationStrictRoute
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                 
                 
                 
                Toggle(
                    "Enforce Routes",
                    isOn: vpn.configurationStrictRoute
                        ? .constant(true)
                        : binding(\.enforceRoutes)
                )
                .disabled(vpn.configurationStrictRoute)
                .accessibilityIdentifier("tunnel.enforceRoutes")
            } footer: {
                Text("If YES, route rules for this tunnel will take precedence over any locally-defined routes. The default is NO.")
            }

            Section {
                Toggle("Include All Networks", isOn: binding(\.includeAllNetworks))
                    .accessibilityIdentifier("tunnel.includeAllNetworks")
            } header: {
                Text("Include All Networks")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("If YES, all network traffic is routed through the tunnel, with some exclusions.")
                     
                     
                     
                    Text("While this is on, the tunnel runs the gVisor stack; a profile that asks for the system or mixed stack is switched, and the switch is listed under Deviations.")
                }
            }

            Section {
                Toggle("Include Local Networks", isOn: binding(\.includeLocalNetworks))
                    .disabled(!(draft.includeAllNetworks || enforceRoutesEffective))
                    .accessibilityIdentifier("tunnel.includeLocalNetworks")
            } header: {
                Text("Include Local Networks")
            } footer: {
                Text("If YES, all traffic destined for local networks will be included from the tunnel.")
            }

            if #available(iOS 16.4, *) {
                Section {
                    Toggle("Include APNs", isOn: binding(\.includeAPNs))
                        .disabled(!draft.includeAllNetworks)
                        .accessibilityIdentifier("tunnel.includeAPNs")
                } header: {
                    Text("Include APNs")
                } footer: {
                    Text("If YES, the network traffic for the Apple Push Notification service (APNs) will be included from the tunnel.")
                }

                Section {
                    Toggle("Include Cellular Services", isOn: binding(\.includeCellularServices))
                        .disabled(!draft.includeAllNetworks)
                        .accessibilityIdentifier("tunnel.includeCellularServices")
                } header: {
                    Text("Include Cellular Services")
                } footer: {
                    Text("If YES, The internet-routable network traffic for cellular services (VoLTE, Wi-Fi Calling, IMS, MMS, Visual Voicemail, etc.) will be included from the tunnel.")
                }
            }

             
             
            Section {
                Toggle("Hide VPN Icon", isOn: binding(\.hideVPNIcon))
                    .accessibilityIdentifier("tunnel.hideVPNIcon")
            } header: {
                Text("Hide VPN Icon")
            } footer: {
                Text("If YES, the VPN badge stays off the status bar: the tunnel leaves 0.0.0.0/31 and ::/127 outside its routes. Takes effect on the next connection.")
            }

            Section {
                Toggle("HomeKit Compatibility", isOn: binding(\.homeKitCompatibility))
                    .accessibilityIdentifier("tunnel.homeKitCompatibility")
            } header: {
                Text("HomeKit Compatibility")
            } footer: {
                Text("If YES, the tunnel does not take the default route and installs a split route table instead, so HomeKit accessories on the local network keep answering. Internet Sharing does not work while this is on. Takes effect on the next connection.")
            }

            if !error.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                        .accessibilityIdentifier("tunnel.error")
                }
            }
        }
        .disabled(isApplying)
        .onAppear {
            guard !hasLoaded else { return }
            draft = vpn.tunnelSettings
            hasLoaded = true
        }
        .onChange(of: vpn.tunnelSettings) { settings in
            draft = settings
        }
    }

    private func binding(_ keyPath: WritableKeyPath<VPNTunnelSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                var next = draft
                next[keyPath: keyPath] = value
                draft = next
                commit(next)
            }
        )
    }

     
     
    private func commit(_ settings: VPNTunnelSettings) {
        isApplying = true
        error = ""
        Task {
            let applied = await vpn.updateTunnelSettings(settings)
            if !applied {
                error = vpn.lastError
                draft = vpn.tunnelSettings
            }
            isApplying = false
        }
    }
}
