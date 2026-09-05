import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorFieldChoices {
     
     
     
     
     
     
     
    private static let clientFingerprints = [
        "chrome", "firefox", "safari", "ios", "android", "edge", "360", "qq",
        "random", "chrome120", "firefox120", "safari16",
        "chrome_psk", "chrome_psk_shuffle", "chrome_padding_psk_shuffle",
        "chrome_pq", "chrome_pq_psk", "randomized",
    ]

     
     
     
    private static let shadowsocksCiphers = ["aes-128-gcm", "aes-256-gcm", "chacha20-ietf-poly1305", "2022-blake3-aes-128-ccm", "2022-blake3-aes-128-gcm", "2022-blake3-aes-256-ccm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305", "2022-blake3-chacha8-poly1305", "aegis-128l", "aegis-256", "aes-128-ccm", "aes-128-cfb", "aes-128-ctr", "aes-128-gcm-siv", "aes-192-ccm", "aes-192-cfb", "aes-192-ctr", "aes-192-gcm", "aes-256-ccm", "aes-256-cfb", "aes-256-ctr", "aes-256-gcm-siv", "aez-384", "ascon128", "ascon128a", "chacha20", "chacha20-ietf", "chacha8-ietf-poly1305", "deoxys-ii-256-128", "lea-128-gcm", "lea-192-gcm", "lea-256-gcm", "none", "rabbit128-poly1305", "rc4-md5", "xchacha20", "xchacha20-ietf-poly1305", "xchacha8-ietf-poly1305"]

    private static let congestionControllers = [
        "bbr", "cubic", "new_reno", "bbr_meta_v1", "bbr_meta_v2",
    ]
    private static let bbrProfiles = ["standard", "conservative", "aggressive"]

     
     
     
     
     
     
     
     
     
     
    private static let ipStackCongestionControllers = ["cubic", "reno", "bbr", "bbr3"]

    static let choicesByField: [String: [String]] = [
         
         
         
         
         
        "*.ip-version": ["dual", "ipv4", "ipv6", "ipv4-prefer", "ipv6-prefer"],
         
         
         
         
         
         
        "anytls.client-fingerprint": Self.clientFingerprints,
        "gost-relay.client-fingerprint": Self.clientFingerprints,
        "snell.client-fingerprint": Self.clientFingerprints,
        "ss.client-fingerprint": Self.clientFingerprints,
        "trojan.client-fingerprint": Self.clientFingerprints,
        "trusttunnel.client-fingerprint": Self.clientFingerprints,
        "vless.client-fingerprint": Self.clientFingerprints,
        "vmess.client-fingerprint": Self.clientFingerprints,
         
        "*.smux.protocol": ["h2mux", "smux", "yamux"],
         
         
         
        "tuic.udp-relay-mode": ["native", "quic"],
         
         
         
         
         
         
        "masque.congestion-controller": Self.congestionControllers,
        "shadowquic.congestion-controller": Self.congestionControllers,
        "trusttunnel.congestion-controller": Self.congestionControllers,
         
         
         
        "hysteria2.bbr-profile": Self.bbrProfiles,
        "masque.bbr-profile": Self.bbrProfiles,
        "shadowquic.bbr-profile": Self.bbrProfiles,
        "trusttunnel.bbr-profile": Self.bbrProfiles,
        "tuic.bbr-profile": Self.bbrProfiles,
         
         
         
         
         
        "masque.network": ["h3", "h2", "h3-l4proxy"],
         
         
         
         
         
         
         
        "hysteria.protocol": ["udp", "wechat-video"],
         
         
         
         
        "hysteria2.obfs": ["salamander", "gecko"],
         
         
         
         
         
         
        "mieru.transport": ["TCP", "UDP"],
         
         
         
        "openvpn.auth": ["SHA256", "SHA1", "SHA384", "SHA512", "MD5"],
        "openvpn.cipher": ["AES-128-GCM", "AES-192-GCM", "AES-256-GCM", "AES-128-CBC", "AES-192-CBC", "AES-256-CBC", "CHACHA20-POLY1305"],
        "openvpn.proto": ["udp", "tcp"],
         
         
         
         
         
         
         
         
         
         
         
        "ss.cipher": Self.shadowsocksCiphers,
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        "ssr.cipher": ["aes-256-cfb", "aes-128-cfb", "aes-192-cfb", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr", "chacha20-ietf", "chacha20", "xchacha20", "rc4-md5", "none"],
        "ssr.obfs": ["plain", "http_simple", "http_post", "random_head", "tls1.2_ticket_auth", "tls1.2_ticket_fastauth"],
        "ssr.protocol": ["origin", "auth_sha1_v4", "auth_aes128_md5", "auth_aes128_sha1", "auth_chain_a", "auth_chain_b"],
         
         
         
         
         
        "snell.version": ["1", "2", "3", "4", "5"],
        "sudoku.aead-method": ["aes-128-gcm", "chacha20-poly1305", "none"],
         
         
         
         
         
        "sudoku.table-type": ["prefer_ascii", "prefer_entropy", "up_ascii_down_entropy", "up_entropy_down_ascii"],
        "sudoku.multiplex": ["off", "auto", "on"],
        "trojan.network": ["tcp", "ws", "grpc"],
         
         
         
         
        "vless.network": ["tcp", "ws", "http", "h2", "grpc", "xhttp"],
         
         
        "vless.flow": ["xtls-rprx-vision"],
         
         
        "ss.plugin": ["obfs", "v2ray-plugin", "gost-plugin", "shadow-tls", "restls", "jls", "kcptun"],
         
         
         
        "ss.udp-over-tcp-version": ["1", "2"],
         
        "snell.obfs-opts.mode": ["tls", "http", "shadow-tls", "restls", "jls"],
         
         
        "mieru.multiplexing": [
            "MULTIPLEXING_DEFAULT", "MULTIPLEXING_OFF", "MULTIPLEXING_LOW",
            "MULTIPLEXING_MIDDLE", "MULTIPLEXING_HIGH",
        ],
        "mieru.handshake-mode": [
            "HANDSHAKE_DEFAULT", "HANDSHAKE_STANDARD", "HANDSHAKE_NO_WAIT",
        ],
         
        "shadowquic.quic-versions": ["v1", "v2"],
         
         
        "sudoku.http-mask-mode": ["legacy", "stream", "poll", "auto", "ws"],
        "sudoku.httpmask.mode": ["legacy", "stream", "poll", "auto", "ws"],
         
         
         
        "sudoku.http-mask-multiplex": ["off", "auto", "on"],
        "sudoku.httpmask.multiplex": ["off", "auto", "on"],
         
         
        "openvpn.key-direction": ["0", "1"],
         
        "openvpn.dev": ["tun"],
         
         
        "hysteria.obfs-protocol": ["udp", "wechat-video", "faketcp"],
         
         
        "vmess.packet-encoding": ["packetaddr", "packet", "xudp"],
         
         
        "vless.xhttp-opts.mode": ["stream-one", "stream-up", "packet-up"],
         
        "snell.obfs-opts.version": ["1", "2", "3"],
        "trojan.shadow-tls-opts.version": ["1", "2", "3"],
        "vmess.shadow-tls-opts.version": ["1", "2", "3"],
        "vless.shadow-tls-opts.version": ["1", "2", "3"],
        "anytls.shadow-tls-opts.version": ["1", "2", "3"],
        "ss.plugin-opts.version": ["1", "2", "3"],
         
         
        "ss.plugin-opts.mode": ["tls", "http", "websocket"],
         
         
        "vmess.cipher": ["auto", "none", "zero", "aes-128-cfb", "aes-128-gcm", "chacha20-poly1305"],
         
         
        "tuic.congestion-controller": Self.congestionControllers,
         
         
         
        "trojan.ss-opts.method": Self.shadowsocksCiphers,
         
         
        "vmess.network": ["tcp", "ws", "http", "h2", "grpc", "mkcp", "kcp", "mekya"],
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        "masque.ip-stack.mode": ["auto", "gvisor", "mips"],
        "openvpn.ip-stack.mode": ["auto", "gvisor", "mips"],
        "wireguard.ip-stack.mode": ["auto", "gvisor", "mips"],
        "zerotier.ip-stack.mode": ["auto", "gvisor", "mips"],
         
         
         
         
         
         
         
        "masque.ip-stack.congestion-controller": Self.ipStackCongestionControllers,
        "openvpn.ip-stack.congestion-controller": Self.ipStackCongestionControllers,
        "wireguard.ip-stack.congestion-controller": Self.ipStackCongestionControllers,
        "zerotier.ip-stack.congestion-controller": Self.ipStackCongestionControllers,

         
         
         
        "zerotier.tcp-fallback-mode": ["auto", "force", "disable"],
    ]

     
     
     
    static func choices(forType typeID: String, key: String) -> [String] {
        choicesByField["\(typeID.lowercased()).\(key)"]
            ?? choicesByField["*.\(key)"]
            ?? []
    }
}
