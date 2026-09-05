import HakoClientUI
import Network
import NetworkExtension
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum DNSOnlyTransport: String, CaseIterable, Codable, Equatable, Identifiable {
    case https
    case tls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .https: return "DoH"
        case .tls: return "DoT"
        }
    }

    var longTitle: String {
        switch self {
        case .https: return "DNS over HTTPS"
        case .tls: return "DNS over TLS"
        }
    }
}

struct DNSOnlyConfiguration: Equatable {
    let transport: DNSOnlyTransport
    let servers: [String]
    let resolver: String

    static func validated(
        transport: DNSOnlyTransport,
        serversText: String,
        resolverText: String
    ) throws -> DNSOnlyConfiguration {
        let separators = CharacterSet(charactersIn: ",;\n\t ")
        var seen = Set<String>()
        let servers = serversText
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !servers.isEmpty else { throw DNSOnlyValidationError.missingServer }
        for server in servers where !isIPAddress(server) {
            throw DNSOnlyValidationError.invalidServer(server)
        }

        let resolver = resolverText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch transport {
        case .https:
            guard let components = URLComponents(string: resolver),
                  components.scheme?.lowercased() == "https",
                  let host = components.host, !host.isEmpty,
                  components.user == nil,
                  components.password == nil,
                  components.fragment == nil,
                  !components.path.isEmpty,
                  components.path != "/",
                  components.url != nil
            else { throw DNSOnlyValidationError.invalidHTTPSURL }
        case .tls:
            guard isValidCertificateName(resolver) else {
                throw DNSOnlyValidationError.invalidTLSServerName
            }
        }
        return DNSOnlyConfiguration(
            transport: transport,
            servers: servers,
            resolver: resolver
        )
    }

    var safeResolverDescription: String {
        switch transport {
        case .https: return SubscriptionURLPresentation.safeDescription(resolver)
        case .tls: return resolver
        }
    }

    func makeSystemSettings() -> NEDNSSettings {
        let settings: NEDNSSettings
        switch transport {
        case .https:
            let https = NEDNSOverHTTPSSettings(servers: servers)
            https.serverURL = URL(string: resolver)
            settings = https
        case .tls:
            let tls = NEDNSOverTLSSettings(servers: servers)
            tls.serverName = resolver
            settings = tls
        }
        if #available(iOS 26.0, macOS 26.0, *) {
            settings.allowFailover = false
        }
        return settings
    }

    private static func isIPAddress(_ value: String) -> Bool {
        IPv4Address(value) != nil || IPv6Address(value) != nil
    }

    private static func isValidCertificateName(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 253,
              !isIPAddress(value)
        else { return false }
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        return !labels.isEmpty && labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  label.first != "-",
                  label.last != "-"
            else { return false }
            return label.utf8.allSatisfy { byte in
                (byte >= 48 && byte <= 57)
                    || (byte >= 65 && byte <= 90)
                    || (byte >= 97 && byte <= 122)
                    || byte == 45
            }
        }
    }
}

 
 
 
struct DNSOnlyResolverChoice: Equatable, Identifiable {
    let preset: DNSResolverPreset
    let configuration: DNSOnlyConfiguration

    var id: String { preset.id }
}

enum DNSOnlyResolverCatalog {
    static let choices: [DNSOnlyResolverChoice] = DNSResolverCatalog.presets.compactMap {
        preset in
        guard let endpoint = DNSResolverProbe.endpoint(for: preset.address),
              !preset.bootstrapServers.isEmpty,
              preset.bootstrapServers.allSatisfy({
                  IPv4Address($0) != nil || IPv6Address($0) != nil
              })
        else { return nil }

        let transport: DNSOnlyTransport
        let resolver: String
        switch endpoint.transport {
        case .https:
            transport = .https
            resolver = preset.address
        case .tls:
            transport = .tls
            resolver = endpoint.host
        case .udp, .tcp, .quic:
            return nil
        }
        guard let configuration = try? DNSOnlyConfiguration.validated(
            transport: transport,
            serversText: preset.bootstrapServers.joined(separator: ", "),
            resolverText: resolver
        ) else { return nil }

        return DNSOnlyResolverChoice(preset: preset, configuration: configuration)
    }

    static func choice(for address: String) -> DNSOnlyResolverChoice? {
        choices.first { $0.preset.address == address }
    }
}

enum DNSOnlyValidationError: LocalizedError {
    case missingServer
    case invalidServer(String)
    case invalidHTTPSURL
    case invalidTLSServerName

    var errorDescription: String? {
        switch self {
        case .missingServer:
            return "Add at least one resolver IP address for secure bootstrap."
        case .invalidServer(let value):
            return "\(value) is not an IPv4 or IPv6 address. Resolver hostnames cannot bootstrap themselves."
        case .invalidHTTPSURL:
            return "Enter an HTTPS resolver URL with a path, without URL credentials or a fragment."
        case .invalidTLSServerName:
            return "Enter the DNS name used to validate the resolver's TLS certificate."
        }
    }
}

struct DNSOnlySystemSnapshot: Equatable {
    var isInstalled: Bool
    var isEnabled: Bool
    var configuration: DNSOnlyConfiguration?

    static let notInstalled = DNSOnlySystemSnapshot(
        isInstalled: false,
        isEnabled: false,
        configuration: nil
    )

    var statusText: String {
        if isEnabled { return "Enabled in Settings" }
         
         
         
        if isInstalled { return "Installed · choose Clash DNS in Settings" }
        return "Not installed"
    }
}

enum NetworkOperatingMode: String, Equatable {
    case packetTunnel
    case dnsOnly

    var title: String {
        switch self {
        case .packetTunnel: return "Packet Tunnel VPN"
        case .dnsOnly: return "DNS-only"
        }
    }
}

struct NetworkOperatingModeStore {
    static let key = "network.operatingMode"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = GlobalConfig.appGroupDefaults) {
        self.defaults = defaults
    }

    var current: NetworkOperatingMode {
        NetworkOperatingMode(rawValue: defaults.string(forKey: Self.key) ?? "")
            ?? .packetTunnel
    }

    func set(_ mode: NetworkOperatingMode) {
        defaults.set(mode.rawValue, forKey: Self.key)
    }
}

@MainActor
protocol DNSOnlySettingsManaging: AnyObject {
    func load() async throws -> DNSOnlySystemSnapshot
    func save(_ configuration: DNSOnlyConfiguration) async throws -> DNSOnlySystemSnapshot
    func remove() async throws -> DNSOnlySystemSnapshot
}

@MainActor
protocol DNSOnlyTunnelControlling: AnyObject {
    func suspendPacketTunnelForDNSOnly() async -> Bool
    func restorePacketTunnelAfterDNSOnly() async -> Bool
}

@MainActor
final class NativeDNSOnlySettingsManager: DNSOnlySettingsManaging {
     
     
    static let profileTitle = "Clash DNS"
    static let profileDescription = "Clash by Hako DNS"

    private let manager: NEDNSSettingsManager

    init(manager: NEDNSSettingsManager = .shared()) {
        self.manager = manager
    }

    func load() async throws -> DNSOnlySystemSnapshot {
        try await loadPreferences()
        return currentSnapshot()
    }

    func save(_ configuration: DNSOnlyConfiguration) async throws -> DNSOnlySystemSnapshot {
        try await loadPreferences()
        manager.localizedDescription = Self.profileTitle
        manager.dnsSettings = configuration.makeSystemSettings()
        manager.onDemandRules = nil
        try await savePreferences()
        try await loadPreferences()
        return currentSnapshot()
    }

    func remove() async throws -> DNSOnlySystemSnapshot {
        try await loadPreferences()
        if manager.dnsSettings != nil {
            let manager = manager
            try await VPNController.withNETimeout(
                seconds: Self.systemPreferenceLimit,
                .nePreferencesTimeout
            ) {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    manager.removeFromPreferences { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: ()) }
                    }
                }
            }
        }
        return .notInstalled
    }

     
     
     
     
     
    private static let systemPreferenceLimit: Double = 15

    private func loadPreferences() async throws {
        let manager = manager
        try await VPNController.withNETimeout(
            seconds: Self.systemPreferenceLimit,
            .nePreferencesTimeout
        ) {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                manager.loadFromPreferences { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: ()) }
                }
            }
        }
    }

    private func savePreferences() async throws {
        let manager = manager
        try await VPNController.withNETimeout(
            seconds: Self.systemPreferenceLimit,
            .nePreferencesTimeout
        ) {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                manager.saveToPreferences { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: ()) }
                }
            }
        }
    }

    private func currentSnapshot() -> DNSOnlySystemSnapshot {
        guard let settings = manager.dnsSettings else { return .notInstalled }
        let configuration: DNSOnlyConfiguration?
        if let https = settings as? NEDNSOverHTTPSSettings,
           let resolver = https.serverURL?.absoluteString {
            configuration = try? DNSOnlyConfiguration.validated(
                transport: .https,
                serversText: https.servers.joined(separator: ","),
                resolverText: resolver
            )
        } else if let tls = settings as? NEDNSOverTLSSettings,
                  let resolver = tls.serverName {
            configuration = try? DNSOnlyConfiguration.validated(
                transport: .tls,
                serversText: tls.servers.joined(separator: ","),
                resolverText: resolver
            )
        } else {
            configuration = nil
        }
        return DNSOnlySystemSnapshot(
            isInstalled: true,
            isEnabled: manager.isEnabled,
            configuration: configuration
        )
    }
}



@MainActor
enum DNSOnlySettingsManagerFactory {
    static func make() -> DNSOnlySettingsManaging {


        return NativeDNSOnlySettingsManager()
    }
}

@MainActor
final class DNSOnlySettingsViewModel: ObservableObject {
    @Published var transport: DNSOnlyTransport
    @Published var serversText: String
    @Published var resolverText: String
    @Published private(set) var snapshot = DNSOnlySystemSnapshot.notInstalled
    @Published private(set) var operatingMode: NetworkOperatingMode
    @Published private(set) var isBusy = false
    @Published private(set) var message = ""
    @Published private(set) var errorMessage = ""

    private let manager: DNSOnlySettingsManaging
    private let tunnel: DNSOnlyTunnelControlling
    private let modeStore: NetworkOperatingModeStore
    private var loadedDraft = false

    init(
        manager: DNSOnlySettingsManaging,
        tunnel: DNSOnlyTunnelControlling,
        modeStore: NetworkOperatingModeStore = NetworkOperatingModeStore(),
        transport: DNSOnlyTransport = .https,
        serversText: String = "",
        resolverText: String = ""
    ) {
        self.manager = manager
        self.tunnel = tunnel
        self.modeStore = modeStore
        self.transport = transport
        self.serversText = serversText
        self.resolverText = resolverText
        operatingMode = modeStore.current
        loadedDraft = !serversText.isEmpty || !resolverText.isEmpty
    }

    func applyResolverChoice(_ choice: DNSOnlyResolverChoice) {
        transport = choice.configuration.transport
        serversText = choice.configuration.servers.joined(separator: ", ")
        resolverText = choice.configuration.resolver
        loadedDraft = true
        message = ""
        errorMessage = ""
    }

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            snapshot = try await manager.load()
            operatingMode = modeStore.current
            if !loadedDraft, let configuration = snapshot.configuration {
                transport = configuration.transport
                serversText = configuration.servers.joined(separator: ", ")
                resolverText = configuration.resolver
                loadedDraft = true
            }
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func install() async {
        guard !isBusy else { return }
        isBusy = true
        message = ""
        errorMessage = ""
        defer { isBusy = false }
        do {
            let configuration = try DNSOnlyConfiguration.validated(
                transport: transport,
                serversText: serversText,
                resolverText: resolverText
            )
            guard await tunnel.suspendPacketTunnelForDNSOnly() else {
                throw DNSOnlyOperationError.packetTunnelCouldNotSuspend
            }
            do {
                snapshot = try await manager.save(configuration)
            } catch {
                _ = await tunnel.restorePacketTunnelAfterDNSOnly()
                throw error
            }
            modeStore.set(.dnsOnly)
            operatingMode = .dnsOnly
            loadedDraft = true
            message = snapshot.isEnabled
                ? "DNS-only is enabled. Packet Tunnel VPN remains disabled."
                : "Configuration installed. Enable Clash DNS in Settings to use DNS-only mode."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAndReturnToVPN() async {
        guard !isBusy else { return }
        isBusy = true
        message = ""
        errorMessage = ""
        defer { isBusy = false }
        do {
            snapshot = try await manager.remove()
            modeStore.set(.packetTunnel)
            operatingMode = .packetTunnel
            guard await tunnel.restorePacketTunnelAfterDNSOnly() else {
                throw DNSOnlyOperationError.packetTunnelCouldNotRestore
            }
            message = "Returned to VPN mode. The Packet Tunnel profile is available but was not started."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum DNSOnlyOperationError: LocalizedError {
    case packetTunnelCouldNotSuspend
    case packetTunnelCouldNotRestore

    var errorDescription: String? {
        switch self {
        case .packetTunnelCouldNotSuspend:
            return "The Packet Tunnel profile could not be suspended, so DNS-only was not installed."
        case .packetTunnelCouldNotRestore:
            return "DNS-only was removed, but the Packet Tunnel profile could not be restored. Start VPN to recreate it."
        }
    }
}

struct DNSOnlySettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var vpn: VPNController
    @StateObject private var model: DNSOnlySettingsViewModel
    @State private var addingResolver = false

    init(vpn: VPNController) {
        self.vpn = vpn
        let usesFixture = false
        _model = StateObject(wrappedValue: DNSOnlySettingsViewModel(
            manager: DNSOnlySettingsManagerFactory.make(),
            tunnel: vpn,
            transport: .https,
            serversText: usesFixture ? "1.1.1.1, 2606:4700:4700::1111" : "",
            resolverText: usesFixture ? "https://resolver.example.test/dns-query" : ""
        ))
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section("Status") {
                OverviewValueRow(title: "Clash Mode", value: .verbatim(model.operatingMode.title))
                    .accessibilityIdentifier("dnsOnly.mode")
                OverviewValueRow(title: "System DNS", value: .verbatim(model.snapshot.statusText))
                    .accessibilityIdentifier("dnsOnly.status")
                OverviewValueRow(title: "Packet Tunnel", value: .verbatim(vpn.status.capitalized))
                if let configuration = model.snapshot.configuration {
                    OverviewValueRow(
                        title: "Installed Resolver",
                        value: .verbatim("\(configuration.transport.title) · \(configuration.safeResolverDescription)")
                    )
                }
            }

            Section {
                Button {
                    addingResolver = true
                } label: {
                    Label(
                        HakoCopy.key("Add Resolver"),
                        systemImage: HakoSymbol.plus.name
                    )
                }
                .hakoMacListAddChrome()
                .accessibilityIdentifier("dnsOnly.addResolver")
                .sheet(isPresented: $addingResolver) {
                    HakoDNSResolverCatalogPicker(
                        existing: model.resolverText.isEmpty
                            ? []
                            : [model.resolverText],
                        presets:
                            DNSOnlyResolverCatalog.choices.map(
                                \.preset
                            ),
                        allowsCustomAddress: false,
                        capabilities: HakoDNSCapabilities(
                            probe: {
                                await DNSResolverReachability
                                    .shared.probe($0)
                            },
                            resolverSummary: {
                                DNSResolverProbe.endpoint(
                                    for: $0
                                )?.protocolLabel
                            },
                            resolverRejectionReason: {
                                DNSServerValidator
                                    .rejectionReason($0)
                            },
                            isResolverTestable: {
                                DNSResolverProbe
                                    .untestableReason(
                                        for: $0
                                    ) == nil
                            }
                        ),
                        icon: {
                            HakoSymbolImage(symbol: $0)
                        }
                    ) { address in
                        guard let choice = DNSOnlyResolverCatalog.choice(for: address) else {
                            return
                        }
                        model.applyResolverChoice(choice)
                    }
                    .hakoModalPresentation(.page)
                }

                Picker("Transport", selection: $model.transport) {
                    ForEach(DNSOnlyTransport.allCases) { transport in
                        Text(hako: .copy(transport.title)).tag(transport)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("dnsOnly.transport")

                hakoPromptField(
                    "Resolver IP addresses",
                    text: $model.serversText
                )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("dnsOnly.servers")

                hakoPromptField(
                    model.transport == .https
                        ? "https://resolver.example/dns-query"
                        : "resolver.example",
                    text: $model.resolverText
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(model.transport == .https ? .URL : .asciiCapable)
                .font(.body.monospaced())
                .accessibilityIdentifier("dnsOnly.resolver")
            } header: {
                Text("Encrypted Resolver")
            } footer: {
                Text("Resolver IPs bootstrap the encrypted connection without asking the current system DNS. DoH URLs may include a provider path or query; Clash never copies them into diagnostics or backups.")
            }

            Section {
                Button {
                    Task { await model.install() }
                } label: {
                    Label(
                        model.snapshot.isInstalled
                            ? "Replace DNS Configuration"
                            : "Install DNS Configuration",
                        systemImage: HakoSymbol.checkmarkShieldFill.name
                    )
                }
                .hakoMacFormActionChrome()
                .disabled(model.isBusy)
                .accessibilityIdentifier("dnsOnly.install")

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh System Status", systemImage: HakoSymbol.arrowClockwise.name)
                }
                .hakoMacFormActionChrome()
                .disabled(model.isBusy)
                .accessibilityIdentifier("dnsOnly.refresh")


                if model.snapshot.isInstalled || model.operatingMode == .dnsOnly {
                    Button(role: .destructive) {
                        Task { await model.removeAndReturnToVPN() }
                    } label: {
                        Label(
                            "Remove DNS & Return to VPN",
                            systemImage: HakoSymbol.arrowUturnBackward.name
                        )
                    }
                    .hakoMacFormActionChrome()
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("dnsOnly.remove")
                }
            } footer: {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                Text("Apple requires the saved DNS configuration to be enabled by you in Settings, and Clash cannot enable it silently. Open Settings yourself and go to General → VPN, DNS & Device Management → DNS, then choose Clash DNS instead of Automatic.")
            }

            if model.isBusy {
                Section { ProgressView("Updating system configuration…") }
            }
            if !model.message.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(model.message), kind: .success)
                        .accessibilityIdentifier("dnsOnly.message")
                }
            }
            if !model.errorMessage.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(model.errorMessage), kind: .error)
                        .accessibilityIdentifier("dnsOnly.error")
                }
            }

            Section("What DNS-only Does") {
                HakoStatusMessage(
                    text: "DNS-only encrypts name lookups. It does not start the core, proxy app traffic, apply proxy rules, or change IP routes.",
                    kind: .information
                )
                Text(hako: .copy(failoverExplanation))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dnsOnly.failover")
                 
                 
                 
                Text("While the VPN is connected the tunnel resolves every name itself, so this configuration is installed but not in use. Turn the VPN off to let it take over.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dnsOnly.tunnelWins")
                Text("The resolver IPs above only open the encrypted connection. A ping or lookup tool reads the network's own DNS list, which this does not rewrite, so it will keep naming that server even while lookups go elsewhere. Ask the resolver instead — most publish a page that says whether you are using it.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dnsOnly.howToVerify")
            }
        }
        
        .hakoPageTitle("DNS-only")
        .onAppear { Task { await model.refresh() } }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }

    private var failoverExplanation: String {
        if #available(iOS 26.0, *) {
             
             
            return "Clash explicitly disables fallback to the default system resolver."
        }
        return "iOS 15–25 does not expose resolver failover control to this API. Use Packet Tunnel VPN when fail-closed DNS is required."
    }

}


