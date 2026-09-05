import Foundation

 
 
 
 
 
 
 
 
 
 
 
struct OverridePatch {
    private var root: OrderedJSON  

     
    static let orderSensitivePolicyKeys: Set<String> = [
        "nameserver-policy", "proxy-server-nameserver-policy",
    ]

     
     
     
     
    static let globalRuntimeKeys: Set<String> = [
        "mixed-port", "socks-port", "port", "redir-port", "tproxy-port",
        "mode", "allow-lan", "log-level", "ipv6", "find-process-mode",
        "keep-alive-interval", "keep-alive-idle", "disable-keep-alive",
        "unified-delay", "tcp-concurrent", "tun", "dns", "geox-url",
        "geodata-loader", "geosite-matcher", "global-ua",
        "external-controller", "hosts", "geo-auto-update",
        "geo-update-interval",
         
         
         
         
         
         
         
         
        "experimental", "profile",
    ]

    static let networkRuntimeKeys: Set<String> = [
        "ipv6", "unified-delay", "tcp-concurrent", "disable-keep-alive",
        "keep-alive-idle", "keep-alive-interval",
    ]

    static let runtimeTrustKeys: Set<String> = [
        "log-level", "global-ua", "geodata-loader", "geosite-matcher",
        "experimental", "profile",
    ]

    init(patchJSON: String) {
        if !patchJSON.isEmpty,
           let parsed = try? OrderedJSON.parse(patchJSON),
           case .object = parsed {
            root = parsed
        } else {
            root = .object([])
        }
    }

    private init(root: OrderedJSON) {
        self.root = root
    }

     
     
    var patchJSON: String {
        guard case let .object(pairs) = root, !pairs.isEmpty else { return "" }
        return root.canonicalSerialized(preservingOrderForKeys: Self.orderSensitivePolicyKeys)
    }

     

    private func get<T>(_ path: [String]) -> T? {
        root.node(at: path)?.foundationValue as? T
    }

    private mutating func set(_ path: [String], _ value: Any?) {
        root = root.setting(path: path, to: value.map { OrderedJSON.from(foundation: $0) })
    }

     
    func value(at path: [String]) -> Any? { get(path) }

     
     
    mutating func setValue(_ value: Any?, at path: [String]) { set(path, value) }

     
    var topLevelKeys: [String] {
        guard case let .object(pairs) = root else { return [] }
        return pairs.map(\.key)
    }

     
    var globalRuntimePatch: OverridePatch {
        retainingTopLevelKeys(Self.globalRuntimeKeys)
    }

     
     
     
    var profileOwnedPatch: OverridePatch {
        removingTopLevelKeys(Self.globalRuntimeKeys)
    }

    func retainingTopLevelKeys(_ keys: Set<String>) -> OverridePatch {
        guard case let .object(pairs) = root else {
            return OverridePatch(root: .object([]))
        }
        return OverridePatch(
            root: .object(pairs.filter { keys.contains($0.key) })
        )
    }

    func removingTopLevelKeys(_ keys: Set<String>) -> OverridePatch {
        guard case let .object(pairs) = root else {
            return OverridePatch(root: .object([]))
        }
        return OverridePatch(
            root: .object(pairs.filter { !keys.contains($0.key) })
        )
    }

     
     
     
    mutating func replaceTopLevelKeys(
        _ keys: Set<String>,
        with source: OverridePatch
    ) {
        for key in keys.sorted() {
            root = root.setting(path: [key], to: source.root.node(at: [key]))
        }
    }

     
     
     
    mutating func overlayTopLevelKeys(
        _ keys: Set<String>,
        from source: OverridePatch
    ) {
        for key in keys.sorted() {
            guard let value = source.root.node(at: [key]) else {
                continue
            }
            root = root.setting(path: [key], to: value)
        }
    }

     

    var mode: String? {
        get { get(["mode"]) }
        set { set(["mode"], newValue) }
    }

    var logLevel: String? {
        get { get(["log-level"]) }
        set { set(["log-level"], newValue) }
    }

    var ipv6: Bool? {
        get { get(["ipv6"]) }
        set { set(["ipv6"], newValue) }
    }

    var unifiedDelay: Bool? {
        get { get(["unified-delay"]) }
        set { set(["unified-delay"], newValue) }
    }

    var tcpConcurrent: Bool? {
        get { get(["tcp-concurrent"]) }
        set { set(["tcp-concurrent"], newValue) }
    }

    var disableKeepAlive: Bool? {
        get { get(["disable-keep-alive"]) }
        set { set(["disable-keep-alive"], newValue) }
    }

    var keepAliveIdle: Int? {
        get { get(["keep-alive-idle"]) }
        set { set(["keep-alive-idle"], newValue) }
    }

    var keepAliveInterval: Int? {
        get { get(["keep-alive-interval"]) }
        set { set(["keep-alive-interval"], newValue) }
    }

    var globalUA: String? {
        get { get(["global-ua"]) }
        set { set(["global-ua"], newValue) }
    }

    var geodataLoader: String? {
        get { get(["geodata-loader"]) }
        set { set(["geodata-loader"], newValue) }
    }

    var geositeMatcher: String? {
        get { get(["geosite-matcher"]) }
        set { set(["geosite-matcher"], newValue) }
    }

     
     
     
    var hosts: [String: Any]? {
        get { get(["hosts"]) }
        set { set(["hosts"], newValue.flatMap { $0.isEmpty ? nil : $0 }) }
    }

     

    var dnsIPv6: Bool? {
        get { get(["dns", "ipv6"]) }
        set { set(["dns", "ipv6"], newValue) }
    }

    var snifferEnabled: Bool? {
        get { get(["sniffer", "enable"]) }
        set { set(["sniffer", "enable"], newValue) }
    }

     

    func snifferGet<T>(_ key: String) -> T? {
        get(["sniffer", key])
    }

    mutating func snifferSet<T>(_ key: String, _ value: T?) {
        set(["sniffer", key], value)
    }

    func snifferProtocolGet<T>(_ protocolID: String, key: String) -> T? {
        get(["sniffer", "sniff", protocolID, key])
    }

     
     
     
    mutating func snifferProtocolSet<T>(_ protocolID: String, key: String, _ value: T?) {
        set(["sniffer", "sniff", protocolID, key], value)
    }

     

    var hasDNSOverride: Bool {
        (root.orderedObject(at: ["dns"])?.isEmpty == false)
    }

    func dnsGet<T>(_ key: String) -> T? {
        get(["dns", key])
    }

    mutating func dnsSet<T>(_ key: String, _ value: T?) {
        set(["dns", key], value)
    }

     
     
     
     
    func dnsPolicyEntries(_ key: String) -> [(key: String, value: OrderedJSON)]? {
        root.orderedObject(at: ["dns", key])
    }

    mutating func setDNSPolicy(_ key: String, _ entries: [(key: String, value: OrderedJSON)]?) {
        let value = entries.flatMap { $0.isEmpty ? nil : OrderedJSON.object($0) }
        root = root.setting(path: ["dns", key], to: value)
    }

     
     
    func fallbackFilterGet<T>(_ key: String) -> T? {
        get(["dns", "fallback-filter", key])
    }

    mutating func fallbackFilterSet<T>(_ key: String, _ value: T?) {
        set(["dns", "fallback-filter", key], value)
    }

     
    mutating func clearDNS() {
        root = root.setting(path: ["dns"], to: nil)
    }

     
     
     
     
    mutating func replaceDNS(with source: OverridePatch) {
        let dns = source.root.node(at: ["dns"])
        let hasContent: Bool
        if case let .object(pairs)? = dns { hasContent = !pairs.isEmpty } else { hasContent = false }
        root = root.setting(path: ["dns"], to: hasContent ? dns : nil)
    }

     

    func tunGet<T>(_ key: String) -> T? {
        get(["tun", key])
    }

    mutating func tunSet<T>(_ key: String, _ value: T?) {
        set(["tun", key], value)
    }

     

    func ntpGet<T>(_ key: String) -> T? {
        get(["ntp", key])
    }

    mutating func ntpSet<T>(_ key: String, _ value: T?) {
        set(["ntp", key], value)
    }

     

    func profileGet<T>(_ key: String) -> T? {
        get(["profile", key])
    }

    mutating func profileSet<T>(_ key: String, _ value: T?) {
        set(["profile", key], value)
    }

    func experimentalGet<T>(_ key: String) -> T? {
        get(["experimental", key])
    }

    mutating func experimentalSet<T>(_ key: String, _ value: T?) {
        set(["experimental", key], value)
    }

    func tlsGet<T>(_ key: String) -> T? {
        get(["tls", key])
    }

    mutating func tlsSet<T>(_ key: String, _ value: T?) {
        set(["tls", key], value)
    }

    func tlsContainsAny(_ keys: Set<String>) -> Bool {
        guard let tls = root.orderedObject(at: ["tls"]) else { return false }
        return keys.contains { key in
            guard let node = tls.first(where: { $0.key == key })?.value else { return false }
            switch node {
            case .scalar("null"):
                return false
            case let .string(value):
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default:
                return true
            }
        }
    }
}
