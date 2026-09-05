import AppKit
import Combine
import HakoClientUI

 
 
 
 
 
 
struct HakoMacStatusMenuSnapshot: Equatable {
    var phase: AppleClientConnectionPhase
    var primaryIntent: AppleClientConnectionIntent?
    var outboundMode: AppleClientOutboundMode
    var selectedRouteName: String?
    var proxies: HakoMacMenuProxyCatalog
    var showsSpeedInMenuBar: Bool
    var hidesDockIcon: Bool
    var upLine: String
    var downLine: String
     
     
    var offersQuitLeavingTunnel: Bool
}

 
 
struct HakoMacStatusMenuActions {
    var primary: () -> Void = {}
    var cancelStart: () -> Void = {}
    var setOutboundMode: (AppleClientOutboundMode) -> Void = { _ in }
    var select: (_ group: String, _ member: String) -> Void = { _, _ in }
     
    var testGroup: (_ group: String) -> Void = { _ in }
    var setShowsSpeedInMenuBar: (Bool) -> Void = { _ in }
    var setHidesDockIcon: (Bool) -> Void = { _ in }
    var openSettings: () -> Void = {}
    var openApp: () -> Void = {}
    var quitLeavingTunnel: () -> Void = {}
    var quit: () -> Void = {}

    static let none = HakoMacStatusMenuActions()
}

 
 
 
final class HakoMacMenuRowAction: NSObject {
    private let perform: () -> Void

    init(_ perform: @escaping () -> Void) {
        self.perform = perform
    }

    @objc func fire(_ sender: Any?) {
        perform()
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
enum HakoMacStatusMenuBuilder {
    static func makeMenu(
        _ snapshot: HakoMacStatusMenuSnapshot,
        actions: HakoMacStatusMenuActions,
        locale: Locale = .current
    ) -> NSMenu {
        let menu = plainMenu()

        func copy(_ key: String) -> String {
            HakoCopy.string(key, locale: locale)
        }

         
        menu.addItem(label(copy(snapshot.phase.statusTitle)))
        switch HakoMacMenuPrimaryRow.resolve(
            phase: snapshot.phase,
            intent: snapshot.primaryIntent
        ) {
        case .intent(let intent):
            menu.addItem(row(copy(intent.toolbarTitle), actions.primary))
        case .cancelStart:
            menu.addItem(row(copy("Cancel"), identifier: "menu-bar.cancel-start", actions.cancelStart))
        case .none:
            break
        }

         
         
        let pointSize = HakoMacMenuRowMetrics.pointSize
        let hostedWidth = HakoMacMenuRowMetrics.groupRowWidth(
            leading: [copy("Mode")] + snapshot.proxies.groups.map { "\($0.name) · \($0.type)" },
            trailing: [copy(snapshot.outboundMode.menuTitle)] + snapshot.proxies.groups.map(\.now)
        )

         
         
         
        let mode = NSMenuItem(title: copy("Mode"), action: nil, keyEquivalent: "")
        mode.setAccessibilityIdentifier("menu-bar.outbound-mode")
        mode.view = HakoMacMenuRowHost.make(
            model: HakoMacMenuRowModel(
                kind: .group, name: copy("Mode"), trailing: copy(snapshot.outboundMode.menuTitle)
            ),
            width: hostedWidth, pointSize: pointSize, closesMenuOnClick: false, onClick: {}
        )
        let modes = plainMenu()
        for candidate in AppleClientOutboundMode.allCases {
            modes.addItem(row(
                copy(candidate.menuTitle),
                state: candidate == snapshot.outboundMode ? .on : .off
            ) { actions.setOutboundMode(candidate) })
        }
        mode.submenu = modes
        menu.addItem(mode)

        if let route = snapshot.selectedRouteName {
            menu.addItem(label(route))
        }

         
         
         
         
        if !snapshot.proxies.groups.isEmpty {
            menu.addItem(.separator())
            let width = hostedWidth
            for group in snapshot.proxies.groups {
                let item = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
                item.setAccessibilityIdentifier("menu-bar.proxy-group")
                let model = HakoMacMenuRowModel(
                    kind: .group, name: group.name, detail: group.type, trailing: group.now
                )
                item.view = HakoMacMenuRowHost.make(
                    model: model, width: width, pointSize: pointSize, closesMenuOnClick: false, onClick: {}
                )
                let submenu = plainMenu()
                let lazy = HakoMacProxySubmenuController(
                    group: { group }, actions: actions, locale: locale
                )
                submenu.delegate = lazy
                 
                item.representedObject = lazy
                item.submenu = submenu
                menu.addItem(item)
            }
        }

         
         
        menu.addItem(.separator())
        menu.addItem(row(
            copy("Show Speed in Menu Bar"),
            identifier: "menu-bar.shows-speed",
            state: snapshot.showsSpeedInMenuBar ? .on : .off
        ) { actions.setShowsSpeedInMenuBar(!snapshot.showsSpeedInMenuBar) })
        menu.addItem(row(
            copy("Hide Dock Icon"),
            identifier: "menu-bar.hides-dock-icon",
            state: snapshot.hidesDockIcon ? .on : .off
        ) { actions.setHidesDockIcon(!snapshot.hidesDockIcon) })
        if !snapshot.showsSpeedInMenuBar {
            menu.addItem(label(snapshot.upLine))
            menu.addItem(label(snapshot.downLine))
        }

         
        menu.addItem(.separator())
        menu.addItem(row(copy("Settings…"), identifier: "menu-bar.settings", actions.openSettings))
        menu.addItem(row(copy("Open Clash"), actions.openApp))

         
        menu.addItem(.separator())
        if snapshot.offersQuitLeavingTunnel {
            menu.addItem(row(
                copy("Quit (Leave VPN Active)"),
                identifier: "menu-bar.quit-leaving-tunnel",
                actions.quitLeavingTunnel
            ))
        }
        menu.addItem(row(copy("Quit Clash"), identifier: "menu-bar.quit", actions.quit))
        return menu
    }

     
     
    private static func plainMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

     
    private static func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func row(
        _ title: String,
        identifier: String? = nil,
        state: NSControl.StateValue = .off,
        _ perform: @escaping () -> Void
    ) -> NSMenuItem {
        let target = HakoMacMenuRowAction(perform)
        let item = NSMenuItem(
            title: title,
            action: #selector(HakoMacMenuRowAction.fire(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = target
        item.state = state
        if let identifier {
            item.setAccessibilityIdentifier(identifier)
        }
        return item
    }
}

extension AppleClientConnectionPhase {
     
     
     
    var statusTitle: String {
        switch self {
        case .disconnected: "Disconnected"
        case .preparing: "STARTING"
        case .connected: "Connected"
        case .disconnecting: "STOPPING"
        case .unavailable: "Unavailable"
        }
    }
}

extension AppleClientConnectionIntent {
    var toolbarTitle: String {
        switch self {
        case .connect: "START"
        case .disconnect: "STOP"
        case .installConfiguration: "Set Up"
        case .activateSystemExtension: "Activate"
        case .updateSystemExtension: "Update"
        }
    }
}

extension AppleClientOutboundMode {
    var menuTitle: String {
        switch self {
        case .global: "Global"
        case .rule: "Rule"
        case .direct: "Direct"
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoMacStatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let snapshot: () -> HakoMacStatusMenuSnapshot
    private let actions: HakoMacStatusMenuActions
    private let locale: Locale
    private let optionIsHeld: () -> Bool
    private let tunnelIsUp: () -> Bool
    private let latency: AnyPublisher<[String: HakoProxyLatencyState], Never>?
    private let testing: AnyPublisher<Bool, Never>?
    private var listening: Set<AnyCancellable> = []

     
     
    var isListening: Bool { !listening.isEmpty }

    init(
        snapshot: @escaping () -> HakoMacStatusMenuSnapshot,
        actions: HakoMacStatusMenuActions,
        locale: Locale = .current,
        optionIsHeld: @escaping () -> Bool = { NSEvent.modifierFlags.contains(.option) },
        tunnelIsUp: @escaping () -> Bool = { false },
        latency: AnyPublisher<[String: HakoProxyLatencyState], Never>? = nil,
        testing: AnyPublisher<Bool, Never>? = nil
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.locale = locale
        self.optionIsHeld = optionIsHeld
        self.tunnelIsUp = tunnelIsUp
        self.latency = latency
        self.testing = testing
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
    }

     
     
     
     
     
     
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.items.isEmpty else { return }
        var current = snapshot()
        current.offersQuitLeavingTunnel = optionIsHeld() && tunnelIsUp()
        let built = HakoMacStatusMenuBuilder.makeMenu(current, actions: actions, locale: locale)
        for item in built.items {
            built.removeItem(item)
            menu.addItem(item)
        }
    }

     
     
     
    func menuWillOpen(_ menu: NSMenu) {
        listening.removeAll()
        latency?
            .sink { [weak self] latency in self?.apply(latency: latency) }
            .store(in: &listening)
        testing?
            .sink { [weak self] isTesting in self?.setTesting(isTesting) }
            .store(in: &listening)
    }

    func menuDidClose(_ menu: NSMenu) {
        listening.removeAll()
        menu.removeAllItems()
    }

     
     
     
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for candidate in menu.items {
            (candidate.view as? HakoMacMenuRowHost)?.model.isHighlighted = candidate === item
        }
    }

     
     
    func apply(latency: [String: HakoProxyLatencyState]) {
        for item in menu.items {
            (item.representedObject as? HakoMacProxySubmenuController)?.apply(latency: latency)
        }
    }

     
    func setTesting(_ isTesting: Bool) {
        for item in menu.items {
            (item.representedObject as? HakoMacProxySubmenuController)?.setTesting(isTesting)
        }
    }
}

 
 
 
 
@MainActor
enum HakoMacStatusItemLabel {
    static func image(showsSpeed: Bool, upLine: String, downLine: String) -> NSImage? {
        if showsSpeed,
           let drawn = HakoMacMenuBarSpeed.menuBarImage(upLine: upLine, downLine: downLine) {
            drawn.isTemplate = true
            return drawn
        }
         
         
        let cat = NSImage(named: HakoMacAsset.menuBarTemplate.rawValue)
        cat?.isTemplate = true
        return cat
    }

    static func accessibilityLabel(showsSpeed: Bool, upLine: String, downLine: String) -> String {
        showsSpeed ? "Clash — \(upLine), \(downLine)" : "Clash"
    }
}

extension HakoMacStatusMenuSnapshot {
     
    static let empty = HakoMacStatusMenuSnapshot(
        phase: .unavailable,
        primaryIntent: nil,
        outboundMode: .rule,
        selectedRouteName: nil,
        proxies: HakoMacMenuProxyCatalog(groups: []),
        showsSpeedInMenuBar: false,
        hidesDockIcon: false,
        upLine: "",
        downLine: "",
        offersQuitLeavingTunnel: false
    )
}

