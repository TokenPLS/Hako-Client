import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorNewNodeDefaults {
    static let valuesByType: [String: [String: Any]] = [
         
         
         
         
         
         
        "vmess": ["alterId": 0, "cipher": "auto"],
        "anytls": ["udp": true],
        "gost-relay": ["udp": true],
        "masque": ["udp": true],
        "mieru": ["udp": true, "transport": "TCP"],
        "socks5": ["udp": true],
         
         
         
        "ss": ["udp": true, "cipher": "aes-128-gcm"],
         
         
         
         
        "ssr": [
            "udp": true, "cipher": "aes-256-cfb",
            "protocol": "origin", "obfs": "plain",
        ],
        "trojan": ["udp": true],
         
         
        "trusttunnel": ["udp": true],
        "wireguard": ["udp": true],
    ]

     
     
    static func applying(
        to mapping: inout [String: Any],
        typeID: String
    ) {
        guard let defaults = valuesByType[typeID] else { return }
        let schema = Set(
            ProxyProtocolEditorSchema.fields(for: typeID).map(\.key)
        )
        for (key, value) in defaults
        where mapping[key] == nil && schema.contains(key) {
            mapping[key] = value
        }
    }
}
