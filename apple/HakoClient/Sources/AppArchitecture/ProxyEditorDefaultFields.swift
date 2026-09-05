import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorDefaultFields {
    static let keysByType: [String: [String]] = [
         
         
         
         
         
         
         
         
        "anytls": [
            "server", "port", "password", "udp",
            "idle-session-check-interval", "idle-session-timeout",
            "min-idle-session", "tfo", "mptcp", "ip-version",
             
             
             
        ],
         
        "gost-relay": ["server", "port", "username", "password", "tls", "mux", "sni", "udp"],
         
        "http": ["server", "port", "username", "password", "tls", "tfo"],
         
        "hysteria": ["server", "port", "auth-str", "obfs", "protocol", "fast-open", "up", "down"],
         
         
         
         
         
         
        "hysteria2": [
             
             
             
            "server", "port", "ports", "password", "obfs", "obfs-password",
            "up", "down", "hop-interval", "cwnd", "udp-mtu",
            "initial-stream-receive-window",
            "initial-connection-receive-window",
            "max-stream-receive-window", "max-connection-receive-window",
            "obfs-min-packet-size", "obfs-max-packet-size", "ip-version",
            "bbr-profile",
        ],
         
         
        "masque": ["server", "port", "private-key", "public-key", "ip", "dns", "mtu", "sni", "congestion-controller", "udp", "remote-dns-resolve"],
         
         
         
         
         
         
         
         
        "mieru": ["server", "port", "port-range", "username", "password", "transport", "udp"],
         
        "openvpn": ["server", "port", "ca", "username", "password", "proto", "cipher", "auth", "udp"],
         
        "shadowquic": ["server", "port", "username", "password", "sni", "congestion-controller", "up", "down"],
         
        "snell": ["server", "port", "psk", "version", "obfs-opts", "tfo", "udp"],
         
        "socks5": ["server", "port", "username", "password", "tls", "tfo", "udp"],
         
         
         
         
         
         
         
         
        "ss": ["server", "port", "password", "cipher", "plugin", "plugin-opts", "tfo", "udp", "udp-over-tcp"],
         
         
         
         
        "ssh": ["server", "port", "username", "password", "private-key", "host-key", "private-key-passphrase"],
         
        "ssr": ["server", "port", "password", "cipher", "protocol", "obfs", "tfo", "udp"],
         
        "sudoku": ["server", "port", "key", "aead-method", "table-type", "multiplex"],
         
        "tailscale": ["auth-key", "hostname", "exit-node", "accept-routes", "udp"],
         
        "trojan": ["server", "port", "password", "network", "sni", "tfo", "udp"],
         
        "trusttunnel": ["server", "port", "username", "password", "udp"],
         
        "tuic": ["server", "port", "uuid", "password", "token", "sni", "congestion-controller", "udp-relay-mode"],
         
        "vless": ["server", "port", "uuid", "encryption", "flow", "network", "tls", "tfo", "udp"],
         
        "vmess": ["server", "port", "uuid", "alterId", "cipher", "network", "tls", "tfo", "udp"],
         
         
         
         
        "wireguard": ["server", "port", "private-key", "public-key", "pre-shared-key", "ip", "dns", "mtu", "persistent-keepalive", "reserved", "udp", "remote-dns-resolve"],
    ]

    static func keys(for typeID: String) -> [String] {
        keysByType[typeID.lowercased()] ?? []
    }
}
