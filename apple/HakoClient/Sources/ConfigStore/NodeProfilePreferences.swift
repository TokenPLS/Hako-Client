import Foundation

struct ActiveNodeProfileState: Equatable {
    let profileID: String
    let selectedMap: [String: String]
    let currentGroupName: String?
    let unfoldedGroups: Set<String>?
}

 
 
 
 
final class NodeProfilePreferencesStore {
    private let profileStore: ProfileStore
    private let activeProfileID: () -> String?

    init(profileStore: ProfileStore, activeProfileID: @escaping () -> String?) {
        self.profileStore = profileStore
        self.activeProfileID = activeProfileID
    }

    static func live() -> NodeProfilePreferencesStore? {
        guard let container = HakoAppIdentifiers.appGroupContainer else { return nil }
        let working = container.appendingPathComponent("working")
        let profiles = ProfileStore(fileURL: working.appendingPathComponent("store/profiles.json"))
        return NodeProfilePreferencesStore(profileStore: profiles) {
            if let configStore = try? ConfigResourceStore(containerURL: container),
               let activeProfileID = (try? configStore.activeIdentity())?.profileID {
                return activeProfileID
            }
            let stored = profiles.load()
            return ProfileCenterPolicy.automaticSelectionID(
                profiles: stored,
                activeProfileID: nil
            )
        }
    }

    func load() -> ActiveNodeProfileState? {
        guard let id = activeProfileID(),
              let profile = profileStore.load().first(where: { $0.id == id }) else { return nil }
        return ActiveNodeProfileState(
            profileID: id,
            selectedMap: profile.selectedMap,
            currentGroupName: profile.currentGroupName,
            unfoldedGroups: profile.unfoldedGroups
        )
    }

    func saveSelection(group: String, proxy: String) {
        updateActive { profile in
            profile.selectedMap[group] = proxy
            profile.currentGroupName = group
        }
    }

     
     
     
     
     
     
     
     
     
     
    @discardableResult
    func clearSelection(group: String) -> Bool {
        updateActive { profile in
            profile.selectedMap.removeValue(forKey: group)
        }
    }

     
     
     
     
     
    @discardableResult
    func restoreSelection(group: String, proxy: String) -> Bool {
        updateActive { profile in
            profile.selectedMap[group] = proxy
        }
    }

    func savePresentation(currentGroup: String?, unfoldedGroups: Set<String>) {
        updateActive { profile in
            profile.currentGroupName = currentGroup
            profile.unfoldedGroups = unfoldedGroups
        }
    }

    @discardableResult
    private func updateActive(_ mutate: (inout Profile) -> Void) -> Bool {
        guard let id = activeProfileID(),
              var profile = profileStore.load().first(where: { $0.id == id })
        else { return false }
        mutate(&profile)
        do {
            try profileStore.upsert(profile)
             
             
             
             
             
             
            NotificationCenter.default.post(
                name: .hakoProfileSelectionDidChange,
                object: nil,
                userInfo: ["profileID": id]
            )
            return true
        } catch {
            return false
        }
    }
}

extension Notification.Name {
     
     
     
    static let hakoProfileSelectionDidChange = Notification.Name("HakoProfileSelectionDidChange")
}
