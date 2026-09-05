import AppIntents
import UniformTypeIdentifiers

 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, *)
enum HakoTunnelShortcut {
     
     
     
     
     
    enum Outcome {
        case start, stop, on, off
    }

    static func sentence(_ outcome: Outcome) -> LocalizedStringResource {
        switch outcome {
        case .start: return "Starting Clash VPN."
        case .stop: return "Stopping Clash VPN."
        case .on: return "Clash VPN is on."
        case .off: return "Clash VPN is off."
        }
    }

    static func drive(
        _ action: HakoSystemRoute.VPNAction,
        _ act: () async -> Bool
    ) async throws {
        if await act() { return }
        HakoSystemActionDispatch.enqueue(.vpn(action))
        throw HakoTunnelIntentError.configurationUnreachable
    }
}

@available(iOS 16.0, *)
enum HakoTunnelIntentError: LocalizedError {
    case configurationUnreachable

    var errorDescription: String? {
        String(localized: "Clash could not reach its VPN configuration. Open Clash once, then run the shortcut again.")
    }
}

@available(iOS 16.0, *)
struct ConnectHakoIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Clash"
    static let description = IntentDescription("Start the installed Clash by Hako VPN profile.")
    static var openAppWhenRun: Bool { false }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await HakoTunnelShortcut.drive(.connect) {
            await HakoVPNControlDriver.apply(connect: true)
        }
        return .result(dialog: IntentDialog(HakoTunnelShortcut.sentence(.start)))
    }
}

@available(iOS 16.0, *)
struct DisconnectHakoIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Clash"
    static let description = IntentDescription("Stop the active Clash by Hako VPN profile.")
    static var openAppWhenRun: Bool { false }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await HakoTunnelShortcut.drive(.disconnect) {
            await HakoVPNControlDriver.apply(connect: false)
        }
        return .result(dialog: IntentDialog(HakoTunnelShortcut.sentence(.stop)))
    }
}

@available(iOS 16.0, *)
struct ToggleHakoIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Clash VPN"
    static let description = IntentDescription("Start or stop Clash based on its current state.")
    static var openAppWhenRun: Bool { false }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

     
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        var applied: Bool?
        try await HakoTunnelShortcut.drive(.toggle) {
            applied = await HakoVPNControlDriver.toggle()
            return applied != nil
        }
        let on = applied ?? false
        return .result(
            value: on,
            dialog: IntentDialog(HakoTunnelShortcut.sentence(on ? .start : .stop))
        )
    }
}

 
 
@available(iOS 16.0, *)
struct GetHakoVPNStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Clash VPN Status"
    static let description = IntentDescription("Reports whether the installed Clash by Hako VPN profile is connected.")
    static var openAppWhenRun: Bool { false }
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let live = await HakoVPNControlDriver.isActive()
        let on = live ?? HakoSystemActionDispatch.handoff.isVPNSnapshotActive
        return .result(
            value: on,
            dialog: IntentDialog(HakoTunnelShortcut.sentence(on ? .on : .off))
        )
    }
}

@available(iOS 16.0, *)
enum HakoRoutingModeIntentValue: String, AppEnum {
    case rule
    case global
    case direct

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Routing Mode"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .rule: "Rule",
        .global: "Global",
        .direct: "Direct",
    ]

    var route: HakoSystemRoute {
        .mode(HakoSystemRoute.RoutingMode(rawValue: rawValue)!)
    }
}

 
 
 
@available(iOS 16.0, *)
struct SetHakoRoutingModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Clash Routing Mode"
    static let description = IntentDescription("Switch Clash between Rule, Global, and Direct routing.")
    static var openAppWhenRun: Bool { true }
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Mode")
    var mode: HakoRoutingModeIntentValue

    static var parameterSummary: some ParameterSummary {
        Summary("Set Clash to \(\.$mode)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        HakoSystemActionDispatch.enqueue(mode.route)
        return .result(dialog: "Opening Clash to switch routing mode.")
    }
}

@available(iOS 16.0, *)
struct ImportHakoConfigurationIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Clash Configuration"
    static let description = IntentDescription("Import one or more YAML configurations into Clash.")
    static var openAppWhenRun: Bool { true }
    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(
        title: "Configuration Files",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var files: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$files) into Clash")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !files.isEmpty else { return .result(dialog: "No configuration files were provided.") }
        guard let inbox = ProfileShareInbox() else { throw ProfileShareInboxError.unavailable }
        for file in files {
            guard ProfileShareInboxAdmission.accepts(file.data) else {
                throw ProfileInstallLinkError.unsupportedFile
            }
            try inbox.enqueue(file.data)
        }
        HakoSystemActionDispatch.enqueue(.open(.profiles))
        return .result(dialog: "Opening Clash to validate and import the configuration.")
    }
}

@available(iOS 16.0, *)
struct HakoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
         
         
         
        AppShortcut(
            intent: ConnectHakoIntent(),
            phrases: ["Start \(.applicationName)"],
            shortTitle: "Start Clash",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: DisconnectHakoIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "Stop Clash",
            systemImageName: "power"
        )
        AppShortcut(
            intent: ToggleHakoIntent(),
            phrases: ["Toggle \(.applicationName) VPN"],
            shortTitle: "Toggle Clash",
            systemImageName: "arrow.triangle.swap"
        )
        AppShortcut(
            intent: GetHakoVPNStatusIntent(),
            phrases: ["Is \(.applicationName) connected"],
            shortTitle: "Get VPN Status",
            systemImageName: "bolt.horizontal.circle"
        )
        AppShortcut(
            intent: SetHakoRoutingModeIntent(),
            phrases: ["Set routing mode in \(.applicationName)"],
            shortTitle: "Set Routing Mode",
            systemImageName: "arrow.triangle.branch"
        )
        AppShortcut(
            intent: ImportHakoConfigurationIntent(),
            phrases: ["Import configuration into \(.applicationName)"],
            shortTitle: "Import Configuration",
            systemImageName: "square.and.arrow.down"
        )
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProfileShareInboxAdmission {
    static func accepts(_ data: Data) -> Bool {
        guard !data.isEmpty, data.count <= ProfileShareInbox.defaultMaximumBytes,
              let text = String(data: data, encoding: .utf8) else { return false }
        do {
            try ConfigTransforms.validateSource(text)
            return true
        } catch {
            return false
        }
    }
}
