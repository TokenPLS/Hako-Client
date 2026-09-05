#if os(iOS) || os(macOS)
import Foundation
import Hako
import WidgetKit

 
 
 
 
 
 
 
 
 
final class WidgetMailboxService {
    private unowned let provider: ExtensionProvider
    private let store: HakoWidgetMailboxStore
    private let queue = DispatchQueue(label: "org.example.hako.widget.mailbox")
    private var accounting = HakoWidgetInterfaceAccounting()
    private var interfaceKind: HakoWidgetInterfaceAccounting.Kind = .other
    private var phase: HakoWidgetPhase = .disconnected
    private var startedAt: Date?
    private var observing = false
     
     
     
     
     
    private var lastGroupJSON: (name: String, json: Data)?

     
     
    private static let groupMemberLimit = HakoWidgetMailbox.groupMemberLimit

    init(provider: ExtensionProvider, store: HakoWidgetMailboxStore) {
        self.provider = provider
        self.store = store
    }

     
    func start() {
        queue.async {
            self.phase = .connected
            self.startedAt = Date()
            self.register()
            self.publish(group: nil, reason: "start", reloads: true, reloadDelay: Self.interactionGrace)
        }
    }

     
     
    func stop() {
        queue.sync {
            self.unregister()
            self.phase = .disconnected
            self.publish(group: nil, reason: "stop", reloads: true)
        }
    }

     
     
     
    func pathChanged(interfaceType: String) {
        queue.async {
            let kind = HakoWidgetInterfaceAccounting.kind(ofInterfaceType: interfaceType)
            if self.phase == .connected, let totals = self.totals() {
                self.accounting.pathChanged(to: kind, totalUp: totals.up, totalDown: totals.down)
            }
            self.interfaceKind = kind
        }
    }

     

    private var center: CFNotificationCenter { CFNotificationCenterGetDarwinNotifyCenter() }

    private static let requestCallback: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else { return }
        Unmanaged<WidgetMailboxService>.fromOpaque(observer).takeUnretainedValue().requestArrived()
    }

    private func register() {
        guard !observing else { return }
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            Self.requestCallback,
            HakoWidgetMailbox.requestNotification as CFString,
            nil,
            .deliverImmediately
        )
        observing = true
    }

    private func unregister() {
        guard observing else { return }
        CFNotificationCenterRemoveObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(HakoWidgetMailbox.requestNotification as CFString),
            nil
        )
        observing = false
    }

    private func requestArrived() {
        queue.async { self.serve() }
    }

     

    private func serve() {
        guard let request = store.takeRequest() else {
             
             
            publish(group: nil, reason: "request without file", reloads: false)
            return
        }
        switch request.command {
        case .refresh:
             
             
             
             
            publish(group: request.group, reason: "refresh", reloads: false)
        case .setMode(let mode):
            act(#"{"cmd":"setMode","mode":"\#(mode.rawValue)"}"#, then: request.group, reason: "setMode \(mode.rawValue)")
        case .select(let group, let name):
            let payload = try? JSONSerialization.data(withJSONObject: ["cmd": "select", "group": group, "name": name])
            act(payload.map { String(decoding: $0, as: UTF8.self) } ?? "{}", then: request.group, reason: "select")
        }
    }

     
     
     
    private func act(_ message: String, then group: String?, reason: String) {
        Task { [weak self] in
            guard let self else { return }
            let answer = await provider.handleMessage(Data(message.utf8))
            answer.afterReply?()
            let reply = String(decoding: answer.reply, as: UTF8.self)
            queue.async {
                 
                 
                 
                 
                self.publish(group: group, reason: "\(reason) → \(reply)", reloads: true, reloadDelay: Self.interactionGrace)
            }
        }
    }

     

     
     
     
     
     
    private static let interactionGrace: TimeInterval = 1.0

    private func publish(group requestedGroup: String?, reason: String, reloads: Bool, reloadDelay: TimeInterval = 0) {
        let began = Date()
        let facts = store.readAppFacts()
        let group = requestedGroup ?? facts?.firstGroup
        var statsJSON: Data?
        var groupJSON: Data?
        var wifi: HakoWidgetBytes?
        var cellular: HakoWidgetBytes?
        var wired: HakoWidgetBytes?
        if phase == .connected {
            if let totals = totals() {
                accounting.observe(totalUp: totals.up, totalDown: totals.down, on: interfaceKind)
            }
            statsJSON = Data(HakoWidgetStatsJSON(group).utf8)
            if let group {
                let json = Data(HakoWidgetGroupJSON(group, Self.groupMemberLimit).utf8)
                groupJSON = json
                lastGroupJSON = (group, json)
            }
            wifi = accounting.wifi
            cellular = accounting.cellular
            wired = accounting.wired
        } else if let group, let last = lastGroupJSON, last.name == group {
            groupJSON = last.json
        }
        let snapshot = HakoWidgetSnapshotComposer.compose(
            phase: phase,
            profile: facts?.profile,
            startedAt: startedAt,
            rate: phase == .connected ? traffic().map { ($0.up, $0.down) } : nil,
            statsJSON: statsJSON,
            groupJSON: groupJSON,
            wifi: wifi,
            cellular: cellular,
            wired: wired,
            at: Date()
        )
        do {
            try store.writeSnapshot(snapshot)
        } catch {
            HakoLogStore.shared.append("widget: snapshot not written  \(error.localizedDescription)", stream: .app, level: .warning)
        }
         
         
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(HakoWidgetMailbox.updatedNotification as CFString),
            nil, nil, true
        )
        if reloads {
            let ask = {
                 
                 
                for kind in HakoWidgetMailbox.Kind.all {
                    WidgetCenter.shared.reloadTimelines(ofKind: kind)
                }
            }
            if reloadDelay > 0 {
                queue.asyncAfter(deadline: .now() + reloadDelay, execute: ask)
            } else {
                ask()
            }
        }
        let milliseconds = Int(Date().timeIntervalSince(began) * 1_000)
         
         
         
        let numbers = "up=\(snapshot.upTotal.map(String.init) ?? "-") down=\(snapshot.downTotal.map(String.init) ?? "-")"
            + " proxy=\(snapshot.proxy.map { "\($0.up)/\($0.down)" } ?? "-") direct=\(snapshot.direct.map { "\($0.up)/\($0.down)" } ?? "-")"
            + " reject=\(snapshot.rejectCount.map(String.init) ?? "-") conns=\(snapshot.connections.map { "\($0.opened)/\($0.active)" } ?? "-")"
            + " wifi=\(snapshot.wifi.map { "\($0.up)/\($0.down)" } ?? "-") cell=\(snapshot.cellular.map { "\($0.up)/\($0.down)" } ?? "-")"
            + " egress=\(snapshot.egress ?? "-") members=\(snapshot.group?.all.count ?? 0)"
        HakoLogStore.shared.append(
            "widget: published \(phase.rawValue) group=\(group ?? "-") reason=\(reason) reloads=\(reloads) in \(milliseconds) ms  \(numbers)",
            stream: .app, level: .info
        )
    }

     
    private func totals() -> (up: Int64, down: Int64)? {
        traffic().map { ($0.upTotal, $0.downTotal) }
    }

     
     
     
    private func traffic() -> (up: Int64, down: Int64, upTotal: Int64, downTotal: Int64)? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(HakoTrafficJSON().utf8)) as? [String: Any],
              let upTotal = (object["upTotal"] as? NSNumber)?.int64Value,
              let downTotal = (object["downTotal"] as? NSNumber)?.int64Value else { return nil }
        let up = (object["up"] as? NSNumber)?.int64Value ?? 0
        let down = (object["down"] as? NSNumber)?.int64Value ?? 0
        return (up, down, upTotal, downTotal)
    }
}
#endif
