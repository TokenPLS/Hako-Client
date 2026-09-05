import Foundation
import HakoClientUI
import WidgetKit

 
 
 
 
 
 
 
enum HakoWidgetFactsPublisher {
    static func facts(activeLabel: String?, sourceYAML: String?, now: Date) -> HakoWidgetAppFacts {
        guard let sourceYAML, !sourceYAML.isEmpty else {
            return HakoWidgetAppFacts(profile: activeLabel, firstGroup: nil, groups: [], writtenAt: now)
        }
         
         
         
         
        let declared = ProxiesOverviewModel.cached(sourceYAML: sourceYAML).groups
            .filter { $0.name != "GLOBAL" }
        let groups = declared.map(\.name)
        let firstSelector = declared.first {
            ProxiesOverviewModel.canonicalAdapterType($0.type) == "selector"
        }?.name
         
         
         
        var members: [String: [String]] = [:]
        var selections: [String: String] = [:]
        for group in declared {
             
             
             
             
             
            let named = group.members.filter {
                $0.name != "COMPATIBLE" && ProxiesOverviewModel.canonicalAdapterType($0.type) != "compatible"
            }
            members[group.name] = named.prefix(HakoWidgetMailbox.groupMemberLimit).map(\.name)
            if let selection = group.configuredSelection, named.contains(where: { $0.name == selection }) {
                selections[group.name] = selection
            }
        }
        return HakoWidgetAppFacts(
            profile: activeLabel,
            firstGroup: firstSelector ?? groups.first,
            groups: groups,
            members: members,
            selections: selections,
            writtenAt: now
        )
    }

    static func write(_ facts: HakoWidgetAppFacts, to store: HakoWidgetMailboxStore) {
        do {
            try store.writeAppFacts(facts)
        } catch {
            HakoLogStore.shared.append(
                "widget facts: not written  \(error.localizedDescription)",
                stream: .app, level: .warning
            )
        }
    }

     
     
    static func publish(activeLabel: String?, sourceYAML: @escaping () -> String?) {
        Task.detached(priority: .utility) {
            let facts = facts(activeLabel: activeLabel, sourceYAML: sourceYAML(), now: Date())
            write(facts, to: HakoWidgetMailboxStore(
                root: HakoAppIdentifiers.appGroupContainer ?? FileManager.default.temporaryDirectory
            ))
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
