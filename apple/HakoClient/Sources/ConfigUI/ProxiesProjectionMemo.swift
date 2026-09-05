import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
final class ProxiesProjectionMemo {
    struct GroupsKey: Equatable {
         
         
         
         
        let outboundMode: ProxyBrowsingVisibility.Mode
        let source: [ProxiesOverviewModel.Group]
        let runtimeCatalog: [ProxyGroup]
        let nowByGroup: [String: String]
        let resolvedNowByGroup: [String: String]
        let isConnected: Bool
    }

    struct UngroupedKey: Equatable {
         
        let outboundMode: ProxyBrowsingVisibility.Mode
        let source: [ProxiesOverviewModel.Proxy]
        let runtimeNodes: [ProxiesOverviewModel.Proxy]
        let runtimeGroups: [ProxyGroup]
        let isConnected: Bool
        let runtimeIsAuthoritative: Bool
    }

    private var groupsKey: GroupsKey?
    private var groupsValue: [HakoProxyGroupSnapshot] = []
    private var ungroupedKey: UngroupedKey?
    private var ungroupedValue: [HakoProxySnapshot] = []

     
     
    private(set) var builds = 0

     
     
     
     
     
    private var memberRowsByGroup:
        [String: (members: [ProxiesOverviewModel.Member], rows: [HakoProxyMemberSnapshot])] = [:]
    private(set) var memberBuilds = 0

    func members(
        of group: ProxiesOverviewModel.Group
    ) -> [HakoProxyMemberSnapshot] {
        if let kept = memberRowsByGroup[group.name],
           kept.members == group.members {
            return kept.rows
        }
        memberBuilds += 1
        let rows = group.members.map {
            HakoProxyMemberSnapshot(
                name: $0.name,
                type: $0.type,
                isGroup: $0.isGroup,
                chainedThrough: $0.chainedThrough
            )
        }
        memberRowsByGroup[group.name] = (group.members, rows)
        return rows
    }

     
     
     
     
     
     
     
    private static func firstDifference(
        _ old: GroupsKey, _ new: GroupsKey
    ) -> String {
        if old.source != new.source { return "source" }
        if old.runtimeCatalog != new.runtimeCatalog { return "runtimeCatalog" }
        if old.nowByGroup != new.nowByGroup { return "nowByGroup" }
        if old.resolvedNowByGroup != new.resolvedNowByGroup {
            return "resolvedNowByGroup"
        }
        if old.isConnected != new.isConnected { return "isConnected" }
         
         
         
        return "unknown"
    }

    func groups(
        _ key: GroupsKey,
        build: () -> [HakoProxyGroupSnapshot]
    ) -> [HakoProxyGroupSnapshot] {
        if let groupsKey {
            if groupsKey == key { return groupsValue }
            HakoPerf.count(
                "proxies.memo.miss." + Self.firstDifference(groupsKey, key)
            )
        }
        builds += 1
        let value = build()
        groupsKey = key
        groupsValue = value
        return value
    }

    func ungrouped(
        _ key: UngroupedKey,
        build: () -> [HakoProxySnapshot]
    ) -> [HakoProxySnapshot] {
        if let ungroupedKey, ungroupedKey == key { return ungroupedValue }
        builds += 1
        let value = build()
        ungroupedKey = key
        ungroupedValue = value
        return value
    }
}


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxiesSweepSnapshotHold {
    struct Key: Equatable {
        let preferences: HakoProxiesDisplayPreferences
        let outboundModeToken: String
        let isConnected: Bool
        let nowByGroup: [String: String]
        let resolvedNowByGroup: [String: String]
        let groupCount: Int
        let ungroupedCount: Int
    }

    static func servesHeld(
        isSweeping: Bool,
        held: Key?,
        current: Key
    ) -> Bool {
        guard isSweeping, let held else { return false }
        return held == current
    }
}
