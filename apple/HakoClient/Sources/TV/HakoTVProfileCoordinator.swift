import Foundation
import NetworkExtension

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoTVProfileCoordinator {
    typealias Loader = @MainActor () async throws -> [any HakoTVSystemProfile]
    typealias Maker = @MainActor () -> any HakoTVSystemProfile

    enum SaveOutcome {
        case saved
        case refused(Error)
        case indeterminate(Error)
         
        case loadFailed(Error)
         
         
        case noProfile
         
         
        case superseded
    }

    private var profile: (any HakoTVSystemProfile)?
     
     
     
    private var intent: Bool
    private var intentSeq = 0
     
     
     
    private(set) var armedWanted = false
    private var profileStamp = 0
    private var generation = 0
    private var queue: Task<Void, Never>?

    private let load: Loader
    private let make: Maker
    private let timeout: TimeInterval
    private let ownedBy: @MainActor (any HakoTVSystemProfile) -> Bool
     
     
     
    private let persistIntent: @MainActor (Bool) -> Void
     
     
     
     
     
     
    private var storedIntent: Bool

    init(
        intent: Bool,
        persistIntent: @escaping @MainActor (Bool) -> Void,
        load: @escaping Loader,
        make: @escaping Maker,
        timeout: TimeInterval,
        ownedBy: @escaping @MainActor (any HakoTVSystemProfile) -> Bool
    ) {
        self.intent = intent
        self.storedIntent = intent
        self.persistIntent = persistIntent
        self.load = load
        self.make = make
        self.timeout = timeout
        self.ownedBy = ownedBy
    }

     
     
    var current: (any HakoTVSystemProfile)? { profile }

     

    private func serialized(_ work: @escaping @MainActor () async -> Void) async {
        let prior = queue
        let task = Task { @MainActor in
            await prior?.value
            await work()
        }
        queue = task
        await task.value
    }

    private func install(_ profile: any HakoTVSystemProfile) {
        self.profile = profile
        profileStamp += 1
    }

    private func arm(_ profile: any HakoTVSystemProfile, wanted: Bool) {
        profile.onDemandRules = wanted ? [NEOnDemandRuleConnect()] : nil
        profile.isOnDemandEnabled = wanted
        armedWanted = wanted
        generation += 1
    }

     
     
     
     
    private func save(_ profile: any HakoTVSystemProfile) async throws {
        let began = generation
        try await HakoTVTunnelController.bounded(timeout, late: { [weak self] result in
            Task { @MainActor in await self?.reconcileLateSave(profile, began: began, result: result) }
        }) { try await profile.saveToPreferences() }
    }

     
     
     
     
     
    private func reconcileLateSave(_ profile: any HakoTVSystemProfile, began: Int, result: Result<Void, Error>) async {
        guard case .success = result else { return }
        await serialized { [weak self] in
            guard let self else { return }
             
             
            if self.profile == nil { self.install(profile) }
            let wanted = self.armedWanted
            guard profile.isOnDemandEnabled != wanted || began != self.generation else { return }
            if profile.isOnDemandEnabled != wanted { self.arm(profile, wanted: wanted) }
            try? await self.save(profile)
        }
    }

    private func isIndeterminate(_ error: Error) -> Bool {
        if case HakoTVTunnelController.ControllerError.systemTimedOut = error { return true }
        return false
    }

     
     
     
    private func loadInstalled() async throws -> (any HakoTVSystemProfile)? {
        let stamp = profileStamp
        let installed = try await HakoTVTunnelController.bounded(timeout) { try await self.load() }
        guard let found = installed.first(where: ownedBy) else { return nil }
        if profileStamp == stamp, profile == nil { install(found) }
        return profile ?? found
    }

     

     
     
     
    func find() async throws {
        guard profile == nil else { return }
        _ = try await loadInstalled()
    }

     
     
     
     
    func setWanted(_ wanted: Bool, apply: @escaping @MainActor (SaveOutcome, Bool) -> Void) async {
        intentSeq += 1
        let seq = intentSeq
        intent = wanted
        await serialized { [weak self] in
            guard let self else { return }
            guard seq == self.intentSeq else { return apply(.superseded, wanted) }
            let outcome = await self.applyWanted(wanted)
            switch outcome {
            case .refused, .loadFailed:
                 
                 
                 
                self.intent = self.storedIntent
            case .saved, .indeterminate, .noProfile, .superseded:
                break
            }
            apply(outcome, wanted)
        }
    }

    private func store(_ wanted: Bool) {
        storedIntent = wanted
        persistIntent(wanted)
    }

    private func applyWanted(_ wanted: Bool) async -> SaveOutcome {
        if profile == nil {
            do { _ = try await loadInstalled() }
            catch { return .loadFailed(error) }
        }
        guard let profile else {
             
             
             
            store(wanted)
            return .noProfile
        }
        let previous = armedWanted
        arm(profile, wanted: wanted)
        do {
            try await save(profile)
            store(wanted)
            return .saved
        } catch {
            if isIndeterminate(error) {
                 
                store(wanted)
                return .indeterminate(error)
            }
            arm(profile, wanted: previous)
            return .refused(error)
        }
    }

     
     
     
     
     
     
     
    func commitStart(
        configure: @escaping @MainActor (any HakoTVSystemProfile) -> Void,
        shouldAbort: @escaping @MainActor () -> Bool
    ) async throws {
        var failure: Error?
        await serialized { [weak self] in
            guard let self else { return }
            if shouldAbort() { failure = CancellationError(); return }
            let profile: any HakoTVSystemProfile
            if let held = self.profile {
                profile = held
            } else {
                do {
                    profile = try await self.loadInstalled() ?? self.make()
                } catch {
                    failure = error
                    return
                }
            }
            configure(profile)
            self.arm(profile, wanted: self.intent)
            do {
                try await self.save(profile)
                self.install(profile)
                try await HakoTVTunnelController.bounded(self.timeout) { try await profile.loadFromPreferences() }
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
    }

     
     
     
     
     
    func stop(performStop: @escaping @MainActor (any HakoTVSystemProfile) -> Void) async {
        await serialized { [weak self] in
            guard let self else { return }
            self.armedWanted = false
            self.generation += 1
            guard let profile = self.profile else { return }
            if profile.isOnDemandEnabled {
                self.arm(profile, wanted: false)
                try? await self.save(profile)
            }
            performStop(profile)
        }
    }
}
