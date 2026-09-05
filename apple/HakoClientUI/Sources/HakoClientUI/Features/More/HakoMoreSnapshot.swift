import Foundation

public struct HakoAboutSnapshot: Codable, Equatable, Sendable {
    public let appVersion: String
     
     
    public let buildNumber: String
     
     
    public let sourceRevision: String
    public let coreVersion: String

    public init(
        appVersion: String = "—",
        buildNumber: String = "",
        sourceRevision: String = "",
        coreVersion: String = "—"
    ) {
        self.appVersion = String(appVersion.prefix(128))
        self.buildNumber = String(buildNumber.prefix(64))
        self.sourceRevision = String(sourceRevision.prefix(64))
        self.coreVersion = String(coreVersion.prefix(128))
    }

     
     
    public var versionLine: String {
        buildNumber.isEmpty
            ? appVersion
            : "\(appVersion) (\(buildNumber))"
    }
}

public struct HakoMoreSnapshot: Codable, Equatable, Sendable {
    public let onDemandEnabled: Bool
    public let onDemandRuleCount: Int
    public let dnsOnlyActive: Bool
     
     
     
    public let tunnelIncludeAllNetworks: Bool
    public let showsDeveloperDestination: Bool
    public let about: HakoAboutSnapshot
     
     
     
     
     
     
     
     
     
     
     
    public let overrideCounts: [HakoMoreDestination: Int]
     
     
     
     
    public let attention: HakoMoreAttention?

    public init(
        onDemandEnabled: Bool = false,
        onDemandRuleCount: Int = 0,
        dnsOnlyActive: Bool = false,
        tunnelIncludeAllNetworks: Bool = false,
        showsDeveloperDestination: Bool = false,
        about: HakoAboutSnapshot = HakoAboutSnapshot(),
        overrideCounts: [HakoMoreDestination: Int] = [:],
        attention: HakoMoreAttention? = nil
    ) {
        self.onDemandEnabled = onDemandEnabled
        self.onDemandRuleCount = max(0, onDemandRuleCount)
        self.dnsOnlyActive = dnsOnlyActive
        self.tunnelIncludeAllNetworks = tunnelIncludeAllNetworks
        self.showsDeveloperDestination = showsDeveloperDestination
        self.about = about
        self.overrideCounts = overrideCounts.filter { $0.value > 0 }
        self.attention = attention
    }

     
     
    func overrideSubtitle(for destination: HakoMoreDestination) -> HakoDisplayText? {
        guard let count = overrideCounts[destination], count > 0 else { return nil }
        return .format("%@ overriding the profile", [String(count)])
    }

    public func presentation(
        for destination: HakoMoreDestination
    ) -> HakoProductDestinationPresentation {
        switch destination {
        case .root:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle:
                    "Core, data, connection, and app settings"
            )
        case .geoResources:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "GeoIP, GeoSite, ASN, and MMDB data"
            )
        case .backupRestore:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "iCloud Drive and local backups"
            )
        case .onDemand:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: onDemandEnabled
                    ? count(
                        onDemandRuleCount,
                        singular: "%@ ordered network rule",
                        plural: "%@ ordered network rules"
                    )
                    : "Wi-Fi and cellular rules",
                badge: onDemandEnabled ? "On" : nil
            )
        case .systemIntegrations:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle:
                    "Shortcuts, Controls, and widgets"
            )
        case .dnsOnly:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "Encrypted resolvers, no packet tunnel",
                badge: dnsOnlyActive ? "Active" : nil
            )
        case .tunnel:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "Enforce Routes and Include All Networks",
                badge: tunnelIncludeAllNetworks ? "On" : nil
            )
        case .dnsAndHosts:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: overrideSubtitle(for: .dnsAndHosts) ?? "App-wide resolvers, fake IP, and local mappings"
            )
        case .tunnelAndRoutes:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: overrideSubtitle(for: .tunnelAndRoutes) ?? "App-wide TUN stack and route coverage"
            )
        case .coreBehavior:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: overrideSubtitle(for: .coreBehavior)
                    ?? "App-wide logging, concurrency, keep-alive, and matcher"
            )
        case .clientSettings:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle:
                    "Traffic, updates, delay tests, and node switching"
            )
        case .appearance:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "Language, theme, tint, and dark appearance"
            )
        case .about:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle: "Version, open source, and release information"
            )
        case .developer:
            return HakoProductDestinationPresentation(
                title: .copy(destination.title),
                subtitle:
                    "Diagnostics and local data"
            )
        }
    }

    public static let empty = HakoMoreSnapshot()

     
    private func count(
        _ value: Int,
        singular: String,
        plural: String
    ) -> HakoDisplayText {
        .format(value == 1 ? singular : plural, ["\(value)"])
    }
}


 
 
 
 
 
 
public struct HakoMoreAttention: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let message: HakoDisplayText
    public let actions: [HakoMoreAttentionAction]
     
     
    public let emphasised: Bool

    public init(id: String, message: HakoDisplayText, actions: [HakoMoreAttentionAction], emphasised: Bool = false) {
        self.id = id
        self.message = message
        self.actions = actions
        self.emphasised = emphasised
    }
}

public struct HakoMoreAttentionAction: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: HakoDisplayText
    public let destructive: Bool

    public init(id: String, title: HakoDisplayText, destructive: Bool = false) {
        self.id = id
        self.title = title
        self.destructive = destructive
    }
}
