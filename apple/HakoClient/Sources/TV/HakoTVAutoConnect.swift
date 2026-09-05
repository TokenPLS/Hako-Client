import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoTVAutoConnect {
     
     
    struct Store {
        static let key = "hako.tv.autoConnect"
        let defaults: UserDefaults

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }

        var isEnabled: Bool {
            defaults.bool(forKey: Self.key)
        }

        func set(_ enabled: Bool) {
            defaults.set(enabled, forKey: Self.key)
        }
    }

     
     
     
     
     
     
     
    enum Outcome {
        case saved
        case refused(Error)
        case indeterminate(Error)
    }

     
     
     
     
     
     
     
     
     
     
     
     
    @discardableResult
    @MainActor
    static func apply(
        wanted: Bool,
        store: Store,
        arm: (Bool) -> Void,
        save: () async throws -> Void,
        isIndeterminate: (Error) -> Bool = { _ in false }
    ) async -> Outcome {
        let previous = store.isEnabled
        store.set(wanted)
        arm(wanted)
        do {
            try await save()
            return .saved
        } catch {
            if isIndeterminate(error) {
                return .indeterminate(error)
            }
            store.set(previous)
            return .refused(error)
        }
    }

     
     
     
     
     
     
     
    @MainActor
    static func stop(
        disarm: () -> Bool,
        save: () async throws -> Void,
        stop: () -> Void
    ) async {
        if disarm() {
            try? await save()
        }
        stop()
    }
}
