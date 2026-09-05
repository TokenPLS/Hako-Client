import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVProxyShareScreen: View {
    @Binding var state: HakoTVProductState
    @ObservedObject var tunnel: HakoTVTunnelController
    @StateObject private var model: ProxyShareModel
    @State private var command: HakoTVProxyShareCommand?
    @State private var portText = ""
    @State private var username = ""
    @State private var password = ""
    @State private var permitsProfileListener = false
    @State private var lanExposureNotices: [String] = []
    @State private var explained: Explained = .profile
    private let permissionDefaults: UserDefaults?

    private enum Explained { case profile, share }

    init(
        state: Binding<HakoTVProductState>,
        tunnel: HakoTVTunnelController,
        model: ProxyShareModel? = nil,
        permissionDefaults: UserDefaults? = UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
    ) {
        _state = state
        self.tunnel = tunnel
        self.permissionDefaults = permissionDefaults
        _model = StateObject(wrappedValue: MainActor.assumeIsolated { model ?? ProxyShareModel() })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Profile listeners")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                Toggle(isOn: $permitsProfileListener) {
                    Text("Let profiles listen on the local network")
                }
                 
                 
                 
                .disabled(!HakoTVProxySharePresentation.permissionIsWritable(permissionDefaults))
                .onHakoTVFocus { explained = .profile }
                .accessibilityIdentifier("tvos.proxyShare.allowLan")

                Text("Share with a username and password")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                Button(model.status.enabled ? "Stop sharing" : "Start sharing") {
                    Task {
                        if model.status.enabled {
                            await model.stop()
                        } else {
                            let submitted = password
                            password = ""
                            await model.start(portText: portText, username: username, password: submitted)
                        }
                    }
                }
                .disabled(model.phase.isBusy || model.phase == .unavailable)
                .onHakoTVFocus { explained = .share }
                .accessibilityIdentifier("tvos.proxyShare.toggle")
                TextField("Port", text: $portText)
                    .keyboardType(.numberPad)
                    .disabled(model.status.enabled)
                    .onHakoTVFocus { explained = .share }
                    .accessibilityIdentifier("tvos.proxyShare.port")
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .disabled(model.status.enabled)
                    .onHakoTVFocus { explained = .share }
                    .accessibilityIdentifier("tvos.proxyShare.username")
                 
                 
                 
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .disabled(model.status.enabled)
                    .onHakoTVFocus { explained = .share }
                    .accessibilityIdentifier("tvos.proxyShare.password")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, 44)

            VStack(alignment: .leading, spacing: 20) {
                switch explained {
                case .profile:
                    Text(HakoTVProxySharePresentation.profileListenerExplanation)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("tvos.proxyShare.profileExplanation")
                     
                    ForEach(lanExposureNotices, id: \.self) { notice in
                        Text(notice)
                            .font(.body)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("tvos.proxyShare.lanExposure")
                case .share:
                    Text(HakoTVProxySharePresentation.sentence(for: model.phase))
                        .font(.title2)
                        .accessibilityIdentifier("tvos.proxyShare.state")
                    if model.status.enabled {
                        Text("Point the other device's proxy at one of these addresses:")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(
                                HakoTVProxySharePresentation.addressLines(model.localAddresses, port: model.status.port),
                                id: \.self
                            ) { line in
                                Text(line)
                                    .font(.title3)
                                    .monospaced()
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("tvos.proxyShare.address")
                        Text("HTTP and SOCKS5 · username and password required")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    if !model.errorMessage.isEmpty {
                         
                         
                        Text(model.errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("tvos.proxyShare.error")
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, 44)
            .animation(.easeOut(duration: 0.18), value: explained)
        }
        .navigationTitle("Share on this network")
        .task {
            permitsProfileListener = LocalNetworkPermission.isPermitted(permissionDefaults)
            lanExposureNotices = CoreLogExcerpt.lanExposureNotices()
            portText = String(model.rememberedPort)
            username = model.savedUsername
            let wire = HakoTVProxyShareCommand(
                send: { [tunnel] message in try await tunnel.sendProxyShare(message) },
                isConnected: { [tunnel] in tunnel.state.isConnected }
            )
            command = wire
            model.bind(command: wire)
            await model.refresh()
        }
        .onChange(of: permitsProfileListener) { _, permitted in
            guard HakoTVProxySharePresentation.permissionIsWritable(permissionDefaults) else {
                permitsProfileListener = false
                return
            }
            LocalNetworkPermission.setPermitted(permitted, in: permissionDefaults)
        }
        .onChange(of: state.isConnected) { _, _ in
            lanExposureNotices = CoreLogExcerpt.lanExposureNotices()
            guard let command else { return }
            model.updateAPIAvailability(command.proxyShareAPIReady)
            Task { await model.refresh() }
        }
    }
}

 
enum HakoTVProxySharePresentation {
     
     
    static func sentence(for phase: ProxySharePhase) -> String {
        switch phase {
        case .unavailable: String(localized: "Connect the tunnel first. Sharing runs inside it.")
        case .loading: String(localized: "Checking…")
        case .disabled: String(localized: "Not sharing.")
        case .starting: String(localized: "Starting…")
        case .running: String(localized: "Sharing on this network.")
        case .stopping: String(localized: "Stopping…")
        case .failed: String(localized: "Sharing did not start.")
        }
    }

     
     
    static var profileListenerExplanation: String {
        String(localized: "Off unless you turn it on. A profile that sets allow-lan opens its own listener on every interface, on the port and with the username and password the profile names — nothing to type here. A profile may set no password. Applies the next time the tunnel connects.")
    }

     
     
     
    static func addressLines(_ addresses: [String], port: Int32) -> [String] {
        addresses.map { address in
            address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"
        }
    }

     
     
    static func permissionIsWritable(_ defaults: UserDefaults?) -> Bool {
        defaults != nil
    }

     
    static func rowValue(permitted: Bool) -> String {
        permitted ? String(localized: "On") : String(localized: "Off")
    }
}
