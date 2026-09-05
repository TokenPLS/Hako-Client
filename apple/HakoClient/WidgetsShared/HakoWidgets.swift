import AppIntents
import SwiftUI
import WidgetKit

 
 
 
 
 

enum HakoWidgetSlotFactory {
    static func slots(for entry: HakoWidgetEntry) -> HakoWidgetSlots {
        let active = entry.tunnelActive
        let group = entry.group ?? entry.facts?.firstGroup
        let powerLabel = Image(systemName: "power")
            .font(.body.weight(.semibold))
            .frame(width: 22, height: 22)
            .accessibilityLabel(Text(hako: .copy(active ? "Connected" : "Not Connected")))
        return HakoWidgetSlots(
            power: entry.tunnelControllable
                ? AnyView(
                     
                     
                     
                     
                     
                    Toggle(isOn: active, intent: HakoWidgetPowerIntent(value: !active)) { powerLabel }
                        .toggleStyle(.button)
                        .buttonBorderShape(.circle)
                        .widgetAccentable()
                )
                : AnyView(
                     
                     
                     
                     
                    Link(destination: HakoSystemRoute.vpn(.connect).url) { powerLabel }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .widgetAccentable()
                ),
            mode: { mode, label in
                active
                    ? AnyView(Button(intent: HakoWidgetSetModeIntent(mode: mode)) { label }.buttonStyle(.plain))
                    : AnyView(Link(destination: HakoSystemRoute.open(.home).url) { label })
            },
            member: { name, label in
                if active, let group {
                    return AnyView(Button(intent: HakoWidgetSelectIntent(group: group, name: name)) { label }.buttonStyle(.plain))
                }
                return AnyView(Link(destination: HakoSystemRoute.open(.proxies).url) { label })
            },
            accent: { AnyView($0.widgetAccentable()) },
            needsSetup: !entry.tunnelControllable
        )
    }

    static func size(for family: WidgetFamily) -> HakoWidgetSize {
        switch family {
        case .systemSmall: return .small
        case .systemLarge, .systemExtraLarge: return .large
        default: return .medium
        }
    }
}

struct HakoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale
    let entry: HakoWidgetEntry

    var body: some View {
        let size = HakoWidgetSlotFactory.size(for: family)
        let slots = HakoWidgetSlotFactory.slots(for: entry)
        Group {
             
             
             
            switch size == .large ? .status : entry.style {
            case .status:
                HakoWidgetMainView(snapshot: entry.snapshot, facts: entry.facts, now: entry.date, locale: locale, size: size, slots: slots)
            case .group:
                HakoWidgetGroupView(snapshot: entry.snapshot, facts: entry.facts, group: entry.group, now: entry.date, size: size, slots: slots)
            case .stats:
                HakoWidgetStatsView(snapshot: entry.snapshot, now: entry.date, locale: locale, size: size)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(HakoSystemRoute.open(entry.style == .group ? .proxies : .home).url)
    }
}

struct HakoMainWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HakoWidgetMailbox.Kind.main,
            intent: HakoWidgetConfigurationIntent.self,
            provider: HakoWidgetProvider()
        ) { entry in
            HakoWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(hako: .copy("Widget: Clash")))
        .description(Text(hako: .copy("Status and the switch, a proxy group, or network stats — choose in Edit Widget.")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
