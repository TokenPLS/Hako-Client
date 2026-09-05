import Combine
import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
struct ProxiesOverviewHost: View {
    @ObservedObject var vpn: VPNController
     
     
     
     
     
     
     
     
    let command: ClashCommandClient
    @ObservedObject var nodes: NodesModel
    @ObservedObject var profiles: ProfilesViewModel
    let isConnected: Bool
    let mode: String
    let profile: Profile
    let sourceModel: ProxiesOverviewModel
    let initiallyExpandedGroup: String?
    var ownsNavigationContainer = true
    @State private var providerUpdateFailure: HakoDisplayText?
     
     
    @State private var providerUpdateDeferred: HakoDisplayText?
     
    @State private var inspectingNode: ProxyNodeInspection?

    var body: some View {
        HakoPerf.measure("proxies.host.body") {
            hosted.hakoProductModal(item: $inspectingNode, role: .form) { inspection in
                nodeDetailSheet(for: inspection)
            }
        }




    }



     
     
     
     
     
     
     
     
    @ViewBuilder
    private var hosted: some View {
        ProxiesOverviewAdapter(
            sourceModel: sourceModel,
             
             
             
             
             
             
             
             
             
             
             
            outboundMode: ProxyBrowsingVisibility.Mode(
                coreValue: {
                    let tunnelUp = ["connected", "reasserting"]
                        .contains(vpn.status)
                    if tunnelUp, mode != "—" {
                        return mode
                    }
                    return profiles.outboundMode(for: profile).rawValue
                }()
            ),
            runtime: ProxiesRuntimeFacts(
                delays: nodes.delays,
                failureReasons: nodes.failureReasons,
                 
                 
                nowByGroup: nodes.nowByGroup,
                resolvedNowByGroup: nodes.resolvedNowByGroup,
                catalog: nodes.groups,
                runtimeNodes: nodes.runtimeProxies,
                providerCatalog: nodes.runtimeProviderCatalog,
                isAuthoritative: nodes.isRuntimeAvailable
            ),
            isConnected: isConnected,
            testingNames: nodes.testingNames,
            isTestingLatency: nodes.isTestingLatency,
            sweepEvents: nodes.latencySweepConduit.eraseToAnyPublisher(),
            latencyCompletedCount: nodes.latencyCompletedCount,
            latencyTotalCount: nodes.latencyTotalCount,
            testAll: {
                guard command.isConnected else {
                    return
                }
                Task {
                    await nodes.testAll()
                }
            },
            testGroup: { groupName in
                guard command.isConnected,
                      let group = nodes.groups.first(
                          where: { $0.name == groupName }
                      )
                else {
                    return
                }
                Task {
                    await nodes.test(group: group)
                }
            },
            switchSelection: { group, member in
                 
                 
                HakoLogStore.shared.append(
                    "proxy pick group=\(group) member=\(member) connected=\(command.isConnected)",
                    stream: .app,
                    level: .info
                )
                if command.isConnected {
                    Task {
                        await nodes.select(
                            group: group,
                            name: member
                        )
                    }
                } else {
                    do {
                        try profiles.updateProxySelection(
                            profileID: profile.id,
                            group: group,
                            member: member,
                            catalog: sourceModel
                        )
                    } catch {
                         
                         
                        HakoLogStore.shared.append(
                            "proxy selection refused offline group=\(group) member=\(member): \(error)",
                            stream: .app,
                            level: .warning
                        )
                    }
                }
            },
            setVisibleGroup: { group in
                if let group {
                    nodes.setCurrentGroup(group)
                }
            },
            updateProvider: { name in
                 
                 
                 
                Task {
                    guard let container = HakoAppIdentifiers.appGroupContainer,
                    let store = try? ConfigResourceStore(
                        containerURL: container
                    ) else { return }
                    do {
                        _ = try await ProviderRefreshService.refresh(
                            name: name,
                            profile: profile,
                            store: store,
                            container: container,
                            vpn: vpn,
                            command: command
                        )
                    } catch {
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                        if SideUpdateDeferral.isDeferred(error) {
                            providerUpdateDeferred = .verbatim(
                                SideUpdateDeferral.displayMessage(error)
                            )
                        } else {
                            providerUpdateFailure =
                                (error as? ConfigurationFailure)?.displayMessage
                                ?? .copy(error.localizedDescription)
                        }
                    }
                    await nodes.refresh()
                }
            },
            setGroupExpanded: { group, isExpanded in
                nodes.setExpanded(isExpanded, group: group)
            },
            setGroupsExpanded: { groups, isExpanded in
                nodes.setExpanded(isExpanded, groups: groups)
            },
            cancelLatency: {
                Task {
                    await nodes.cancelLatencyTests(
                        reason: .requested
                    )
                }
            },
            refreshCatalog: { Task { await nodes.refresh() } },
             
             
            unpinGroup: { group in
                Task { await nodes.unfix(group: group) }
            },
             
            actionRefusals: nodes.actionRefusals,
            testMember: { name in Task { await nodes.test(name) } },
            inspectMember: { name in inspectingNode = ProxyNodeInspection(name: name) },
            initiallyExpandedGroup: initiallyExpandedGroup,
            rememberedExpandedGroups: nodes.unfoldedGroups,
            ownsNavigationContainer: ownsNavigationContainer
        )
        .alert(
            "Provider update failed",
            isPresented: Binding(
                get: { providerUpdateFailure != nil },
                set: { if !$0 { providerUpdateFailure = nil } }
            )
        ) {
            Button("OK", role: .cancel) { providerUpdateFailure = nil }
        } message: {
            Text(hako: providerUpdateFailure ?? .verbatim(""))
        }
        .alert(
            "Update applies at the next activation",
            isPresented: Binding(
                get: { providerUpdateDeferred != nil },
                set: { if !$0 { providerUpdateDeferred = nil } }
            )
        ) {
            Button("OK", role: .cancel) { providerUpdateDeferred = nil }
        } message: {
             
            Text(hako: providerUpdateDeferred ?? .verbatim(""))
        }
    }
}

struct RulesOverviewHost: View {
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var profiles: ProfilesViewModel
    let profile: Profile
    let openProxiesGroup: (String) -> Void
    var ownsNavigationContainer = true
     
     
     
    @State private var compileVerdicts = ProviderCompileVerdicts()

    var body: some View {
         
         
         
        RulesOverviewAdapter(
            sourceYAML: profiles.uiProjectedYAML(for: profile),
            canInspectActiveRules: command.isConnected,
            compileVerdicts: compileVerdicts,
            openProxiesGroup: openProxiesGroup,
            ownsNavigationContainer: ownsNavigationContainer,
            activeRules: {
                 
                 
                 
                ActiveRulesView(command: command)
            }
        )
         
         
         
         
         
         
         
        .task(id: "\(profile.id)#\(profile.activeRevision ?? "")#\(command.isConnected)") {
             
             
             
             
            guard profiles.activeProfileID == profile.id,
                  let container = HakoAppIdentifiers.appGroupContainer else {
                compileVerdicts = ProviderCompileVerdicts()
                return
            }
            let coreHome = container.appendingPathComponent("working")
            var verdicts = await Task.detached(priority: .utility) {
                ProviderCompileVerdicts.load(coreHome: coreHome)
            }.value
             
             
             
            if command.isConnected,
               let catalog = try? await command.providerRuntimeCatalog() {
                for (name, provider) in catalog.ruleProviders {
                    verdicts.entryCounts[name] = provider.ruleCount
                }
            }
            compileVerdicts = verdicts
        }
    }
}

 
 
 
struct SessionProxiesRailRoot: View {
    @ObservedObject var vpn: VPNController
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var nodes: NodesModel
    @ObservedObject var profiles: ProfilesViewModel
    let profileRefreshToken: Int
     
     
     
    let avoidsLiveProviderStore: Bool
    @Binding var stagedGroup: String?

    @State private var preparedModel: ProxiesOverviewModel?
    @State private var preparedProfileID: Profile.ID?
     
     
     
     
    @State private var railStamp = UUID()
     
     
     
     
     
     
     
     
    @State private var openedGroup: String?

    @MainActor
    init(
        vpn: VPNController,
        command: ClashCommandClient,
        nodes: NodesModel,
        profiles: ProfilesViewModel,
        profileRefreshToken: Int,
        avoidsLiveProviderStore: Bool,
        stagedGroup: Binding<String?>
    ) {
        self.vpn = vpn
        self.command = command
        self.nodes = nodes
        self.profiles = profiles
        self.profileRefreshToken = profileRefreshToken
        self.avoidsLiveProviderStore = avoidsLiveProviderStore
        self._stagedGroup = stagedGroup
         
         
         
         
         
         
         
         
         
        _openedGroup = State(initialValue: stagedGroup.wrappedValue)
         
         
         
         
         
         
         
         
         
         
         
         
         
        let restored: (model: ProxiesOverviewModel, profileID: Profile.ID)? =
            HakoPerf.measure("proxies.host.init.cache") {
                guard let profile = HomeProfileResolution.workingProfile(
                    in: profiles
                ),
                      let cached = ProxiesRailPreparationCache.shared.value(
                          for: profile.id
                      ),
                       
                      cached.sourceYAML == profiles.cachedUIProjectedYAML(for: profile)
                else { return nil }
                return (cached.model, cached.profileID)
            }
        if let restored {
            _preparedModel = State(initialValue: restored.model)
            _preparedProfileID = State(initialValue: restored.profileID)
        }
         
         
         
        HakoPerf.count("proxies.rail.init")
    }

    var body: some View {
        Group {
            if let profile = HomeProfileResolution.workingProfile(
                in: profiles
            ) {
                if let preparedModel, preparedProfileID == profile.id {
                    ProxiesOverviewHost(
                        vpn: vpn,
                        command: command,
                        nodes: nodes,
                        profiles: profiles,
                        isConnected: command.isConnected,
                        mode: command.mode,
                        profile: profile,
                         
                         
                         
                         
                         
                         
                        sourceModel: preparedModel.applying(
                            selectedMap: profile.selectedMap
                        ),
                         
                         
                         
                         
                        initiallyExpandedGroup: openedGroup,
                        ownsNavigationContainer: false
                    )
                } else {
                    ProgressView()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }
            } else {
                HakoEmptyState(
                    title: "No Profile",
                    message:
                        "Add a profile before browsing its proxies.",
                    symbol: .exclamationmarkTriangle
                )
            }
        }
        .task(
            id: PreparationKey(
                profileID: HomeProfileResolution.workingProfile(
                    in: profiles
                )?.id,
                refreshToken: profileRefreshToken,
                overrides: HomeProfileResolution.workingProfile(
                    in: profiles
                )?.proxyNodeOverrides
            )
        ) {
             
             
             
             
             
            HakoPerf.markProxiesRailTaskFires(
                stamp: String(railStamp.uuidString.prefix(5))
            )
            await prepare()
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            await nodes.refresh()
        }
        .onAppear {
            guard let staged = stagedGroup else { return }
            HakoPerf.markProxiesRailConsumesStagedGroup()
             
             
            if openedGroup != staged {
                openedGroup = staged
            }
             
             
             
             
             
            Task { @MainActor in
                stagedGroup = nil
            }
        }
    }

    fileprivate struct PreparationKey: Hashable {
        let profileID: Profile.ID?
        let refreshToken: Int
         
         
         
         
         
         
         
         
        let overrides: ProxyNodeOverrideSpec?
    }

    @MainActor
    private func prepare() async {
        guard let profile = HomeProfileResolution.workingProfile(
            in: profiles
        ) else {
            preparedModel = nil
            preparedProfileID = nil
            return
        }
         
         
        let cachedSource = profiles.cachedUIProjectedYAML(for: profile)
        let projectionInputs = cachedSource == nil
            ? profiles.uiProjectionInputs(for: profile)
            : nil
        let selectedMap = profile.selectedMap
         
         
         
         
         
        let cached = ProxiesRailPreparationCache.shared.value(
            for: profile.id
        )
        let began = DispatchTime.now().uptimeNanoseconds
        let avoidsStore = avoidsLiveProviderStore
         
         
         
         
        let comparison = cached.map {
            (
                sourceYAML: $0.sourceYAML,
                fingerprint: $0.fingerprint
            )
        }
        let handle = Task.detached(
            priority: .userInitiated
        ) { () -> (ProxiesRailPreparation, String?)? in
            let sourceYAML: String? = cachedSource ?? projectionInputs.flatMap {
                CustomNodesGroupMaterializer.projectForUI(
                    sourceYAML: $0.sourceYAML, profile: profile
                )
            }
            var providersDir: URL?
            if !avoidsStore,
               let container = HakoAppIdentifiers.appGroupContainer,
               let store = try? ConfigResourceStore(
                   containerURL: container
               ),
                
                
                
                
               let identity = try? store.activeIdentity() {
                providersDir = store.providersDirectory(
                    profileID: identity.profileID,
                    revision: identity.revision
                )
            }
            if Task.isCancelled { return nil }
             
             
             
            let catalog = providersDir.flatMap {
                ProviderCatalog.load(providersDir: $0)
            }
            let fingerprint = ProxiesProviderFingerprint.of(
                directory: providersDir,
                catalog: catalog
            )
            if let comparison,
               comparison.sourceYAML == sourceYAML,
               comparison.fingerprint == fingerprint {
                return (.unchanged, sourceYAML)
            }
            if Task.isCancelled { return nil }
            var providerNodes:
                [String: [ProxiesOverviewModel.Proxy]] = [:]
            if let providersDir, let catalog {
                providerNodes = ProviderNodesLoader.load(
                    catalog: catalog,
                    providersDir: providersDir
                )
            }
            if Task.isCancelled { return nil }
            return (.built(
                model: ProxiesOverviewModel.make(
                    sourceYAML: sourceYAML,
                    selectedMap: selectedMap,
                    providerNodes: providerNodes,
                     
                     
                     
                     
                    loadFailures: (catalog?.entries ?? [])
                        .reduce(into: [String: String]()) { map, entry in
                            if entry.kind == "proxy", let failure = entry.loadFailure {
                                map[entry.name] = failure
                            }
                        }
                ),
                fingerprint: fingerprint
            ), sourceYAML)
        }
         
         
         
        let result = await withTaskCancellationHandler {
            await handle.value
        } onCancel: {
            handle.cancel()
        }
        guard !Task.isCancelled, let (outcome, sourceYAML) = result else {
            return
        }
        if cachedSource == nil, let projectionInputs {
            profiles.rememberUIProjectedYAML(
                sourceYAML, key: projectionInputs.key, for: profile
            )
        }
        switch outcome {
        case .unchanged:
             
             
             
             
             
             
            if let cached,
               preparedModel == nil
                   || preparedProfileID != cached.profileID {
                preparedModel = cached.model
                preparedProfileID = cached.profileID
            }
        case .built(let model, let fingerprint):
            preparedModel = model
            preparedProfileID = profile.id
            ProxiesRailPreparationCache.shared.store(
                (
                    model: model,
                    profileID: profile.id,
                    sourceYAML: sourceYAML,
                    fingerprint: fingerprint
                ),
                for: profile.id
            )
             
             
            HakoPerf.span(
                "proxies.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "groups=\(model.groups.count)"
            )
        }
    }
}

 
private enum ProxiesRailPreparation: Sendable {
    case unchanged
    case built(model: ProxiesOverviewModel, fingerprint: String)
}

 
 
 
 
 
 
 
 
 
 
 
enum ProxiesProviderFingerprint {
    static func of(directory: URL?, catalog: ProviderCatalog?) -> String {
        guard let directory else { return "none" }
        let manager = FileManager.default
        func stamp(_ url: URL) -> String {
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? -1
            let modified = (attributes?[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? -1
            return "\(url.lastPathComponent)|\(size)|\(modified)"
        }
        guard let catalog else {
             
             
             
            return "nocatalog"
        }
        var parts: [String] = []
        for entry in catalog.entries where entry.kind == "proxy" {
            parts.append(
                "\(entry.name)|"
                    + stamp(directory.appendingPathComponent(entry.path))
            )
        }
        return parts.sorted().joined(separator: ";")
    }
}

 
 
@MainActor
private enum ProxiesRailPreparationCache {
    static let shared = HakoLastPreparation<
        Profile.ID,
        (
            model: ProxiesOverviewModel,
            profileID: Profile.ID,
            sourceYAML: String?,
            fingerprint: String
        )
    >()
}

 
struct SessionRulesRailRoot: View {
    @ObservedObject var command: ClashCommandClient
    @ObservedObject var profiles: ProfilesViewModel
    let openProxiesGroup: (String) -> Void

    var body: some View {
        if let profile = HomeProfileResolution.workingProfile(
            in: profiles
        ) {
            RulesOverviewHost(
                command: command,
                profiles: profiles,
                profile: profile,
                openProxiesGroup: openProxiesGroup,
                ownsNavigationContainer: false
            )
        } else {
            HakoEmptyState(
                title: "No Profile",
                message:
                    "Add a profile before browsing its rules.",
                symbol: .exclamationmarkTriangle
            )
        }
    }
}

 
 
enum HomeProfileResolution {
    @MainActor
    static func workingProfile(
        in profiles: ProfilesViewModel
    ) -> Profile? {
        if let active = profiles.activeProfileID,
           let profile = profiles.profiles.first(
               where: { $0.id == active }
           ) {
            return profile
        }
        if let id = ProfileCenterPolicy.automaticSelectionID(
            profiles: profiles.profiles,
            activeProfileID: nil
        ) {
            return profiles.profiles.first { $0.id == id }
        }
        return nil
    }
}



 
 
 
 
 
extension ProxiesOverviewHost: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        let equal = a.isConnected == b.isConnected
            && a.mode == b.mode
            && a.profile.id == b.profile.id
            && a.profile.activeRevision == b.profile.activeRevision
             
             
             
             
             
             
            && a.sourceModel == b.sourceModel
            && a.initiallyExpandedGroup == b.initiallyExpandedGroup
            && a.ownsNavigationContainer == b.ownsNavigationContainer
        HakoPerf.count(equal ? "proxies.host.eq.hit" : "proxies.host.eq.miss")
        return equal
    }
}

extension ProxiesOverviewHost {
     
     
     
     
     
    fileprivate func nodeDetailSheet(for inspection: ProxyNodeInspection) -> some View {
         
         
         
         
        let inputs = profiles.uiProjectionInputs(for: profile)
        let cached = profiles.cachedUIProjectedYAML(for: profile)
        var providersDir: URL?
        if let container = HakoAppIdentifiers.appGroupContainer,
           let store = try? ConfigResourceStore(containerURL: container),
           let identity = try? store.activeIdentity() {
            providersDir = store.providersDirectory(
                profileID: identity.profileID,
                revision: identity.revision
            )
        }
        return ProxyNodeEditorSheet(
            nodeName: inspection.name,
            sourceYAML: inputs.sourceYAML,
            cachedProjection: cached,
            profile: profile,
            providersDir: providersDir,
            profiles: profiles
        )
    }
}
