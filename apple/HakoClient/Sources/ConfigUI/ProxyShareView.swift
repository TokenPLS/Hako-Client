import HakoClientUI
import SwiftUI

enum ProxyShareEndpointFormatter {
    static func format(address: String, port: Int32) -> String {
        address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"
    }
}

struct ProxyShareView: View {
    @ObservedObject var model: ProxyShareModel

     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var deviations: ConfigDeviationReport?
    @State private var portText = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmsReset = false
     
     
     
    @State private var permitsProfileLANListener = false
     
     
    @State private var lanExposureNotices: [String] = []

    var body: some View {
         
         
         
         
         
        HakoMacSettingsFormContainer {
            actionSection
            if model.status.enabled {
                connectSection
            }
            serverSection
            securitySection
            profileListenerSection
            listenerDeviationsSection
        }
        
        .hakoPageTitle("LAN Proxy Share")
        .hakoDetailPageInsets()
        .task {
            hydrateDraft(overwriteUsername: true)
            permitsProfileLANListener = LocalNetworkPermission.isPermitted(
                UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
            )
             
             
             
             
             
            lanExposureNotices = CoreLogExcerpt.lanExposureNotices()
            deviations = await Task.detached(priority: .utility) {
                RunningCoreDeviations.activeProfileReport()
            }.value
            await model.refresh()
            hydrateDraft(overwriteUsername: username.isEmpty)
        }
        .onChange(of: permitsProfileLANListener) { permitted in
            LocalNetworkPermission.setPermitted(
                permitted,
                in: UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
            )
        }
        .refreshable {
            await model.refresh()
            hydrateDraft(overwriteUsername: username.isEmpty)
        }
        .onChange(of: model.rememberedPort) { _ in
            if !isEditingPort { portText = String(model.rememberedPort) }
        }
        .confirmationDialog(
            "Reset LAN proxy credentials?",
            isPresented: $confirmsReset,
            titleVisibility: .visible
        ) {
            Button("Reset Credentials", role: .destructive) {
                Task {
                    if await model.reset() {
                        password = ""
                        hydrateDraft(overwriteUsername: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sharing stops first. The saved username and password are then removed from this device.")
        }
    }

    private var actionSection: some View {
        Section {
             
             
             
             
             
            Button {
                Task {
                    if model.status.enabled {
                        _ = await model.stop()
                    } else {
                        await submit()
                    }
                }
            } label: {
                 
                 
                 
                 
                 
                Text(model.status.enabled ? "Stop Sharing" : "Start Sharing")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .hakoPrimaryActionButtonStyle()
            .hakoCapsuleButtonBorderShape()
            .controlSize(.regular)
            .tint(model.status.enabled ? .green : .blue)
            .disabled(model.phase == .unavailable || model.phase.isBusy)
            .accessibilityIdentifier("proxyShare.toggle")
            .accessibilityValue(model.phase.title)

            if model.phase.isBusy {
                HStack(spacing: HakoTheme.Spacing.row) {
                    ProgressView()
                    Text(model.phase.title)
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if !model.errorMessage.isEmpty {
                HakoStatusMessage(text: .copy(model.errorMessage), kind: .error)
                    .accessibilityIdentifier("proxyShare.error")
            }
        } footer: {
            Text(hako: .copy(actionExplanation))
        }
    }

    private var connectSection: some View {
        Section {
            if reachableAddresses.isEmpty {
                HakoStatusMessage(
                    text: .copy("No usable Wi-Fi or Personal Hotspot address is available."),
                    kind: .information
                )
            } else {
                ForEach(reachableAddresses, id: \.self) { address in
                    Text(ProxyShareEndpointFormatter.format(
                        address: address,
                        port: model.status.port
                    ))
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .subheadline.monospaced())
                    .textSelection(.enabled)
                }
            }
            OverviewValueRow(title: "Username", value: .verbatim(model.savedUsername))
        } header: {
            Text("Connect From Another Device")
        } footer: {
            Text("Point the other device at one address above, over HTTP or SOCKS5, with this username and its saved password.")
        }
    }

    private var serverSection: some View {
        Section {
             
             
             
             
             
            HakoFieldRow(
                "Port",
                hint: "7890",
                text: $portText,
                monospaced: true,
                identifier: "proxyShare.port"
            )
            .keyboardType(.numberPad)
            .disabled(inputsDisabled)

            HakoFieldRow(
                "Username",
                hint: "Required",
                text: $username,
                identifier: "proxyShare.username"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(inputsDisabled)

             
             
             
            HakoFieldRow(
                "Password",
                hint: ProxyShareCredentialPolicy.passwordByteRangeDescription,
                text: $password,
                secure: true,
                identifier: "proxyShare.password"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(inputsDisabled)
        } header: {
            Text("Server")
        } footer: {
            Text(hako: .copy(serverExplanation))
        }
    }

    private var securitySection: some View {
        Section {
             
             
             
             
             
            Button(role: .destructive) {
                confirmsReset = true
            } label: {
                Text("Reset Saved Credentials")
            }
             
             
            .hakoMacFormActionChrome()
            .disabled(model.phase.isBusy || !model.hasSavedPassword)
            .accessibilityIdentifier("proxyShare.reset")
        } header: {
            Text("Security")
        } footer: {
             
             
            Text("Only private, unique-local, and link-local source addresses are accepted. Sharing closes when the VPN stops, and credentials never enter profiles, backups, logs, or diagnostics.")
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private var profileListenerSection: some View {
        Section {
            Toggle(isOn: $permitsProfileLANListener) {
                Text("Let profiles listen on the local network")
            }
            .accessibilityIdentifier("proxyShare.allowLan")
             
             
             
             
             
            ForEach(lanExposureNotices, id: \.self) { notice in
                Label {
                    Text(hako: .verbatim(notice))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: HakoSymbol.exclamationmarkTriangleFill.rawValue)
                        .foregroundStyle(Color.orange)
                }
                .accessibilityIdentifier("proxyShare.lanExposure")
            }
        } header: {
            Text("Profile Listeners")
        } footer: {
             
             
             
             
             
            Text("Off unless you turn it on. A profile's allow-lan opens that profile's own listener on every interface — and unlike sharing above, a profile may set no password. Applies the next time the tunnel starts.")
        }
    }

     
     
     
     
    private var listenerDeviationsSection: some View {
        ConfigDeviationSection(
            report: deviations,
            fields: RunningCoreDeviations.fields(for: [.localProxyListeners]),
            identifierPrefix: "proxyShare.deviation"
        )
    }

     
     
     
     
     
     
     
     
    private var reachableAddresses: [String] {
        let dialable = model.localAddresses.filter { address in
            let value = address.lowercased()
            return !value.hasPrefix("169.254.")
                && !value.hasPrefix("fe80:")
                && !value.contains("%")
        }
        return dialable.isEmpty ? model.localAddresses : dialable
    }

    private var actionExplanation: String {
        switch model.phase {
        case .unavailable:
            return "Connect Clash to make the authenticated local proxy available."
        case .failed:
            return "The last change was not confirmed. The Core status will be checked again when this page refreshes."
        case .running:
            return "The VPN stays connected while sharing runs."
        default:
            return "Starting may ask for Local Network access; Clash cannot accept nearby devices without it."
        }
    }

    private var serverExplanation: String {
        if model.status.enabled {
            return "Stop sharing to change the port or credentials."
        }
         
         
         
        return "Both HTTP and SOCKS5 always require the same username and password. Enter the password each time you start sharing — you need to know it to type it into the other device."
    }

     
     
    private var inputsDisabled: Bool {
        model.phase == .unavailable
            || model.phase.isBusy
            || model.status.enabled
    }

    private var isEditingPort: Bool {
        portText != String(model.rememberedPort)
    }

    private func hydrateDraft(overwriteUsername: Bool) {
        if portText.isEmpty || !isEditingPort {
            portText = String(model.rememberedPort)
        }
        if overwriteUsername {
            username = model.savedUsername
        }
    }

    private func submit() async {
        let submittedPassword = password
        password = ""
        _ = await model.start(
            portText: portText,
            username: username,
            password: submittedPassword
        )
    }
}

struct OverviewMoreSettingsCard: View {
    @ObservedObject var proxyShare: ProxyShareModel

    var body: some View {
        HakoOverviewCard {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                OverviewCardHeader(
                    title: "More Settings",
                    symbol: .gearshape,
                    tint: .blue
                )

                HakoRoutedViewLink {
                    ProxyShareView(model: proxyShare)
                } label: {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        HakoIconWell(symbol: .network, tint: .green)
                        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                            Text("LAN Proxy Share")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("Authenticated HTTP and SOCKS5 for nearby devices")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        HakoStatusBadge(
                            title: proxyShare.phase == .running ? "On" : "Off",
                            tint: proxyShare.phase == .running ? .green : .gray
                        )
                        Image(systemName: HakoSymbol.chevronForward.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, HakoTheme.Spacing.tight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview.moreSettings.proxyShare")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.card.moreSettings")
    }
}


