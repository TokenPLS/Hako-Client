import HakoClientUI
import SwiftUI

 
 
 
public struct HakoMacSecondaryUnavailableView: View {
    private let destination: HakoMacSecondaryDestination

    public init(destination: HakoMacSecondaryDestination) {
        self.destination = destination
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HakoClientUI.HakoTheme.Spacing.section) {
                Text(destination.title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                HakoClientUI.HakoFeatureCard(
                    palette: HakoMacPlatformPresentation.palette
                ) {
                    HakoClientUI.HakoEmptyState(
                        title: "Not Available on This Mac Yet",
                        message: unavailableMessage
                    ) {
                        HakoSymbolImage(symbol: symbol)
                    }
                }
            }
            .frame(
                maxWidth: HakoClientUI.HakoTheme.Regular.Detail.maximumContentWidth,
                alignment: .leading
            )
            .padding(.horizontal, HakoClientUI.HakoTheme.Spacing.standard)
            .padding(.vertical, HakoClientUI.HakoTheme.Spacing.section)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(HakoMacPlatformPresentation.palette.canvas)
        .navigationTitle(destination.title)
        .accessibilityIdentifier("hako.mac.secondary.\(identifier)")
    }

    private var unavailableMessage: String {
        switch destination {
        case .rules, .activeRules, .dnsQuery, .homeAdjustment,
             .runtimeConfiguration, .configuration:
            "This page needs the active profile configuration surface before it can make changes."
        case .utility:
            "This page needs a live, bounded diagnostic data source from the macOS Packet Tunnel."
        case .more:
            "This page needs its macOS platform capability before settings can be changed."
        case .profiles, .proxies:
            "This page needs its macOS product data source before it can be used."
        }
    }

    private var symbol: HakoSymbol {
        switch destination {
        case .profiles:
            .rectangleStackFill
        case .proxies:
            .proxyDomain
        case .rules:
            .ruleDomain
        case .activeRules:
            .listBulletRectangle
        case .dnsQuery:
            .globeAsiaAustralia
        case .homeAdjustment(let action):
            switch action {
            case .customNodes, .proxyChains:
                .serverRack
            case .routingRules:
                .ruleDomain
            case .connection:
                .network
            case .proxySources, .ruleSets:
                .shippingbox
            case .advancedOverrides, .rawFields:
                .curlybraces
            }
        case .runtimeConfiguration:
            .docText
        case .configuration:
            .gearshape
        case .utility(let destination):
            destination.symbol
        case .more(let destination):
            destination.symbol
        }
    }

    private var identifier: String {
        switch destination {
        case .profiles:
            "profiles"
        case .proxies:
            "proxies"
        case .rules:
            "rules"
        case .activeRules:
            "active-rules"
        case .dnsQuery:
            "dns-query"
        case .homeAdjustment(let action):
            "home-adjustment.\(action.rawValue)"
        case .runtimeConfiguration:
            "runtime-configuration"
        case .configuration:
            "configuration"
        case .utility(let destination):
            "utility.\(destination.rawValue)"
        case .more(let destination):
            "more.\(destination.rawValue)"
        }
    }
}
