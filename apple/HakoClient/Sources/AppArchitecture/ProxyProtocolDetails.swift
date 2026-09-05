import Foundation

struct ProxyProtocolDetailRow: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case text
        case privateText
        case secret
        case toggle
    }

    let label: String
    let value: String
    let kind: Kind
     
     
     
     
    let key: String?

    init(label: String, value: String, kind: Kind = .text, key: String? = nil) {
        self.label = label
        self.value = value
        self.kind = kind
        self.key = key
    }

    var id: String { label }

    var searchableValue: String {
        switch kind {
        case .privateText, .secret:
            return "Configured"
        case .text, .toggle:
            return value
        }
    }
}

struct ProxyProtocolDetailSection: Equatable, Identifiable, Sendable {
    let title: String
    let rows: [ProxyProtocolDetailRow]

    var id: String { title }
}

struct ProxyProtocolDetails: Equatable, Sendable {
    let typeID: String
    let displayName: String
    let summary: String
    let sections: [ProxyProtocolDetailSection]
     
     
     
    let configurationJSON: String

    var visibleText: String {
        ([displayName, summary] + sections.flatMap { section in
            [section.title] + section.rows.flatMap { [$0.label, $0.searchableValue] }
        }).joined(separator: " ")
    }
}

struct ProxyProtocolSpecification: Equatable, Sendable {
    let typeID: String
    let displayName: String
    let summary: String
    let aliases: [String]
}

 
 
 
enum ProxyProtocolCatalog {
    static let formalTypeIDs = [
        "ss", "ssr", "socks5", "http", "vmess", "vless", "snell",
        "trojan", "hysteria", "hysteria2", "wireguard", "tuic",
        "gost-relay", "direct", "dns", "reject", "rematch", "ssh",
        "mieru", "anytls", "sudoku", "masque", "trusttunnel",
        "openvpn", "tailscale", "shadowquic", "zerotier",
    ]

    static let specifications: [ProxyProtocolSpecification] = [
        .init(typeID: "ss", displayName: "Shadowsocks", summary: "Encrypted TCP and UDP proxy using a selected Shadowsocks cipher.", aliases: ["shadowsocks"]),
        .init(typeID: "ssr", displayName: "ShadowsocksR", summary: "Legacy ShadowsocksR outbound with protocol and obfuscation layers.", aliases: ["shadowsocksr"]),
        .init(typeID: "socks5", displayName: "SOCKS5", summary: "SOCKS5 upstream with optional authentication, TLS, and UDP relay.", aliases: ["socks"]),
        .init(typeID: "http", displayName: "HTTP", summary: "HTTP CONNECT upstream with optional authentication and TLS.", aliases: ["http proxy"]),
        .init(typeID: "vmess", displayName: "VMess", summary: "VMess outbound with selectable transport, TLS, Reality, and packet modes.", aliases: []),
        .init(typeID: "vless", displayName: "VLESS", summary: "VLESS outbound with flow, transport, TLS, Reality, and packet modes.", aliases: []),
        .init(typeID: "snell", displayName: "Snell", summary: "Snell encrypted proxy with versioned protocol and optional obfuscation.", aliases: []),
        .init(typeID: "trojan", displayName: "Trojan", summary: "TLS-oriented Trojan proxy with optional WebSocket or gRPC transport.", aliases: []),
        .init(typeID: "hysteria", displayName: "Hysteria", summary: "QUIC-based Hysteria v1 outbound with bandwidth and receive-window tuning.", aliases: ["hysteria1"]),
        .init(typeID: "hysteria2", displayName: "Hysteria 2", summary: "Hysteria v2 QUIC outbound with port hopping, obfuscation, and congestion tuning.", aliases: ["hy2", "hysteria 2"]),
        .init(typeID: "wireguard", displayName: "WireGuard", summary: "WireGuard tunnel outbound with one or more peers and optional remote DNS.", aliases: ["wire guard"]),
        .init(typeID: "tuic", displayName: "TUIC", summary: "QUIC-based TUIC outbound with UDP relay and congestion-control options.", aliases: []),
        .init(typeID: "gost-relay", displayName: "GOST Relay", summary: "GOST-compatible relay outbound with optional TLS, multiplexing, and UDP.", aliases: ["gost relay", "gostrelay"]),
        .init(typeID: "direct", displayName: "Direct", summary: "Sends traffic directly to its destination without a proxy server.", aliases: ["direct connection"]),
        .init(typeID: "dns", displayName: "DNS", summary: "Routes matched DNS traffic through the core's DNS outbound.", aliases: []),
        .init(typeID: "reject", displayName: "Reject", summary: "Rejects matched traffic instead of opening an outbound connection.", aliases: ["reject-drop", "reject drop"]),
        .init(typeID: "rematch", displayName: "Rematch", summary: "Returns matching to a configured rule or sub-rule target.", aliases: []),
        .init(typeID: "ssh", displayName: "SSH", summary: "TCP proxying through an authenticated SSH connection.", aliases: []),
        .init(typeID: "mieru", displayName: "Mieru", summary: "Mieru proxy with TCP or UDP transport and multiplexing controls.", aliases: []),
        .init(typeID: "anytls", displayName: "AnyTLS", summary: "TLS proxy with session-pool controls and optional UDP support.", aliases: ["any tls"]),
        .init(typeID: "sudoku", displayName: "Sudoku", summary: "Sudoku encrypted transport with padding, table, and optional HTTP masking.", aliases: []),
        .init(typeID: "masque", displayName: "MASQUE", summary: "HTTP/3 MASQUE tunnel with key-based authentication and tunnel addressing.", aliases: []),
        .init(typeID: "trusttunnel", displayName: "TrustTunnel", summary: "TrustTunnel outbound with TLS, QUIC, health checks, and stream reuse.", aliases: ["trust tunnel"]),
        .init(typeID: "openvpn", displayName: "OpenVPN", summary: "OpenVPN client tunnel with certificate, cipher, keepalive, and MTU options.", aliases: ["open vpn"]),
        .init(typeID: "tailscale", displayName: "Tailscale", summary: "Embedded tsnet outbound for tailnet routes and optional exit-node use.", aliases: ["tail scale"]),
        .init(typeID: "shadowquic", displayName: "ShadowQUIC", summary: "QUIC outbound with username/password auth (JLS-forced) and congestion-control tuning.", aliases: ["shadow quic"]),
        .init(typeID: "zerotier", displayName: "ZeroTier", summary: "Embedded ZeroTier outbound that joins a network and routes through it.", aliases: ["zero tier"]),
    ]

    private static let lookup: [String: ProxyProtocolSpecification] = {
        var result: [String: ProxyProtocolSpecification] = [:]
        for item in specifications {
            for value in [item.typeID, item.displayName] + item.aliases {
                result[normalize(value)] = item
            }
        }
        return result
    }()

    static func specification(for rawType: String) -> ProxyProtocolSpecification? {
        lookup[normalize(rawType)]
    }

    static func details(for mapping: [String: Any]) -> ProxyProtocolDetails? {
        guard let rawType = mapping["type"] as? String,
              let specification = specification(for: rawType) else { return nil }

        var sections: [ProxyProtocolDetailSection] = []

        let connectionRows = connectionRows(mapping)
        if !connectionRows.isEmpty {
            sections.append(.init(title: "Server Information", rows: connectionRows))
        }

        let authenticationRows = authenticationRows(mapping)
        if !authenticationRows.isEmpty {
            sections.append(.init(title: "Authentication", rows: authenticationRows))
        }

        let protocolRows = protocolRows(for: specification.typeID, mapping: mapping)
        if !protocolRows.isEmpty {
            sections.append(.init(title: sectionTitle(for: specification.typeID), rows: protocolRows))
        }

        let securityRows = securityRows(mapping)
        if !securityRows.isEmpty {
            sections.append(.init(title: "TLS & Security", rows: securityRows))
        }

        let transportRows = transportRows(mapping)
        if !transportRows.isEmpty {
            sections.append(.init(title: "Transport", rows: transportRows))
        }

        let dialerRows = dialerRows(mapping)
        if !dialerRows.isEmpty {
            sections.append(.init(title: "Dialing", rows: dialerRows))
        }

        return ProxyProtocolDetails(
            typeID: specification.typeID,
            displayName: specification.displayName,
            summary: specification.summary,
            sections: sections,
            configurationJSON: configurationJSON(mapping)
        )
    }

    static func mapping(from configurationJSON: String) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(configurationJSON.utf8)) as? [String: Any]
    }

    private static func configurationJSON(_ mapping: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(mapping),
              let data = try? JSONSerialization.data(
                withJSONObject: mapping,
                options: [.sortedKeys]
              ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

     
     
    static let simulatedConfigurations: [[String: Any]] = [
        ["name": "Shadowsocks Demo", "type": "ss", "server": "ss.example", "port": 443, "cipher": "2022-blake3-aes-128-gcm", "password": "configured-secret", "udp": true, "plugin": "v2ray-plugin", "plugin-opts": ["mode": "websocket", "host": "cdn.example", "path": "/proxy", "tls": true], "udp-over-tcp": true, "udp-over-tcp-version": 2, "client-fingerprint": "ios", "tfo": true, "ip-version": "dual"],
        ["name": "ShadowsocksR Demo", "type": "ssr", "server": "ssr.example", "port": 8443, "cipher": "aes-256-gcm", "protocol": "auth_sha1_v4", "protocol-param": "configured-parameter", "obfs": "tls1.2_ticket_auth", "obfs-param": "cdn.example", "password": "configured-secret", "udp": true, "ip-version": "ipv4-prefer"],
        ["name": "SOCKS5 Demo", "type": "socks5", "server": "socks.example", "port": 1080, "username": "configured-user", "password": "configured-secret", "tls": true, "udp": true, "skip-cert-verify": false, "fingerprint": "configured-fingerprint", "tfo": true],
        ["name": "HTTP Demo", "type": "http", "server": "http.example", "port": 443, "username": "configured-user", "password": "configured-secret", "tls": true, "sni": "proxy.example", "headers": ["User-Agent": "Hako"], "skip-cert-verify": false, "mptcp": true],
        ["name": "VMess Demo", "type": "vmess", "server": "vmess.example", "port": 443, "uuid": "configured-identity", "alterId": 0, "cipher": "auto", "network": "ws", "tls": true, "servername": "edge.example", "udp": true, "packet-encoding": "xudp", "xudp": true, "global-padding": true, "authenticated-length": true, "client-fingerprint": "ios", "ws-opts": ["path": "/gateway", "max-early-data": 2048, "early-data-header-name": "Sec-WebSocket-Protocol"]],
        ["name": "VLESS Demo", "type": "vless", "server": "vless.example", "port": 443, "uuid": "configured-identity", "flow": "xtls-rprx-vision", "network": "xhttp", "tls": true, "servername": "edge.example", "udp": true, "encryption": "none", "packet-encoding": "xudp", "xudp": true, "client-fingerprint": "ios", "reality-opts": ["public-key": "configured-key", "short-id": "configured-short-id"], "xhttp-opts": ["mode": "auto", "host": "cdn.example", "path": "/api"]],
        ["name": "Snell Demo", "type": "snell", "server": "snell.example", "port": 44046, "psk": "configured-secret", "version": 4, "udp": true, "reuse": true, "client-fingerprint": "ios", "obfs-opts": ["mode": "shadow-tls", "host": "cdn.example", "version": 2]],
        ["name": "Trojan Demo", "type": "trojan", "server": "trojan.example", "port": 443, "password": "configured-secret", "network": "grpc", "sni": "edge.example", "udp": true, "alpn": ["h2"], "client-fingerprint": "ios", "grpc-opts": ["grpc-service-name": "configured-service", "ping-interval": 20, "max-connections": 4]],
        ["name": "Hysteria Demo", "type": "hysteria", "server": "hysteria.example", "ports": "443,8443", "protocol": "udp", "up": "50 Mbps", "down": "200 Mbps", "auth-str": "configured-secret", "obfs": "configured-obfuscation", "sni": "edge.example", "alpn": ["h3"], "fast-open": true, "recv-window-conn": 8_388_608, "recv-window": 16_777_216, "disable-mtu-discovery": false, "hop-interval": 30],
        ["name": "Hysteria 2 Demo", "type": "hysteria2", "server": "23fr.cloudfrontcdn.com", "port": 443, "ports": "40000-50000", "password": "configured-secret", "hop-interval": "30s", "up": "auto", "down": "auto", "obfs": "salamander", "obfs-password": "configured-secret", "obfs-min-packet-size": 64, "obfs-max-packet-size": 1400, "sni": "edge.example", "ech-opts": ["enable": false, "config": "", "query-server-name": ""], "skip-cert-verify": true, "fingerprint": "", "alpn": ["h3"], "cwnd": 64, "bbr-profile": "standard", "udp-mtu": 1200],
        ["name": "WireGuard Demo", "type": "wireguard", "server": "wireguard.example", "port": 51820, "private-key": "configured-private-key", "public-key": "configured-public-key", "pre-shared-key": "configured-secret", "ip": "172.16.0.2/32", "ipv6": "fd00::2/128", "mtu": 1280, "workers": 2, "udp": true, "persistent-keepalive": 25, "remote-dns-resolve": true, "dns": ["1.1.1.1"], "allowed-ips": ["0.0.0.0/0", "::/0"], "peers": [["server": "wireguard.example", "port": 51820, "public-key": "configured-public-key"]]],
        ["name": "TUIC Demo", "type": "tuic", "server": "tuic.example", "port": 443, "uuid": "configured-identity", "password": "configured-secret", "ip": "172.16.1.2", "heartbeat-interval": 10_000, "alpn": ["h3"], "udp-relay-mode": "native", "congestion-controller": "bbr", "reduce-rtt": true, "request-timeout": 8_000, "max-udp-relay-packet-size": 1200, "fast-open": true, "max-open-streams": 32, "udp-over-stream": true, "udp-over-stream-version": 2],
        ["name": "GOST Relay Demo", "type": "gost-relay", "server": "relay.example", "port": 443, "username": "configured-user", "password": "configured-secret", "forward": true, "tls": true, "sni": "relay.example", "client-fingerprint": "ios", "udp": true, "mux": true],
        ["name": "Direct Demo", "type": "direct", "ip-version": "dual"],
        ["name": "DNS Demo", "type": "dns", "ip-version": "ipv4-prefer"],
        ["name": "Reject Demo", "type": "reject"],
        ["name": "Rematch Demo", "type": "rematch", "target-rematch-name": "configured-target", "target-sub-rule": "configured-sub-rule"],
        ["name": "SSH Demo", "type": "ssh", "server": "ssh.example", "port": 22, "username": "configured-user", "password": "configured-secret", "private-key": "configured-private-key", "private-key-passphrase": "configured-secret", "host-key": ["configured-host-key"], "host-key-algorithms": ["ssh-ed25519"]],
        ["name": "Mieru Demo", "type": "mieru", "server": "mieru.example", "port-range": "20000-20100", "transport": "TCP", "username": "configured-user", "password": "configured-secret", "multiplexing": "MULTIPLEXING_HIGH", "handshake-mode": "HANDSHAKE_STANDARD", "traffic-pattern": "configured-profile", "udp": false],
        ["name": "AnyTLS Demo", "type": "anytls", "server": "anytls.example", "port": 443, "password": "configured-secret", "sni": "edge.example", "ech-opts": ["enable": false, "config": "", "query-server-name": ""], "client-fingerprint": "ios", "alpn": ["h2", "http/1.1"], "skip-cert-verify": true, "fingerprint": "configured-sha256", "certificate": "configured-certificate", "private-key": "configured-private-key", "udp": true, "idle-session-check-interval": 30, "idle-session-timeout": 300, "min-idle-session": 2, "tfo": true, "ip-version": "dual"],
        ["name": "Sudoku Demo", "type": "sudoku", "server": "sudoku.example", "port": 443, "key": "configured-secret", "aead-method": "aes-256-gcm", "padding-min": 8, "padding-max": 64, "table-type": "prefer_entropy", "enable-pure-downlink": true, "http-mask": true, "http-mask-mode": "auto", "http-mask-tls": true, "http-mask-host": "cdn.example", "path-root": "/proxy", "http-mask-multiplex": "auto"],
        ["name": "MASQUE Demo", "type": "masque", "server": "masque.example", "port": 443, "private-key": "configured-private-key", "public-key": "configured-public-key", "ip": "172.16.2.2", "ipv6": "fd00::3", "uri": "/.well-known/masque", "sni": "edge.example", "network": "udp", "mtu": 1280, "udp": true, "handshake-timeout": 8, "congestion-controller": "bbr", "cwnd": 64, "remote-dns-resolve": true, "dns": ["1.1.1.1"]],
        ["name": "TrustTunnel Demo", "type": "trusttunnel", "server": "trust.example", "port": 443, "username": "configured-user", "password": "configured-secret", "sni": "edge.example", "client-fingerprint": "ios", "alpn": ["h3"], "udp": true, "health-check": true, "quic": true, "congestion-controller": "bbr", "cwnd": 64, "max-connections": 4, "min-streams": 2, "max-streams": 16],
        ["name": "OpenVPN Demo", "type": "openvpn", "server": "openvpn.example", "port": 1194, "proto": "udp", "dev": "tun", "cipher": "AES-256-GCM", "auth": "SHA256", "ca": "configured-ca", "cert": "configured-cert", "key": "configured-key", "tls-crypt": "configured-secret", "username": "configured-user", "password": "configured-secret", "comp-lzo": "no", "ping": 10, "ping-restart": 60, "handshake-timeout": 15, "mtu": 1500, "udp": true, "remote-dns-resolve": true, "dns": ["1.1.1.1"]],
        ["name": "Tailscale Demo", "type": "tailscale", "auth-key": "configured-secret", "hostname": "hako-demo", "control-url": "https://control.example", "state-dir": "Configured", "ephemeral": true, "udp": true, "accept-routes": true, "exit-node": "configured-exit-node", "exit-node-allow-lan-access": false],
        ["name": "ShadowQUIC Demo", "type": "shadowquic", "server": "shadowquic.example", "port": 443, "username": "configured-user", "password": "configured-secret", "sni": "edge.example", "alpn": ["h3"], "quic-versions": ["v1"], "udp-over-stream": true, "zero-rtt": true, "keep-alive-interval": 10_000, "congestion-controller": "bbr", "up": "100 Mbps", "down": "100 Mbps", "cwnd": 32, "bbr-profile": "standard", "recv-window-conn": 8_388_608, "recv-window": 16_777_216, "disable-mtu-discovery": false, "max-datagram-frame-size": 1400, "max-open-streams": 1024],
        ["name": "ZeroTier Demo", "type": "zerotier", "network": "0123456789abcdef", "state-dir": "Configured", "planet": "Configured", "mtu": 2800, "physical-mtu": 1500, "udp": true, "remote-dns-resolve": true, "dns": ["1.1.1.1"], "low-bandwidth": false, "encrypted-hello": true, "primary-port": 9993, "secondary-port": 9994, "tcp-fallback-mode": "auto", "tcp-fallback-relay": "relay.example", "remote-trace-target": "trace.example", "remote-trace-level": 1, "ip-stack": ["mode": "auto", "congestion-controller": "cubic"], "orbit": [["world": "configured-world", "seed": "configured-seed"]]],
    ]

    private static func protocolRows(
        for typeID: String,
        mapping: [String: Any]
    ) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        switch typeID {
        case "ss":
            appendString(&rows, "Cipher", "cipher", mapping)
            appendString(&rows, "Plugin", "plugin", mapping)
            appendNestedString(&rows, "Plugin Mode", parent: "plugin-opts", key: "mode", mapping)
            appendNestedPrivateString(&rows, "Plugin Host", parent: "plugin-opts", key: "host", mapping)
            appendNestedString(&rows, "Plugin Path", parent: "plugin-opts", key: "path", mapping)
            appendNestedBool(&rows, "Plugin TLS", parent: "plugin-opts", key: "tls", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "UDP over TCP", "udp-over-tcp", mapping)
            appendNumber(&rows, "UDP over TCP Version", "udp-over-tcp-version", mapping)
            appendString(&rows, "Client Fingerprint", "client-fingerprint", mapping)
        case "ssr":
            appendString(&rows, "Cipher", "cipher", mapping)
            appendString(&rows, "SSR Protocol", "protocol", mapping)
            appendConfigured(&rows, "Protocol Parameter", keys: ["protocol-param"], mapping)
            appendString(&rows, "Obfuscation", "obfs", mapping)
            appendPrivateString(&rows, "Obfuscation Host", "obfs-param", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
        case "socks5":
            appendBool(&rows, "TLS", "tls", mapping)
            appendBool(&rows, "UDP Relay", "udp", mapping)
        case "http":
            appendBool(&rows, "TLS", "tls", mapping)
            appendCount(&rows, "Custom Headers", "headers", mapping)
        case "vmess":
            appendNumber(&rows, "Alter ID", "alterId", mapping)
            appendString(&rows, "Cipher", "cipher", mapping)
            appendString(&rows, "Transport", "network", mapping)
            appendString(&rows, "Packet Encoding", "packet-encoding", mapping)
            appendBool(&rows, "TLS", "tls", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "XUDP", "xudp", mapping)
            appendBool(&rows, "Global Padding", "global-padding", mapping)
            appendBool(&rows, "Authenticated Length", "authenticated-length", mapping)
            appendNestedString(&rows, "WebSocket Path", parent: "ws-opts", key: "path", mapping)
            appendNestedNumber(&rows, "Early Data", parent: "ws-opts", key: "max-early-data", mapping, suffix: " bytes")
            appendNestedString(&rows, "Early Data Header", parent: "ws-opts", key: "early-data-header-name", mapping)
        case "vless":
            appendString(&rows, "Flow", "flow", mapping)
            appendString(&rows, "Encryption", "encryption", mapping)
            appendString(&rows, "Transport", "network", mapping)
            appendString(&rows, "Packet Encoding", "packet-encoding", mapping)
            appendBool(&rows, "TLS", "tls", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "XUDP", "xudp", mapping)
            appendNestedString(&rows, "XHTTP Mode", parent: "xhttp-opts", key: "mode", mapping)
            appendNestedPrivateString(&rows, "XHTTP Host", parent: "xhttp-opts", key: "host", mapping)
            appendNestedString(&rows, "XHTTP Path", parent: "xhttp-opts", key: "path", mapping)
        case "snell":
            appendNumber(&rows, "Version", "version", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Connection Reuse", "reuse", mapping)
            appendNestedString(&rows, "Obfuscation", parent: "obfs-opts", key: "mode", mapping)
            appendNestedPrivateString(&rows, "Obfuscation Host", parent: "obfs-opts", key: "host", mapping)
            appendNestedNumber(&rows, "Obfuscation Version", parent: "obfs-opts", key: "version", mapping)
        case "trojan":
            appendString(&rows, "Transport", "network", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendList(&rows, "ALPN", "alpn", mapping)
            appendNestedConfigured(&rows, "gRPC Service", parent: "grpc-opts", keys: ["grpc-service-name"], mapping)
            appendNestedNumber(&rows, "gRPC Ping", parent: "grpc-opts", key: "ping-interval", mapping, suffix: " s")
            appendNestedNumber(&rows, "gRPC Connections", parent: "grpc-opts", key: "max-connections", mapping)
        case "hysteria":
            appendString(&rows, "Protocol", "protocol", mapping)
            appendString(&rows, "Upload Limit", "up", mapping)
            appendString(&rows, "Download Limit", "down", mapping)
            appendConfigured(&rows, "Obfuscation", keys: ["obfs", "obfs-protocol"], mapping)
            appendBool(&rows, "Fast Open", "fast-open", mapping)
            appendNumber(&rows, "Connection Receive Window", "recv-window-conn", mapping)
            appendNumber(&rows, "Receive Window", "recv-window", mapping)
            appendBool(&rows, "MTU Discovery", "disable-mtu-discovery", mapping, inverted: true)
            appendNumber(&rows, "Port Hop Interval", "hop-interval", mapping, suffix: " s")
        case "hysteria2":
            appendConfigured(&rows, "Port Hopping", keys: ["ports"], mapping)
            appendString(&rows, "Hop Interval", "hop-interval", mapping)
            appendString(&rows, "Upload Limit", "up", mapping)
            appendString(&rows, "Download Limit", "down", mapping)
            appendString(&rows, "Obfuscation", "obfs", mapping)
            appendNumber(&rows, "Obfuscation Packet Minimum", "obfs-min-packet-size", mapping, suffix: " bytes")
            appendNumber(&rows, "Obfuscation Packet Maximum", "obfs-max-packet-size", mapping, suffix: " bytes")
            appendNumber(&rows, "Congestion Window", "cwnd", mapping)
            appendString(&rows, "BBR Profile", "bbr-profile", mapping)
            appendNumber(&rows, "UDP MTU", "udp-mtu", mapping)
        case "wireguard":
            appendNumber(&rows, "Peers", value: arrayCount(mapping["peers"]))
            appendPrivateString(&rows, "IPv4 Address", "ip", mapping)
            appendPrivateString(&rows, "IPv6 Address", "ipv6", mapping)
            appendNumber(&rows, "MTU", "mtu", mapping)
            appendNumber(&rows, "Workers", "workers", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendNumber(&rows, "Persistent Keepalive", "persistent-keepalive", mapping, suffix: " s")
            appendBool(&rows, "Remote DNS", "remote-dns-resolve", mapping)
            appendList(&rows, "DNS Servers", "dns", mapping, privateValues: true)
            appendList(&rows, "Allowed IPs", "allowed-ips", mapping, privateValues: true)
        case "tuic":
            appendPrivateString(&rows, "Tunnel Address", "ip", mapping)
            appendNumber(&rows, "Heartbeat", "heartbeat-interval", mapping, suffix: " ms")
            appendString(&rows, "UDP Relay", "udp-relay-mode", mapping)
            appendString(&rows, "Congestion Control", "congestion-controller", mapping)
            appendBool(&rows, "Reduced RTT", "reduce-rtt", mapping)
            appendNumber(&rows, "Request Timeout", "request-timeout", mapping, suffix: " ms")
            appendNumber(&rows, "Maximum UDP Packet", "max-udp-relay-packet-size", mapping, suffix: " bytes")
            appendBool(&rows, "Fast Open", "fast-open", mapping)
            appendNumber(&rows, "Maximum Open Streams", "max-open-streams", mapping)
            appendBool(&rows, "UDP over Stream", "udp-over-stream", mapping)
            appendNumber(&rows, "UDP over Stream Version", "udp-over-stream-version", mapping)
        case "gost-relay":
            appendBool(&rows, "Forward Mode", "forward", mapping)
            appendBool(&rows, "TLS", "tls", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Multiplexing", "mux", mapping)
        case "direct":
            rows.append(.init(label: "Behavior", value: "Connect directly"))
        case "dns":
            rows.append(.init(label: "Behavior", value: "Use DNS outbound"))
        case "reject":
            rows.append(.init(label: "Behavior", value: "Reject traffic"))
        case "rematch":
            appendConfigured(&rows, "Rule Target", keys: ["target-rematch-name"], mapping)
            appendConfigured(&rows, "Sub-rule Target", keys: ["target-sub-rule"], mapping)
        case "ssh":
            appendList(&rows, "Host Key Algorithms", "host-key-algorithms", mapping)
            appendConfigured(&rows, "Host Key Pinning", keys: ["host-key"], mapping)
        case "mieru":
            appendString(&rows, "Transport", "transport", mapping)
            appendString(&rows, "Multiplexing", "multiplexing", mapping)
            appendString(&rows, "Handshake", "handshake-mode", mapping)
            appendString(&rows, "Traffic Pattern", "traffic-pattern", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
        case "anytls":
            appendBool(&rows, "UDP", "udp", mapping)
            appendList(&rows, "ALPN", "alpn", mapping)
            appendNumber(&rows, "Idle Check", "idle-session-check-interval", mapping, suffix: " s")
            appendNumber(&rows, "Idle Timeout", "idle-session-timeout", mapping, suffix: " s")
            appendNumber(&rows, "Minimum Idle Sessions", "min-idle-session", mapping)
        case "sudoku":
            appendString(&rows, "AEAD", "aead-method", mapping)
            appendString(&rows, "Table", "table-type", mapping)
            appendRange(&rows, "Padding", lowerKey: "padding-min", upperKey: "padding-max", mapping: mapping)
            appendBool(&rows, "Pure Downlink", "enable-pure-downlink", mapping)
            appendBool(&rows, "HTTP Mask", "http-mask", mapping)
            appendString(&rows, "HTTP Mask Mode", "http-mask-mode", mapping)
            appendBool(&rows, "HTTP Mask TLS", "http-mask-tls", mapping)
            appendPrivateString(&rows, "HTTP Mask Host", "http-mask-host", mapping)
            appendString(&rows, "Path Root", "path-root", mapping)
            appendString(&rows, "HTTP Multiplexing", "http-mask-multiplex", mapping)
        case "masque":
            appendString(&rows, "Network", "network", mapping)
            appendPrivateString(&rows, "IPv4 Address", "ip", mapping)
            appendPrivateString(&rows, "IPv6 Address", "ipv6", mapping)
            appendString(&rows, "URI", "uri", mapping)
            appendNumber(&rows, "MTU", "mtu", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendNumber(&rows, "Handshake Timeout", "handshake-timeout", mapping, suffix: " s")
            appendString(&rows, "Congestion Control", "congestion-controller", mapping)
            appendNumber(&rows, "Congestion Window", "cwnd", mapping)
            appendBool(&rows, "Remote DNS", "remote-dns-resolve", mapping)
            appendList(&rows, "DNS Servers", "dns", mapping, privateValues: true)
        case "trusttunnel":
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Health Check", "health-check", mapping)
            appendBool(&rows, "QUIC", "quic", mapping)
            appendString(&rows, "Congestion Control", "congestion-controller", mapping)
            appendNumber(&rows, "Congestion Window", "cwnd", mapping)
            appendNumber(&rows, "Maximum Connections", "max-connections", mapping)
            appendRange(&rows, "Streams", lowerKey: "min-streams", upperKey: "max-streams", mapping: mapping)
        case "openvpn":
            appendString(&rows, "Transport", "proto", mapping)
            appendString(&rows, "Device", "dev", mapping)
            appendString(&rows, "Cipher", "cipher", mapping)
            appendString(&rows, "Authentication Digest", "auth", mapping)
            appendNumber(&rows, "Ping", "ping", mapping, suffix: " s")
            appendNumber(&rows, "Restart After", "ping-restart", mapping, suffix: " s")
            appendNumber(&rows, "Handshake Timeout", "handshake-timeout", mapping, suffix: " s")
            appendNumber(&rows, "MTU", "mtu", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Remote DNS", "remote-dns-resolve", mapping)
            appendList(&rows, "DNS Servers", "dns", mapping, privateValues: true)
        case "tailscale":
            appendPrivateString(&rows, "Hostname", "hostname", mapping)
            appendPrivateString(&rows, "Control Server", "control-url", mapping)
            appendConfigured(&rows, "State Storage", keys: ["state-dir"], mapping)
            appendBool(&rows, "Ephemeral Node", "ephemeral", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Accept Routes", "accept-routes", mapping)
            appendConfigured(&rows, "Exit Node", keys: ["exit-node"], mapping)
            appendBool(&rows, "Exit Node LAN Access", "exit-node-allow-lan-access", mapping)
        case "zerotier":
             
             
             
             
            appendPrivateString(&rows, "Network", "network", mapping)
            appendConfigured(&rows, "Planet", keys: ["planet"], mapping)
            appendConfigured(&rows, "State Storage", keys: ["state-dir"], mapping)
            appendNumber(&rows, "MTU", "mtu", mapping)
            appendNumber(&rows, "Physical MTU", "physical-mtu", mapping)
            appendNumber(&rows, "Primary Port", "primary-port", mapping)
            appendNumber(&rows, "Secondary Port", "secondary-port", mapping)
            appendString(&rows, "TCP Fallback", "tcp-fallback-mode", mapping)
            appendPrivateString(&rows, "TCP Fallback Relay", "tcp-fallback-relay", mapping)
            appendNestedString(&rows, "IP Stack", parent: "ip-stack", key: "mode", mapping)
            appendNestedString(
                &rows,
                "Congestion Control",
                parent: "ip-stack",
                key: "congestion-controller",
                mapping
            )
            appendCount(&rows, "Orbit Moons", "orbit", mapping)
            appendBool(&rows, "UDP", "udp", mapping)
            appendBool(&rows, "Remote DNS Resolve", "remote-dns-resolve", mapping)
            appendList(&rows, "DNS", "dns", mapping)
            appendBool(&rows, "Low Bandwidth", "low-bandwidth", mapping)
            appendBool(&rows, "Encrypted Hello", "encrypted-hello", mapping)
            appendPrivateString(&rows, "Remote Trace Target", "remote-trace-target", mapping)
            appendNumber(&rows, "Remote Trace Level", "remote-trace-level", mapping)
        default:
            break
        }
        return rows
    }

    private static func connectionRows(_ mapping: [String: Any]) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        appendPrivateString(&rows, "Server", "server", mapping)
        appendPrivateNumber(&rows, "Port", "port", mapping)
        appendPrivateString(&rows, "Ports", "ports", mapping)
        appendPrivateString(&rows, "Port Range", "port-range", mapping)
        return rows
    }

    private static func authenticationRows(_ mapping: [String: Any]) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        appendPrivateString(&rows, "Username", "username", mapping)
        appendSecret(&rows, "Password", "password", mapping)
        appendSecret(&rows, "Identity", "uuid", mapping)
        appendSecret(&rows, "Token", "token", mapping)
        appendSecret(&rows, "Authentication", "auth", mapping)
        appendSecret(&rows, "Authentication String", "auth-str", mapping)
        appendSecret(&rows, "Pre-shared Key", "psk", mapping)
        appendSecret(&rows, "Encryption Key", "key", mapping)
        appendSecret(&rows, "Auth Key", "auth-key", mapping)
        appendSecret(&rows, "Private Key", "private-key", mapping)
        appendSecret(&rows, "Private Key Passphrase", "private-key-passphrase", mapping)
        appendSecret(&rows, "Public Key", "public-key", mapping)
        appendSecret(&rows, "Peer Pre-shared Key", "pre-shared-key", mapping)
        appendConfigured(&rows, "Certificate Authority", keys: ["ca"], mapping)
        appendConfigured(&rows, "Client Certificate", keys: ["cert", "certificate"], mapping)
        appendConfigured(&rows, "TLS Crypt", keys: ["tls-crypt"], mapping)
        return rows
    }

    private static func securityRows(_ mapping: [String: Any]) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        appendPrivateString(&rows, "TLS Name", "sni", mapping)
        if mapping["sni"] == nil {
            appendPrivateString(&rows, "TLS Name", "servername", mapping)
        }
        appendString(&rows, "Client Fingerprint", "client-fingerprint", mapping)
        appendConfigured(&rows, "Certificate Fingerprint", keys: ["fingerprint"], mapping)
        appendList(&rows, "ALPN", "alpn", mapping)
        if mapping["skip-cert-verify"] != nil {
            appendBool(&rows, "Certificate Verification", "skip-cert-verify", mapping, inverted: true)
        }
        appendConfigured(&rows, "ECH", keys: ["ech-opts"], mapping)
        appendConfigured(&rows, "Reality", keys: ["reality-opts"], mapping)
        return rows
    }

    private static func transportRows(_ mapping: [String: Any]) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        if let smux = mapping["smux"] as? [String: Any], smux["enabled"] as? Bool == true {
            rows.append(.init(label: "Multiplexing", value: "On", kind: .toggle))
            appendString(&rows, "Mux Protocol", "protocol", smux)
            appendRange(&rows, "Mux Streams", lowerKey: "min-streams", upperKey: "max-streams", mapping: smux)
        }
        appendBool(&rows, "TCP Fast Open", "tfo", mapping)
        appendBool(&rows, "Multipath TCP", "mptcp", mapping)
        appendString(&rows, "IP Preference", "ip-version", mapping)
        return rows
    }

    private static func dialerRows(_ mapping: [String: Any]) -> [ProxyProtocolDetailRow] {
        var rows: [ProxyProtocolDetailRow] = []
        appendPrivateString(&rows, "Proxy Chain", "dialer-proxy", mapping)
        appendPrivateString(&rows, "Bound Interface", "interface-name", mapping)
        appendNumber(&rows, "Routing Mark", "routing-mark", mapping)
        return rows
    }

    private static func role(for typeID: String) -> String {
        switch typeID {
        case "direct", "dns", "reject", "rematch": return "Built-in outbound"
        case "wireguard", "masque", "openvpn", "tailscale": return "Tunnel outbound"
        default: return "Proxy outbound"
        }
    }

    private static func sectionTitle(for typeID: String) -> String {
        switch typeID {
        case "direct", "dns", "reject", "rematch": return "Behavior"
        case "wireguard", "masque", "openvpn", "tailscale", "zerotier":
            return "Tunnel"
        default: return "Protocol"
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func hasValue(_ value: Any?) -> Bool {
        switch value {
        case nil: return false
        case let string as String: return !string.isEmpty
        case let values as [Any]: return !values.isEmpty
        case let values as [String: Any]: return !values.isEmpty
        default: return true
        }
    }

    private static func appendConfigured(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        keys: [String],
        _ mapping: [String: Any]
    ) {
        guard let key = keys.first(where: { hasValue(mapping[$0]) }) else { return }
         
         
        rows.append(.init(label: label, value: "Configured", key: key))
    }

    private static func appendNestedConfigured(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        parent: String,
        keys: [String],
        _ mapping: [String: Any]
    ) {
        guard let nested = mapping[parent] as? [String: Any],
              keys.contains(where: { hasValue(nested[$0]) }) else { return }
        rows.append(.init(label: label, value: "Configured", key: parent))
    }

    private static func appendString(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        guard let value = mapping[key] as? String, !value.isEmpty else { return }
        rows.append(.init(label: label, value: value))
    }

    private static func appendPrivateString(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        guard let value = mapping[key] as? String, !value.isEmpty else { return }
        rows.append(.init(label: label, value: value, kind: .privateText, key: key))
    }

    private static func appendNestedString(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        parent: String,
        key: String,
        _ mapping: [String: Any]
    ) {
        guard let nested = mapping[parent] as? [String: Any] else { return }
        appendString(&rows, label, key, nested)
    }

    private static func appendNestedPrivateString(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        parent: String,
        key: String,
        _ mapping: [String: Any]
    ) {
        guard let nested = mapping[parent] as? [String: Any] else { return }
        appendPrivateString(&rows, label, key, nested)
    }

    private static func appendSecret(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        guard hasValue(mapping[key]) else { return }
        rows.append(.init(label: label, value: "••••••••••••", kind: .secret, key: key))
    }

    private static func appendBool(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any],
        inverted: Bool = false
    ) {
        guard let value = mapping[key] as? Bool else { return }
        let effective = inverted ? !value : value
        rows.append(.init(label: label, value: effective ? "On" : "Off", kind: .toggle))
    }

    private static func appendNestedBool(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        parent: String,
        key: String,
        _ mapping: [String: Any]
    ) {
        guard let nested = mapping[parent] as? [String: Any] else { return }
        appendBool(&rows, label, key, nested)
    }

    private static func appendNumber(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any],
        suffix: String = ""
    ) {
        guard let number = mapping[key] as? NSNumber else { return }
        rows.append(.init(label: label, value: "\(number)\(suffix)"))
    }

    private static func appendPrivateNumber(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        guard let number = mapping[key] as? NSNumber else { return }
        rows.append(.init(label: label, value: "\(number)", kind: .privateText))
    }

    private static func appendNestedNumber(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        parent: String,
        key: String,
        _ mapping: [String: Any],
        suffix: String = ""
    ) {
        guard let nested = mapping[parent] as? [String: Any] else { return }
        appendNumber(&rows, label, key, nested, suffix: suffix)
    }

    private static func appendNumber(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        value: Int?
    ) {
        guard let value else { return }
        rows.append(.init(label: label, value: "\(value)"))
    }

    private static func appendList(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any],
        privateValues: Bool = false
    ) {
        guard let values = mapping[key] as? [String], !values.isEmpty else { return }
        rows.append(.init(
            label: label,
            value: values.joined(separator: ", "),
            kind: privateValues ? .privateText : .text
        ))
    }

    private static func appendCount(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        let count: Int?
        if let values = mapping[key] as? [String: Any] {
            count = values.count
        } else if let values = mapping[key] as? [String: String] {
            count = values.count
        } else if let values = mapping[key] as? [Any] {
            count = values.count
        } else {
            count = nil
        }
        guard let count, count > 0 else { return }
        rows.append(.init(label: label, value: "\(count) configured"))
    }

    private static func appendRange(
        _ rows: inout [ProxyProtocolDetailRow],
        _ label: String,
        lowerKey: String,
        upperKey: String,
        mapping: [String: Any]
    ) {
        let lower = mapping[lowerKey] as? NSNumber
        let upper = mapping[upperKey] as? NSNumber
        guard lower != nil || upper != nil else { return }
        let value: String
        if let lower, let upper {
            value = "\(lower)–\(upper)"
        } else if let lower {
            value = "From \(lower)"
        } else {
            value = "Up to \(upper!)"
        }
        rows.append(.init(label: label, value: value))
    }

    private static func arrayCount(_ value: Any?) -> Int? {
        guard let value = value as? [Any], !value.isEmpty else { return nil }
        return value.count
    }
}

struct ProxyEditorSchemaField: Decodable, Identifiable {
    let goName: String
    let key: String
    let goType: String
    let required: Bool
    let nested: [ProxyEditorSchemaField]?

    var id: String { key }
    var children: [ProxyEditorSchemaField] { nested ?? [] }

     
     
     
     
    var editorControlKind: ProxyEditorControlKind {
        if goType == "*bool" { return .optionalBool }
        let valueType = String(goType.trimmingPrefix("*"))
        if valueType == "bool" { return .bool }
        if valueType == "[]string" { return .stringList }
        if !children.isEmpty && !valueType.hasPrefix("[]") { return .nestedObject }
        if valueType.hasPrefix("map[") || valueType.hasPrefix("[]") { return .json }
        if Self.secretKeys.contains(key.lowercased()) { return .secret }
        if Self.isNumeric(valueType) { return .number }
        return .text
    }

    init?(mapping: [String: Any]) {
        guard let goName = mapping["goName"] as? String,
              let key = mapping["key"] as? String,
              let goType = mapping["goType"] as? String,
              let required = mapping["required"] as? Bool else { return nil }
        self.goName = goName
        self.key = key
        self.goType = goType
        self.required = required
        if let rawChildren = mapping["nested"] as? [Any] {
            let children = rawChildren.compactMap { $0 as? [String: Any] }
            guard children.count == rawChildren.count else { return nil }
            let decoded = children.compactMap(Self.init(mapping:))
            guard decoded.count == children.count else { return nil }
            nested = decoded
        } else {
            nested = nil
        }
    }

    private static func isNumeric(_ value: String) -> Bool {
        value.hasPrefix("int") || value.hasPrefix("uint") || value.hasPrefix("float")
    }

    private static let secretKeys: Set<String> = [
        "auth", "auth-key", "key", "obfs-password", "password", "pre-shared-key",
        "private-key", "private-key-passphrase", "psk", "public-key", "secret",
        "tls-auth", "tls-crypt", "tls-crypt-v2", "token", "username", "uuid",
    ]
}

enum ProxyEditorControlKind: String, CaseIterable {
    case bool
    case optionalBool
    case nestedObject
    case json
    case stringList
    case secret
    case number
    case text
}

private extension String {
    func trimmingPrefix(_ prefix: Character) -> String {
        String(drop(while: { $0 == prefix }))
    }
}

enum ProxyProtocolEditorSchema {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let auditedCoreRevision = "187d44170b2ecef2519588b7fc0da18be3f47c85"

    static let fieldsByType: [String: [ProxyEditorSchemaField]] = {
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(normalizedEmbeddedJSON(rawJSON).utf8)
        ),
              let protocols = object as? [String: Any] else {
            assertionFailure("Bundled proxy protocol schema is not valid JSON")
            return [:]
        }
        var result: [String: [ProxyEditorSchemaField]] = [:]
        for (typeID, value) in protocols {
            guard let rawMappings = value as? [Any] else {
                assertionFailure("Bundled proxy protocol schema is malformed for \(typeID)")
                return [:]
            }
            let mappings = rawMappings.compactMap { $0 as? [String: Any] }
            guard mappings.count == rawMappings.count else {
                assertionFailure("Bundled proxy protocol schema is malformed for \(typeID)")
                return [:]
            }
            let fields = mappings.compactMap(ProxyEditorSchemaField.init(mapping:))
            guard fields.count == mappings.count else {
                assertionFailure("Bundled proxy protocol schema is incomplete for \(typeID)")
                return [:]
            }
            result[typeID] = fields
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        assert(result.count == 27, "Bundled proxy protocol schema must cover every parser type")
        assert(
            Set(ProxyProtocolCatalog.formalTypeIDs) == Set(result.keys),
            """
            The proxy type catalog and the bundled schema must name the same \
            types: anything the core can parse is a type the editor offers to \
            create. Missing here: \
            \(Set(result.keys).subtracting(ProxyProtocolCatalog.formalTypeIDs).sorted())
            """
        )
         
         
         
         
         
         
         
         
         
        result["ss"] = result["ss"].map {
            augmentNestedChildren($0, key: "plugin-opts", children: pluginOptionFields)
        }
        result["snell"] = result["snell"].map {
            augmentNestedChildren($0, key: "obfs-opts", children: snellObfsOptionFields)
        }
        return result
    }()

    private static let pluginOptionFields: [[String: Any]] = [
        ["goName": "Mode", "key": "mode", "goType": "string", "required": false],
        ["goName": "Host", "key": "host", "goType": "string", "required": false],
        ["goName": "Path", "key": "path", "goType": "string", "required": false],
        ["goName": "TLS", "key": "tls", "goType": "bool", "required": false],
        ["goName": "Password", "key": "password", "goType": "string", "required": false],
        ["goName": "Version", "key": "version", "goType": "int", "required": false],
        ["goName": "Mux", "key": "mux", "goType": "bool", "required": false],
        ["goName": "Fingerprint", "key": "fingerprint", "goType": "string", "required": false],
        ["goName": "SkipCertVerify", "key": "skip-cert-verify", "goType": "bool", "required": false],
         
         
         
         
         
         
        ["goName": "VersionHint", "key": "version-hint", "goType": "string", "required": false],
        ["goName": "Username", "key": "username", "goType": "string", "required": false],
        ["goName": "Certificate", "key": "certificate", "goType": "string", "required": false],
        ["goName": "PrivateKey", "key": "private-key", "goType": "string", "required": false],
        ["goName": "NameCertVerify", "key": "name-cert-verify", "goType": "string", "required": false],
    ]

    private static let snellObfsOptionFields: [[String: Any]] = [
        ["goName": "Mode", "key": "mode", "goType": "string", "required": false],
        ["goName": "Host", "key": "host", "goType": "string", "required": false],
        ["goName": "Password", "key": "password", "goType": "string", "required": false],
        ["goName": "Version", "key": "version", "goType": "int", "required": false],
         
         
         
        ["goName": "VersionHint", "key": "version-hint", "goType": "string", "required": false],
        ["goName": "Username", "key": "username", "goType": "string", "required": false],
         
         
         
        ["goName": "Certificate", "key": "certificate", "goType": "string", "required": false],
        ["goName": "PrivateKey", "key": "private-key", "goType": "string", "required": false],
        ["goName": "NameCertVerify", "key": "name-cert-verify", "goType": "string", "required": false],
    ]

     
     
     
     
    private static func augmentNestedChildren(
        _ fields: [ProxyEditorSchemaField],
        key: String,
        children: [[String: Any]]
    ) -> [ProxyEditorSchemaField] {
        fields.map { field in
            guard field.key == key, field.nested == nil,
                  let augmented = ProxyEditorSchemaField(mapping: [
                      "goName": field.goName,
                      "key": field.key,
                      "goType": field.goType,
                      "required": field.required,
                      "nested": children,
                  ]) else { return field }
            return augmented
        }
    }

     
     
     
    private static let globalFields: [ProxyEditorSchemaField] = {
        let json = #"""[{"goName":"SMUX","key":"smux","goType":"SingMuxOption","required":false,"nested":[{"goName":"Enabled","key":"enabled","goType":"bool","required":false},{"goName":"Protocol","key":"protocol","goType":"string","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"int","required":false},{"goName":"MinStreams","key":"min-streams","goType":"int","required":false},{"goName":"MaxStreams","key":"max-streams","goType":"int","required":false},{"goName":"Padding","key":"padding","goType":"bool","required":false},{"goName":"Statistic","key":"statistic","goType":"bool","required":false},{"goName":"OnlyTcp","key":"only-tcp","goType":"bool","required":false},{"goName":"BrutalOpts","key":"brutal-opts","goType":"BrutalOption","required":false,"nested":[{"goName":"Enabled","key":"enabled","goType":"bool","required":false},{"goName":"Up","key":"up","goType":"string","required":false},{"goName":"Down","key":"down","goType":"string","required":false}]}]}]"""#
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(normalizedEmbeddedJSON(json).utf8)
        ),
              let mappings = object as? [[String: Any]] else {
            assertionFailure("Bundled global proxy schema is not valid JSON")
            return []
        }
        let fields = mappings.compactMap(ProxyEditorSchemaField.init(mapping:))
        assert(fields.count == mappings.count, "Bundled global proxy schema is incomplete")
        return fields
    }()

     
     
     
     
     
     
     
     
     
     
     
     
     
    private static let resolvedFieldsByType: [String: [ProxyEditorSchemaField]] =
        fieldsByType.mapValues { $0 + globalFields }

    private static let fieldIndexByType: [String: [String: ProxyEditorSchemaField]] =
        resolvedFieldsByType.mapValues { fields in
            Dictionary(
                fields.map { ($0.key, $0) },
                 
                 
                uniquingKeysWith: { first, _ in first }
            )
        }

    private static func canonicalTypeID(_ typeID: String) -> String {
        ProxyProtocolCatalog.specification(for: typeID)?.typeID
            ?? typeID.lowercased()
    }

    static func fields(for typeID: String) -> [ProxyEditorSchemaField] {
        resolvedFieldsByType[canonicalTypeID(typeID)] ?? []
    }

    static func field(_ key: String, typeID: String) -> ProxyEditorSchemaField? {
        fieldIndexByType[canonicalTypeID(typeID)]?[key]
    }

    static func supports(_ key: String, typeID: String) -> Bool {
        field(key, typeID: typeID) != nil
    }

     
     
     
    private static func normalizedEmbeddedJSON(_ value: String) -> String {
        guard value.hasPrefix("\"\""), value.hasSuffix("\"\"") else { return value }
        return String(value.dropFirst(2).dropLast(2))
    }

     
    static let rawJSON = #"""{"anytls":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Password","key":"password","goType":"string","required":true},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ShadowTLSOpts","key":"shadow-tls-opts","goType":"ShadowTLSOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Version","key":"version","goType":"int","required":false}]},{"goName":"RestlsOpts","key":"restls-opts","goType":"RestlsOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"VersionHint","key":"version-hint","goType":"string","required":false},{"goName":"RestlsScript","key":"restls-script","goType":"string","required":false}]},{"goName":"JLSOpts","key":"jls-opts","goType":"JLSOptions","required":false,"nested":[{"goName":"Username","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true}]},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"ClientMetadata","key":"client-metadata","goType":"string","required":false},{"goName":"IdleSessionCheckInterval","key":"idle-session-check-interval","goType":"int","required":false},{"goName":"IdleSessionTimeout","key":"idle-session-timeout","goType":"int","required":false},{"goName":"MinIdleSession","key":"min-idle-session","goType":"int","required":false},{"goName":"DisableReuse","key":"disable-reuse","goType":"bool","required":false}],"direct":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true}],"dns":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true}],"gost-relay":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Forward","key":"forward","goType":"bool","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"Mux","key":"mux","goType":"bool","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"Username","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"http":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UserName","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"map[string]string","required":false}],"hysteria":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":false},{"goName":"Ports","key":"ports","goType":"string","required":false},{"goName":"Protocol","key":"protocol","goType":"string","required":false},{"goName":"ObfsProtocol","key":"obfs-protocol","goType":"string","required":false},{"goName":"Up","key":"up","goType":"string","required":true},{"goName":"UpSpeed","key":"up-speed","goType":"int","required":false},{"goName":"Down","key":"down","goType":"string","required":true},{"goName":"DownSpeed","key":"down-speed","goType":"int","required":false},{"goName":"Auth","key":"auth","goType":"string","required":false},{"goName":"AuthString","key":"auth-str","goType":"string","required":false},{"goName":"Obfs","key":"obfs","goType":"string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"ReceiveWindowConn","key":"recv-window-conn","goType":"int","required":false},{"goName":"ReceiveWindow","key":"recv-window","goType":"int","required":false},{"goName":"DisableMTUDiscovery","key":"disable-mtu-discovery","goType":"bool","required":false},{"goName":"FastOpen","key":"fast-open","goType":"bool","required":false},{"goName":"HopInterval","key":"hop-interval","goType":"int","required":false}],"hysteria2":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":false},{"goName":"Ports","key":"ports","goType":"string","required":false},{"goName":"HopInterval","key":"hop-interval","goType":"string","required":false},{"goName":"Up","key":"up","goType":"string","required":false},{"goName":"Down","key":"down","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Obfs","key":"obfs","goType":"string","required":false},{"goName":"ObfsPassword","key":"obfs-password","goType":"string","required":false},{"goName":"ObfsMinPacketSize","key":"obfs-min-packet-size","goType":"int","required":false},{"goName":"ObfsMaxPacketSize","key":"obfs-max-packet-size","goType":"int","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"CWND","key":"cwnd","goType":"int","required":false},{"goName":"BBRProfile","key":"bbr-profile","goType":"string","required":false},{"goName":"UdpMTU","key":"udp-mtu","goType":"int","required":false},{"goName":"HandshakeTimeout","key":"handshake-timeout","goType":"int","required":false},{"goName":"RealmOpts","key":"realm-opts","goType":"Hysteria2RealmOption","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"ServerURL","key":"server-url","goType":"string","required":false},{"goName":"Token","key":"token","goType":"string","required":false},{"goName":"RealmID","key":"realm-id","goType":"string","required":false},{"goName":"STUNServers","key":"stun-servers","goType":"[]string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false}]},{"goName":"InitialStreamReceiveWindow","key":"initial-stream-receive-window","goType":"uint64","required":false},{"goName":"MaxStreamReceiveWindow","key":"max-stream-receive-window","goType":"uint64","required":false},{"goName":"InitialConnectionReceiveWindow","key":"initial-connection-receive-window","goType":"uint64","required":false},{"goName":"MaxConnectionReceiveWindow","key":"max-connection-receive-window","goType":"uint64","required":false}],"masque":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"PrivateKey","key":"private-key","goType":"string","required":true},{"goName":"PublicKey","key":"public-key","goType":"string","required":true},{"goName":"Ip","key":"ip","goType":"string","required":false},{"goName":"Ipv6","key":"ipv6","goType":"string","required":false},{"goName":"URI","key":"uri","goType":"string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"MTU","key":"mtu","goType":"int","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"HandshakeTimeout","key":"handshake-timeout","goType":"int","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Network","key":"network","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false},{"goName":"CWND","key":"cwnd","goType":"int","required":false},{"goName":"BBRProfile","key":"bbr-profile","goType":"string","required":false},{"goName":"IPStack","key":"ip-stack","goType":"IPStackOption","required":false,"nested":[{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false}]},{"goName":"RemoteDnsResolve","key":"remote-dns-resolve","goType":"bool","required":false},{"goName":"Dns","key":"dns","goType":"[]string","required":false}],"mieru":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":false},{"goName":"PortRange","key":"port-range","goType":"string","required":false},{"goName":"Transport","key":"transport","goType":"string","required":true},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"UserName","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true},{"goName":"Multiplexing","key":"multiplexing","goType":"string","required":false},{"goName":"HandshakeMode","key":"handshake-mode","goType":"string","required":false},{"goName":"TrafficPattern","key":"traffic-pattern","goType":"string","required":false}],"openvpn":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Proto","key":"proto","goType":"string","required":false},{"goName":"Dev","key":"dev","goType":"string","required":false},{"goName":"Cipher","key":"cipher","goType":"string","required":false},{"goName":"DataCiphers","key":"data-ciphers","goType":"[]string","required":false},{"goName":"DataCipherFallback","key":"data-ciphers-fallback","goType":"string","required":false},{"goName":"Auth","key":"auth","goType":"string","required":false},{"goName":"CompLZO","key":"comp-lzo","goType":"string","required":false},{"goName":"CA","key":"ca","goType":"string","required":true},{"goName":"Cert","key":"cert","goType":"string","required":false},{"goName":"Key","key":"key","goType":"string","required":false},{"goName":"TLSAuth","key":"tls-auth","goType":"string","required":false},{"goName":"KeyDirection","key":"key-direction","goType":"string","required":false},{"goName":"TLSCrypt","key":"tls-crypt","goType":"string","required":false},{"goName":"TLSCryptV2","key":"tls-crypt-v2","goType":"string","required":false},{"goName":"Username","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"PeerInfo","key":"peer-info","goType":"map[string]string","required":false},{"goName":"Ping","key":"ping","goType":"int","required":false},{"goName":"PingRestart","key":"ping-restart","goType":"int","required":false},{"goName":"TranWindow","key":"tran-window","goType":"*int","required":false},{"goName":"HandshakeTimeout","key":"handshake-timeout","goType":"int","required":false},{"goName":"MTU","key":"mtu","goType":"int","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"IPStack","key":"ip-stack","goType":"IPStackOption","required":false,"nested":[{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false}]},{"goName":"RemoteDnsResolve","key":"remote-dns-resolve","goType":"bool","required":false},{"goName":"Dns","key":"dns","goType":"[]string","required":false}],"reject":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true}],"rematch":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"TargetRematchName","key":"target-rematch-name","goType":"*string","required":false},{"goName":"TargetSubRule","key":"target-sub-rule","goType":"*string","required":false}],"shadowquic":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Username","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"QUICVersions","key":"quic-versions","goType":"[]string","required":false},{"goName":"UDPOverStream","key":"udp-over-stream","goType":"bool","required":false},{"goName":"ZeroRTT","key":"zero-rtt","goType":"bool","required":false},{"goName":"KeepAliveInterval","key":"keep-alive-interval","goType":"int","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false},{"goName":"Up","key":"up","goType":"string","required":false},{"goName":"Down","key":"down","goType":"string","required":false},{"goName":"CWND","key":"cwnd","goType":"int","required":false},{"goName":"BBRProfile","key":"bbr-profile","goType":"string","required":false},{"goName":"ReceiveWindowConn","key":"recv-window-conn","goType":"int","required":false},{"goName":"ReceiveWindow","key":"recv-window","goType":"int","required":false},{"goName":"DisableMTUDiscovery","key":"disable-mtu-discovery","goType":"bool","required":false},{"goName":"MaxDatagramFrameSize","key":"max-datagram-frame-size","goType":"int","required":false},{"goName":"MaxOpenStreams","key":"max-open-streams","goType":"int","required":false}],"snell":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Psk","key":"psk","goType":"string","required":true},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"Version","key":"version","goType":"int","required":false},{"goName":"Reuse","key":"reuse","goType":"bool","required":false},{"goName":"ObfsOpts","key":"obfs-opts","goType":"map[string]any","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"socks5":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UserName","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false}],"ss":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Password","key":"password","goType":"string","required":true},{"goName":"Cipher","key":"cipher","goType":"string","required":true},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"Plugin","key":"plugin","goType":"string","required":false},{"goName":"PluginOpts","key":"plugin-opts","goType":"map[string]any","required":false},{"goName":"UDPOverTCP","key":"udp-over-tcp","goType":"bool","required":false},{"goName":"UDPOverTCPVersion","key":"udp-over-tcp-version","goType":"int","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"ssh":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UserName","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"PrivateKeyPassphrase","key":"private-key-passphrase","goType":"string","required":false},{"goName":"HostKey","key":"host-key","goType":"[]string","required":false},{"goName":"HostKeyAlgorithms","key":"host-key-algorithms","goType":"[]string","required":false}],"ssr":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Password","key":"password","goType":"string","required":true},{"goName":"Cipher","key":"cipher","goType":"string","required":true},{"goName":"Obfs","key":"obfs","goType":"string","required":true},{"goName":"ObfsParam","key":"obfs-param","goType":"string","required":false},{"goName":"Protocol","key":"protocol","goType":"string","required":true},{"goName":"ProtocolParam","key":"protocol-param","goType":"string","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false}],"sudoku":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Key","key":"key","goType":"string","required":true},{"goName":"AEADMethod","key":"aead-method","goType":"string","required":false},{"goName":"PaddingMin","key":"padding-min","goType":"*int","required":false},{"goName":"PaddingMax","key":"padding-max","goType":"*int","required":false},{"goName":"TableType","key":"table-type","goType":"string","required":false},{"goName":"EnablePureDownlink","key":"enable-pure-downlink","goType":"*bool","required":false},{"goName":"HTTPMask","key":"http-mask","goType":"*bool","required":false},{"goName":"HTTPMaskMode","key":"http-mask-mode","goType":"string","required":false},{"goName":"HTTPMaskTLS","key":"http-mask-tls","goType":"bool","required":false},{"goName":"HTTPMaskHost","key":"http-mask-host","goType":"string","required":false},{"goName":"PathRoot","key":"path-root","goType":"string","required":false},{"goName":"Multiplex","key":"multiplex","goType":"string","required":false},{"goName":"HTTPMaskMultiplex","key":"http-mask-multiplex","goType":"string","required":false},{"goName":"HTTPMaskOptions","key":"httpmask","goType":"*SudokuHTTPMaskOptions","required":false,"nested":[{"goName":"Disable","key":"disable","goType":"bool","required":false},{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"Host","key":"host","goType":"string","required":false},{"goName":"PathRoot","key":"path-root","goType":"string","required":false},{"goName":"Multiplex","key":"multiplex","goType":"string","required":false}]},{"goName":"CustomTable","key":"custom-table","goType":"string","required":false},{"goName":"CustomTables","key":"custom-tables","goType":"[]string","required":false}],"tailscale":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Hostname","key":"hostname","goType":"string","required":false},{"goName":"AuthKey","key":"auth-key","goType":"string","required":false},{"goName":"ControlURL","key":"control-url","goType":"string","required":false},{"goName":"StateDir","key":"state-dir","goType":"string","required":false},{"goName":"Ephemeral","key":"ephemeral","goType":"bool","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"AcceptRoutes","key":"accept-routes","goType":"*bool","required":false},{"goName":"ExitNode","key":"exit-node","goType":"string","required":false},{"goName":"ExitNodeAllowLANAccess","key":"exit-node-allow-lan-access","goType":"*bool","required":false}],"trojan":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Password","key":"password","goType":"string","required":true},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"Network","key":"network","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ShadowTLSOpts","key":"shadow-tls-opts","goType":"ShadowTLSOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Version","key":"version","goType":"int","required":false}]},{"goName":"RestlsOpts","key":"restls-opts","goType":"RestlsOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"VersionHint","key":"version-hint","goType":"string","required":false},{"goName":"RestlsScript","key":"restls-script","goType":"string","required":false}]},{"goName":"JLSOpts","key":"jls-opts","goType":"JLSOptions","required":false,"nested":[{"goName":"Username","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true}]},{"goName":"RealityOpts","key":"reality-opts","goType":"RealityOptions","required":false,"nested":[{"goName":"PublicKey","key":"public-key","goType":"string","required":true},{"goName":"ShortID","key":"short-id","goType":"string","required":false},{"goName":"SupportX25519MLKEM768","key":"support-x25519mlkem768","goType":"bool","required":false}]},{"goName":"GrpcOpts","key":"grpc-opts","goType":"GrpcOptions","required":false,"nested":[{"goName":"GrpcServiceName","key":"grpc-service-name","goType":"string","required":false},{"goName":"GrpcUserAgent","key":"grpc-user-agent","goType":"string","required":false},{"goName":"PingInterval","key":"ping-interval","goType":"int","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"int","required":false},{"goName":"MinStreams","key":"min-streams","goType":"int","required":false},{"goName":"MaxStreams","key":"max-streams","goType":"int","required":false}]},{"goName":"WSOpts","key":"ws-opts","goType":"WSOptions","required":false,"nested":[{"goName":"Path","key":"path","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"map[string]string","required":false},{"goName":"MaxEarlyData","key":"max-early-data","goType":"int","required":false},{"goName":"EarlyDataHeaderName","key":"early-data-header-name","goType":"string","required":false},{"goName":"V2rayHttpUpgrade","key":"v2ray-http-upgrade","goType":"bool","required":false},{"goName":"V2rayHttpUpgradeFastOpen","key":"v2ray-http-upgrade-fast-open","goType":"bool","required":false}]},{"goName":"SSOpts","key":"ss-opts","goType":"TrojanSSOption","required":false,"nested":[{"goName":"Enabled","key":"enabled","goType":"bool","required":false},{"goName":"Method","key":"method","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false}]},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"trusttunnel":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UserName","key":"username","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"HealthCheck","key":"health-check","goType":"bool","required":false},{"goName":"Quic","key":"quic","goType":"bool","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false},{"goName":"CWND","key":"cwnd","goType":"int","required":false},{"goName":"BBRProfile","key":"bbr-profile","goType":"string","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"int","required":false},{"goName":"MinStreams","key":"min-streams","goType":"int","required":false},{"goName":"MaxStreams","key":"max-streams","goType":"int","required":false}],"tuic":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"Token","key":"token","goType":"string","required":false},{"goName":"UUID","key":"uuid","goType":"string","required":false},{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Ip","key":"ip","goType":"string","required":false},{"goName":"HeartbeatInterval","key":"heartbeat-interval","goType":"int","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"ReduceRtt","key":"reduce-rtt","goType":"bool","required":false},{"goName":"RequestTimeout","key":"request-timeout","goType":"int","required":false},{"goName":"UdpRelayMode","key":"udp-relay-mode","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false},{"goName":"DisableSni","key":"disable-sni","goType":"bool","required":false},{"goName":"MaxUdpRelayPacketSize","key":"max-udp-relay-packet-size","goType":"int","required":false},{"goName":"FastOpen","key":"fast-open","goType":"bool","required":false},{"goName":"MaxOpenStreams","key":"max-open-streams","goType":"int","required":false},{"goName":"CWND","key":"cwnd","goType":"int","required":false},{"goName":"BBRProfile","key":"bbr-profile","goType":"string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ReceiveWindowConn","key":"recv-window-conn","goType":"int","required":false},{"goName":"ReceiveWindow","key":"recv-window","goType":"int","required":false},{"goName":"DisableMTUDiscovery","key":"disable-mtu-discovery","goType":"bool","required":false},{"goName":"MaxDatagramFrameSize","key":"max-datagram-frame-size","goType":"int","required":false},{"goName":"SNI","key":"sni","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"UDPOverStream","key":"udp-over-stream","goType":"bool","required":false},{"goName":"UDPOverStreamVersion","key":"udp-over-stream-version","goType":"int","required":false}],"vless":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UUID","key":"uuid","goType":"string","required":true},{"goName":"Flow","key":"flow","goType":"string","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"PacketAddr","key":"packet-addr","goType":"bool","required":false},{"goName":"XUDP","key":"xudp","goType":"bool","required":false},{"goName":"PacketEncoding","key":"packet-encoding","goType":"string","required":false},{"goName":"Encryption","key":"encryption","goType":"string","required":false},{"goName":"Network","key":"network","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ShadowTLSOpts","key":"shadow-tls-opts","goType":"ShadowTLSOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Version","key":"version","goType":"int","required":false}]},{"goName":"RestlsOpts","key":"restls-opts","goType":"RestlsOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"VersionHint","key":"version-hint","goType":"string","required":false},{"goName":"RestlsScript","key":"restls-script","goType":"string","required":false}]},{"goName":"JLSOpts","key":"jls-opts","goType":"JLSOptions","required":false,"nested":[{"goName":"Username","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true}]},{"goName":"RealityOpts","key":"reality-opts","goType":"RealityOptions","required":false,"nested":[{"goName":"PublicKey","key":"public-key","goType":"string","required":true},{"goName":"ShortID","key":"short-id","goType":"string","required":false},{"goName":"SupportX25519MLKEM768","key":"support-x25519mlkem768","goType":"bool","required":false}]},{"goName":"HTTPOpts","key":"http-opts","goType":"HTTPOptions","required":false,"nested":[{"goName":"Method","key":"method","goType":"string","required":false},{"goName":"Path","key":"path","goType":"[]string","required":false},{"goName":"Headers","key":"headers","goType":"map[string][]string","required":false}]},{"goName":"HTTP2Opts","key":"h2-opts","goType":"HTTP2Options","required":false,"nested":[{"goName":"Host","key":"host","goType":"[]string","required":false},{"goName":"Path","key":"path","goType":"string","required":false}]},{"goName":"GrpcOpts","key":"grpc-opts","goType":"GrpcOptions","required":false,"nested":[{"goName":"GrpcServiceName","key":"grpc-service-name","goType":"string","required":false},{"goName":"GrpcUserAgent","key":"grpc-user-agent","goType":"string","required":false},{"goName":"PingInterval","key":"ping-interval","goType":"int","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"int","required":false},{"goName":"MinStreams","key":"min-streams","goType":"int","required":false},{"goName":"MaxStreams","key":"max-streams","goType":"int","required":false}]},{"goName":"WSOpts","key":"ws-opts","goType":"WSOptions","required":false,"nested":[{"goName":"Path","key":"path","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"map[string]string","required":false},{"goName":"MaxEarlyData","key":"max-early-data","goType":"int","required":false},{"goName":"EarlyDataHeaderName","key":"early-data-header-name","goType":"string","required":false},{"goName":"V2rayHttpUpgrade","key":"v2ray-http-upgrade","goType":"bool","required":false},{"goName":"V2rayHttpUpgradeFastOpen","key":"v2ray-http-upgrade-fast-open","goType":"bool","required":false}]},{"goName":"XHTTPOpts","key":"xhttp-opts","goType":"XHTTPOptions","required":false,"nested":[{"goName":"Path","key":"path","goType":"string","required":false},{"goName":"Host","key":"host","goType":"string","required":false},{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"map[string]string","required":false},{"goName":"NoGRPCHeader","key":"no-grpc-header","goType":"bool","required":false},{"goName":"XPaddingBytes","key":"x-padding-bytes","goType":"string","required":false},{"goName":"XPaddingObfsMode","key":"x-padding-obfs-mode","goType":"bool","required":false},{"goName":"XPaddingKey","key":"x-padding-key","goType":"string","required":false},{"goName":"XPaddingHeader","key":"x-padding-header","goType":"string","required":false},{"goName":"XPaddingPlacement","key":"x-padding-placement","goType":"string","required":false},{"goName":"XPaddingMethod","key":"x-padding-method","goType":"string","required":false},{"goName":"UplinkHTTPMethod","key":"uplink-http-method","goType":"string","required":false},{"goName":"SessionPlacement","key":"session-placement","goType":"string","required":false},{"goName":"SessionKey","key":"session-key","goType":"string","required":false},{"goName":"SessionTable","key":"session-table","goType":"string","required":false},{"goName":"SessionLength","key":"session-length","goType":"string","required":false},{"goName":"SeqPlacement","key":"seq-placement","goType":"string","required":false},{"goName":"SeqKey","key":"seq-key","goType":"string","required":false},{"goName":"UplinkDataPlacement","key":"uplink-data-placement","goType":"string","required":false},{"goName":"UplinkDataKey","key":"uplink-data-key","goType":"string","required":false},{"goName":"UplinkChunkSize","key":"uplink-chunk-size","goType":"string","required":false},{"goName":"ScMaxEachPostBytes","key":"sc-max-each-post-bytes","goType":"string","required":false},{"goName":"ScMinPostsIntervalMs","key":"sc-min-posts-interval-ms","goType":"string","required":false},{"goName":"ReuseSettings","key":"reuse-settings","goType":"*XHTTPReuseSettings","required":false,"nested":[{"goName":"MaxConcurrency","key":"max-concurrency","goType":"string","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"string","required":false},{"goName":"CMaxReuseTimes","key":"c-max-reuse-times","goType":"string","required":false},{"goName":"HMaxRequestTimes","key":"h-max-request-times","goType":"string","required":false},{"goName":"HMaxReusableSecs","key":"h-max-reusable-secs","goType":"string","required":false},{"goName":"HKeepAlivePeriod","key":"h-keep-alive-period","goType":"int","required":false}]},{"goName":"DownloadSettings","key":"download-settings","goType":"*XHTTPDownloadSettings","required":false,"nested":[{"goName":"Path","key":"path","goType":"*string","required":false},{"goName":"Host","key":"host","goType":"*string","required":false},{"goName":"Headers","key":"headers","goType":"*map[string]string","required":false},{"goName":"ReuseSettings","key":"reuse-settings","goType":"*XHTTPReuseSettings","required":false,"nested":[{"goName":"MaxConcurrency","key":"max-concurrency","goType":"string","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"string","required":false},{"goName":"CMaxReuseTimes","key":"c-max-reuse-times","goType":"string","required":false},{"goName":"HMaxRequestTimes","key":"h-max-request-times","goType":"string","required":false},{"goName":"HMaxReusableSecs","key":"h-max-reusable-secs","goType":"string","required":false},{"goName":"HKeepAlivePeriod","key":"h-keep-alive-period","goType":"int","required":false}]},{"goName":"Server","key":"server","goType":"*string","required":false},{"goName":"Port","key":"port","goType":"*int","required":false},{"goName":"TLS","key":"tls","goType":"*bool","required":false},{"goName":"ALPN","key":"alpn","goType":"*[]string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"*ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ShadowTLSOpts","key":"shadow-tls-opts","goType":"*ShadowTLSOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Version","key":"version","goType":"int","required":false}]},{"goName":"RestlsOpts","key":"restls-opts","goType":"*RestlsOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"VersionHint","key":"version-hint","goType":"string","required":false},{"goName":"RestlsScript","key":"restls-script","goType":"string","required":false}]},{"goName":"JLSOpts","key":"jls-opts","goType":"*JLSOptions","required":false,"nested":[{"goName":"Username","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true}]},{"goName":"RealityOpts","key":"reality-opts","goType":"*RealityOptions","required":false,"nested":[{"goName":"PublicKey","key":"public-key","goType":"string","required":true},{"goName":"ShortID","key":"short-id","goType":"string","required":false},{"goName":"SupportX25519MLKEM768","key":"support-x25519mlkem768","goType":"bool","required":false}]},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"*bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"*string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"*string","required":false},{"goName":"Certificate","key":"certificate","goType":"*string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"*string","required":false},{"goName":"ServerName","key":"servername","goType":"*string","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"*string","required":false}]}]},{"goName":"WSHeaders","key":"ws-headers","goType":"map[string]string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ServerName","key":"servername","goType":"string","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"vmess":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Server","key":"server","goType":"string","required":true},{"goName":"Port","key":"port","goType":"int","required":true},{"goName":"UUID","key":"uuid","goType":"string","required":true},{"goName":"AlterID","key":"alterId","goType":"int","required":true},{"goName":"Cipher","key":"cipher","goType":"string","required":true},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"Network","key":"network","goType":"string","required":false},{"goName":"TLS","key":"tls","goType":"bool","required":false},{"goName":"ALPN","key":"alpn","goType":"[]string","required":false},{"goName":"SkipCertVerify","key":"skip-cert-verify","goType":"bool","required":false},{"goName":"NameCertVerify","key":"name-cert-verify","goType":"string","required":false},{"goName":"Fingerprint","key":"fingerprint","goType":"string","required":false},{"goName":"Certificate","key":"certificate","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":false},{"goName":"ServerName","key":"servername","goType":"string","required":false},{"goName":"ECHOpts","key":"ech-opts","goType":"ECHOptions","required":false,"nested":[{"goName":"Enable","key":"enable","goType":"bool","required":false},{"goName":"Config","key":"config","goType":"string","required":false},{"goName":"QueryServerName","key":"query-server-name","goType":"string","required":false}]},{"goName":"ShadowTLSOpts","key":"shadow-tls-opts","goType":"ShadowTLSOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"Version","key":"version","goType":"int","required":false}]},{"goName":"RestlsOpts","key":"restls-opts","goType":"RestlsOptions","required":false,"nested":[{"goName":"Password","key":"password","goType":"string","required":false},{"goName":"VersionHint","key":"version-hint","goType":"string","required":false},{"goName":"RestlsScript","key":"restls-script","goType":"string","required":false}]},{"goName":"JLSOpts","key":"jls-opts","goType":"JLSOptions","required":false,"nested":[{"goName":"Username","key":"username","goType":"string","required":true},{"goName":"Password","key":"password","goType":"string","required":true}]},{"goName":"RealityOpts","key":"reality-opts","goType":"RealityOptions","required":false,"nested":[{"goName":"PublicKey","key":"public-key","goType":"string","required":true},{"goName":"ShortID","key":"short-id","goType":"string","required":false},{"goName":"SupportX25519MLKEM768","key":"support-x25519mlkem768","goType":"bool","required":false}]},{"goName":"TLSMirrorOpts","key":"tlsmirror-opts","goType":"TLSMirrorOptions","required":false,"nested":[{"goName":"PrimaryKey","key":"primary-key","goType":"string","required":false},{"goName":"ExplicitNonceCipherSuites","key":"explicit-nonce-ciphersuites","goType":"[]uint16","required":false},{"goName":"DeferInstanceDerivedWriteTime","key":"defer-instance-derived-write-time","goType":"TLSMirrorTimeSpec","required":false,"nested":[{"goName":"BaseNanoseconds","key":"base-nanoseconds","goType":"uint64","required":false},{"goName":"UniformRandomMultiplierNanoseconds","key":"uniform-random-multiplier-nanoseconds","goType":"uint64","required":false}]},{"goName":"TransportLayerPadding","key":"transport-layer-padding","goType":"TLSMirrorTransportLayerPadding","required":false,"nested":[{"goName":"Enabled","key":"enabled","goType":"bool","required":false}]},{"goName":"ConnectionEnrolment","key":"connection-enrolment","goType":"*TLSMirrorConnectionEnrolment","required":false,"nested":[{"goName":"PrimaryIngressOutbound","key":"primary-ingress-outbound","goType":"string","required":false},{"goName":"PrimaryEgressOutbound","key":"primary-egress-outbound","goType":"string","required":false}]},{"goName":"EmbeddedTrafficGenerator","key":"embedded-traffic-generator","goType":"TLSMirrorTrafficGenerator","required":false,"nested":[{"goName":"Steps","key":"steps","goType":"[]TLSMirrorTrafficStep","required":false,"nested":[{"goName":"Name","key":"name","goType":"string","required":false},{"goName":"Host","key":"host","goType":"string","required":false},{"goName":"Path","key":"path","goType":"string","required":false},{"goName":"Method","key":"method","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"[]TLSMirrorTrafficHeader","required":false,"nested":[{"goName":"Name","key":"name","goType":"string","required":false},{"goName":"Value","key":"value","goType":"string","required":false},{"goName":"Values","key":"values","goType":"[]string","required":false}]},{"goName":"NextStep","key":"next-step","goType":"[]TLSMirrorTrafficTransferCandidate","required":false,"nested":[{"goName":"Weight","key":"weight","goType":"int32","required":false},{"goName":"GotoLocation","key":"goto-location","goType":"int","required":false}]},{"goName":"ConnectionReady","key":"connection-ready","goType":"bool","required":false},{"goName":"ConnectionRecallExit","key":"connection-recall-exit","goType":"bool","required":false},{"goName":"WaitTime","key":"wait-time","goType":"TLSMirrorTimeSpec","required":false,"nested":[{"goName":"BaseNanoseconds","key":"base-nanoseconds","goType":"uint64","required":false},{"goName":"UniformRandomMultiplierNanoseconds","key":"uniform-random-multiplier-nanoseconds","goType":"uint64","required":false}]},{"goName":"H2DoNotWaitForDownloadFinish","key":"h2-do-not-wait-for-download-finish","goType":"bool","required":false}]}]},{"goName":"SequenceWatermarkingEnabled","key":"sequence-watermarking-enabled","goType":"bool","required":false}]},{"goName":"MekyaOpts","key":"mekya-opts","goType":"MekyaOptions","required":false,"nested":[{"goName":"URL","key":"url","goType":"string","required":false},{"goName":"H2PoolSize","key":"h2-pool-size","goType":"int","required":false},{"goName":"MaxWriteDelay","key":"max-write-delay","goType":"int","required":false},{"goName":"MaxRequestSize","key":"max-request-size","goType":"int","required":false},{"goName":"PollingIntervalInitial","key":"polling-interval-initial","goType":"int","required":false},{"goName":"MaxWriteSize","key":"max-write-size","goType":"int","required":false},{"goName":"MaxWriteDurationMs","key":"max-write-duration-ms","goType":"int","required":false},{"goName":"MaxSimultaneousWriteConnection","key":"max-simultaneous-write-connection","goType":"int","required":false},{"goName":"PacketWritingBuffer","key":"packet-writing-buffer","goType":"int","required":false},{"goName":"KCP","key":"kcp","goType":"MKCPOptions","required":false,"nested":[{"goName":"MTU","key":"mtu","goType":"uint32","required":false},{"goName":"TTI","key":"tti","goType":"uint32","required":false},{"goName":"UplinkCapacity","key":"uplink-capacity","goType":"uint32","required":false},{"goName":"DownlinkCapacity","key":"downlink-capacity","goType":"uint32","required":false},{"goName":"Congestion","key":"congestion","goType":"bool","required":false},{"goName":"WriteBuffer","key":"write-buffer","goType":"uint32","required":false},{"goName":"ReadBuffer","key":"read-buffer","goType":"uint32","required":false},{"goName":"Seed","key":"seed","goType":"string","required":false},{"goName":"Header","key":"header","goType":"string","required":false}]}]},{"goName":"MKCPOpts","key":"mkcp-opts","goType":"MKCPOptions","required":false,"nested":[{"goName":"MTU","key":"mtu","goType":"uint32","required":false},{"goName":"TTI","key":"tti","goType":"uint32","required":false},{"goName":"UplinkCapacity","key":"uplink-capacity","goType":"uint32","required":false},{"goName":"DownlinkCapacity","key":"downlink-capacity","goType":"uint32","required":false},{"goName":"Congestion","key":"congestion","goType":"bool","required":false},{"goName":"WriteBuffer","key":"write-buffer","goType":"uint32","required":false},{"goName":"ReadBuffer","key":"read-buffer","goType":"uint32","required":false},{"goName":"Seed","key":"seed","goType":"string","required":false},{"goName":"Header","key":"header","goType":"string","required":false}]},{"goName":"HTTPOpts","key":"http-opts","goType":"HTTPOptions","required":false,"nested":[{"goName":"Method","key":"method","goType":"string","required":false},{"goName":"Path","key":"path","goType":"[]string","required":false},{"goName":"Headers","key":"headers","goType":"map[string][]string","required":false}]},{"goName":"HTTP2Opts","key":"h2-opts","goType":"HTTP2Options","required":false,"nested":[{"goName":"Host","key":"host","goType":"[]string","required":false},{"goName":"Path","key":"path","goType":"string","required":false}]},{"goName":"GrpcOpts","key":"grpc-opts","goType":"GrpcOptions","required":false,"nested":[{"goName":"GrpcServiceName","key":"grpc-service-name","goType":"string","required":false},{"goName":"GrpcUserAgent","key":"grpc-user-agent","goType":"string","required":false},{"goName":"PingInterval","key":"ping-interval","goType":"int","required":false},{"goName":"MaxConnections","key":"max-connections","goType":"int","required":false},{"goName":"MinStreams","key":"min-streams","goType":"int","required":false},{"goName":"MaxStreams","key":"max-streams","goType":"int","required":false}]},{"goName":"WSOpts","key":"ws-opts","goType":"WSOptions","required":false,"nested":[{"goName":"Path","key":"path","goType":"string","required":false},{"goName":"Headers","key":"headers","goType":"map[string]string","required":false},{"goName":"MaxEarlyData","key":"max-early-data","goType":"int","required":false},{"goName":"EarlyDataHeaderName","key":"early-data-header-name","goType":"string","required":false},{"goName":"V2rayHttpUpgrade","key":"v2ray-http-upgrade","goType":"bool","required":false},{"goName":"V2rayHttpUpgradeFastOpen","key":"v2ray-http-upgrade-fast-open","goType":"bool","required":false}]},{"goName":"PacketAddr","key":"packet-addr","goType":"bool","required":false},{"goName":"XUDP","key":"xudp","goType":"bool","required":false},{"goName":"PacketEncoding","key":"packet-encoding","goType":"string","required":false},{"goName":"GlobalPadding","key":"global-padding","goType":"bool","required":false},{"goName":"AuthenticatedLength","key":"authenticated-length","goType":"bool","required":false},{"goName":"ClientFingerprint","key":"client-fingerprint","goType":"string","required":false}],"wireguard":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Server","key":"server","goType":"string","required":false},{"goName":"Port","key":"port","goType":"int","required":false},{"goName":"PublicKey","key":"public-key","goType":"string","required":false},{"goName":"PreSharedKey","key":"pre-shared-key","goType":"string","required":false},{"goName":"Reserved","key":"reserved","goType":"[]uint8","required":false},{"goName":"AllowedIPs","key":"allowed-ips","goType":"[]string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Ip","key":"ip","goType":"string","required":false},{"goName":"Ipv6","key":"ipv6","goType":"string","required":false},{"goName":"PrivateKey","key":"private-key","goType":"string","required":true},{"goName":"Workers","key":"workers","goType":"int","required":false},{"goName":"MTU","key":"mtu","goType":"int","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"PersistentKeepalive","key":"persistent-keepalive","goType":"int","required":false},{"goName":"IPStack","key":"ip-stack","goType":"IPStackOption","required":false,"nested":[{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false}]},{"goName":"AmneziaWGOption","key":"amnezia-wg-option","goType":"*AmneziaWGOption","required":false,"nested":[{"goName":"Version","key":"version","goType":"int","required":false},{"goName":"JC","key":"jc","goType":"int","required":false},{"goName":"JMin","key":"jmin","goType":"int","required":false},{"goName":"JMax","key":"jmax","goType":"int","required":false},{"goName":"S1","key":"s1","goType":"int","required":false},{"goName":"S2","key":"s2","goType":"int","required":false},{"goName":"S3","key":"s3","goType":"int","required":false},{"goName":"S4","key":"s4","goType":"int","required":false},{"goName":"H1","key":"h1","goType":"string","required":false},{"goName":"H2","key":"h2","goType":"string","required":false},{"goName":"H3","key":"h3","goType":"string","required":false},{"goName":"H4","key":"h4","goType":"string","required":false},{"goName":"I1","key":"i1","goType":"string","required":false},{"goName":"I2","key":"i2","goType":"string","required":false},{"goName":"I3","key":"i3","goType":"string","required":false},{"goName":"I4","key":"i4","goType":"string","required":false},{"goName":"I5","key":"i5","goType":"string","required":false},{"goName":"J1","key":"j1","goType":"string","required":false},{"goName":"J2","key":"j2","goType":"string","required":false},{"goName":"J3","key":"j3","goType":"string","required":false},{"goName":"Itime","key":"itime","goType":"int64","required":false},{"goName":"HeaderProtectionKey","key":"header-protection-key","goType":"string","required":false},{"goName":"ContentPaddingAddition","key":"content-padding-addition","goType":"string","required":false},{"goName":"RekeyAfterTime","key":"rekey-after-time","goType":"string","required":false},{"goName":"RekeyTimeout","key":"rekey-timeout","goType":"string","required":false},{"goName":"RejectAfterTime","key":"reject-after-time","goType":"string","required":false},{"goName":"KeepaliveTimeout","key":"keepalive-timeout","goType":"string","required":false},{"goName":"MaxHandshakeAttempts","key":"max-handshake-attempts","goType":"string","required":false},{"goName":"RandomTrailers","key":"random-trailers","goType":"bool","required":false},{"goName":"DisableCookies","key":"disable-cookies","goType":"bool","required":false}]},{"goName":"Peers","key":"peers","goType":"[]WireGuardPeerOption","required":false,"nested":[{"goName":"Server","key":"server","goType":"string","required":false},{"goName":"Port","key":"port","goType":"int","required":false},{"goName":"PublicKey","key":"public-key","goType":"string","required":false},{"goName":"PreSharedKey","key":"pre-shared-key","goType":"string","required":false},{"goName":"Reserved","key":"reserved","goType":"[]uint8","required":false},{"goName":"AllowedIPs","key":"allowed-ips","goType":"[]string","required":false}]},{"goName":"RemoteDnsResolve","key":"remote-dns-resolve","goType":"bool","required":false},{"goName":"Dns","key":"dns","goType":"[]string","required":false},{"goName":"RefreshServerIPInterval","key":"refresh-server-ip-interval","goType":"int","required":false}],"zerotier":[{"goName":"TFO","key":"tfo","goType":"bool","required":false},{"goName":"MPTCP","key":"mptcp","goType":"bool","required":false},{"goName":"Interface","key":"interface-name","goType":"string","required":false},{"goName":"RoutingMark","key":"routing-mark","goType":"int","required":false},{"goName":"IPVersion","key":"ip-version","goType":"C.DNSPrefer","required":false},{"goName":"DialerProxy","key":"dialer-proxy","goType":"string","required":false},{"goName":"Name","key":"name","goType":"string","required":true},{"goName":"Network","key":"network","goType":"string","required":true},{"goName":"StateDir","key":"state-dir","goType":"string","required":false},{"goName":"Planet","key":"planet","goType":"string","required":false},{"goName":"MTU","key":"mtu","goType":"int","required":false},{"goName":"IPStack","key":"ip-stack","goType":"IPStackOption","required":false,"nested":[{"goName":"Mode","key":"mode","goType":"string","required":false},{"goName":"CongestionController","key":"congestion-controller","goType":"string","required":false}]},{"goName":"PhysicalMTU","key":"physical-mtu","goType":"int","required":false},{"goName":"UDP","key":"udp","goType":"bool","required":false},{"goName":"RemoteDnsResolve","key":"remote-dns-resolve","goType":"bool","required":false},{"goName":"Dns","key":"dns","goType":"[]string","required":false},{"goName":"LowBandwidth","key":"low-bandwidth","goType":"bool","required":false},{"goName":"EncryptedHello","key":"encrypted-hello","goType":"bool","required":false},{"goName":"PrimaryPort","key":"primary-port","goType":"int","required":false},{"goName":"SecondaryPort","key":"secondary-port","goType":"int","required":false},{"goName":"TCPFallbackMode","key":"tcp-fallback-mode","goType":"string","required":false},{"goName":"TCPFallbackRelay","key":"tcp-fallback-relay","goType":"string","required":false},{"goName":"Orbit","key":"orbit","goType":"[]ZeroTierOrbitOption","required":false,"nested":[{"goName":"World","key":"world","goType":"string","required":true},{"goName":"Seed","key":"seed","goType":"string","required":true}]},{"goName":"RemoteTraceTarget","key":"remote-trace-target","goType":"string","required":false},{"goName":"RemoteTraceLevel","key":"remote-trace-level","goType":"uint64","required":false}]}"""#
}

enum ProxyConfigurationInspector {
    static func detailsByNodeName(yaml: String) -> [String: ProxyProtocolDetails] {
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: yaml) else { return [:] }
        return parsed.memo("proxies.protocolDetails") { detailsByNodeName(root: parsed.root) }
    }

    static func detailsByNodeName(root: [String: Any]) -> [String: ProxyProtocolDetails] {
        guard let proxies = root["proxies"] as? [[String: Any]] else { return [:] }
         
         
         
         
         
        return Dictionary(proxies.compactMap { mapping -> (String, ProxyProtocolDetails)? in
            guard let name = mapping["name"] as? String,
                  !name.isEmpty,
                  let details = ProxyProtocolCatalog.details(for: mapping) else { return nil }
            return (name, details)
        }, uniquingKeysWith: { first, _ in first })
    }

    static func activeDetails() -> [String: ProxyProtocolDetails] {


         
         
        guard let yaml = ActiveConfigurationText.current() else { return [:] }
        return detailsByNodeName(yaml: yaml)
    }
}
