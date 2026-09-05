import Hako
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVMoreHub: View {
    enum Row: Hashable, CaseIterable {
        case autoConnect
        case dns
        case userAgent
        case proxyShare
        case diagnostics
        case geodata
        case version

        var title: String {
            switch self {
            case .autoConnect: String(localized: "Connect automatically")
            case .dns: String(localized: "DNS")
            case .userAgent: String(localized: "User-Agent")
            case .proxyShare: String(localized: "Share on this network")
            case .diagnostics: String(localized: "Diagnostics")
            case .geodata: String(localized: "Geo data")
            case .version: String(localized: "Version")
            }
        }

         
         
         
         
         
         
        var identifier: String {
            switch self {
            case .autoConnect: "autoConnect"
            case .dns: "dns"
            case .userAgent: "userAgent"
            case .proxyShare: "proxyShare"
            case .diagnostics: "diagnostics"
            case .geodata: "geodata"
            case .version: "version"
            }
        }

        var explanation: String {
            switch self {
            case .autoConnect:
                String(localized: "When the Apple TV is on and has a network, the tunnel comes up by itself — no need to open this app first. STOP does not turn this off: it only stops the tunnel until the next Connect, which arms it again.")
            case .dns:
                String(localized: "The tunnel's own resolvers, as the profile names them. Not a system DNS setting — an Apple TV has none to change; the policy editor stays on your phone.")
            case .userAgent:
                String(localized: "The name this app gives when it downloads a profile or a provider. Panels read it to decide which format to hand back, so Clash — the core's own name — is the one to keep unless a panel of yours answers better to another client.")
            case .proxyShare:
                String(localized: "Let other devices on your network use this Apple TV as their HTTP or SOCKS5 proxy, with the port, username and password your profile names. The tunnel has to be running.")
            case .diagnostics:
                String(localized: "Read-only status of the running tunnel: whether it is up, what it is using, and what it has loaded.")
            case .geodata:
                String(localized: "Which copy of the GeoIP and GeoSite databases the tunnel is using.")
            case .version:
                String(localized: "The app version and build, for a support report.")
            }
        }

         
        var isDoor: Bool {
            switch self {
            case .dns, .userAgent, .proxyShare, .diagnostics: true
            case .autoConnect, .geodata, .version: false
            }
        }
    }

    enum Door: Hashable { case dns, userAgent, proxyShare, diagnostics }

     
     
    static func userAgentValue(defaults: UserDefaults = ClientUserAgent.appGroupDefaults) -> String {
        ClientUserAgent.preset(from: defaults).label
    }

     
     
    static func proxyShareValue(defaults: UserDefaults? = UserDefaults(suiteName: HakoAppIdentifiers.appGroup)) -> String {
        HakoTVProxySharePresentation.rowValue(permitted: LocalNetworkPermission.isPermitted(defaults))
    }

    @Binding var state: HakoTVProductState
    @Binding var opened: Door?
     
     
     
     
    var onAutoConnect: (Bool) -> Void = { _ in }

     
     
    @State private var explained: Row = .autoConnect

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            List {
                Section("Network") {
                     
                     
                     
                     
                     
                     
                     
                    Toggle(isOn: Binding(
                        get: { state.autoConnect },
                        set: { wanted in
                            state.autoConnect = wanted
                            onAutoConnect(wanted)
                        }
                    )) {
                        Text(Row.autoConnect.title)
                    }
                    .onHakoTVFocus { explained = .autoConnect }
                    .accessibilityIdentifier("tvos.more.\(Row.autoConnect.identifier)")
                    row(.dns, value: Self.dnsValue(state)) { opened = .dns }
                    row(.userAgent, value: Self.userAgentValue()) { opened = .userAgent }
                    row(.proxyShare, value: Self.proxyShareValue()) { opened = .proxyShare }
                }
                Section("System") {
                    row(.diagnostics, value: "") { opened = .diagnostics }
                    row(.geodata, value: state.geodataSource.localizedForTelevision) {}
                }
                Section("About") {
                    row(.version, value: Self.version(from: .main)) {}
                }
            }
            .listStyle(.grouped)
            .safeAreaPadding(.horizontal, 44)
            .frame(maxWidth: .infinity)

            ZStack {
                if explained == .version {
                     
                     
                     
                     
                     
                     
                     
                     
                    about
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(explained.title)
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.tertiary)
                        Text(Self.explanation(for: explained, state: state))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.18), value: explained)
        }
         
    }

     
     
     
     
    private var about: some View {
        VStack(spacing: 12) {
            HakoTVBrandMark(width: HakoTVBrandMark.aboutWidth)
                .padding(.bottom, 20)
            Text("Clash")
                .font(.title2)
            Text("Powered by Hako")
                .font(.body)
                .foregroundStyle(.secondary)
            Text(Self.versionLine(from: .main))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(Self.coreVersionLine(Self.coreVersion()))
                .font(.body.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tvos.more.about")
    }

    private func row(_ row: Row, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent(row.title, value: value)
        }
        .onHakoTVFocus { explained = row }
        .accessibilityIdentifier("tvos.more.\(row.identifier)")
    }

     

     
     
    static func explanation(for row: Row, state: HakoTVProductState) -> String {
        if row == .autoConnect, let issue = state.autoConnectIssue { return issue }
        return row.explanation
    }

     
     
    static func dnsValue(_ state: HakoTVProductState) -> String {
        String(localized: "\(state.dnsNameservers.count) resolvers · \(state.dnsEnhancedMode)")
    }

     
    static func versionLine(from bundle: Bundle) -> String {
        String(localized: "Version \(version(from: bundle))")
    }

     
     
     
     
     
     
     
     
    static func coreVersionLine(_ version: String) -> String {
        "Hako \(version.isEmpty ? "—" : version)"
    }

     
     
     
     
     
     
     
    static func coreVersion() -> String {
        HakoVersion()
    }

     
    static func version(from bundle: Bundle) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }
}
