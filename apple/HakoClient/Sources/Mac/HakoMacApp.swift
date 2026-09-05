import AppKit
import Combine
import HakoClientKit
import HakoClientUI
import HakoMacClient
import SwiftUI
import os

@MainActor
private final class HakoMacApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
         
         
        HakoMacDockIcon.apply(
            hidesIcon: UserDefaults.standard.bool(forKey: HakoMacDockIcon.key)
        )
         
         
         
        DispatchQueue.main.async {
            guard NSApplication.shared.windows.allSatisfy({
                $0.level != .normal || !$0.canBecomeKey
            }) else { return }
            HakoMacSceneModel.current?.openMainWindow()
        }


    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

     
     
     
     
     
    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let vpn = HakoMacSceneModel.current?.vpn else { return .terminateNow }
        let quit = HakoMacQuit(
            isTunnelUp: { [weak vpn] in
                guard let vpn else { return false }
                return HakoMacQuit.tunnelIsUp(status: vpn.status)
            },
             
             
             
             
            stop: { [weak vpn] in await vpn?.stop() },
            allowTermination: { sender.reply(toApplicationShouldTerminate: true) }
        )
        pendingQuit = quit
        return quit.reply(for: HakoMacQuit.nextTermination)
    }

     
    private var pendingQuit: HakoMacQuit?

     
     
     
     
     
     
     
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        guard !hasVisibleWindows else { return true }
        HakoMacSceneModel.current?.openMainWindow()
        return true
    }

     
     
     
     
     
    func applicationDidUpdate(_ notification: Notification) {
        HakoMacDockIcon.apply(
            hidesIcon: UserDefaults.standard.bool(forKey: HakoMacDockIcon.key)
        )
    }

     
     
     
     
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let model = HakoMacSceneModel.current else { return nil }
        let locale = model.preferences.language.locale
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: HakoCopy.string(
                    model.snapshot.connection.phase.statusTitle,
                    locale: locale
                ),
                action: nil,
                keyEquivalent: ""
            )
        )
        if let intent = model.snapshot.connection.primaryIntent {
            let action = NSMenuItem(
                title: HakoCopy.string(intent.toolbarTitle, locale: locale),
                action: #selector(performDockPrimaryAction),
                keyEquivalent: ""
            )
            action.target = self
            menu.addItem(action)
        }
        return menu
    }

    @objc private func performDockPrimaryAction() {
        HakoMacSceneModel.current?.performPrimaryAction()
    }
}

private struct HakoMacUIReviewEnvironment: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {

        content

    }
}

@main
struct HakoMacApp: App {
    @NSApplicationDelegateAdaptor(HakoMacApplicationDelegate.self)
    private var applicationDelegate
    @StateObject private var model = HakoMacSceneModel()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase

    init() {
         
         
        HakoPerfBootstrap.install()
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        DispatchQueue.global(qos: .utility).async {
            _ = ThirdPartyLicenseInventory.shared.modules.count
        }
         
         
         
         
        ProxyNodeEditorMacOverrides.proxyTypeRow = { draft, hidesNonServerTypes in
            AnyView(
                ProxyTypeMacRow(
                    draft: draft,
                    hidesNonServerTypes: hidesNonServerTypes
                )
            )
        }
         
         
         
         
        ProxyNodeEditorMacOverrides.editorContainer = { content in
            AnyView(ProxyNodeMacEditorContainer(content: content))
        }
    }

    var body: some Scene {
         
         
         
         
        Window("Clash", id: "main") {
            HakoMacRootView(
                snapshot: model.snapshot,
                actions: model.actions,
                navigationRequest: $model.navigationRequest,
                secondaryContent: { destination in
                     
                     
                     
                     
                     
                     
                     
                     
                    AnyView(
                        HakoDeferredPageContent {
                            model.secondaryContent(destination)
                        } placeholder: {
                            HakoMacPlatformPresentation.palette.canvas
                                .ignoresSafeArea()
                        }
                        .id(destination)
                    )
                },
                detailOverlay: { root in
                    model.pooledDetailOverlay(for: root)
                },
                moreAttentionAction: { actionID in
                    model.performLegacySettingsAttention(actionID: actionID)
                }
            )
            .environment(\.hakoShellLayout, .regularSidebar)
             
             
            .modifier(HakoMacLiveResizeReporting())
             
             
             
            .environment(\.hakoBackupDataScope, model.backupScope)
            .environment(\.hakoTrafficFeed, model.trafficFeed)
            .modifier(HakoMacUIReviewEnvironment())
            .hakoMacWindowChrome()
             
             
             
             
             
            .onAppear {
                model.rememberWindowOpener(openWindow)
            }
            .task {
                await model.prepare()
            }
            .onOpenURL { url in
                model.open(url)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: ProviderFirstLoadRetry.didRefreshNotification
                )
            ) { _ in
                model.applyFirstLoadRefreshes()
            }
            .alert(
                "Outbound mode unchanged",
                isPresented: Binding(
                    get: { !model.modeRefusalMessage.isEmpty },
                    set: { presented in
                        if !presented {
                            model.dismissModeRefusalMessage()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    model.dismissModeRefusalMessage()
                }
            } message: {
                Text(hako: .copy(model.modeRefusalMessage))
            }
            .alert(
                Text(hako: .copy(
                    model.profileImports.pendingConfirmation
                        .map { HakoMacInstallLinkPrompt(pending: $0).title }
                        ?? "Add this subscription?"
                )),
                isPresented: Binding(
                     
                     
                     
                     
                     
                    get: {
                        model.profileImports.pendingConfirmation != nil
                            && scenePhase == .active
                    },
                     
                     
                     
                     
                     
                     
                    set: { presented in
                        if !presented,
                           let pending = model.profileImports.pendingConfirmation {
                            HakoLogStore.shared.append(
                                "install link alert torn down (state kept)  \(pending)",
                                stream: .app, level: .warning)
                        }
                    }
                )
            ) {
                Button("Add") {
                    model.profileImports.acceptPendingConfirmation()
                    model.navigationRequest = .profiles
                }
                Button("Don't Add", role: .cancel) {
                    model.profileImports.declinePendingConfirmation()
                }
            } message: {
                if let pending = model.profileImports.pendingConfirmation {
                    let prompt = HakoMacInstallLinkPrompt(pending: pending)
                     
                     
                     
                    Text(hako: .copy(prompt.lead)) + Text(hako: .verbatim(prompt.link))
                }
            }
            .modifier(
                HakoMacPreferencesEnvironment(
                    preferences: model.preferences,
                    presentsRestartPrompt: true
                )
            )
        }
        .defaultSize(width: 1040, height: 720)
         
         
         
        WindowGroup("Edit Source", id: "source-editor", for: HakoMacSourceEditorRequest.self) { $request in
            if let request {
                HakoMacSourceEditorWindow(request: request, profiles: model.profiles)
            }
        }
        .defaultSize(width: 920, height: 720)
         
         
        .commandsRemoved()
        .windowResizability(.contentMinSize)
        .commands {
            HakoMacProductCommands()
        }

    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoMacDockIcon {
     
    static let key = "hako.mac.hide-dock-icon"

     
     
     
     
     
    static func policy(
        hidesIcon: Bool,
        hasVisibleWindow: Bool
    ) -> NSApplication.ActivationPolicy {
        hidesIcon && !hasVisibleWindow ? .accessory : .regular
    }

    @MainActor
    static func apply(hidesIcon: Bool, application: NSApplication = .shared) {
        let visible = application.windows.contains {
            $0.isVisible && $0.level == .normal && $0.canBecomeKey
        }
        let wanted = policy(hidesIcon: hidesIcon, hasVisibleWindow: visible)
        guard application.activationPolicy() != wanted else { return }
        application.setActivationPolicy(wanted)
         
         
        if wanted == .regular {
            application.activate(ignoringOtherApps: true)
        }
    }
}

enum HakoMacMenuBarSpeed {
     
     
    static let key = "hako.mac.menu-bar-speed"

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func rate(_ bytesPerSecond: Int64) -> String {
        let bitsPerSecond = Double(max(bytesPerSecond, 0)) * 8
        if bitsPerSecond < 1_000_000 {
            return String(format: "%.1f Kbps", bitsPerSecond / 1_000)
        }
        if bitsPerSecond < 1_000_000_000 {
            return String(format: "%.1f Mbps", bitsPerSecond / 1_000_000)
        }
        return String(format: "%.1f Gbps", bitsPerSecond / 1_000_000_000)
    }

     
     
     
     
    static let widestLine = "999.9 Mbps ↑"

    static func up(_ bytesPerSecond: Int64) -> String { rate(bytesPerSecond) + " ↑" }

    static func down(_ bytesPerSecond: Int64) -> String { rate(bytesPerSecond) + " ↓" }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @MainActor
    static func menuBarImage(upLine: String, downLine: String) -> NSImage? {
        guard !upLine.isEmpty, !downLine.isEmpty,
              let cat = NSImage(named: HakoMacAsset.menuBarTemplate.rawValue)
        else { return nil }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
             
             
            .foregroundColor: NSColor.black,
        ]
        let upLine = upLine as NSString
        let downLine = downLine as NSString
        let upSize = upLine.size(withAttributes: attributes)
        let downSize = downLine.size(withAttributes: attributes)

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let reserve = (widestLine as NSString).size(withAttributes: attributes)
        let column = ceil(max(reserve.width, max(upSize.width, downSize.width)))
        let line = ceil(max(upSize.height, downSize.height))
         
         
         
        let height = line * 2 - 2
         
         
        let cat18: CGFloat = 18
        let gap: CGFloat = 3
        let size = CGSize(width: cat18 + gap + column, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            cat.draw(
                in: CGRect(
                    x: 0,
                    y: (height - cat18) / 2,
                    width: cat18,
                    height: cat18
                )
            )
             
             
             
             
             
            upLine.draw(
                at: CGPoint(
                    x: cat18 + gap + column - upSize.width,
                    y: height - line
                ),
                withAttributes: attributes
            )
            downLine.draw(
                at: CGPoint(x: cat18 + gap + column - downSize.width, y: 0),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
private final class HakoMacMenuBarTrafficFeed: ObservableObject {
    @Published private(set) var upLine = ""
    @Published private(set) var downLine = ""

     
     
     
     
     
     
     
     
     
     
    private var trackingDepth = 0
    private var menuIsTracking: Bool { trackingDepth > 0 }
     
    private var thaw: DispatchWorkItem?
    private var pending: (up: String, down: String)?
    private var subscriptions: Set<AnyCancellable> = []

    init(command: ClashCommandClient) {
        upLine = HakoMacMenuBarSpeed.up(command.traffic.upload)
        downLine = HakoMacMenuBarSpeed.down(command.traffic.download)
        command.$traffic
            .sink { [weak self] traffic in
                self?.offer(
                    up: HakoMacMenuBarSpeed.up(traffic.upload),
                    down: HakoMacMenuBarSpeed.down(traffic.download)
                )
            }
            .store(in: &subscriptions)
        let center = NotificationCenter.default
        center.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                 
                 
                self.thaw?.cancel()
                self.thaw = nil
                self.trackingDepth += 1
            }
            .store(in: &subscriptions)
        center.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.trackingDepth = max(0, self.trackingDepth - 1)
                guard self.trackingDepth == 0 else { return }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.trackingDepth == 0 else { return }
                    self.thaw = nil
                    if let pending = self.pending {
                        self.pending = nil
                        self.upLine = pending.up
                        self.downLine = pending.down
                    }
                }
                self.thaw = work
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.25, execute: work
                )
                return
            }
            .store(in: &subscriptions)
    }

    private func offer(up: String, down: String) {
        guard up != upLine || down != downLine else { return }
        if menuIsTracking {
            pending = (up, down)
        } else {
            upLine = up
            downLine = down
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoMacProxiesGhostChrome: View, Equatable {
    let model: HakoMacSceneModel
    @ObservedObject var channels: HakoRegularRootChannels

    init(model: HakoMacSceneModel) {
        self.model = model
        self.channels = model.proxiesChannels
    }

    static func == (
        lhs: HakoMacProxiesGhostChrome,
        rhs: HakoMacProxiesGhostChrome
    ) -> Bool {
        lhs.model === rhs.model
    }

    var body: some View {
        Color.clear
            .searchable(
                text: $channels.searchText,
                prompt: Text("Search proxies")
            )
            .hakoToolbarUnlessInPanel {
                HakoProxiesToolbar(
                    showsDismissControl: false,
                    hasExpandedGroups: model.proxiesHasExpandedGroupsNow,
                     
                     
                     
                     
                     
                     
                    canRefreshCatalog: true,
                    refreshDisabled: model.isTestingLatencyNow,
                    preferences: Binding(
                        get: {
                            HakoProxiesDisplayPreferences.uiTestOverride()
                                ?? HakoProxiesDisplayPreferences.load()
                        },
                        set: { [weak model] value in
                             
                             
                             
                             
                             
                            model?.applyProxiesDisplayPreferences(value)
                        }
                    ),
                    onDismiss: {},
                    onToggleFold: { [weak model] in
                        model?.proxiesChannels.foldCommand += 1
                    },
                    onRefresh: { [weak model] in
                        guard let model else { return }
                        Task { await model.refreshNodes() }
                    },
                    onShowDisplayOptions: {},
                    icon: { HakoSymbolImage(symbol: $0) }
                )
            }
    }
}

@MainActor
private final class HakoMacSceneModel: ObservableObject {
     
     
     
     
     
     
     
     
    private var automaticRefreshDriver: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    @Published private(set) var snapshot: AppleClientSnapshot = .empty
     
     
     
     
     
    let trafficFeed = HakoTrafficFeed(traffic: .zero)

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var menuTrackingDepth = 0
    private var heldSnapshot: AppleClientSnapshot?
    private var snapshotThaw: DispatchWorkItem?
    private var menuGate: Set<AnyCancellable> = []

     
     
     
     
     
     
     
     
     
     
     
     
     
    private var refreshScheduled = false

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.refreshScheduled = false
            self.refreshSnapshot()
        }
    }

    private func publish(_ value: AppleClientSnapshot) {
        guard menuTrackingDepth > 0 || snapshotThaw != nil else {
            snapshot = value
            return
        }
        heldSnapshot = value
    }

    private func observeMenuTracking() {
        let center = NotificationCenter.default
        center.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.snapshotThaw?.cancel()
                self.snapshotThaw = nil
                self.menuTrackingDepth += 1
            }
            .store(in: &menuGate)
        center.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.menuTrackingDepth = max(0, self.menuTrackingDepth - 1)
                guard self.menuTrackingDepth == 0 else { return }
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.menuTrackingDepth == 0 else { return }
                    self.snapshotThaw = nil
                    if let held = self.heldSnapshot {
                        self.heldSnapshot = nil
                        self.snapshot = held
                    }
                }
                self.snapshotThaw = work
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.25, execute: work
                )
            }
            .store(in: &menuGate)
    }
    @Published var navigationRequest: HakoMacSecondaryDestination?
    @Published private var stagedProxyGroup: String?
    @Published private var profileRefreshToken = 0
     
     
    @Published private var lanAddress: String?
     
     
     
     
     
     
    @Published private(set) var modeRefusalMessage = ""
     
     
     
     
    let proxiesChannels = HakoRegularRootChannels()
     
     
     
    private var poolContentEpoch = 0
    func nextPoolEpoch() -> Int {
        poolContentEpoch &+= 1
        return poolContentEpoch
    }
     
     
    let rulesChannels = HakoRegularRootChannels()
    @Published private var proxiesHasExpandedGroups = false
     
     
     
    private lazy var proxiesFoldStateSink = HakoBoolSink { [weak self] value in
        guard let self, self.proxiesHasExpandedGroups != value else {
            return
        }
        self.proxiesHasExpandedGroups = value
    }
     
     
    private lazy var rulesFoldStateSink = HakoBoolSink { _ in }

    let vpn: VPNController
    let profiles: ProfilesViewModel
     
     
     
     
    let reviewContainer: URL?
     
     
     
     
    let backupScope: HakoBackupDataScope
    let command: ClashCommandClient
    let stats: StatsModel
    let nodes: NodesModel
     
     
    var proxiesHasExpandedGroupsNow: Bool { proxiesHasExpandedGroups }
    var isTestingLatencyNow: Bool { nodes.isTestingLatency }
    func refreshNodes() async { await nodes.refresh() }
     
     
     
     
     
     
     
    func applyProxiesDisplayPreferences(
        _ value: HakoProxiesDisplayPreferences
    ) {
        value.save()
        proxiesChannels.requestDisplayPreferences(value)
    }
    let networkQuality: NetworkQualityModel
    let stun: STUNTestModel
    let connections: ConnectionsModel
    let proxyShare: ProxyShareModel
    let profileImports: ProfileImportRouter
    let preferences: AppPreferencesModel

    private var revision: UInt64 = 0
    private var cancellables: Set<AnyCancellable> = []
     
     
     
     
     
    lazy var menuBarTraffic = HakoMacMenuBarTrafficFeed(command: command)

    private lazy var connectionRequests = ConnectionRequestCoalescer(
        gestureWindow: { NSEvent.doubleClickInterval },
         
         
         
         
         
         
         
         
        isSettling: { [weak self] in
            guard let status = self?.vpn.status.lowercased() else { return false }
            return status == "connecting" || status == "disconnecting"
        }
    )

    init() {
         
         
         
         
         
         
         
        defer {
            Self.current = self
             
             
             
             
            let sink: () -> Void = { [weak nodes = self.nodes] in
                nodes?.latencyPublishQuietUntil = Date(
                    timeIntervalSinceNow: 0.6
                )
            }
            proxiesChannels.uiTransitionSink = sink
            rulesChannels.uiTransitionSink = sink
        }
        let vpn = VPNController()
        self.vpn = vpn
        let reviewContainer = (nil as URL?)
        self.reviewContainer = reviewContainer
            backupScope = .ordinary
            profiles = ProfilesViewModel(vpn: vpn)
        command = ClashCommandClient()
        stats = StatsModel()
            nodes = NodesModel()
        networkQuality = NetworkQualityModel()
        stun = STUNTestModel()
            connections = ConnectionsModel()
        proxyShare = ProxyShareModel()
        profileImports = ProfileImportRouter()
        preferences = AppPreferencesModel()

        observeRuntimeChanges()

        observeMenuTracking()
        refreshSnapshot()
        Self.current = self
        installStatusItem()
    }

     
     
     
     
    static weak var current: HakoMacSceneModel?

     
    private(set) var statusItem: NSStatusItem?
    private var statusMenuController: HakoMacStatusMenuController?
    private var statusItemSubscriptions: Set<AnyCancellable> = []

     
     
    func focusMainWindow(_ openWindow: OpenWindowAction) {
        if raiseExistingMainWindow() { return }
        openWindow(id: "main")
    }

     
     
     
    private var openWindowAction: OpenWindowAction?

    func rememberWindowOpener(_ openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

     
     
    func openSourceEditor(profileID: String) {
        openWindowAction?(
            id: "source-editor",
            value: HakoMacSourceEditorRequest(profileID: profileID)
        )
    }

     
     
    func openMainWindow() {
        if raiseExistingMainWindow() { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindowAction?(id: "main")
    }

    @discardableResult
    private func raiseExistingMainWindow() -> Bool {
        guard let window = NSApplication.shared.windows.first(where: {
            $0.level == .normal && $0.canBecomeKey
        }) else { return false }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return true
    }

     
     
     
     
     
    var currentOutboundMode: AppleClientOutboundMode {
        AppleClientOutboundMode(rawValue: outboundMode.rawValue) ?? .rule
    }

    var actions: AppleClientActions {
        let home = AppleClientActions(capability: .home) {
            [weak self] action in
            guard case .home(let command) = action else { return }
            await self?.perform(command)
        }
        let connection = AppleClientActions(capability: .connection) {
            [weak self] action in
            guard case .connection(let intent) = action else { return }
            await self?.performConnection(intent)
        }
        let profiles = AppleClientActions(capability: .profiles) {
            [weak self] action in
            guard let self, case .profiles(let command) = action else { return }
            switch command {
            case .select(let id):
                await self.selectProfile(id)
            case let .adoptHeldBackUpdate(id, keyPath):
                self.adoptHeldBackUpdate(id, keyPath: keyPath)
            case .dismissHeldBackUpdates(let id):
                self.dismissHeldBackUpdates(id)
            default:
                 
                 
                 
                break
            }
        }
        let selection = AppleClientActions(capability: .profileSelection) {
            [weak self] action in
            guard case .selectProfile(let id) = action else { return }
            await self?.selectProfile(id)
        }
        let routing = AppleClientActions(capability: .outboundMode) {
            [weak self] action in
            guard case .setOutboundMode(let mode) = action else { return }
            await self?.setOutboundMode(mode)
        }
        let utilities = AppleClientActions(capability: .utilities) {
            action in
            guard case .openUtility = action else { return }
        }
        let more = AppleClientActions(capability: .more) { action in
            guard case .openMore = action else { return }
        }
        return (try? AppleClientActions.composing([
            home,
            connection,
            profiles,
            selection,
            routing,
            utilities,
            more,
        ])) ?? .unavailable
    }

    func prepare() async {
             
             
             
            vpn.legacySettingsMigration = vpn.migrateLegacyGlobalSettingsIfNeeded()
        profiles.load()
         
        recomputeHomeRuleTally()
        profiles.selectSoleProfileIfNeeded()
        profileImports.importSharedFiles()
        rebind()
        prewarmEditorPreparations()
        await vpn.refresh()
        rebind()
        connections.sync(command.isConnected)
        proxyShare.updateAPIAvailability(command.isConnected)
        if command.isConnected {
            await command.refreshMetadata()
            await nodes.refresh()
            await proxyShare.refresh()
        }
        startAutomaticResourceRefresh()
        refreshSnapshot()
    }

     
     
    private func startAutomaticResourceRefresh() {
        guard !false,
              automaticRefreshDriver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await BackgroundRefresh.scanOnForegroundIfDue() }
        }
        automaticRefreshDriver = Task {
            await BackgroundRefresh.scanOnForegroundIfDue()
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        BackgroundRefresh.foregroundScanInterval
                    ) * 1_000_000_000
                )
                guard !Task.isCancelled else { break }
                await BackgroundRefresh.scanOnForegroundIfDue()
            }
        }
    }

    deinit {
        automaticRefreshDriver?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

     
     
     
     
    private var legacySettingsAttention: LegacySettingsAttention? {
        guard let result = vpn.legacySettingsMigration else { return nil }
        return LegacySettingsAttention.make(from: result, profiles: profiles.profiles)
    }

     
     
     
    func performLegacySettingsAttention(actionID: String) {
        guard let attention = legacySettingsAttention,
              let action = attention.actions.first(where: { $0.id == actionID })
        else { return }
        switch action.resolution {
        case .openProfile, .openScripts:
             
             
             
            navigationRequest = .profiles
        default:
            guard let workingDirectory = HakoAppIdentifiers.appGroupContainer?
                .appendingPathComponent("working", isDirectory: true)
            else { return }
            if let fresh = LegacySettingsResolver.perform(
                action.resolution,
                attentionID: attention.id,
                workingDirectory: workingDirectory
            ) {
                vpn.legacySettingsMigration = fresh
            }
             
             
             
            profiles.load()
            refreshSnapshot()
        }
    }

    func dismissModeRefusalMessage() {
        modeRefusalMessage = ""
    }

     
     
     
    func cancelStart() {
        Task { await performPrimaryAction(.cancel) }
    }

    func performPrimaryAction() {
        guard let intent = snapshot.connection.primaryIntent else { return }
        Task { await performConnection(intent) }
    }

    func selectProfile(_ id: HakoClientKit.Profile.ID) async {
        guard let profile = profiles.profiles.first(
            where: { $0.id == id.rawValue }
        ) else { return }
        guard await profiles.selectAndWait(profile) else {
            refreshSnapshot()
            return
        }
        activeRuntimeDidChange()
        refreshSnapshot()
    }

     
     
    func adoptHeldBackUpdate(_ id: HakoClientKit.Profile.ID, keyPath: String) {
        guard let profile = profiles.profiles.first(where: { $0.id == id.rawValue }) else { return }
        do {
            try profiles.adoptHeldBackUpdate(profile, keyPath: keyPath)
            activeRuntimeDidChange()
        } catch {
            Logger(subsystem: HakoPerf.subsystem, category: "profiles")
                .error("adopt held-back update failed: \(String(describing: error), privacy: .public)")
        }
        refreshSnapshot()
    }

     
    func dismissHeldBackUpdates(_ id: HakoClientKit.Profile.ID) {
        guard let profile = profiles.profiles.first(where: { $0.id == id.rawValue }) else { return }
        do {
            try profiles.dismissHeldBackUpdates(profile)
        } catch {
            Logger(subsystem: HakoPerf.subsystem, category: "profiles")
                .error("dismiss held-back updates failed: \(String(describing: error), privacy: .public)")
        }
        refreshSnapshot()
    }

    func setOutboundMode(_ mode: AppleClientOutboundMode) async {
        guard let profile = currentProfile,
              let storedMode = Profile.OutboundMode(
                  rawValue: mode.rawValue
              )
        else { return }

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if OutboundModeSelection.changesNothing(
            requested: storedMode,
            stored: profiles.outboundMode(for: profile),
            running: command.isConnected ? command.mode : nil
        ) {
            return
        }

        if storedMode == .global, command.isConnected {
             
             
             
             
             
            var verdict = GlobalModeConfirmation.verdict(
                groupCount: nodes.groups.count,
                selectionConfirmed: await nodes.ensureGlobalProxySelection()
            )
            if verdict == .notYetKnown {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                try? await Task.sleep(nanoseconds: 400_000_000)
                verdict = GlobalModeConfirmation.verdict(
                    groupCount: nodes.groups.count,
                    selectionConfirmed: await nodes.ensureGlobalProxySelection()
                )
            }
            switch verdict {
            case .confirmed:
                break
            case .notYetKnown:
                 
                 
                 
                 
                modeRefusalMessage = """
                    The core has not reported its proxy groups yet, so \
                    Global mode was not applied. Try again in a moment.
                    """
                return
            case .refused:
                 
                 
                 
                 
                modeRefusalMessage =
                    GlobalProxySelectionPolicy.refusal(groups: nodes.groups)
                    ?? """
                        The GLOBAL group resolves to a direct connection, not \
                        a proxy. Global mode sends every flow through GLOBAL, \
                        so select a proxy in that group first.
                        """
                return
            }
        }

        do {
             
             
             
             
             
             
             
            try profiles.updateOutboundMode(
                profileID: profile.id,
                mode: storedMode,
                kernelCarriesTheChange: command.isConnected
            )
            if command.isConnected {
                await command.setMode(storedMode.rawValue)
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                if command.isConnected, command.mode != storedMode.rawValue {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await command.setMode(storedMode.rawValue)
                }
                if command.isConnected, command.mode != storedMode.rawValue {
                    modeRefusalMessage = """
                        The running tunnel did not accept the mode change. \
                        The profile was saved; the mode applies on the next \
                        connect.
                        """
                }
            }
        } catch {
             
             
            modeRefusalMessage = """
                The outbound mode could not be saved to this profile. \
                \(error.localizedDescription)
                """
            return
        }
        refreshSnapshot()
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private func performConnection(
        _ intent: AppleClientConnectionIntent,
        beforeRun: (@MainActor @Sendable () -> Void)? = nil
    ) async {
        await connectionRequests.run { [weak self] in
            await beforeRun?()
            await self?.performConnectionUncoalesced(intent)
            return true
        }
    }

    private func performConnectionUncoalesced(
        _ intent: AppleClientConnectionIntent
    ) async {
        switch intent {
        case .disconnect:
            await vpn.stop()
        case .connect, .activateSystemExtension,
             .updateSystemExtension, .installConfiguration:
            if let currentProfile,
               profiles.activeProfileID != currentProfile.id
            {
                guard await profiles.selectAndWait(currentProfile)
                else { return }
            } else {
                _ = await vpn.start()
            }
        }
        rebind()
        refreshSnapshot()
    }

     
     
     
    func applyFirstLoadRefreshes() {
        let updates = ProviderFirstLoadRetry.takeRuntimeUpdates()
        guard !updates.isEmpty else { return }
        Task { [command] in
            for update in updates {
                _ = await command.sideUpdateProvider(update)
            }
        }
    }

    func open(_ url: URL) {
        if let route = HakoSystemRoute(url: url) {
            handleSystemRoute(route)
            return
        }
        profileImports.open(url)
        if url.isFileURL {
            navigationRequest = .profiles
        }
    }

     
     
     
     
     
     
    private func handleSystemRoute(_ route: HakoSystemRoute) {
        Task { [weak self] in
            guard let self else { return }
             
             
             
            await self.vpn.refresh()
            let plan = HakoMacSystemRoutePlan.plan(
                for: route,
                isActive: HakoSystemVPNPolicy.isActive(self.vpn.status)
            )
            if let destination = plan.destination {
                self.navigationRequest = destination
            }
            if let mode = plan.mode {
                await self.setOutboundMode(mode)
            }
            switch plan.command {
            case .start?:
                await self.performConnection(.connect)
            case .stop?:
                await self.performConnection(.disconnect)
            case .unchanged?, nil:
                break
            }
        }
    }

    func secondaryContent(
        _ destination: HakoMacSecondaryDestination
    ) -> AnyView {
        switch destination {
        case .profiles:
             
             
             
             
             
             
            AnyView(
                ProfileCenterAdapter(
                    profiles: profiles,
                    importRouter: profileImports,
                    ownsNavigationContainer: false,
                    palette: HakoMacPlatformPresentation.palette,
                    onActiveRuntimeChanged: {
                        [weak self] in
                        self?.activeRuntimeDidChange()
                    },
                    capabilityInterceptor: { [weak self] destination in
                        guard let self,
                              case .sourceEditor(let id) = destination
                        else { return false }
                        self.openSourceEditor(profileID: id.rawValue)
                        return true
                    },
                    listPresentation: { list in
                        AnyView(
                            HakoMacProfilesList(
                                profiles: list.profiles,
                                selectingProfileID: list.selectingProfileID,
                                selectionFailure: list.selectionFailure,
                                select: list.select,
                                openDetail: list.openDetail,
                                reorder: list.reorder,
                                 
                                 
                                addProfile: list.openImport,
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                backupDestination: {
                                    [vpn = self.vpn,
                                     command = self.command,
                                     preferences = self.preferences] in
                                    AnyView(
                                        GoldenFlowMoreDestinationAdapter(
                                            vpn: vpn,
                                            command: command,
                                            preferences: preferences,
                                            destination: .backupRestore,
                                            usesRegularDetailLayout: true
                                        )
                                    )
                                },
                                sync: { list.perform(.sync(id: $0)) },
                                duplicate: {
                                    list.perform(.duplicate(id: $0))
                                },
                                export: { list.perform(.export(id: $0)) },
                                delete: { list.perform(.delete(id: $0)) }
                            )
                        )
                    }
                )
                .hakoToolbarUnlessInPanel {
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    ToolbarItem(placement: .primaryAction) {
                        if self.profiles.hasSubscriptionProfile {
                            Button {
                                self.profiles.syncAll()
                            } label: {
                                Label {
                                    Text(hako: .copy("Update All"))
                                } icon: {
                                    Image(systemName: HakoSymbol.arrowTriangle2Circlepath.name)
                                }
                            }
                            .disabled(self.profiles.isSyncingAll)
                            .help(Text(hako: .copy("Update All")))
                            .accessibilityIdentifier("profile-center.sync-all")
                        }
                    }
                }
            )
        case .proxies:
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            AnyView(
                HakoMacProxiesGhostChrome(model: self).equatable()
            )
        case .rules:
             
             
             
            AnyView(
                Color.clear
                    .searchable(
                        text: Binding(
                            get: { [weak self] in
                                self?.rulesChannels.searchText ?? ""
                            },
                            set: { [weak self] in
                                self?.rulesChannels.searchText = $0
                            }
                        ),
                        prompt: Text("Search rules")
                    )
            )
        case .activeRules:
            AnyView(ActiveRulesView(command: command))
        case .dnsQuery:
            AnyView(DNSQueryView(command: command))
        case .homeAdjustment(let action):
            homeAdjustmentContent(action)
        case .runtimeConfiguration:
            runtimeConfigurationContent()
        case .configuration:
            AnyView(
                GoldenFlowMoreDestinationAdapter(
                    vpn: vpn,
                    command: command,
                    preferences: preferences,
                    destination: .coreBehavior,
                    usesRegularDetailLayout: true
                )
            )
        case .utility(let destination):
            AnyView(
                GoldenFlowUtilitiesDestinationAdapter(
                    vpn: vpn,
                    command: command,
                    connections: connections,
                    networkQuality: networkQuality,
                    stun: stun,
                    proxyShare: proxyShare,
                    destination: destination,
                    usesRegularDetailLayout: true,
                    loadsPersistedLogs:
                        !false
                )
            )
        case .more(let destination):
            AnyView(
                GoldenFlowMoreDestinationAdapter(
                    vpn: vpn,
                    command: command,
                    preferences: preferences,
                    destination: destination,
                    usesRegularDetailLayout: true
                )
            )
        }
    }

    private func runtimeConfigurationContent() -> AnyView {
        guard let profile = currentProfile else {
            return AnyView(
                HakoMacSecondaryUnavailableView(
                    destination: .runtimeConfiguration
                )
            )
        }
         
         
         
        let isActive = profiles.activeProfileID == profile.id
        let verdictsHome: URL? = reviewContainer
            ?? HakoAppIdentifiers.appGroupContainer
        return AnyView(
            HakoMacRuntimeConfigurationPage(
                profile: profile,
                isActive: isActive,
                fetchTexts: { [weak self] in
                    guard let self else { return (nil, nil, nil) }
                    return (
                        self.profiles.capturedSourceText(for: profile),
                        self.profiles.previewText(for: profile),
                        self.profiles.sourceYAML(for: profile)
                    )
                },
                blockedRuleSets: isActive
                    ? { [verdictsHome] in
                        guard let verdictsHome else { return [] }
                        return ProviderCompileVerdicts
                            .load(
                                coreHome: verdictsHome
                                    .appendingPathComponent("working")
                            )
                            .blockedRuleProviders
                    }
                    : nil
            )
            .equatable()
        )
    }

    private func homeAdjustmentContent(
        _ action: HakoHomeAdjustmentAction
    ) -> AnyView {
        guard let profile = currentProfile else {
            return AnyView(
                HakoMacSecondaryUnavailableView(
                    destination: .homeAdjustment(action)
                )
            )
        }

        switch action {
        case .customNodes:
            return AnyView(
                CustomNodesView(
                    profile: profile,
                    sourceYAML: profiles.uiProjectedYAML(for: profile),
                    ownsNavigationContainer: false,
                    loadDraft: {
                        try self.profiles.providerDefinitionsDraft(
                            for: profile
                        )
                    },
                    prepareDraft: {
                        try await self.profiles.providerDefinitionsDraftAsync(
                            for: profile
                        )
                    },
                    saveDraft: {
                        try self.profiles.updateProviderDefinitions($0)
                    },
                    renameNode: {
                        try self.profiles.renameProxyNode(
                            profileID: profile.id, from: $0, to: $1
                        )
                    }
                )
            )
        case .proxyChains:
            return AnyView(
                HakoMacDeferredSourcePage(
                    profile: profile,
                    fetch: { [weak self, profile] in
                        self?.profiles.runtimeSourceYAML(for: profile)
                    }
                ) { rawYAML in
                AnyView(ProfileProxyChainsView(
                    profile: profile,
                    rawYAML: rawYAML,
                    ownsNavigationContainer: false,
                    save: {
                        try self.profiles.updateProxyChains($0)
                    },
                    measure: false
                        ? { name in
                            name == "Review Entry" ? 12 : 34
                        }
                        : self.command.isConnected ? { name in
                            let outcome =
                                await self.command.urlTestQuietly(name: name)
                            return outcome.succeeded ? outcome.delay : 0
                        }
                        : nil,
                    savePayloadDialers: { edits in
                        try self.savePayloadDialerEdits(
                            edits,
                            profileID: profile.id
                        )
                    },
                    openCustomNodes: { [weak self] in
                         
                         
                         
                        self?.navigationRequest =
                            .homeAdjustment(.customNodes)
                    }
                ))
                }
                .equatable()
            )
        case .routingRules:
            return AnyView(
                ProfileRulesAdapter(
                    profile: profile,
                    sourceYAML: profiles.uiProjectedYAML(for: profile),
                    ownsNavigationContainer: false
                ) {
                    try self.profiles.updateRules($0)
                }
            )
        case .connection:
            return AnyView(
                ProfileNetworkSettingsView(
                    profile: profile,
                    sourceYAML: self.profiles.uiProjectedYAML(for: profile),
                    ownsNavigationContainer: false,
                    udpFallbackGuardInput: { [profiles = self.profiles] in
                        await profiles.udpFallbackGuardInput(for: profile)
                    }
                ) {
                    try self.profiles.updateNetwork($0)
                }
            )
        case .proxySources:
            return AnyView(
                ProfileProviderDefinitionsView(
                    profile: profile,
                    kind: .proxy,
                    ownsNavigationContainer: false,
                    load: {
                        try await self.profiles.providerDefinitionsDraftAsync(
                            for: profile
                        )
                    },
                    save: {
                        try self.profiles.updateProviderDefinitions($0)
                    }
                )
            )
        case .ruleSets:
            return AnyView(
                ProfileProviderDefinitionsView(
                    profile: profile,
                    kind: .rule,
                    ownsNavigationContainer: false,
                    load: {
                        try await self.profiles.providerDefinitionsDraftAsync(
                            for: profile
                        )
                    },
                    save: {
                        try self.profiles.updateProviderDefinitions($0)
                    }
                )
            )
        case .advancedOverrides:
            return AnyView(
                HakoMacDeferredSourcePage(
                    profile: profile,
                    fetch: { [weak self, profile] in
                        self?.profiles.sourceYAML(for: profile)
                    }
                ) { sourceYAML in
                AnyView(ProfileAdvancedOverridesView(
                    profile: profile,
                    sourceYAML: sourceYAML,
                    ownsNavigationContainer: false,
                    save: {
                        try self.profiles.updateAdvancedOverrides($0)
                    }
                ))
                }
                .equatable()
            )
        case .rawFields:
            return AnyView(
                ProfileAdditionalFieldsView(
                    profile: profile,
                    ownsNavigationContainer: false,
                    save: {
                        try self.profiles.updateAdvancedOverrides($0)
                    }
                )
            )
        }
    }

    private func savePayloadDialerEdits(
        _ edits: [ProxyPayloadDialerEdit],
        profileID: String
    ) throws {
        guard !edits.isEmpty else {
            return
        }
        guard let latest = profiles.profiles.first(
            where: { $0.id == profileID }
        ) else {
            throw PipelineError.sourceUnavailable(
                "the profile is no longer available"
            )
        }
        var working = try profiles.providerDefinitionsDraft(for: latest)
        for edit in edits {
            try working.setPayloadDialer(
                provider: edit.provider,
                node: edit.node,
                dialerProxy: edit.dialerProxy
            )
        }
        try profiles.updateProviderDefinitions(working)
    }

    private var currentProfile: Profile? {
        return HomeProfileResolution.workingProfile(in: profiles)
    }

    private var outboundMode: Profile.OutboundMode {
        if command.isConnected,
           let live = Profile.OutboundMode(
               rawValue: command.mode.lowercased()
           )
        {
            return live
        }
        return currentProfile.map(profiles.outboundMode) ?? .rule
    }

     
     
     
     
    var menuBarProxyCatalog: HakoMacMenuProxyCatalog {
        HakoMacMenuProxyCatalog.make(
            groups: nodes.groups,
            mode: ProxyBrowsingVisibility.Mode(coreValue: outboundMode.rawValue),
            delays: nodes.delays,
            testing: nodes.testingNames
        )
    }

     
     
     
     
    fileprivate func menuBarLatency(delays: [String: Int], testing: Set<String>) -> [String: HakoProxyLatencyState] {
        HakoMacMenuProxyCatalog.make(
            groups: nodes.groups,
            mode: ProxyBrowsingVisibility.Mode(coreValue: outboundMode.rawValue),
            delays: delays,
            testing: testing
        ).groups.reduce(into: [:]) { all, group in
            all.merge(group.latency) { _, new in new }
        }
    }

    private var selectedRoute: (name: String?, delay: Int?) {
         
         
         
         
         
         
         
        guard outboundMode == .global,
              let group = nodes.groups.first(
                  where: { $0.name == "GLOBAL" }
              )
        else { return (nil, nil) }
        let route =
            group.resolvedNow.isEmpty ? group.now : group.resolvedNow
        guard !route.isEmpty else { return (nil, nil) }
        return (route, nodes.delays[route])
    }

    private var connectionPhase: AppleClientConnectionPhase {
        switch vpn.status.lowercased() {
        case "connected", "reasserting":
            .connected
        case "connecting":
            .preparing
        case "disconnecting":
            .disconnecting
        case "invalid", "unknown", "unavailable":
            .unavailable
        default:
            .disconnected
        }
    }

    private func trafficSnapshot(_ traffic: ClashTrafficSnapshot) -> AppleClientTrafficSnapshot {
        AppleClientTrafficSnapshot(
            uploadBytesPerSecond: traffic.upload,
            downloadBytesPerSecond: traffic.download,
            uploadTotalBytes: traffic.uploadTotal,
            downloadTotalBytes: traffic.downloadTotal,
            uploadRatesBytesPerSecond: traffic.uploadHistory,
            downloadRatesBytesPerSecond: traffic.downloadHistory,
            coreStartedAtUnixSeconds: command.runtimeDiagnostics?.startTimeUnix ?? 0
        )
    }

    private func refreshSnapshot() {
        revision &+= 1
        let profile = currentProfile
        let selected = profile.flatMap { stored in
            try? HakoClientKit.Profile.ID(stored.id)
        }.map {
            AppleClientProfileSnapshot(
                id: $0,
                label: profile?.label ?? ""
            )
        }
        let mode = outboundMode
        let route = selectedRoute
        let info = AppBuildInfo.current()

        publish(AppleClientSnapshot(
            revision: revision,
            selectedProfile: selected,
            connection: AppleClientConnectionSnapshot(
                phase: connectionPhase,
                selectedRouteName: route.name,
                selectedRouteDelayMilliseconds: route.delay,
                issue: vpn.reportableLastError.isEmpty
                    ? nil
                    : AppleClientFailure(
                        code: .connection,
                        title: "Connection",
                        message: vpn.reportableLastError
                    )
            ),
            home: AppleClientHomeSnapshot(
                routing: AppleClientRoutingSnapshot(
                    mode:
                        AppleClientOutboundMode(
                            rawValue: mode.rawValue
                        ) ?? .rule
                ),
                traffic: trafficSnapshot(command.traffic),
                proxyGroupCount: nodes.groups.count,
                proxyCount: nodes.nodeCatalog.count,
                ruleCount: homeRuleTally?.count ?? command.rules.count,
                connection:
                    HakoHomeConnectionPresenter.presentation(
                        for: HakoHomeConnectionFacts(
                            activeProfileName: profile?.label,
                            vpnStatus: vpn.status,
                            errorMessage: vpn.reportableLastError,
                            allowsSystemVPNProfileReset:
                                vpn.systemVPNProfileResetAvailable,
                            isSwitchingProxy:
                                nodes.isSwitchingProxy,
                            mode: mode.rawValue,
                            selectedProxyName: route.name,
                            selectedProxyDelayMilliseconds:
                                route.delay
                        )
                    ),
                favoriteCards: HomeFavoriteCardPreferences().load(),
                trafficScope: TrafficStatisticsSettings.onlyProxy()
                    ? .proxiedOnly
                    : .allTraffic,
                proxies: HakoHomeDomainSnapshot(
                    count: nodes.nodeCatalog.count,
                    countUnit: "proxies",
                    names: nodes.groups.map(\.name)
                ),
                rules: HakoHomeDomainSnapshot(
                    count: homeRuleTally?.count,
                    countUnit: "rules",
                    names: homeRuleTally?.targets ?? []
                ),
                 
                 
                 
                 
                 
                egress: egressSnapshot,
                lanAddress: lanAddress,
                adjustments: HakoHomeAdjustmentModule.allCases.map {
                    HakoHomeAdjustmentSnapshot(
                        module: $0,
                        summary: adjustmentSummary($0)
                    )
                },
                isProfileActionInFlight:
                    profiles.isActivationInFlight
            ),
            profiles: HakoProfilesSnapshot(
                profiles: profiles.profiles.compactMap(
                    profileSnapshot
                ),
                statusMessage: profiles.statusMessage,
                featureAvailability: .full
            ),
            utilities: HakoUtilitiesSnapshot(
                nativeAPIConnected: command.isConnected,
                activeConnectionCount:
                    connections.activeConnectionCount,
                requestCount: connections.requestLog.count,
                logCount: command.logs.count,
                isRecordingLogs: HakoLogSettings.isRecording(
                    from: GlobalConfig.appGroupDefaults
                ),
                logRetentionTitle: HakoLogSettings.retention(
                    from: GlobalConfig.appGroupDefaults
                ).title,
                networkQualitySummary: networkQuality.summary,
                stunSummary: stun.summary,
                proxyShareStatus: proxyShare.phase.title,
                proxyShareEnabled: proxyShare.status.enabled
            ),
            more: HakoMoreSnapshot(
                dnsOnlyActive:
                    NetworkOperatingModeStore().current == .dnsOnly,
                about: HakoAboutSnapshot(
                    appVersion: info.appVersion,
                    buildNumber: info.buildNumber,
                    sourceRevision: info.sourceRevision,
                    coreVersion: info.coreVersion
                ),
                 
                 
                 
                 
                 
                overrideCounts: OverrideEntryCount.moreCounts(
                    in: currentProfile.map { profiles.settingsProfile(for: $0) }?
                        .override.patchJSON ?? ""
                ),
                attention: legacySettingsAttention?.snapshot
            ),
            capabilities: AppleClientCapabilities([
                .home: .available,
                .profiles: .available,
                .proxies:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
                .activity:
                    command.isConnected
                        ? .available
                        : .unavailable(.requiresConnection),
                .rules:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
                .dns:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
                .utilities: .available,
                .more: .available,
                .configuration:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
                .connection:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
                .profileSelection:
                    profiles.profiles.isEmpty
                        ? .unavailable(.requiresProfile)
                        : .available,
                .outboundMode:
                    profile == nil
                        ? .unavailable(.requiresProfile)
                        : .available,
            ])
        ))
    }

    private func profileSnapshot(
        _ profile: Profile
    ) -> HakoProfileSnapshot? {
        guard let id = try? HakoClientKit.Profile.ID(profile.id)
        else { return nil }
        let source: HakoProfileSourceKind
        let sourceSummary: HakoDisplayText
        switch profile.source {
        case .url:
            source = .remote
            sourceSummary = "Subscription"
        case .file(let name):
            source = .file
            sourceSummary = .copy(name)
        case .clipboard:
            source = .clipboard
            sourceSummary = "Local profile"
        }
        let isCurrent = profile.id == profiles.activeProfileID
        return HakoProfileSnapshot(
            id: id,
            label: profile.label,
            source: source,
            sourceSummary: sourceSummary,
            lastUpdatedAt: profile.lastUpdatedAt,
            autoUpdate: profile.autoUpdate,
            updateIntervalHours: profile.updateIntervalHours,
            isCurrent: isCurrent,
            isBusy: profile.id == profiles.busyProfileID,
            canEditSource: true,
            canDelete: !isCurrent,
            deleteSubtitle:
                isCurrent
                    ? "Switch profiles before removing this one"
                    : "Remove this profile from Clash",
            runtimeSummary:
                isCurrent ? "Active runtime" : "Saved profile",
             
             
             
            heldBackUpdates: (profile.suppressedUpdates ?? []).map {
                HakoProfileHeldBackUpdate(
                    keyPath: $0.keyPath,
                    change: HakoProfileHeldBackUpdate.Change(rawValue: $0.change.rawValue) ?? .changed,
                    newValue: $0.newValue,
                    appValue: $0.appValue
                )
            }
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var egressSnapshot: HakoHomeEgressSnapshot {
        let connected = vpn.status == "connected"
        let address = stats.egressIP
        let hasResult =
            connected
            && !address.isEmpty
            && address != "—"
            && address != "checking…"
            && address != "VPN not connected"
            && !address.hasPrefix("error")
        let detail = [stats.egressCountryName, stats.egressISP]
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: " · ")
        return HakoHomeEgressSnapshot(
            address: hasResult ? address : nil,
            flag: hasResult
                ? EgressLookupResult.flagEmoji(
                    countryCode: stats.egressCountryCode
                )
                : "",
            detail: hasResult ? detail : "",
            canRefresh: connected,
            isChecking: connected && address == "checking…"
        )
    }

     
     
     
    private var locale: Locale { preferences.language.locale }

     
     
     
     
     
     
     
     
     
     
     
    private func adjustmentSummary(
        _ module: HakoHomeAdjustmentModule
    ) -> String {
        guard let profile = currentProfile else { return module.subtitle }
        switch module {
        case .nodes:
            let chains = profile.proxyChain?.assignments.count ?? 0
            return chains == 0
                ? module.subtitle
                : HakoCopy.format("%d proxy chains", locale: locale, chains)
        case .rules:
            let count = profile.override.appendRules.count
            return count == 0
                ? module.subtitle
                : HakoCopy.format("%d personal rules", locale: locale, count)
        case .network:
            let count = ProfileNetworkDraft(profile: profile)
                .customizedProfileFieldCount
            return count == 0
                ? module.subtitle
                : HakoCopy.format(
                    "%d profile network settings",
                    locale: locale,
                    count
                )
        case .resources:
            guard let counts = homeResourceCounts, counts.hasResources else {
                return module.subtitle
            }
            if counts.providers > 0 {
                return HakoCopy.format(
                    "%d proxy sources · %d rule sets",
                    locale: locale,
                    counts.proxyProviders,
                    counts.ruleProviders
                )
            }
            return HakoCopy.format(
                "%d supporting files",
                locale: locale,
                counts.supportingFiles
            )
        case .advancedOverrides:
            switch profile.overwriteMode ?? .standard {
            case .standard:
                let count = ProfileAdvancedOverridesDraft(profile: profile)
                    .rawPatchFieldCount
                return count == 0
                    ? HakoCopy.string("Visual settings only", locale: locale)
                    : HakoCopy.format(
                        "%d additional fields",
                        locale: locale,
                        count
                    )
            case .script:
                return profile.selectedScriptID == nil
                    ? HakoCopy.string("Choose a local script", locale: locale)
                    : HakoCopy.string("Local script selected", locale: locale)
            case .custom:
                let custom = profile.customOverwrite ?? CustomOverwriteSpec()
                return HakoCopy.format(
                    "%d custom groups · %d rules",
                    locale: locale,
                    custom.proxyGroups.count,
                    custom.rules.count
                )
            }
        }
    }

     
     
     
     
     
     
     
     
     
    private func perform(_ command: HakoHomeCommand) async {
        switch command {
        case .performPrimaryAction(let action):
            await performPrimaryAction(action)
        case .openProfiles:
             
             
             
             
             
             
            break
        case .openProxies:
            navigationRequest = .proxies
        case .openRules:
            navigationRequest = .rules
        case .openAdjustment(let action):
            navigationRequest = .homeAdjustment(action)
        case .openRuntimeConfiguration:
            navigationRequest = .runtimeConfiguration
        case .setCards(let cards):
            HomeFavoriteCardPreferences().save(
                HakoHomeCatalog.normalized(cards)
            )
            refreshSnapshot()
        case .setTrafficScope(let scope):
            let onlyProxy = scope == .proxiedOnly
            guard onlyProxy != TrafficStatisticsSettings.onlyProxy() else {
                return
            }
            TrafficStatisticsSettings.setOnlyProxy(onlyProxy)
             
            self.command.applyTrafficStatisticsPreference()
            refreshSnapshot()
        case .refreshExternalIP:
            await stats.checkEgressIP()
            refreshSnapshot()
        case .refreshLANIP:
            lanAddress = LANAddressInventory.current().first
        case .showConnectionIssue:
             
             
             
            break
        }
    }

    private func performPrimaryAction(_ action: HakoHomePrimaryAction) async {
        switch action {
        case .openProfiles:
            navigationRequest = .profiles
        case .connect, .retry:
            await performConnection(.connect)
        case .cancel:
            await performConnection(.disconnect) { [weak self] in
                self?.profiles.cancelActivation()
            }
        case .disconnect:
            await performConnection(.disconnect)
        case .retryProxy:
            await vpn.forceRestart()
            rebind()
        case .none:
            break
        }
    }

    private func rebind() {
        command.bind(session: vpn.session)
        command.sync(vpnStatus: vpn.status)
        stats.bind(session: vpn.session, command: command)
        nodes.bind(command: command)
        stun.bind(command: command)
        proxyShare.bind(command: command)
    }

     
     
     
    func pooledDetailOverlay(
        for root: HakoRootDestination?
    ) -> AnyView {
        AnyView(
            ZStack {
                HakoMacPooledRootSlot(
                    destination: .proxies,
                    visible: root == .proxies,
                    channels: proxiesChannels,
                    foldStateSink: proxiesFoldStateSink,
                    background: HakoMacPlatformPresentation.palette.canvas,
                    content: { [weak self] in
                        guard let self else { return AnyView(EmptyView()) }
                        return AnyView(
                            HakoMacFrozenPoolContent(
                                freeze: HakoMacPoolFreeze(
                                     
                                     
                                     
                                     
                                    frozen: root != .proxies
                                        || self.nodes.isTestingLatency,
                                    epoch: self.nextPoolEpoch()
                                )
                            ) {
                                 
                                 
                                 
                                 
                                 
                                 
                                HakoDeferredPageContent {
                                SessionProxiesRailRoot(
                                    vpn: self.vpn,
                                    command: self.command,
                                    nodes: self.nodes,
                                    profiles: self.profiles,
                                    profileRefreshToken:
                                        self.profileRefreshToken,
                                    avoidsLiveProviderStore:
                                        false,
                                    stagedGroup: Binding(
                                        get: { [weak self] in
                                            self?.stagedProxyGroup
                                        },
                                        set: { [weak self] in
                                            self?.stagedProxyGroup = $0
                                        }
                                    )
                                )
                                } placeholder: {
                                    HakoMacPlatformPresentation.palette
                                        .canvas.ignoresSafeArea()
                                }
                            }
                            .equatable()
                        )
                    }
                )
                .allowsHitTesting(root == .proxies)

                HakoMacPooledRootSlot(
                    destination: .rules,
                    visible: root == .rules,
                    channels: rulesChannels,
                    foldStateSink: rulesFoldStateSink,
                    background: HakoMacPlatformPresentation.palette.canvas,
                    content: { [weak self] in
                        guard let self else { return AnyView(EmptyView()) }
                        return AnyView(
                            HakoMacFrozenPoolContent(
                                freeze: HakoMacPoolFreeze(
                                    frozen: root != .rules,
                                    epoch: self.nextPoolEpoch()
                                )
                            ) {
                            SessionRulesRailRoot(
                                command: self.command,
                                profiles: self.profiles,
                                openProxiesGroup: { [weak self] group in
                                    guard let self else { return }
                                     
                                     
                                     
                                     
                                    self.stagedProxyGroup = group
                                    self.proxiesChannels
                                        .requestOpenGroup(group)
                                    self.navigationRequest = .proxies
                                }
                            )
                            }
                            .equatable()
                        )
                    }
                )
                .allowsHitTesting(root == .rules)
            }
        )
    }

     
     

     
     
     
     
     
     
    private func prewarmEditorPreparations() {
        guard let profile = currentProfile else { return }
        let raw = profiles.runtimeSourceYAML(for: profile)
        Task { @MainActor in
            await ProfileProxyChainsView.prewarm(
                profile: profile, rawYAML: raw
            )
            if let raw {
                await ProfilesViewModel.prewarmProviderDraft(
                    profile: profile, raw: raw
                )
            }
             
             
             
             
             
            await ProfileDNSSettingsAdapter.prewarm(
                profile: profile,
                sourceYAML: self.profiles.uiProjectedYAML(for: profile),
                sidecar: ProfileDNSSettingsAdapter.sidecarYAML(
                    profileID: profile.id
                )
            )
        }
    }

     
     
     
     
     
    private let editorPrewarm = HakoMacQuietPeriod(seconds: 2)

    private func activeRuntimeDidChange() {
        profileRefreshToken &+= 1
         
         
         
        proxiesChannels.contentGeneration &+= 1
        nodes.noteRouteChanged()
        Task {
            await nodes.refresh()
        }
        editorPrewarm.request { [weak self] in
            self?.prewarmEditorPreparations()
        }
        recomputeHomeRuleTally()
        refreshSnapshot()
    }

     
     
     
     
     
     
     
     
     
     
    private var homeRuleTally: (count: Int, targets: [String])?
     
     
     
    private var homeResourceCounts: HomeResourceCounts?

    private func recomputeHomeRuleTally() {
        let profile = currentProfile
         
         
         
         
         
        let projected = profile.flatMap {
            profiles.effectiveYAML(for: $0)
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let tally = ProfileConfigTally.make(sourceYAML: projected)
            let overview = RulesOverviewModel.make(sourceYAML: projected)
            let resources = HomeResourceCounts.make(
                profile: profile,
                sourceYAML: projected
            )
            let targets = overview.buckets.prefix(3).map {
                "\($0.target) \($0.rules.count)"
            }
            await MainActor.run {
                guard let self else { return }
                self.homeRuleTally = tally.map { ($0.rules, Array(targets)) }
                self.homeResourceCounts = resources
                self.refreshSnapshot()
            }
        }
    }

    private func observeRuntimeChanges() {
         
         
         
         
         
         
         
        for publisher in [
            vpn.objectWillChange,
            profiles.objectWillChange,
            nodes.objectWillChange,
            connections.objectWillChange,
            networkQuality.objectWillChange,
            stun.objectWillChange,
            proxyShare.objectWillChange,
            preferences.objectWillChange,
             
             
             
             
             
             
             
            profileImports.objectWillChange,
        ] {
            publisher.sink { [weak self] _ in
                self?.scheduleRefresh()
            }
            .store(in: &cancellables)
        }

        command.$traffic
            .sink { [weak self] traffic in
                guard let self else { return }
                trafficFeed.traffic = trafficSnapshot(traffic)
            }
            .store(in: &cancellables)
        for publisher in [
            command.$isConnected.map { _ in () }.eraseToAnyPublisher(),
            command.$mode.map { _ in () }.eraseToAnyPublisher(),
            command.$lastError.map { _ in () }.eraseToAnyPublisher(),
            command.$rules.map { _ in () }.eraseToAnyPublisher(),
            command.$runtimeDiagnostics.map { _ in () }.eraseToAnyPublisher(),
            command.$proxiesData.map { _ in () }.eraseToAnyPublisher(),
            command.$peerCoreVersion.map { _ in () }.eraseToAnyPublisher(),
            command.$peerCapabilities.map { _ in () }.eraseToAnyPublisher(),
            command.$previousGoCrashReport.map { _ in () }.eraseToAnyPublisher(),
            command.$previousOOMEvidence.map { _ in () }.eraseToAnyPublisher(),
            command.$isCollectingMemory.map { _ in () }.eraseToAnyPublisher(),
            command.$memoryActionMessage.map { _ in () }.eraseToAnyPublisher(),
             
             
            command.$logs.map(\.count).removeDuplicates()
                .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
                .map { _ in () }.eraseToAnyPublisher(),
        ] {
            publisher.sink { [weak self] in
                self?.scheduleRefresh()
            }
            .store(in: &cancellables)
        }

        vpn.$status
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self else { return }
                command.sync(vpnStatus: status)
            }
            .store(in: &cancellables)

        command.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                connections.sync(connected)
                proxyShare.updateAPIAvailability(connected)
                if connected {
                    Task {
                        await self.nodes.refresh()
                        await self.proxyShare.refresh()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoMacPreferencesEnvironment: ViewModifier {
    @ObservedObject var preferences: AppPreferencesModel
     
     
    var presentsRestartPrompt = false


    @State private var offersLanguageRestart = false

    func body(content: Content) -> some View {
        content
            .tint(preferences.accent.color)
            .onAppear {
                applyAppearance(preferences.themeMode)
                installDetailCanvasFallback()
            }
            .onChange(of: preferences.themeMode) { mode in
                applyAppearance(mode)
            }
             
             
             
             
             
             
             
             
            .onChange(of: preferences.language) { _ in
                if presentsRestartPrompt {
                    offersLanguageRestart = true
                }
            }
            .alert(
                "Reopen Clash to change language?",
                isPresented: $offersLanguageRestart
            ) {
                Button("Reopen Now") {
                    relaunchForLanguageChange()
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text(
                    "The tunnel stays connected. The new language takes effect when Clash reopens."
                )
            }
    }

     
     
     
    @MainActor
    private func installDetailCanvasFallback() {
        HakoRegularDetailCanvasFallback.color =
            HakoMacPlatformPresentation.palette.canvas
    }

    private func applyAppearance(_ mode: AppThemeMode) {
        NSApplication.shared.appearance = switch mode {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    private func relaunchForLanguageChange() {
         
         
         
         
        guard HakoMacQuit.nextTermination != .relaunchForLanguageChange
        else { return }
        HakoMacQuit.nextTermination = .relaunchForLanguageChange
         
         
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = [
            "-c",
            "sleep 0.6; /usr/bin/open \"\(Bundle.main.bundlePath)\"",
        ]
        try? relauncher.run()
        NSApplication.shared.terminate(nil)
    }
}

 
 
 
 
private struct HakoMacProductCommands: Commands {
     
     
     
     
     
     
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .appInfo) {
            Button {
                open(.more(.about))
            } label: {
                Text(hako: .copy("About Clash"))
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button {
                open(.more(.root))
            } label: {
                Text(hako: .copy("Settings…"))
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .help) {}
    }

    private func open(_ destination: HakoMacSecondaryDestination) {
        Task { @MainActor in
            guard let model = HakoMacSceneModel.current else { return }
            model.focusMainWindow(openWindow)
            model.navigationRequest = destination
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoMacRuntimeConfigurationPage: View, Equatable {
    struct Inputs {
        var source: String?
        var snapshot: ProfileFinalConfigurationSnapshot
        var base: String?
        var comparison: String?
    }

    let profile: Profile
    let isActive: Bool
     
     
    let fetchTexts: () -> (source: String?, effective: String?, raw: String?)
    let blockedRuleSets:
        (@Sendable () async -> [ProviderCompileVerdicts.Blocked])?

    @State private var inputs: Inputs?

    static func == (
        lhs: HakoMacRuntimeConfigurationPage,
        rhs: HakoMacRuntimeConfigurationPage
    ) -> Bool {
         
         
        lhs.profile == rhs.profile && lhs.isActive == rhs.isActive
    }

    var body: some View {
        Group {
            if let inputs {
                ProfileFinalConfigurationView(
                    title: "Final Configuration",
                    snapshot: inputs.snapshot,
                    sourceYAML: inputs.source,
                     
                     
                     
                    comparisonYAML: inputs.comparison,
                     
                     
                     
                     
                    baseYAML: inputs.base,
                    ownsNavigationContainer: false,
                    blockedRuleSets: blockedRuleSets
                )
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: profile) {
            let texts = fetchTexts()
             
             
             
            let captured = profile
            async let baseTask: String? = Task.detached(
                priority: .userInitiated
            ) {
                texts.raw.flatMap {
                    RunningCoreDeviations.handedToCore(
                        profile: captured, sidecarYAML: $0
                    )
                }
            }.value
            async let snapshotTask = Task.detached(
                priority: .userInitiated
            ) {
                ProfileFinalConfigurationSnapshot.make(
                    sourceYAML: texts.source,
                    effectiveYAML: texts.effective
                )
            }.value
            inputs = await Inputs(
                source: texts.source,
                snapshot: snapshotTask,
                base: baseTask,
                comparison: texts.raw
            )
        }
    }
}

 
 
 
 
 
 
 
private struct HakoMacDeferredSourcePage: View, Equatable {
    let profile: Profile
     
    let fetch: () -> String?
    let content: (String?) -> AnyView

     
    @State private var text: String??

    static func == (
        lhs: HakoMacDeferredSourcePage,
        rhs: HakoMacDeferredSourcePage
    ) -> Bool {
        lhs.profile == rhs.profile
    }

    var body: some View {
        Group {
            if let text {
                content(text)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: profile) {
            text = .some(fetch())
        }
    }
}

 

 
 
 
 
 
 
 
 
 
 
extension HakoMacSceneModel {
    fileprivate func installStatusItem() {
        let controller = HakoMacStatusMenuController(
            snapshot: { [weak self] in
                self?.makeStatusMenuSnapshot() ?? .empty
            },
            actions: makeStatusMenuActions(),
            tunnelIsUp: { [weak self] in
                guard let self else { return false }
                return HakoMacQuit.tunnelIsUp(status: self.vpn.status)
            },
             
             
            latency: nodes.$delays
                .combineLatest(nodes.$testingNames)
                .map { [weak self] delays, testing in
                    self?.menuBarLatency(delays: delays, testing: testing) ?? [:]
                }
                .eraseToAnyPublisher(),
            testing: nodes.$isTestingLatency.eraseToAnyPublisher()
        )
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = controller.menu
        statusMenuController = controller
        statusItem = item
        refreshStatusButton()
        menuBarTraffic.$upLine
            .combineLatest(menuBarTraffic.$downLine)
            .dropFirst()
            .sink { [weak self] _ in self?.refreshStatusButton() }
            .store(in: &statusItemSubscriptions)
    }

    private func refreshStatusButton() {
        guard let button = statusItem?.button else { return }
        let showsSpeed = UserDefaults.standard.bool(forKey: HakoMacMenuBarSpeed.key)
        button.image = HakoMacStatusItemLabel.image(
            showsSpeed: showsSpeed,
            upLine: menuBarTraffic.upLine,
            downLine: menuBarTraffic.downLine
        )
        button.setAccessibilityLabel(HakoMacStatusItemLabel.accessibilityLabel(
            showsSpeed: showsSpeed,
            upLine: menuBarTraffic.upLine,
            downLine: menuBarTraffic.downLine
        ))
    }

    private func makeStatusMenuSnapshot() -> HakoMacStatusMenuSnapshot {
        HakoMacStatusMenuSnapshot(
            phase: snapshot.connection.phase,
            primaryIntent: snapshot.connection.primaryIntent,
            outboundMode: currentOutboundMode,
            selectedRouteName: snapshot.connection.selectedRouteName,
            proxies: menuBarProxyCatalog,
            showsSpeedInMenuBar: UserDefaults.standard.bool(forKey: HakoMacMenuBarSpeed.key),
            hidesDockIcon: UserDefaults.standard.bool(forKey: HakoMacDockIcon.key),
            upLine: menuBarTraffic.upLine,
            downLine: menuBarTraffic.downLine,
            offersQuitLeavingTunnel: false
        )
    }

     
     
     
    fileprivate func makeStatusMenuActions() -> HakoMacStatusMenuActions {
        var actions = HakoMacStatusMenuActions.none
        actions.primary = { [weak self] in self?.performPrimaryAction() }
        actions.cancelStart = { [weak self] in self?.cancelStart() }
        actions.setOutboundMode = { [weak self] mode in
            Task { await self?.setOutboundMode(mode) }
        }
        actions.select = { [weak self] group, member in
            Task { await self?.nodes.select(group: group, name: member) }
        }
         
        actions.testGroup = { [weak self] name in
            guard let self, let group = self.nodes.groups.first(where: { $0.name == name }) else { return }
            Task { await self.nodes.test(group: group) }
        }
        actions.setShowsSpeedInMenuBar = { [weak self] shows in
            UserDefaults.standard.set(shows, forKey: HakoMacMenuBarSpeed.key)
            self?.refreshStatusButton()
        }
        actions.setHidesDockIcon = { hides in
            UserDefaults.standard.set(hides, forKey: HakoMacDockIcon.key)
            HakoMacDockIcon.apply(hidesIcon: hides)
        }
         
        actions.openSettings = { [weak self] in
            self?.openMainWindow()
            self?.navigationRequest = .more(.root)
        }
        actions.openApp = { [weak self] in self?.openMainWindow() }
        actions.quitLeavingTunnel = {
            HakoMacQuit.nextTermination = .readerQuitLeavingTunnelRunning
            NSApplication.shared.terminate(nil)
        }
        actions.quit = { NSApplication.shared.terminate(nil) }
        return actions
    }
}
