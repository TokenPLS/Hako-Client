import SwiftUI

 
 
 
 
 
 
 
struct HakoTVShell: View {
     
     
     
    enum Tab: Hashable { case home, utilities, more }

    var stage: HakoTVTestStage?
     
     
    let matrix: HakoTVLaunchOverrides?
     
     
     
    var connectsOnLaunch = false
     
     
    var updatesOnLaunch = false

    @State private var tab: Tab = .home
     
     
    @State private var fixture: HakoTVProductState
     
     
    @StateObject private var tunnel: HakoTVTunnelController
     
     
     
    @State private var store: HakoTVSubscriptionStore
     
     
    @State private var showsAddSubscription = false
     
     
     
     
    @State private var showsOutboundMode = false
     
     
    @State private var showsSubscriptions = false
     
     
    @State private var subscriptionDoor: HakoTVSubscription.ID?
     
     
    @State private var editDoor: EditDoor?

    struct EditDoor: Identifiable, Hashable {
        let id: HakoTVSubscription.ID
    }
     
     
     
    @State private var showsNodes = false
     
     
    @State private var utilitiesDoor: HakoTVUtilitiesHub.Door?
     
    @State private var moreDoor: HakoTVMoreHub.Door?
     
     
     
     
    @State private var connectionDoor: HakoTVConnectionsScreen.Door?
     
     
     
     
     
     
     
    @State private var showsProviders = false

    init(stage: HakoTVTestStage?, connectsOnLaunch: Bool = false, updatesOnLaunch: Bool = false, matrix: HakoTVLaunchOverrides? = nil, store: HakoTVSubscriptionStore = HakoTVSubscriptionStore()) {
        self.stage = stage
        self.connectsOnLaunch = connectsOnLaunch
        self.updatesOnLaunch = updatesOnLaunch
        self.matrix = matrix
        let fixture: HakoTVProductState.Fixture = switch stage {
        case .nodesMany: .manyGroups
        case .nodesManyTen: .manyGroupsTenNodes
        case .nodesLongNames: .longNames
        default: .prototype
        }
        _fixture = State(initialValue: HakoTVProductState(fixture: fixture))
        _tunnel = StateObject(wrappedValue: HakoTVTunnelController())
         
         
         
        var store = stage == .subscriptions || stage == .subscriptionDetail || stage == .editSubscription || stage == .addSubscription
            ? HakoTVSubscriptionStore.stageFixture()
            : store


        _store = State(initialValue: store)
    }

    private var hasConfiguration: Bool {
        !store.subscriptions.isEmpty
    }

     
     
     
    private var live: Bool { stage == nil }

    private var state: Binding<HakoTVProductState> {
        live ? $tunnel.state : $fixture
    }

     
     
     
    private func primaryAction() {
        guard let current = store.current else { return }
        let presentation = HakoTVHomePresentation.make(state: tunnel.state)
        Task {
            if tunnel.state.isConnected || presentation.cancels {
                await tunnel.disconnect()
            } else {
                await tunnel.connect(subscription: current)
            }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
             
             
             
             
             
            NavigationStack {
                Group {
                    if hasConfiguration || stage == .home || stage == .connected || stage == .outboundMode {
                        HakoTVHomeView(
                            state: state,
                            showsOutboundMode: $showsOutboundMode,
                            showsSubscriptions: $showsSubscriptions,
                            showsNodes: $showsNodes,
                            onPrimaryAction: live ? primaryAction : nil
                        )
                    } else {
                        HakoTVWelcomeView { showsAddSubscription = true }
                    }
                }
                .navigationDestination(isPresented: $showsOutboundMode) {
                    HakoTVOutboundModeScreen(
                        state: state,
                        onSelect: live ? { mode in Task { await tunnel.setMode(mode) } } : nil
                    )
                }
                .navigationDestination(isPresented: $showsNodes) {
                    HakoTVNodesScreen(
                        state: state,
                        onPin: live ? { member, group in Task { await tunnel.pin(member: member, group: group) } } : nil,
                        onTestAll: live ? { group in Task { await tunnel.testAll(group: group) } } : nil,
                        onTest: live ? { member in Task { await tunnel.testOne(member: member) } } : nil
                    )
                }
                .navigationDestination(isPresented: $showsSubscriptions) {
                    HakoTVSubscriptionsScreen(
                        store: $store,
                        onOpen: { subscriptionDoor = $0 },
                        onAdd: { showsAddSubscription = true }
                    )
                }
                .navigationDestination(item: $subscriptionDoor) { id in
                    HakoTVSubscriptionDetailScreen(
                        store: $store,
                        id: id,
                        refresh: live ? tunnel.state.refresh : nil,
                        onDone: {
                             
                             
                             
                             
                             
                            subscriptionDoor = nil
                        },
                        onUpdate: live ? {
                            if let subscription = store.subscriptions.first(where: { $0.id == id }) {
                                Task { await tunnel.refresh(subscription: subscription) }
                            }
                        } : nil,
                        onEdit: { editDoor = EditDoor(id: id) }
                    )
                }
                .navigationDestination(item: $editDoor) { door in
                    HakoTVEditSubscriptionScreen(store: $store, id: door.id) { newAddress in
                         
                         
                        editDoor = nil
                         
                         
                         
                         
                         
                         
                         
                        guard live,
                              let subscription = HakoTVEditSubscriptionScreen.refreshTarget(
                                  newAddress: newAddress, in: store
                              )
                        else { return }
                        Task { await tunnel.refresh(subscription: subscription) }
                    }
                }
                .navigationDestination(isPresented: $showsAddSubscription) {
                    HakoTVAddSubscriptionScreen(store: $store) {
                         
                         
                         
                        showsAddSubscription = false
                    }
                }
            }
             
             
             
             
            .hakoTVTitleSafe()
            .tabItem { Text("Home") }
            .tag(Tab.home)

            utilitiesTab
                .hakoTVTitleSafe()
                .tabItem { Text("Utilities") }
                .tag(Tab.utilities)

             
             
            NavigationStack {
                HakoTVMoreHub(state: state, opened: $moreDoor, onAutoConnect: { wanted in
                     
                     
                     
                     
                     
                    Task { await tunnel.setAutoConnect(wanted) }
                })
                    .navigationDestination(item: $moreDoor) { door in
                        switch door {
                        case .dns:
                            HakoTVDNSScreen(state: state)
                        case .userAgent:
                            HakoTVUserAgentScreen()
                        case .proxyShare:
                            HakoTVProxyShareScreen(state: state, tunnel: tunnel)
                        case .diagnostics:
                            HakoTVDiagnosticsScreen(
                                state: state,
                                openDNS: { moreDoor = .dns },
                                openProviders: { showsProviders = true }
                            )
                        }
                    }
                    .navigationDestination(isPresented: $showsProviders) {
                        HakoTVProvidersScreen(state: state)
                    }
            }
            .hakoTVTitleSafe()
            .tabItem { Text("More") }
            .tag(Tab.more)
        }


        .onChange(of: tunnel.lastActivation) { _, activation in
             
             
             
            guard let activation else { return }
            store.markUpdated(activation.subscriptionID, at: activation.at)
        }
        .onChange(of: store.current, initial: true) { previous, current in
             
             
             
             
             
             
            let row = Self.homeProfileRow(for: current, fixture: HakoTVProductState())
            state.wrappedValue.profileName = row.name
            state.wrappedValue.profileAge = row.age
             
             
             
             
             
             
            guard live, previous?.id != current?.id else { return }
            if let current {
                Task { await tunnel.subscriptionChanged(to: current) }
            } else {
                Task { await tunnel.disconnect() }
            }
        }
        .task(id: stage) {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            guard stage == .connectionsLive || stage == .connectionDetail else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                HakoTVConnectionsScreen.liveTick(&fixture, at: Date())
            }
        }
        .onExitCommand(perform: currentTabDoor == nil ? nil : closeTopmostDoor)
        .task {
             
             
            if live {
                await runMatrixPreparation()
                if connectsOnLaunch { primaryAction() }
                await runMatrixProbes()
                if updatesOnLaunch, let current = store.current {
                    showsSubscriptions = true
                    try? await Task.sleep(for: .milliseconds(400))
                    subscriptionDoor = current.id
                    Task { await tunnel.refresh(subscription: current) }
                }
            }
             
             
            if stage == .connected { fixture.stage = .connected }
            if stage == .outboundMode { showsOutboundMode = true }
            if let mode = stage?.outboundModeOverride { fixture.outboundMode = mode }
            if stage?.opensNodes == true {
                tab = .utilities
                utilitiesDoor = .nodes
            }
            if stage == .rules {
                tab = .utilities
                utilitiesDoor = .rules
            }
            if stage == .connections || stage == .connectionsLive || stage == .connectionDetail {
                tab = .utilities
                utilitiesDoor = .connections
            }
            if stage == .connectionDetail, let first = HakoTVConnectionsScreen.rows(fixture.connections, kind: .all).first {
                 
                 
                 
                try? await Task.sleep(for: .milliseconds(400))
                connectionDoor = HakoTVConnectionsScreen.Door(connection: first)
            }
            if stage == .subscriptions { showsSubscriptions = true }
            if stage == .subscriptionDetail {
                 
                 
                 
                showsSubscriptions = true
                try? await Task.sleep(for: .milliseconds(400))
                subscriptionDoor = store.subscriptions.first { $0.id != store.current?.id }?.id
            }
            if stage == .editSubscription, let current = store.current {
                 
                showsSubscriptions = true
                try? await Task.sleep(for: .milliseconds(400))
                subscriptionDoor = current.id
                try? await Task.sleep(for: .milliseconds(400))
                editDoor = EditDoor(id: current.id)
            }
            if stage == .addSubscription { showsAddSubscription = true }
            if stage == .more { tab = .more }
            if stage == .diagnostics { tab = .more; moreDoor = .diagnostics }
            if stage == .dns { tab = .more; moreDoor = .dns }
            if stage == .userAgent { tab = .more; moreDoor = .userAgent }
            if stage == .proxyShare { tab = .more; moreDoor = .proxyShare }
            if stage == .providers {
                 
                 
                 
                tab = .more
                moreDoor = .diagnostics
                try? await Task.sleep(for: .milliseconds(400))
                showsProviders = true
            }
        }
    }

     
     
     
     
     
     
     
     
    @ViewBuilder
    private var utilitiesTab: some View {
        NavigationStack {
            HakoTVUtilitiesHub(opened: $utilitiesDoor)
                .navigationDestination(item: $utilitiesDoor) { door in
                    switch door {
                    case .nodes:
                        HakoTVNodesScreen(
                            state: state,
                            onPin: live ? { member, group in Task { await tunnel.pin(member: member, group: group) } } : nil,
                            onTestAll: live ? { group in Task { await tunnel.testAll(group: group) } } : nil,
                        onTest: live ? { member in Task { await tunnel.testOne(member: member) } } : nil
                        )
                    case .rules:
                        HakoTVRulesScreen(state: state)
                    case .connections:
                        HakoTVConnectionsScreen(state: state, opened: $connectionDoor)
                    }
                }
                 
                 
                 
                .navigationDestination(item: $connectionDoor) { door in
                    HakoTVConnectionDetailScreen(state: state, seed: door.connection)
                }
        }
    }

     
    enum DoorPop: Equatable {
        case edit, subscriptionDetail, addSubscription, subscriptions, nodes, outboundMode
        case utilities, connectionDetail, more, providers
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func doorToClose(
        tab: Tab,
        editOpen: Bool, detailOpen: Bool, addOpen: Bool,
        subscriptionsOpen: Bool, nodesOpen: Bool, outboundOpen: Bool,
        utilitiesOpen: Bool, connectionOpen: Bool, moreOpen: Bool, providersOpen: Bool
    ) -> DoorPop? {
        switch tab {
        case .home:
             
             
            if editOpen { return .edit }
            if detailOpen { return .subscriptionDetail }
            if addOpen { return .addSubscription }
            if subscriptionsOpen { return .subscriptions }
            if nodesOpen { return .nodes }
            if outboundOpen { return .outboundMode }
            return nil
        case .utilities:
             
             
            if connectionOpen { return .connectionDetail }
            return utilitiesOpen ? .utilities : nil
        case .more:
             
             
            if providersOpen { return .providers }
            return moreOpen ? .more : nil
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    enum DoorUnder: Equatable {
        case more(HakoTVMoreHub.Door)
        case utilities(HakoTVUtilitiesHub.Door)
    }

    static func doorUnder(_ door: DoorPop) -> DoorUnder? {
        switch door {
        case .providers: .more(.diagnostics)
        case .connectionDetail: .utilities(.connections)
        default: nil
        }
    }

    private var currentTabDoor: DoorPop? {
        Self.doorToClose(tab: tab,
                         editOpen: editDoor != nil, detailOpen: subscriptionDoor != nil,
                         addOpen: showsAddSubscription, subscriptionsOpen: showsSubscriptions,
                         nodesOpen: showsNodes, outboundOpen: showsOutboundMode,
                         utilitiesOpen: utilitiesDoor != nil, connectionOpen: connectionDoor != nil,
                         moreOpen: moreDoor != nil, providersOpen: showsProviders)
    }

    private func closeTopmostDoor() {


        let closing = currentTabDoor
        switch closing {
        case .edit: editDoor = nil
        case .subscriptionDetail: subscriptionDoor = nil
        case .addSubscription: showsAddSubscription = false
        case .subscriptions: showsSubscriptions = false
        case .nodes: showsNodes = false
        case .outboundMode: showsOutboundMode = false
        case .utilities: utilitiesDoor = nil
        case .connectionDetail: connectionDoor = nil
        case .providers: showsProviders = false
        case .more: moreDoor = nil
        case nil: break
        }
         
         
         
        if let top = closing, let under = Self.doorUnder(top) {
            switch under {
            case .more(let door): moreDoor = door
            case .utilities(let door): utilitiesDoor = door
            }
        }


    }

     
     
     
     
     
    private func runMatrixPreparation() async {


        await tunnel.prepare(subscription: store.current)


    }

     
     
    private func runMatrixProbes() async {


    }

}

extension HakoTVShell {
     

     
     
     
    static func homeProfileRow(
        for current: HakoTVSubscription?,
        fixture: HakoTVProductState
    ) -> (name: String, age: String) {
        guard let current else { return (fixture.profileName, fixture.profileAge) }
        return (current.title, HakoTVSubscriptionUpdatedWords.text(updatedAt: current.updatedAt))
    }
}

extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoTVTitleSafe() -> some View {
        safeAreaPadding(EdgeInsets(top: 60, leading: 90, bottom: 60, trailing: 90))
    }


}
