import HakoClientUI
import SwiftUI

public struct HakoMacRootView: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let secondaryContent: @MainActor (HakoMacSecondaryDestination) -> AnyView
     
     
     
    private let detailOverlay:
        @MainActor (HakoClientUI.HakoRootDestination?) -> AnyView
    private let moreAttentionAction: @MainActor (String) -> Void

    @State private var navigationState:
        HakoClientUI.AppleClientNavigationState
    @State private var configurationDestination:
        HakoMacSecondaryDestination = .configuration
    @State private var isPickingProfile = false
    @Binding private var navigationRequest:
        HakoMacSecondaryDestination?

    public init(
        snapshot: AppleClientSnapshot,
        selection: HakoMacDestination = .home,
        actions: AppleClientActions,
        navigationRequest:
            Binding<HakoMacSecondaryDestination?> = .constant(nil),
        secondaryContent: @escaping @MainActor (HakoMacSecondaryDestination) -> AnyView = {
            AnyView(HakoMacSecondaryUnavailableView(destination: $0))
        },
        detailOverlay: @escaping @MainActor (
            HakoClientUI.HakoRootDestination?
        ) -> AnyView = { _ in AnyView(EmptyView()) },
         
         
         
        moreAttentionAction: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.secondaryContent = secondaryContent
        self.detailOverlay = detailOverlay
        self.moreAttentionAction = moreAttentionAction
        _navigationRequest = navigationRequest
        _navigationState = State(
            initialValue: HakoClientUI.AppleClientNavigationState(
                selectedRoot: selection
            )
        )
    }

    public var body: some View {
         
         
         
        HakoClientUI.HakoRegularClientShell(
            navigationState: $navigationState,
            sidebarBehavior: .systemMenuOnly,
            background: HakoMacPlatformPresentation.palette.canvas,
            sidebarBackground: HakoMacPlatformPresentation.palette.surface
        ) { destination in
            HakoSymbolImage(
                symbol: destination.symbol,
                resizesToFit: true
            )
        } rootContent: { destination in
            sharedProductPage(for: destination)
        } destinationContent: { destination in
            sharedDestinationContent(destination)
        } detailOverlay: { destination in
            detailOverlay(destination)
        }
        .frame(minWidth: 880, minHeight: 600)
         
         
         
        .environment(
            \.hakoFullWidthSegmentedPickerAdapter,
            HakoMacPlatformPresentation.fullWidthSegmentedPickerAdapter
        )
        .accessibilityIdentifier("hako.mac.root")
        .onAppear {
            HakoNavigationHooks.resignCurrentField =
                HakoMacPlatformPresentation.resignCurrentField
             
             
             
            HakoMacFrameCounter.install()
            consumeNavigationRequest()
        }
        .onChange(of: navigationRequest) { _ in
            consumeNavigationRequest()
        }
        .hakoPageProbe("window-root")
    }

    @ViewBuilder
    private func sharedProductPage(
        for destination: HakoClientUI.HakoRootDestination
    ) -> some View {
        switch destination {
        case .home:
             
             
             
             
             
            HakoDeferredPageContent {
            HakoClientUI.HakoHomeView(
                snapshot: snapshot,
                actions: navigationAwareActions,
                presentationClass: .regularTouch,
                palette: productPalette,
                 
                 
                customizationPresentation: { _ in
                    AnyView(
                        HakoMacCardCustomizationPanel(
                            favorites: snapshot.home.favoriteCards
                        ) { cards in
                            let actions = navigationAwareActions
                            let snapshot = snapshot
                            Task {
                                try? await actions.perform(
                                    .home(.setCards(cards)),
                                    allowedBy: snapshot
                                )
                            }
                        }
                    )
                }
            ) { symbol in
                 
                 
                 
                 
                 
                 
                 
                HakoSymbolImage(symbol: symbol)
                    .popover(
                        isPresented: profilePickerPresentation(for: symbol),
                        arrowEdge: .bottom
                    ) {
                        HakoMacProfilePicker(
                            profiles: snapshot.profiles.profiles,
                            select: { id in
                                isPickingProfile = false
                                Task { @MainActor in
                                    try? await actions.perform(
                                        .selectProfile(id: id),
                                        allowedBy: snapshot
                                    )
                                }
                            }
                        )
                    }
            }
            } placeholder: {
                HakoMacPlatformPresentation.palette.canvas
                    .ignoresSafeArea()
            }
        case .utilities:
            HakoClientUI.HakoUtilitiesView(
                snapshot: snapshot,
                destination: utilitiesDestinationBinding,
                presentationClass: .regularTouch,
                palette: productPalette,
                 
                 
                 
                 
                 
                omitting: HakoUtilitiesCatalog.regularHubExcludes,
                icon: { symbol in
                    HakoSymbolImage(symbol: symbol)
                },
                destinationContent: { destination in
                    sharedDestinationContent(.utilities(destination))
                }
            )
        case .more:
            HakoClientUI.HakoMoreView(
                snapshot: snapshot,
                destination: moreDestinationBinding,
                presentationClass: .regularTouch,
                palette: productPalette,
                 
                 
                omitting: HakoMoreCatalog.regularHubExcludes,
                attentionAction: moreAttentionAction,
                icon: { symbol in
                    HakoSymbolImage(symbol: symbol)
                },
                destinationContent: { destination in
                    sharedDestinationContent(.more(destination))
                }
            )
        case .profiles, .proxies, .rules, .connections, .requests, .logs,
             .dns, .about:
            sharedDestinationContent(destination.productDestination)
        }
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        HakoMacPlatformPresentation.palette
    }

    private var navigationAwareActions: AppleClientActions {
        let components = actions.providedCapabilities.map { capability in
            AppleClientActions(capability: capability) { action in
                navigate(for: action)
                try await actions.perform(action, allowedBy: snapshot)
            }
        }
        return (try? AppleClientActions.composing(components))
            ?? .unavailable
    }

    private var utilitiesDestinationBinding:
        Binding<HakoUtilitiesDestination>
    {
        Binding(
            get: {
                guard navigationState.selectedRoot == .utilities,
                      case .utilities(let destination) =
                        navigationState.destination
                else {
                    return .root
                }
                return destination
            },
            set: { destination in
                openUtility(destination)
            }
        )
    }

    private var moreDestinationBinding:
        Binding<HakoMoreDestination>
    {
        Binding(
            get: {
                guard navigationState.selectedRoot == .more,
                      case .more(let destination) =
                        navigationState.destination
                else {
                    return .root
                }
                return destination
            },
            set: { destination in
                openMore(destination)
            }
        )
    }

    private func sharedDestinationContent(
        _ destination: HakoClientUI.AppleClientDestination
    ) -> AnyView {
        if destination == .configuration {
            return secondaryContent(configurationDestination)
        }
        if let macDestination = HakoMacSecondaryDestination(
            sharedDestination: destination
        ) {
            return secondaryContent(macDestination)
        } else {
            return AnyView(sharedProductPage(for: destination.root))
        }
    }

    private func consumeNavigationRequest() {
        guard let requested = navigationRequest else { return }
        if requested.isConfigurationDestination {
            configurationDestination = requested
        }
        navigationState.navigate(to: requested.sharedDestination)
        navigationRequest = nil
    }

    private func navigate(for action: AppleClientAction) {
        let destination: HakoClientUI.AppleClientDestination?
        switch action {
        case .home(let command):
            if let requested =
                HakoMacSecondaryDestination(homeCommand: command)
            {
                configurationDestination = requested
                destination = .configuration
            } else {
                switch command {
                case .openProfiles:
                     
                     
                    isPickingProfile = true
                    destination = nil
                case .openProxies:
                    destination = .proxies
                case .openRules:
                    destination = .rules
                case .performPrimaryAction, .showConnectionIssue,
                     .setCards, .setTrafficScope, .refreshExternalIP,
                     .refreshLANIP:
                    destination = nil
                case .openAdjustment, .openRuntimeConfiguration:
                    destination = nil
                }
            }
        case .rules(.openActiveRules):
            destination = .activeRules
        case .rules(.openProxiesGroup):
            destination = .proxies
        case .dns(.openDNSQuery):
            destination = .dnsQuery
        default:
            destination = nil
        }
        if let destination {
            navigationState.navigate(to: destination)
        }
    }

    private func openUtility(_ destination: HakoUtilityDestination) {
        if destination == .root {
            navigationState.selectRoot(.utilities)
            return
        }
        navigationState.navigate(to: .utilities(destination))
        Task { @MainActor in
            try? await actions.perform(
                .openUtility(destination),
                allowedBy: snapshot
            )
        }
    }

    private func openMore(_ destination: HakoMoreDestination) {
        if destination == .root {
            navigationState.selectRoot(.more)
            return
        }
        navigationState.navigate(to: .more(destination))
        Task { @MainActor in
            try? await actions.perform(
                .openMore(destination),
                allowedBy: snapshot
            )
        }
    }
}

private extension HakoMacSecondaryDestination {
    var isConfigurationDestination: Bool {
        switch self {
        case .homeAdjustment, .runtimeConfiguration, .configuration:
            true
        case .profiles, .proxies, .rules, .activeRules, .dnsQuery,
             .utility, .more:
            false
        }
    }

    var sharedDestination: HakoClientUI.AppleClientDestination {
        switch self {
        case .profiles:
            .profiles
        case .proxies:
            .proxies
        case .rules:
            .rules
        case .activeRules:
            .activeRules
        case .dnsQuery:
            .dnsQuery
        case .homeAdjustment, .runtimeConfiguration, .configuration:
            .configuration
        case .utility(let destination):
            .utilities(destination)
        case .more(let destination):
            .more(destination)
        }
    }

    init?(
        sharedDestination destination: HakoClientUI.AppleClientDestination
    ) {
        switch destination {
        case .profiles, .profileImport, .profileDetail:
            self = .profiles
        case .proxies:
            self = .proxies
        case .rules:
            self = .rules
        case .activeRules:
            self = .activeRules
        case .dnsQuery:
            self = .dnsQuery
        case .configuration:
            self = .configuration
        case .utilities(let destination) where destination != .root:
            self = .utility(destination)
        case .more(let destination) where destination != .root:
            self = .more(destination)
        case .home, .utilities, .more:
            return nil
        }
    }
}

extension HakoMacRootView {
}

extension HakoMacRootView {
     
     
     
    fileprivate func profilePickerPresentation(
        for symbol: HakoSymbol
    ) -> Binding<Bool> {
        symbol == .chevronDown ? $isPickingProfile : .constant(false)
    }
}
