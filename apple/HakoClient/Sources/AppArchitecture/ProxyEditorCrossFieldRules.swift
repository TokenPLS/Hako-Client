import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorCrossFieldRules {
    struct Violation: Equatable {
         
        let message: String
         
        let key: String
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func violations(
        typeID: String,
        value: (String) -> String,
        nested: (String, String) -> String,
        hasObject: (String) -> Bool = { _ in false },
        list: (String) -> [String] = { _ in [] },
        elementLists: (String, String) -> [[String]] = { _, _ in [] }
    ) -> [Violation] {
        var found: [Violation] = []

         
         
         
        let securityContainers = [
            "reality-opts", "shadow-tls-opts", "restls-opts", "jls-opts",
            "tlsmirror-opts",
        ]
        let configuredSecurity = securityContainers.filter { hasObject($0) }

         
         
         
        if ["vmess", "vless"].contains(typeID),
           !configuredSecurity.isEmpty,
           value("tls") != "true" {
            found.append(Violation(
                message: "This security layer needs TLS. Turn TLS on, or remove the layer.",
                key: "tls"
            ))
        }

         
         
         
        if typeID == "vmess", ["kcp", "mkcp"].contains(value("network")) {
            let tcpOnly = ["shadow-tls-opts", "restls-opts", "jls-opts"]
            if let container = tcpOnly.first(where: { hasObject($0) }) {
                found.append(Violation(
                    message: "This security layer needs a TCP transport. Change the network, or remove the layer.",
                    key: container
                ))
            }
        }

         
         
        if ["trojan", "anytls", "vmess", "vless"].contains(typeID),
           configuredSecurity.count > 1 {
            found.append(Violation(
                message: "Only one security layer can be used at a time. Remove the others.",
                key: configuredSecurity[1]
            ))
        }

         
         
         
        for (container, keys) in [
            ("reality-opts", ["public-key"]),
            ("jls-opts", ["username", "password"]),
        ] where hasObject(container) {
            if keys.contains(where: { nested(container, $0).isEmpty }) {
                found.append(Violation(
                    message: "This security layer is missing something it needs. Open its options and fill in every row.",
                    key: container
                ))
            }
        }

         
         
        if typeID == "trojan",
           nested("ss-opts", "enabled") == "true",
           nested("ss-opts", "password").isEmpty {
            found.append(Violation(
                message: "The Shadowsocks layer needs a password. Set one, or turn the layer off.",
                key: "ss-opts"
            ))
        }

         
         
         
         
         
         
         
        let keypairIsTLS = !["ssh", "wireguard", "masque"].contains(typeID)
        if keypairIsTLS,
           !value("certificate").isEmpty != !value("private-key").isEmpty {
            found.append(Violation(
                message: "A client certificate needs its private key. Set both, or clear both.",
                key: value("certificate").isEmpty ? "certificate" : "private-key"
            ))
        }

         
         
         
        if typeID == "openvpn" {
            let cert = value("cert"), key = value("key")
            if !cert.isEmpty != !key.isEmpty {
                found.append(Violation(
                    message: "OpenVPN needs the certificate and its key together. Set both, or clear both.",
                    key: cert.isEmpty ? "cert" : "key"
                ))
            } else if cert.isEmpty, value("username").isEmpty {
                found.append(Violation(
                     
                     
                     
                    message: "OpenVPN needs either a certificate and key, or a username.",
                    key: "username"
                ))
            }
        }

         
         
         
         
         
        if typeID == "trusttunnel" {
            let alpn = list("alpn")
            let usesQUIC = value("quic") == "true"
            let required = usesQUIC ? "h3" : "h2"
            if !alpn.isEmpty, !alpn.contains(required) {
                found.append(Violation(
                    message: usesQUIC
                        ? "With QUIC on, this proxy needs h3 among its ALPN protocols. Add it, or clear the list."
                        : "This proxy needs h2 among its ALPN protocols. Add it, clear the list, or turn QUIC on.",
                    key: "alpn"
                ))
            }
        }

         
        if typeID == "sudoku",
           let low = Int(value("padding-min")), let high = Int(value("padding-max")),
           high < low {
            found.append(Violation(
                message: "The maximum padding cannot be smaller than the minimum.",
                key: "padding-max"
            ))
        }

         
         
         
        if typeID == "sudoku", hasObject("httpmask"),
           !value("http-mask-mode").isEmpty || !value("http-mask-host").isEmpty {
            found.append(Violation(
                message: "The HTTP mask options replace the separate HTTP mask rows. Use one or the other.",
                key: "httpmask"
            ))
        }

         
         
        if typeID == "hysteria2",
           !value("obfs").isEmpty,
           value("obfs-password").isEmpty {
            found.append(Violation(
                message: "Obfuscation needs its password. Set one, or clear the obfuscation.",
                key: "obfs-password"
            ))
        }

         
         
        if typeID == "snell", value("udp") == "true" {
            let version = Int(value("version")) ?? 1
            if version < 3 {
                found.append(Violation(
                    message: "Snell carries UDP from version 3. Raise the version, or turn UDP off.",
                    key: "version"
                ))
            }
        }

         
         
         
        if typeID == "hysteria2",
           value("port").isEmpty, value("ports").isEmpty {
            found.append(Violation(
                message: "Hysteria 2 needs a port, or a port range to hop across.",
                key: "port"
            ))
        }

         
         
         
        if typeID == "wireguard", value("public-key").isEmpty,
           list("peers").isEmpty {
            found.append(Violation(
                message: "WireGuard needs the peer's public key.",
                key: "public-key"
            ))
        }

         
         
        if typeID == "masque", value("network") != "h3-l4proxy",
           value("ip").isEmpty, value("ipv6").isEmpty {
            found.append(Violation(
                message: "MASQUE needs a local address. Give it an IPv4 address or an IPv6 address.",
                key: "ip"
            ))
        }

         
         
        if typeID == "gost-relay", value("port").isEmpty {
            found.append(Violation(
                message: "This proxy needs a port.", key: "port"
            ))
        }

         
         
        if typeID == "openvpn",
           !value("tls-auth").isEmpty, !value("tls-crypt").isEmpty {
            found.append(Violation(
                message: "OpenVPN takes tls-auth or tls-crypt, not both. Clear one of them.",
                key: "tls-crypt"
            ))
        }

         
         
        if typeID == "openvpn", !value("tls-crypt-v2").isEmpty,
           !value("tls-auth").isEmpty || !value("tls-crypt").isEmpty {
            found.append(Violation(
                message: "OpenVPN takes tls-crypt-v2 on its own. Clear tls-auth and tls-crypt.",
                key: "tls-crypt-v2"
            ))
        }

         
         
        if typeID == "ssh",
           !value("private-key-passphrase").isEmpty,
           value("private-key").isEmpty {
            found.append(Violation(
                message: "A passphrase needs the private key it unlocks.",
                key: "private-key"
            ))
        }

         
        if typeID == "masque", let timeout = Int(value("handshake-timeout")),
           timeout < 0 {
            found.append(Violation(
                message: "The handshake timeout cannot be negative.",
                key: "handshake-timeout"
            ))
        }

         
        if typeID == "wireguard" {
            let reserved = list("reserved").joined(separator: ",")
            if !reserved.isEmpty {
                let parts = reserved
                    .split(whereSeparator: { ",[] ".contains($0) })
                    .filter { !$0.isEmpty }
                if parts.count != 3 {
                    found.append(Violation(
                        message: "Reserved takes exactly three bytes.",
                        key: "reserved"
                    ))
                }
            }
        }

         
         
         
        if typeID == "hysteria2" {
            let low = Int(value("obfs-min-packet-size")) ?? 0
            let high = Int(value("obfs-max-packet-size")) ?? 0
            if (low > 0 || high > 0), low <= 0 || high < low {
                found.append(Violation(
                    message: "The obfuscation packet sizes need a positive minimum and a maximum no smaller than it.",
                    key: "obfs-max-packet-size"
                ))
            }
        }

         
         
         
        if typeID == "wireguard" {
            let allowed = elementLists("peers", "allowed-ips")
            if allowed.contains(where: { $0.isEmpty }) {
                found.append(Violation(
                    message: "Every WireGuard peer needs its allowed IPs. Fill them in, or remove the peer.",
                    key: "peers"
                ))
            }
            let reserved = elementLists("peers", "reserved")
            if reserved.contains(where: { !$0.isEmpty && $0.count != 3 }) {
                found.append(Violation(
                    message: "A WireGuard peer's reserved value is exactly three bytes. Give it three, or clear it.",
                    key: "peers"
                ))
            }
        }

         
         
         
         
         
        if typeID == "wireguard",
           value("ip").isEmpty, value("ipv6").isEmpty {
            found.append(Violation(
                message: "WireGuard needs a local address. Give it an IPv4 address, an IPv6 address, or both.",
                key: "ip"
            ))
        }

         
         
         
        if typeID == "ss", !value("plugin").isEmpty {
            let mode = nested("plugin-opts", "mode")
            let expected: [String]
            switch value("plugin") {
            case "obfs": expected = ["tls", "http"]
            case "v2ray-plugin", "gost-plugin": expected = ["websocket"]
            default: expected = []
            }
            if !expected.isEmpty, !expected.contains(mode) {
                found.append(Violation(
                    message: mode.isEmpty
                        ? "This plugin needs a mode. Open Plugin Options and choose one."
                        : "This plugin does not run in that mode. Open Plugin Options and choose another.",
                    key: "plugin-opts"
                ))
            }
            found.append(contentsOf: obfsRequirements(
                dialect: value("plugin"),
                container: "plugin-opts",
                nested: nested
            ))
        }

         
         
         
        if typeID == "snell" {
            found.append(contentsOf: obfsRequirements(
                dialect: nested("obfs-opts", "mode"),
                container: "obfs-opts",
                nested: nested
            ))
        }

         
         
         
         
         

         
         
         
         
         
        if typeID == "mieru" {
            let port = value("port")
            let range = value("port-range")
            if port.isEmpty, range.isEmpty {
                found.append(Violation(
                    message: "Mieru needs a port or a port range. Fill in one of them.",
                    key: "port"
                ))
            } else if !port.isEmpty, !range.isEmpty {
                found.append(Violation(
                    message: "Mieru takes a port or a port range, not both. Clear one of them.",
                    key: "port-range"
                ))
            }
        }

        return found
    }

     
     
     
     
     
    private static func obfsRequirements(
        dialect: String,
        container: String,
        nested: (String, String) -> String
    ) -> [Violation] {
         
         
         
         
        let required: [String]
        let message: String
        switch dialect {
         
        case "shadow-tls":
            required = ["host"]
            message = "Shadow-TLS needs a host. Open the obfuscation options and fill it in."
         
        case "restls":
            required = ["password", "host", "version-hint"]
            message = "RESTLS needs a password, a host and a version hint. Open the obfuscation options and fill them in."
         
        case "jls":
            required = ["host", "username", "password"]
            message = "JLS needs a host, a username and a password. Open the obfuscation options and fill them in."
        default:
            return []
        }
        guard required.contains(where: { nested(container, $0).isEmpty })
        else { return [] }
        return [Violation(message: message, key: container)]
    }
}
