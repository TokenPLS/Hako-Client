import Foundation

 
 
 
 

 
public enum HakoWidgetPhase: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case reasserting
}

 
public enum HakoWidgetMode: String, Codable, CaseIterable, Sendable {
    case rule
    case global
    case direct
}

public struct HakoWidgetBytes: Codable, Equatable, Sendable {
    public var up: Int64
    public var down: Int64

    public init(up: Int64, down: Int64) {
        self.up = up
        self.down = down
    }
}

public struct HakoWidgetConnections: Codable, Equatable, Sendable {
    public let opened: Int
    public let active: Int
    public let rejected: Int

    public init(opened: Int, active: Int, rejected: Int) {
        self.opened = opened
        self.active = active
        self.rejected = rejected
    }
}

 
 
public struct HakoWidgetGroupSlice: Codable, Equatable, Sendable {
    public let name: String
    public let type: String
    public let now: String?
    public let all: [String]

    public init(name: String, type: String, now: String?, all: [String]) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
    }
}

 
 
 
public struct HakoWidgetSnapshot: Codable, Equatable, Sendable {
    public var phase: HakoWidgetPhase
    public var profile: String?
    public var mode: HakoWidgetMode?
     
     
    public var egress: String?
    public var startedAt: Date?
    public var upTotal: Int64?
    public var downTotal: Int64?
     
     
     
    public var upRate: Int64?
    public var downRate: Int64?
    public var proxy: HakoWidgetBytes?
    public var direct: HakoWidgetBytes?
    public var reject: HakoWidgetBytes?
    public var rejectCount: Int?
    public var connections: HakoWidgetConnections?
    public var wifi: HakoWidgetBytes?
    public var cellular: HakoWidgetBytes?
     
    public var wired: HakoWidgetBytes?
    public var group: HakoWidgetGroupSlice?
     
     
    public var at: Date

    public static let freshness: TimeInterval = 30 * 60

    public init(
        phase: HakoWidgetPhase,
        profile: String? = nil,
        mode: HakoWidgetMode? = nil,
        egress: String? = nil,
        startedAt: Date? = nil,
        upTotal: Int64? = nil,
        downTotal: Int64? = nil,
        upRate: Int64? = nil,
        downRate: Int64? = nil,
        proxy: HakoWidgetBytes? = nil,
        direct: HakoWidgetBytes? = nil,
        reject: HakoWidgetBytes? = nil,
        rejectCount: Int? = nil,
        connections: HakoWidgetConnections? = nil,
        wifi: HakoWidgetBytes? = nil,
        cellular: HakoWidgetBytes? = nil,
        wired: HakoWidgetBytes? = nil,
        group: HakoWidgetGroupSlice? = nil,
        at: Date
    ) {
        self.phase = phase
        self.profile = profile
        self.mode = mode
        self.egress = egress
        self.startedAt = startedAt
        self.upTotal = upTotal
        self.downTotal = downTotal
        self.upRate = upRate
        self.downRate = downRate
        self.proxy = proxy
        self.direct = direct
        self.reject = reject
        self.rejectCount = rejectCount
        self.connections = connections
        self.wifi = wifi
        self.cellular = cellular
        self.wired = wired
        self.group = group
        self.at = at
    }

    public func isFresh(now: Date) -> Bool {
        now.timeIntervalSince(at) <= Self.freshness
    }

     
     
     
     
    public func asDisconnected() -> HakoWidgetSnapshot {
        HakoWidgetSnapshot(phase: .disconnected, profile: profile, group: group, at: at)
    }
}

 
 
 
 
public enum HakoWidgetSnapshotComposer {
    public static func compose(
        phase: HakoWidgetPhase,
        profile: String?,
        startedAt: Date?,
        rate: (up: Int64, down: Int64)? = nil,
        statsJSON: Data?,
        groupJSON: Data?,
        wifi: HakoWidgetBytes?,
        cellular: HakoWidgetBytes?,
        wired: HakoWidgetBytes? = nil,
        at: Date
    ) -> HakoWidgetSnapshot {
        var snapshot = HakoWidgetSnapshot(
            phase: phase, profile: profile, startedAt: startedAt,
            wifi: wifi, cellular: cellular, wired: wired, at: at
        )
        if let stats = object(statsJSON) {
            snapshot.mode = (stats["mode"] as? String).flatMap(HakoWidgetMode.init(rawValue:))
            snapshot.upTotal = int64(stats["upTotal"])
            snapshot.downTotal = int64(stats["downTotal"])
            snapshot.upRate = rate?.up
            snapshot.downRate = rate?.down
            snapshot.egress = stats["egress"] as? String
            if let outbound = stats["byOutbound"] as? [String: Any] {
                snapshot.proxy = bytes(outbound["proxy"])
                snapshot.direct = bytes(outbound["direct"])
                snapshot.reject = bytes(outbound["reject"])
                snapshot.rejectCount = (outbound["reject"] as? [String: Any]).flatMap { int($0["count"]) }
            }
            if let counts = stats["connections"] as? [String: Any],
               let opened = int(counts["opened"]),
               let active = int(counts["active"]),
               let rejected = int(counts["rejected"]) {
                snapshot.connections = HakoWidgetConnections(opened: opened, active: active, rejected: rejected)
            }
        }
         
         
        if let group = object(groupJSON), let name = group["name"] as? String {
            snapshot.group = HakoWidgetGroupSlice(
                name: name,
                type: group["type"] as? String ?? "",
                now: group["now"] as? String,
                all: group["all"] as? [String] ?? []
            )
        }
        return snapshot
    }

    private static func object(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func int64(_ value: Any?) -> Int64? { (value as? NSNumber)?.int64Value }
    private static func int(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    private static func bytes(_ value: Any?) -> HakoWidgetBytes? {
        guard let dictionary = value as? [String: Any],
              let up = int64(dictionary["up"]),
              let down = int64(dictionary["down"]) else { return nil }
        return HakoWidgetBytes(up: up, down: down)
    }
}
