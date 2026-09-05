import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
enum AcknowledgementsCatalog {
     
     
     
     
     
     
    struct Highlight: Identifiable, Hashable {
        let module: String
        let role: String
        var id: String { module }
    }

     
     
     
     
     
     
     
     
     
     
    static let framework = Highlight(
        module: "github.com/TokenPLS/Hako",
        role: "The Apple framework this client links, and the only one it calls. Its licence covers this whole app."
    )

     
     
     
     
     
     
    static let highlights: [Highlight] = [
        Highlight(
            module: "github.com/metacubex/mihomo",
            role: "The upstream proxy kernel Hako is built on. Every rule, protocol and DNS decision is its work."
        ),
        Highlight(
            module: "github.com/metacubex/sing-tun",
            role: "The tun interface the tunnel is built on."
        ),
        Highlight(
            module: "github.com/metacubex/gvisor",
            role: "The userspace TCP/IP stack every connection is carried by."
        ),
        Highlight(
            module: "github.com/metacubex/sing",
            role: "The networking primitives the transports are written against."
        ),
        Highlight(
            module: "github.com/metacubex/quic-go",
            role: "QUIC, underneath Hysteria 2, TUIC and HTTP/3."
        ),
        Highlight(
            module: "github.com/metacubex/sing-quic",
            role: "Hysteria, Hysteria 2 and TUIC."
        ),
        Highlight(
            module: "github.com/metacubex/sing-shadowsocks",
            role: "Shadowsocks."
        ),
        Highlight(
            module: "github.com/metacubex/sing-vmess",
            role: "VMess and VLESS."
        ),
        Highlight(
            module: "github.com/metacubex/sing-wireguard",
            role: "WireGuard, with wireguard-go and amneziawg-go beneath it."
        ),
        Highlight(
            module: "github.com/metacubex/tailscale",
            role: "Tailscale."
        ),
        Highlight(
            module: "github.com/enfein/mieru/v3",
            role: "Mieru."
        ),
        Highlight(
            module: "github.com/metacubex/utls",
            role: "TLS handshakes that look like a browser's."
        ),
        Highlight(
            module: "github.com/miekg/dns",
            role: "Every DNS message this app reads or writes."
        ),
        Highlight(
            module: "github.com/oschwald/maxminddb-golang",
            role: "Reading the ASN and GeoIP databases."
        ),
        Highlight(
            module: "gopkg.in/yaml.v3",
            role: "Reading and writing your configuration."
        ),
        Highlight(
            module: "github.com/sagernet/gomobile",
            role: "The bridge that lets Swift call the core."
        ),
        Highlight(
            module: "MetaCubeX/meta-rules-dat",
            role: "The bundled geo databases and rule sets."
        ),
    ]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    struct SystemFramework: Identifiable, Hashable {
        let name: String
         
        let usage: String
        var id: String { name }
    }

    static let systemFrameworks: [SystemFramework] = [
        SystemFramework(
            name: "NetworkExtension",
            usage: "NEPacketTunnelProvider runs the tunnel, NETunnelProviderManager installs it, NEDNSSettingsManager installs the DNS-only profile."
        ),
        SystemFramework(
            name: "Network",
            usage: "NWPathMonitor, for what the device is actually connected to."
        ),
        SystemFramework(
            name: "SwiftUI, UIKit",
            usage: "Every screen in this app."
        ),
        SystemFramework(
            name: "Combine",
            usage: "Publishing connection and traffic state to those screens."
        ),
        SystemFramework(
            name: "CryptoKit",
            usage: "SHA-256 over bundled resources and downloaded providers."
        ),
        SystemFramework(
            name: "Security",
            usage: "The Keychain, holding the local proxy sharing credentials."
        ),
        SystemFramework(
            name: "JavaScriptCore",
            usage: "JSContext, running the main(config) script in your profile."
        ),
        SystemFramework(
            name: "BackgroundTasks",
            usage: "BGTaskScheduler, refreshing subscriptions while the app is away."
        ),
        SystemFramework(
            name: "WidgetKit, AppIntents",
            usage: "The Control Center control and the Shortcuts actions."
        ),
        SystemFramework(
            name: "AVFoundation, PhotosUI",
            usage: "AVCaptureSession and PHPickerViewController, for reading a subscription QR code."
        ),
        SystemFramework(
            name: "UniformTypeIdentifiers",
            usage: "Importing and exporting profiles as files."
        ),
        SystemFramework(
            name: "MetricKit",
            usage: "MXMetricManager, whose reports stay on the device."
        ),
    ]

     
     
     
     
     
     
     
     
     
     
     
    static let trademarkNotices: [String] = [
        "\"WireGuard\" and the \"WireGuard\" logo are registered trademarks of Jason A. Donenfeld.",
        "OpenVPN® is a registered trademark of OpenVPN Inc.",
        "Tailscale is a trademark of Tailscale Inc.",
         
         
         
         
         
        "Apple, SwiftUI, Face ID, iCloud, and App Store are trademarks of Apple Inc., registered in the U.S. and other countries and regions.",
    ]

     
    static let trademarkStatement =
        "These names appear here to identify the protocols the core implements and the system frameworks this app is built against. Clash is not affiliated with, endorsed by, or sponsored by their owners."

     
    static let sourceOfferStatement =
        "This app is free software under the GNU General Public License v3. The complete corresponding source for the core and everything linked into it is published, and every licence above is reproduced in full."
}
