import Foundation
import WidgetKit

 
 
 
struct HakoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HakoWidgetSnapshot?
    let facts: HakoWidgetAppFacts?
    let tunnelActive: Bool
    let style: HakoWidgetStyle
    let group: String?
     
     
     
     
    var tunnelControllable: Bool = true
}

enum HakoWidgetTimelineBuilder {
     
     
     
    static func entry(style: HakoWidgetStyle, group: String?) async -> HakoWidgetEntry {
        let store = HakoWidgetMailboxClient.store
        let state = await HakoVPNControlDriver.state(journal: false)
        let active = state?.active ?? false
        var snapshot: HakoWidgetSnapshot?
        if active {
            snapshot = await HakoWidgetMailboxClient.requestAndWait(.refresh, group: group, kind: style.rawValue)
        } else {
            HakoLogStore.shared.append("widget client: \(style.rawValue) timeline with the tunnel down", stream: .app, level: .info)
            snapshot = store.readSnapshot()
             
             
             
             
            if let file = snapshot, file.phase == .connected {
                snapshot = file.asDisconnected()
            }
        }
        return HakoWidgetEntry(
            date: Date(), snapshot: snapshot, facts: store.readAppFacts(),
            tunnelActive: active, style: style, group: group,
            tunnelControllable: state?.controllable ?? false
        )
    }

     
     
     
     
    static func timeline(_ entry: HakoWidgetEntry) -> Timeline<HakoWidgetEntry> {
        let policy: TimelineReloadPolicy
        let fileSaysConnected = HakoWidgetMailboxClient.store.readSnapshot()?.phase == .connected
        switch entry.snapshot?.phase {
        case .connected where entry.tunnelActive:
            policy = .after(entry.date.addingTimeInterval(30 * 60))
        case .connecting, .disconnecting, .reasserting:
            policy = .after(entry.date.addingTimeInterval(3))
        default:
             
             
            policy = (entry.tunnelActive || fileSaysConnected)
                ? .after(entry.date.addingTimeInterval(3))
                : .never
        }
        return Timeline(entries: [entry], policy: policy)
    }

    static func placeholder(style: HakoWidgetStyle) -> HakoWidgetEntry {
        HakoWidgetEntry(date: Date(), snapshot: nil, facts: nil, tunnelActive: false, style: style, group: nil)
    }

     
     
    static func preview(style: HakoWidgetStyle) -> HakoWidgetEntry {
        let now = Date()
        let snapshot = HakoWidgetSnapshot(
            phase: .connected, profile: "Clash", mode: .rule, egress: "🇸🇬 Singapore 01",
            startedAt: now.addingTimeInterval(-3_600),
            upTotal: 24_500_000, downTotal: 318_000_000,
            proxy: HakoWidgetBytes(up: 20_000_000, down: 300_000_000),
            direct: HakoWidgetBytes(up: 4_500_000, down: 18_000_000),
            reject: HakoWidgetBytes(up: 0, down: 0), rejectCount: 12,
            connections: HakoWidgetConnections(opened: 186, active: 9, rejected: 12),
            wifi: HakoWidgetBytes(up: 24_500_000, down: 318_000_000),
            cellular: HakoWidgetBytes(up: 0, down: 0),
            group: HakoWidgetGroupSlice(
                name: "Proxy", type: "Selector", now: "🇸🇬 Singapore 01",
                all: ["🇸🇬 Singapore 01", "🇭🇰 Hong Kong 02", "🇯🇵 Tokyo 03", "🇺🇸 Los Angeles 04"]
            ),
            at: now
        )
        let facts = HakoWidgetAppFacts(profile: "Clash", firstGroup: "Proxy", groups: ["Proxy"], writtenAt: now)
        return HakoWidgetEntry(date: now, snapshot: snapshot, facts: facts, tunnelActive: true, style: style, group: "Proxy")
    }
}

struct HakoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = HakoWidgetEntry
    typealias Intent = HakoWidgetConfigurationIntent

    func placeholder(in _: Context) -> HakoWidgetEntry {
        HakoWidgetTimelineBuilder.placeholder(style: .status)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> HakoWidgetEntry {
        if context.isPreview { return HakoWidgetTimelineBuilder.preview(style: configuration.style) }
        return await HakoWidgetTimelineBuilder.entry(style: configuration.style, group: configuration.group?.id)
    }

    func timeline(for configuration: Intent, in _: Context) async -> Timeline<HakoWidgetEntry> {
        HakoWidgetTimelineBuilder.timeline(
            await HakoWidgetTimelineBuilder.entry(style: configuration.style, group: configuration.group?.id)
        )
    }
}
