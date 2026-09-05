import AppIntents
import Foundation

 
 
 
 
 

 
 
 
 
 
 
struct HakoWidgetPowerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set Clash VPN From Widget"
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "VPN Connected")
    var value: Bool

    init() {}

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        HakoLogStore.shared.append("widget: power tapped → \(value)", stream: .app, level: .info)
        if !value {
             
             
            HakoWidgetMailboxClient.markDisconnected()
        }
        if !(await HakoVPNControlDriver.apply(connect: value)) {
            HakoSystemActionDispatch.enqueue(.vpn(value ? .connect : .disconnect))
        }
         
         
        return .result()
    }
}

 
 
struct HakoWidgetSetModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Clash Mode"
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Mode")
    var mode: String

    init() {}

    init(mode: HakoWidgetMode) {
        self.mode = mode.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let mode = HakoWidgetMode(rawValue: mode) {
            _ = await HakoWidgetMailboxClient.requestAndWait(.setMode(mode), group: nil)
        }
        return .result()
    }
}

 
 
struct HakoWidgetSelectIntent: AppIntent {
    static let title: LocalizedStringResource = "Select Clash Node"
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Group")
    var group: String

    @Parameter(title: "Node")
    var name: String

    init() {}

    init(group: String, name: String) {
        self.group = group
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        _ = await HakoWidgetMailboxClient.requestAndWait(.select(group: group, name: name), group: group)
        return .result()
    }
}

 

 
 
enum HakoWidgetStyle: String, AppEnum {
    case status
    case group
    case stats

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shows")
    static let caseDisplayRepresentations: [HakoWidgetStyle: DisplayRepresentation] = [
        .status: DisplayRepresentation(title: "Status and Switch"),
        .group: DisplayRepresentation(title: "Proxy Group"),
        .stats: DisplayRepresentation(title: "Network Stats"),
    ]
}

 
 
struct HakoWidgetGroupEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Proxy Group")
    static let defaultQuery = HakoWidgetGroupQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct HakoWidgetGroupQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HakoWidgetGroupEntity] {
        identifiers.map(HakoWidgetGroupEntity.init(id:))
    }

    func suggestedEntities() async throws -> [HakoWidgetGroupEntity] {
        (HakoWidgetMailboxClient.store.readAppFacts()?.groups ?? []).map(HakoWidgetGroupEntity.init(id:))
    }

    func defaultResult() async -> HakoWidgetGroupEntity? {
        HakoWidgetMailboxClient.store.readAppFacts()?.firstGroup.map(HakoWidgetGroupEntity.init(id:))
    }
}

struct HakoWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Clash Widget"
    static let description = IntentDescription("What this widget shows.")

    @Parameter(title: "Shows", default: .status)
    var style: HakoWidgetStyle

    @Parameter(title: "Group")
    var group: HakoWidgetGroupEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$style, .equalTo, HakoWidgetStyle.group) {
            Summary("\(\.$style) \(\.$group)")
        } otherwise: {
            Summary("\(\.$style)")
        }
    }
}
