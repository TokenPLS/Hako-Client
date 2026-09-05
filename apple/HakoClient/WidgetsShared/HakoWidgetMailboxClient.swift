import Foundation

 
 
 
 
enum HakoWidgetMailboxClient {
    static var store: HakoWidgetMailboxStore {
        HakoWidgetMailboxStore(
            root: HakoAppIdentifiers.appGroupContainer ?? FileManager.default.temporaryDirectory
        )
    }

     
     
    static func requestAndWait(_ command: HakoWidgetRequest.Command, group: String?, kind: String = "") async -> HakoWidgetSnapshot? {
        let store = store
        let request = HakoWidgetRequest(command: command, group: group)
        let began = Date()
        do {
            try store.writeRequest(request)
        } catch {
            HakoLogStore.shared.append(
                "widget client: request not written  \(error.localizedDescription)",
                stream: .app, level: .warning
            )
            return store.readSnapshot()
        }
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(HakoWidgetMailbox.requestNotification as CFString),
            nil, nil, true
        )
        let deadline = began.addingTimeInterval(HakoWidgetMailbox.waitForSnapshot)
        var latest = store.readSnapshot()
        var answered = latest.map { $0.at >= request.at } ?? false
        while !answered, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let snapshot = store.readSnapshot() {
                latest = snapshot
                answered = snapshot.at >= request.at
            }
        }
        let milliseconds = Int(Date().timeIntervalSince(began) * 1_000)
        let phase = latest.map { $0.phase.rawValue } ?? "none"
        HakoLogStore.shared.append(
            "widget client: \(kind) \(word(command)) answered=\(answered) in \(milliseconds) ms phase=\(phase) proxy=\(latest?.proxy != nil) conns=\(latest?.connections != nil)",
            stream: .app, level: .info
        )
        return latest
    }

     
     
     
    static func markDisconnected() {
        let store = store
        if let file = store.readSnapshot(), file.phase == .connected {
            try? store.writeSnapshot(file.asDisconnected())
        }
    }

    private static func word(_ command: HakoWidgetRequest.Command) -> String {
        switch command {
        case .refresh: return "refresh"
        case .setMode(let mode): return "setMode \(mode.rawValue)"
        case .select: return "select"
        }
    }
}
