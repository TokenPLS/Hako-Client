import HakoClientUI
import Foundation
import SwiftUI

 
 
 
 
struct HomeCustomizationEditModePresenter: View {
    let content: AnyView

#if !os(macOS)
    @State private var editMode: EditMode = .active
#endif

    var body: some View {
#if os(macOS)
        content
#else
        content.environment(\.editMode, $editMode)
#endif
    }
}

 
 
 
 
struct ProfileConfigTally: Equatable {
    let proxies: Int
    let proxyGroups: Int
    let rules: Int
    let proxyProviders: Int
    let ruleProviders: Int
    let subRules: Int
    let groupNames: [String]
    let ruleProviderNames: [String]

     
     
     
     
     
     
     
    static func make(sourceYAML: String?, tunnelRunning: Bool = true) -> ProfileConfigTally? {
        guard let yaml = sourceYAML,
              let root = ConfigTransforms.parsedRoot(forYAML: yaml)?.root
        else {
            return nil
        }

        let groups = (root["proxy-groups"] as? [[String: Any]]) ?? []
        let ruleProviders =
            (root["rule-providers"] as? [String: Any]) ?? [:]
        return ProfileConfigTally(
            proxies: (root["proxies"] as? [Any])?.count ?? 0,
             
             
             
             
             
             
            proxyGroups: groups.count
                + (tunnelRunning && !groups.contains { $0["name"] as? String == "GLOBAL" }
                    ? 1 : 0),
            rules: (root["rules"] as? [Any])?.count ?? 0,
            proxyProviders:
                (root["proxy-providers"] as? [String: Any])?.count ?? 0,
            ruleProviders: ruleProviders.count,
            subRules: (root["sub-rules"] as? [String: Any])?.count ?? 0,
            groupNames: groups.compactMap { $0["name"] as? String },
            ruleProviderNames: ruleProviders.keys.sorted()
        )
    }
}

 
 
 
 
 
 
 
 
@MainActor
final class HomeTallyCache {
    struct Key: Equatable {
        let profileID: String
        let refreshToken: Int
    }

    struct Entry {
        let tally: ProfileConfigTally?
        let rulesOverview: RulesOverviewModel?
        let subscriptionNodeTally: Int?
        let resourceCounts: HomeResourceCounts?
    }

    static let shared = HomeTallyCache()

    private var key: Key?
    private var entry: Entry?

    func entry(for key: Key) -> Entry? {
        self.key == key ? entry : nil
    }

    func store(_ entry: Entry, for key: Key) {
        self.key = key
        self.entry = entry
    }

    func reset() {
        key = nil
        entry = nil
    }
}

struct HomeConnectionIssueView: View {
     
     
     
     
     
     
     
     
     
     
    enum Action: Equatable {
         
         
         
        case viewLogs
        case resetVPNProfile
    }

    static func actions(allowsSystemVPNProfileReset: Bool) -> [Action] {
        var actions: [Action] = [.viewLogs]
        if allowsSystemVPNProfileReset { actions.append(.resetVPNProfile) }
        return actions
    }

    let issue: HomeConnectionIssue
    @ObservedObject var vpn: VPNController
     
     
     
    var openLogs: () -> Void = {}
     
     
    var startupExplanation: HakoStartupExplanation?
     
     
    var geoNameCount: Int?
     
    var billLines: [MemoryBillSection.Line] = []
     
    var ruleSetItems: [MemoryTrimManageView.Item] = []
     
     
    var trimSpec: MemoryTrimSpec = MemoryTrimSpec()
    var onSaveTrim: (MemoryTrimSpec) -> Void = { _ in }
     
     
     
     
    var dnsPolicyKeys: [(String, Int64?)] = []
    var dnsFilterEntries: [(String, Int64?)] = []
    var geoSiteItems: [(String, Int64?)] = []
    var geoIPItems: [(String, Int64?)] = []
     
    var providerLoadRows: [ProviderLoadDetailView.Row] = []
    @State private var managesRuleSets = false
    @State private var managesDNS = false
    @State private var managesGeo = false
    @State private var showsProviderLoad = false
     
     
    var coreLog: [String] = []
    var strippedNotices: [String] = []
     
     
    var unreadableRuleSets: [ProvidersModel.Row] = []

    @Environment(\.locale) private var locale

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var confirmsVPNProfileReset = false
     
    @State private var wantsLogsOnDismiss = false
    @State private var feedback: HakoFeedbackPresentation?

    var body: some View {
        HakoFeatureNavigationContainer {
            content
        }
        .confirmationDialog(
            "Reset VPN Profile?",
            isPresented: $confirmsVPNProfileReset,
            titleVisibility: .visible
        ) {
            Button(
                "Reset VPN Profile",
                role: .destructive
            ) {
                resetVPNProfile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This removes and recreates only Clash’s VPN entry in Settings."
            )
        }
        .hakoFeedbackOverlay(
            $feedback,
            dismissTitle: "Done"
        )
        .sheet(isPresented: $managesRuleSets) {
            HakoFeatureNavigationContainer {
                MemoryTrimManageView(
                    items: ruleSetItems,
                    dropped: Set(trimSpec.droppedRuleProviders)
                ) { dropped in
                    var spec = trimSpec
                    spec.droppedRuleProviders = dropped.sorted()
                    onSaveTrim(spec)
                    dismiss()
                }
            }
            .hakoModalPresentation(.page)
        }
        .sheet(isPresented: $managesDNS) {
            HakoFeatureNavigationContainer {
                DNSTrimManageView(
                    policyKeys: dnsPolicyKeys,
                    filterEntries: dnsFilterEntries,
                    droppedKeys: Set(trimSpec.droppedDNSPolicyKeys),
                    droppedEntries: Set(trimSpec.droppedFakeIPFilterEntries)
                ) { keys, entries in
                    var spec = trimSpec
                    spec.droppedDNSPolicyKeys = keys.sorted()
                    spec.droppedFakeIPFilterEntries = entries.sorted()
                    onSaveTrim(spec)
                    dismiss()
                }
            }
            .hakoModalPresentation(.page)
        }
        .sheet(isPresented: $managesGeo) {
            HakoFeatureNavigationContainer {
                GeoTrimManageView(
                    siteItems: geoSiteItems,
                    ipItems: geoIPItems,
                    droppedSites: Set(trimSpec.droppedGeoSiteRules),
                    droppedIPs: Set(trimSpec.droppedGeoIPRules)
                ) { sites, ips in
                    var spec = trimSpec
                    spec.droppedGeoSiteRules = sites.sorted()
                    spec.droppedGeoIPRules = ips.sorted()
                    onSaveTrim(spec)
                    dismiss()
                }
            }
            .hakoModalPresentation(.page)
        }
        .sheet(isPresented: $showsProviderLoad) {
            HakoFeatureNavigationContainer {
                ProviderLoadDetailView(rows: providerLoadRows)
            }
            .hakoModalPresentation(.page)
        }
        .onDisappear {
             
             
             
            guard wantsLogsOnDismiss else { return }
            wantsLogsOnDismiss = false
            openLogs()
        }
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
    private var content: some View {
        List {
             
             
            Section {
                Text(
                    hako: startupExplanation?.detail
                        ?? .copy(issue.message)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("connection.issue.reason")

                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                if let wayOut = startupExplanation?.wayOut(named: geoNameCount) {
                    Text(hako: wayOut)
                        .font(.subheadline)
                        .accessibilityIdentifier("connection.issue.way-out")
                }
            }


            if !billLines.isEmpty {
                MemoryBillSection(lines: billLines) { id in
                    switch id {
                    case "rule-sets": managesRuleSets = true
                    case "dns": managesDNS = true
                    case "geo": managesGeo = true
                    case "providers": showsProviderLoad = true
                    default: break
                    }
                }
                .accessibilityIdentifier("connection.issue.bill")
            }

             
             
             
             
            if startupExplanation != nil, !unreadableRuleSets.isEmpty {
                Section("Not In Effect") {
                    ForEach(unreadableRuleSets) { row in
                        VStack(
                            alignment: .leading,
                            spacing: HakoTheme.Spacing.tight
                        ) {
                            Text(hako: .verbatim(row.name))
                                .font(.subheadline.weight(.medium))
                            if let failure = row.loadFailure {
                                Text(hako: .verbatim(failure))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .accessibilityIdentifier(
                            "connection.issue.unreadable.\(row.name)"
                        )
                    }
                }
            }

             
             
            if !coreLog.isEmpty {
                if !strippedNotices.isEmpty {
                Section {
                    ForEach(strippedNotices, id: \.self) { notice in
                        Text(hako: .verbatim(notice))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(hako: .copy("What the Core Said This Run"))
                } footer: {
                    Text(hako: .copy("The core's own notices, verbatim: what it removed, what it kept but cannot match, and anything it wants you to know about who can reach this device."))
                }
            }

            Section("Core Log") {
                    ForEach(Array(coreLog.enumerated()), id: \.offset) {
                        _, line in
                        Text(hako: .verbatim(line))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Button {
                        wantsLogsOnDismiss = true
                        dismiss()
                    } label: {
                        Label(
                            "Open Full Log",
                            systemImage: HakoSymbol.docText.name
                        )
                        .font(.subheadline)
                    }
                    .accessibilityIdentifier("connection.issue.logs")
                }
                .accessibilityIdentifier("connection.issue.core-log")
            }

             
             
            if issue.allowsSystemVPNProfileReset {
                Section {
                    Button(role: .destructive) {
                        confirmsVPNProfileReset = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset VPN Profile")
                            Text(
                                "Recreates Clash’s VPN entry in Settings. Your Clash profiles, subscriptions, and credentials stay unchanged."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("connection.issue.reset")
                }
            }
        }
        .navigationTitle("Can’t Connect")
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                HakoSheetCloseButton { dismiss() }
            }
        }
    }

    private func resetVPNProfile() {
        feedback = .loading(
            title: "Resetting VPN Profile",
            accessibilityIdentifier: "connection.issue.reset.loading"
        )
        Task { @MainActor in
            if await vpn.resetSystemVPNProfile() {
                feedback = .success(
                    title: "VPN Profile Reset",
                    message: "Clash’s VPN profile is ready. Connect when you are ready.",
                    accessibilityIdentifier:
                        "connection.issue.reset.success"
                )
                try? await Task.sleep(nanoseconds: 900_000_000)
                feedback = nil
                dismiss()
            } else {
                feedback = .error(
                    title: "Reset Failed",
                    message: .verbatim(vpn.reportableLastError),
                    accessibilityIdentifier:
                        "connection.issue.reset.failure"
                )
            }
        }
    }
}

 
 
 
 
 
struct HakoFeatureNavigationContainer<Content: View>: View {
    let ownsNavigationContainer: Bool
    private let content: Content

    init(
        ownsNavigationContainer: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.ownsNavigationContainer = ownsNavigationContainer
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        HakoSingleColumnNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            content
        }
    }
}

extension View {
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoPageSizedSheet() -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoSheetPresentation() -> some View {
        hakoOwnsProductCanvas()
            .hakoInlineSheetTitle()
            .hakoModalPresentation(.page)
    }

    @ViewBuilder
    func hakoFeaturePresentation(
        ownsNavigationContainer: Bool
    ) -> some View {
        if ownsNavigationContainer {
            hakoSheetPresentation()
        } else {
            self
        }
    }

     
     
     
     
     
     
     
     
     
    @ViewBuilder
    fileprivate func hakoInlineSheetTitle() -> some View {
#if os(macOS)
        self
#else
        if #available(iOS 17.0, *) {
            self.toolbarTitleDisplayMode(.inline)
        } else {
            self.navigationBarTitleDisplayMode(.inline)
        }
#endif
    }

}
