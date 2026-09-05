import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVBrandMark: View {
     
     
     
    static let width: CGFloat = 307
     
     
     
    static let aboutWidth: CGFloat = 200

    var width: CGFloat = HakoTVBrandMark.width

    var body: some View {
        Image("HakoBrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

 

 
 
 
enum HakoTVTestAppearance: String, Equatable, Sendable {
    case light
    case dark

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

enum HakoTVTestContentSize: String, Equatable, Sendable {
    case accessibilityExtraLarge = "accessibility-extra-large"
}

 
 
enum HakoTVTestStage: String, Equatable, Sendable {
    case welcome
    case home
    case connected
     
    case outboundMode = "outbound-mode"
     
     
    case nodes
     
     
    case nodesMany = "nodes-many"
     
     
    case nodesLongNames = "nodes-long-names"
     
     
    case nodesManyTen = "nodes-many-ten"
     
     
    case nodesDirect = "nodes-direct"
     
    case rules
     
    case connections
     
     
    case connectionsLive = "connections-live"
     
     
     
    case connectionDetail = "connection-detail"
     
     
    case subscriptions
     
    case proxyShare = "proxy-share"
     
     
    case subscriptionDetail = "subscription-detail"
     
     
    case editSubscription = "edit-subscription"
     
     
    case addSubscription = "add-subscription"
     
    case more
    case diagnostics
    case dns
     
     
     
    case userAgent = "user-agent"
     
    case providers

     
     
    var opensNodes: Bool {
        switch self {
        case .nodes, .nodesMany, .nodesManyTen, .nodesLongNames, .nodesDirect: true
        default: false
        }
    }

     
     
    var outboundModeOverride: HakoTVOutboundMode? {
        self == .nodesDirect ? .direct : nil
    }
}

struct HakoTVLaunchOverrides: Equatable, Sendable {
    let appearance: HakoTVTestAppearance?
    let contentSize: HakoTVTestContentSize?
    let stage: HakoTVTestStage?
     
     
     
     
    let connectsOnLaunch: Bool
     
     
     
    let updatesOnLaunch: Bool
     
     
    let disconnectsOnLaunch: Bool
     
     
     
    let useProfileURL: String?
     
     
     
    let allowLAN: Bool?
     
     
     
     
    let proxyShare: ProxyShareConfiguration?
     
     
     
    let probeSpec: String?
     
    let dumpsDiagnostics: Bool

    init(environment: [String: String]) {
        appearance = environment["HAKO_TV_APPEARANCE"]
            .flatMap(HakoTVTestAppearance.init(rawValue:))
        contentSize = environment["HAKO_TV_CONTENT_SIZE"]
            .flatMap(HakoTVTestContentSize.init(rawValue:))
        stage = environment["HAKO_TV_STAGE"]
            .flatMap(HakoTVTestStage.init(rawValue:))
        connectsOnLaunch = environment["HAKO_TV_CONNECT_ON_LAUNCH"] == "1"
        updatesOnLaunch = environment["HAKO_TV_UPDATE_ON_LAUNCH"] == "1"
        disconnectsOnLaunch = environment["HAKO_TV_DISCONNECT_ON_LAUNCH"] == "1"
        useProfileURL = environment["HAKO_TV_USE_PROFILE_URL"]
        allowLAN = environment["HAKO_TV_ALLOW_LAN"].flatMap { $0 == "1" ? true : ($0 == "0" ? false : nil) }
        proxyShare = Self.proxyShareOverride(environment["HAKO_TV_PROXY_SHARE"])
        probeSpec = environment["HAKO_TV_PROBE"]
        dumpsDiagnostics = environment["HAKO_TV_DIAG"] == "1"
    }
}

extension HakoTVLaunchOverrides {
     
     
     
    static func proxyShareOverride(_ raw: String?) -> ProxyShareConfiguration? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let port = Int32(parts[0]) else { return nil }
        let username = String(parts[1]), password = String(parts[2])
        guard !username.isEmpty, !password.isEmpty else { return nil }
        return ProxyShareConfiguration(port: port, username: username, password: password)
    }
}
