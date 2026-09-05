import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVProductState {
     
     
     
    enum Stage { case disconnected, connecting, connected, disconnecting }

     
     
     
     
    enum Fixture { case prototype, manyGroups, manyGroupsTenNodes, longNames }

    var stage: Stage = .disconnected
     
     
     
    var autoConnect: Bool = false
     
     
    var autoConnectIssue: String?
     
     
    var issue: String?
     
     
    var pipelinePhase: HakoTVConfigPipeline.Phase?
     
     
     
     
    var refresh: Refresh?

    enum Refresh: Equatable {
        case updating(HakoTVSubscription.ID, HakoTVConfigPipeline.Phase)
        case failed(HakoTVSubscription.ID, String)
    }
    var profileName: String = "Home profile"
    var profileAge: String = "Updated 2 hours ago"
    var nodeName: String = "Hong Kong 04"
    var nodeGroup: String = "Node selection"
    var outboundMode: HakoTVOutboundMode = .rule
    var nodeCount: Int = 37
    var groupCount: Int = 12
    var ruleCount: Int = 1284
     
    var connectedSince: Date? = Date(timeIntervalSinceNow: -(72 * 60 + 5))
     
    var downloadBytesPerSecond: Int64 = 6_025_000
    var uploadBytesPerSecond: Int64 = 387_500
    var sessionBytes: Int64 = 2_576_980_378
    var connectionCount: Int = 46

     
     
    var proxyGroups: [HakoProxyGroupSnapshot]
     
    var latency: [String: HakoProxyLatencyState]
     
     
    var failureReasons: [String: String] = [:]
     
     
    var rules: [HakoRuleLineSnapshot]
     
     
     
    var connections: [HakoActivityConnectionSnapshot]

     
     
    var memoryBytes: Int64 = 29_779_558
    var geodataSource: String = "Bundled"
    var ruleProvidersLoaded: Int = 4
    var ruleProvidersTotal: Int = 4
     
     
     
     
     
     
    var providers: [HakoTVProviderCatalog.Entry] = HakoTVProviderCatalog.Entry.prototype
     
     
     
     
     
     
     
     
     
     
     
    var lastProblem: Problem? = Problem(
        sentence: String(localized: "The subscription could not be fetched: the request timed out."),
        at: Date().addingTimeInterval(-22 * 60)
    )

    struct Problem: Equatable {
        let sentence: String
        let at: Date
    }

    mutating func note(problem: String, at moment: Date = Date()) {
        lastProblem = Problem(sentence: problem, at: moment)
    }

     
     
    var dnsEnhancedMode: String = "fake-ip"
    var dnsNameservers: [String] = ["https://doh.pub/dns-query", "https://dns.alidns.com/dns-query"]
    var dnsFallback: [String] = ["https://1.1.1.1/dns-query", "tls://8.8.4.4"]
    var dnsDefaultNameservers: [String] = ["223.5.5.5", "119.29.29.29"]

    var isConnected: Bool { stage == .connected }

     
     
     
    static var empty: HakoTVProductState {
        var state = HakoTVProductState(fixture: .prototype)
        state.stage = .disconnected
        state.profileName = ""
        state.profileAge = ""
        state.nodeName = ""
        state.nodeGroup = ""
        state.nodeCount = 0
        state.groupCount = 0
        state.ruleCount = 0
        state.connectedSince = nil
        state.downloadBytesPerSecond = 0
        state.uploadBytesPerSecond = 0
        state.sessionBytes = 0
        state.connectionCount = 0
        state.proxyGroups = []
        state.latency = [:]
        state.rules = []
        state.connections = []
         
         
         
         
         
        state.providers = []
        state.lastProblem = nil
        state.memoryBytes = 0
        state.ruleProvidersLoaded = 0
        state.ruleProvidersTotal = 0
        state.dnsEnhancedMode = ""
        state.dnsNameservers = []
        state.dnsFallback = []
        state.dnsDefaultNameservers = []
        return state
    }

    init(fixture: Fixture = .prototype) {
        let built = Self.buildProxyFixture(fixture)
        proxyGroups = built.groups
        latency = built.latency
        rules = Self.buildRulesFixture()
        ruleCount = rules.count
        connections = Self.buildConnectionsFixture()
        connectionCount = connections.count
    }

     
     
     
     
     
    mutating func pin(member: String, in groupName: String) {
        guard let index = proxyGroups.firstIndex(where: { $0.name == groupName }) else { return }
        let group = proxyGroups[index]
        guard group.allowsMemberChoice,
              group.members.contains(where: { $0.name == member })
        else { return }
        proxyGroups[index] = HakoProxyGroupSnapshot(
            name: group.name,
            type: group.type,
            members: group.members,
            configuredSelection: group.configuredSelection,
            runtimeSelection: member,
            resolvedRuntimeRoute: group.resolvedRuntimeRoute,
            icon: group.icon
        )
    }

     

    private static func buildProxyFixture(
        _ fixture: Fixture
    ) -> (groups: [HakoProxyGroupSnapshot], latency: [String: HakoProxyLatencyState]) {
         
         
         
        let protocols = ["shadowsocks", "shadowsocks", "shadowsocks", "trojan", "vmess", "hysteria2"]
        let delays = [94, 117, 112, 151, 197, 166, 180, 129, 148, 103, 88, 210, 176, 134, 121, 99, 158, 143]
         
         
         
         
        let longTails = ["IEPL 专线 1.5x [Premium]", "BGP · 家宽 · 0.8x", "Netflix / Disney+ 解锁 · 2x", "IPLC 中转 · 低延迟", "Standard 1x", "游戏加速 · UDP · 3x"]
        let hongKong = (1...18).map { index in
            HakoProxyMemberSnapshot(
                name: fixture == .longNames
                    ? String(format: "🇭🇰 Hong Kong %02d · %@", index, longTails[(index - 1) % longTails.count])
                    : String(format: "Hong Kong %02d", index),
                type: protocols[(index - 1) % protocols.count]
            )
        }
        var latency: [String: HakoProxyLatencyState] = [:]
        for (member, delay) in zip(hongKong, delays) {
            latency[member.name] = .measured(milliseconds: delay)
        }
         
        latency[hongKong[4].name] = .failed
         
         
         
         
        latency[hongKong[5].name] = .testing
        latency[hongKong[6].name] = .testing
        latency[hongKong[7].name] = .timedOut
        let singapore = (1...6).map { index in
            HakoProxyMemberSnapshot(name: String(format: "Singapore %02d", index), type: "trojan")
        }
        for (index, member) in singapore.enumerated() {
            latency[member.name] = .measured(milliseconds: 60 + index * 9)
        }
        let regions = [
            HakoProxyMemberSnapshot(name: "Hong Kong", type: "URLTest", isGroup: true),
            HakoProxyMemberSnapshot(name: "Streaming", type: "Selector", isGroup: true),
            HakoProxyMemberSnapshot(name: "DIRECT", type: "Direct"),
        ]
        var groups = [
            HakoProxyGroupSnapshot(
                name: "Node selection",
                type: "select",
                members: regions,
                configuredSelection: "Hong Kong"
            ),
            HakoProxyGroupSnapshot(
                name: "Hong Kong",
                type: "url-test",
                members: hongKong,
                runtimeSelection: hongKong[3].name
            ),
            HakoProxyGroupSnapshot(
                name: "Streaming",
                type: "select",
                members: singapore,
                configuredSelection: "Singapore 02"
            ),
            HakoProxyGroupSnapshot(
                name: "Fallback",
                type: "fallback",
                members: Array(hongKong.prefix(4)) + Array(singapore.prefix(2)),
                runtimeSelection: "Hong Kong 01"
            ),
            HakoProxyGroupSnapshot(
                name: "Final",
                type: "select",
                members: [
                    HakoProxyMemberSnapshot(name: "Node selection", type: "Selector", isGroup: true),
                    HakoProxyMemberSnapshot(name: "DIRECT", type: "Direct"),
                ]
            ),
        ]
        if fixture == .longNames {
             
             
            groups.swapAt(0, 1)
        }
        if fixture == .manyGroups || fixture == .manyGroupsTenNodes {
             
             
            let extra = ["Japan", "Taiwan", "Korea", "United States", "United Kingdom", "Germany",
                         "France", "Netherlands", "Canada", "Australia", "India", "Brazil",
                         "Turkey", "Russia", "Argentina", "South Africa"]
            for (regionIndex, region) in extra.enumerated() {
                let perGroup = fixture == .manyGroupsTenNodes ? 10 : 4
                let members = (1...perGroup).map { index in
                    HakoProxyMemberSnapshot(
                        name: String(format: "%@ %02d", region, index),
                        type: protocols[(index + regionIndex) % protocols.count]
                    )
                }
                for (index, member) in members.enumerated() {
                    latency[member.name] = .measured(milliseconds: 120 + regionIndex * 7 + index * 11)
                }
                groups.append(
                    HakoProxyGroupSnapshot(
                        name: region,
                        type: regionIndex % 3 == 0 ? "url-test" : "select",
                        members: members,
                        runtimeSelection: members.first?.name
                    )
                )
            }
        }
        return (groups, latency)
    }

     
     
     
     
     
     
    private static func buildRulesFixture() -> [HakoRuleLineSnapshot] {
        func line(_ type: String, _ payload: String, _ target: String) -> HakoRuleLineSnapshot {
            HakoRuleLineSnapshot(
                raw: [type, payload, target].filter { !$0.isEmpty }.joined(separator: ","),
                type: type,
                payload: payload,
                target: target
            )
        }
        var rules: [HakoRuleLineSnapshot] = [
            line("DST-PORT", "443", "Node selection"),
            line("NETWORK", "udp", "DIRECT"),
            line("PROCESS-NAME", "com.apple.Music", "DIRECT"),
            line("PROCESS-PATH", "/Applications/Safari.app", "Node selection"),
            line("IP-CIDR", "192.168.0.0/16", "DIRECT"),
            line("SOURCE-APP-TEAM-ID", "EXAMPLETEAM", "DIRECT"),
            line("IP-ASN", "13335", "Node selection"),
            line("RULE-SET", "streaming", "Streaming"),
            line("AND", "((DOMAIN-SUFFIX,cdn.example),(NETWORK,tcp))", "Node selection"),
        ]
        let words = ["cdn", "static", "img", "api", "edge", "media", "video", "login", "auth", "sync"]
        let tlds = ["com", "net", "org", "io", "tv", "app"]
        let targets = ["Node selection", "Streaming", "DIRECT", "Hong Kong"]
        for index in 0..<1_240 {
            let word = words[index % words.count]
            let tld = tlds[(index / words.count) % tlds.count]
            let target = targets[index % targets.count]
            switch index % 9 {
            case 0, 1, 2, 3, 4:
                rules.append(line("DOMAIN-SUFFIX", "\(word)\(index).example.\(tld)", target))
            case 5:
                rules.append(line("DOMAIN-KEYWORD", "\(word)\(index)", target))
            case 6:
                rules.append(line("GEOIP", ["cn", "us", "jp", "hk"][index % 4], target))
            case 7:
                rules.append(line("IP-CIDR", "10.\(index % 255).0.0/16", "DIRECT"))
            default:
                rules.append(line("DST-PORT", "\(8_000 + index % 1_000)", target))
            }
            if index % 40 == 39 {
                rules.append(line("RULE-SET", "provider-\(index / 40)", target))
            }
            if index % 400 == 399 {
                rules.append(line("PROCESS-NAME-REGEX", "^com\\.example\\.\(word)", "DIRECT"))
                rules.append(line("IN-USER", "guest", "DIRECT"))
            }
        }
        rules.append(line("GEOSITE", "cn", "DIRECT"))
        rules.append(line("GEOIP", "cn", "DIRECT"))
        rules.append(line("MATCH", "", "Final"))
        return rules
    }

     
     
     
     
     
     
    private static func buildConnectionsFixture() -> [HakoActivityConnectionSnapshot] {
        struct Seed {
            let destination: String
            let rule: String
            let payload: String
            let chains: [String]
            let bytes: Int64
        }
        let seeds: [Seed] = [
            Seed(destination: "occ-0-2774-2773.1.nflxso.net:443", rule: "GeoSite", payload: "netflix", chains: ["Hong Kong 04", "Hong Kong", "Streaming"], bytes: 13_002_342),
            Seed(destination: "ipv4-c002-hkg001-ix.1.oca.nflxvideo.net:443", rule: "GeoSite", payload: "netflix", chains: ["Hong Kong 04", "Hong Kong", "Streaming"], bytes: 421_527_040),
            Seed(destination: "time.apple.com:123", rule: "Domain", payload: "time.apple.com", chains: ["DIRECT"], bytes: 1_229),
            Seed(destination: "gateway.icloud.com:443", rule: "RuleSet", payload: "apple", chains: ["DIRECT"], bytes: 90_112),
            Seed(destination: "ads.example-tracker.net:443", rule: "GeoSite", payload: "category-ads-all", chains: ["REJECT", "Ads"], bytes: 0),
            Seed(destination: "api.github.com:443", rule: "DomainSuffix", payload: "github.com", chains: ["Hong Kong 04", "Hong Kong", "Node selection"], bytes: 34_816),
            Seed(destination: "unknown-host.example.org:443", rule: "Match", payload: "", chains: ["Hong Kong 04", "Hong Kong", "Final"], bytes: 2_048),
        ]
        var rows: [HakoActivityConnectionSnapshot] = []
         
         
         
         
         
         
        let base = Date().addingTimeInterval(-90)
        func append(_ seed: Seed, index: Int) {
            rows.append(
                HakoActivityConnectionSnapshot(
                    id: "fixture-\(index)",
                    destination: seed.destination,
                    source: "192.168.1.20:\(51_000 + index)",
                    network: index % 5 == 0 ? "UDP" : "TCP",
                    route: seed.chains.joined(separator: " → "),
                    rule: seed.rule,
                    upload: seed.bytes / 12,
                    download: seed.bytes - seed.bytes / 12,
                    start: base.addingTimeInterval(TimeInterval(-index * 7)),
                    chains: seed.chains,
                    rulePayload: seed.payload
                )
            )
        }
        for (index, seed) in seeds.enumerated() {
            append(seed, index: index)
        }
         
        let proxiedHosts = ["cdn.example.tv", "static.example.app", "img.example.io", "video.example.net", "edge.example.com"]
        let directHosts = ["push.apple.com", "mesu.apple.com", "ocsp.apple.com", "configuration.ls.apple.com"]
        var index = seeds.count
        var proxied = seeds.filter { $0.chains.first != "DIRECT" && $0.chains.first != "REJECT" }.count
        var direct = seeds.filter { $0.chains.first == "DIRECT" }.count
        while proxied < 31 {
            append(Seed(destination: "\(proxiedHosts[index % proxiedHosts.count]):443", rule: "DomainSuffix",
                        payload: proxiedHosts[index % proxiedHosts.count],
                        chains: ["Hong Kong 04", "Hong Kong", index % 2 == 0 ? "Node selection" : "Streaming"],
                        bytes: Int64(20_000 + index * 3_331)), index: index)
            index += 1; proxied += 1
        }
        while direct < 14 {
            append(Seed(destination: "\(directHosts[index % directHosts.count]):443", rule: "GeoSite",
                        payload: "apple", chains: ["DIRECT"], bytes: Int64(3_000 + index * 517)), index: index)
            index += 1; direct += 1
        }
        return rows
    }
}

 
 
 
 
 
 
 
 
 
 
 
enum HakoTVOutboundMode: String, CaseIterable, Equatable, Sendable {
    case global
    case rule
    case direct

     
    var title: String {
        switch self {
        case .global: String(localized: "Global")
        case .rule: String(localized: "Rule")
        case .direct: String(localized: "Direct")
        }
    }

     
     
    var kernelToken: String { rawValue }

     
     
     
    var explanation: String {
        switch self {
        case .global: String(localized: "Send all traffic through the selected proxy")
        case .rule: String(localized: "Route traffic by the profile rules")
        case .direct: String(localized: "Connect directly, without a proxy")
        }
    }
}
