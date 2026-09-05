import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProviderFirstLoadRetry {
    enum Trigger: String { case activation, connected, scan }

    struct Outcome: Equatable {
        var attempted = 0
        var updated = 0
        var failed = 0
        var skippedInFlight = 0
         
        var skippedLoadedInCore = 0
    }

     
     
     
     
     
     
     
     
     
    nonisolated(unsafe) static var loadedRuleProvidersInCore: (@Sendable () async -> Set<String>)?

     
     
    static let didRefreshNotification = Notification.Name("org.example.hako.provider.first-load.refreshed")

     
     
     
     
    static func select(entries: [ProviderCatalog.Entry]) -> [ProviderCatalog.Entry] {
        entries.filter { $0.lastUpdatedAt == nil && $0.kind == "rule" }
    }

     
    static func select(entries: [ProviderCatalog.Entry], loadedInCore: Set<String>) -> [ProviderCatalog.Entry] {
        select(entries: entries).filter { !loadedInCore.contains($0.name) }
    }

     
     
     
     
     
    static func budget(for trigger: Trigger, tunnelUp: Bool) -> ProviderFetchBudget {
        .patient
    }

     

    final class InFlight: @unchecked Sendable {
        private let lock = NSLock()
        private var names: Set<String> = []

         
        func claim(_ wanted: [String]) -> (claimed: [String], busy: Int) {
            lock.lock(); defer { lock.unlock() }
            var claimed: [String] = []
            var busy = 0
            for name in wanted {
                if names.contains(name) { busy += 1 } else { names.insert(name); claimed.append(name) }
            }
            return (claimed, busy)
        }

        func release(_ done: [String]) {
            lock.lock(); defer { lock.unlock() }
            for name in done { names.remove(name) }
        }

        var count: Int { lock.lock(); defer { lock.unlock() }; return names.count }
    }

    static let inFlight = InFlight()

     
     
     
     
     
     
    private static let rerunLock = NSLock()
    nonisolated(unsafe) private static var rerunAfterInFlight = false

    static func requestRerunAfterInFlight() {
        rerunLock.lock(); rerunAfterInFlight = true; rerunLock.unlock()
    }

    static func takeRerunRequest() -> Bool {
        rerunLock.lock(); defer { rerunLock.unlock() }
        let requested = rerunAfterInFlight
        rerunAfterInFlight = false
        return requested
    }

     

    private static let updatesLock = NSLock()
    nonisolated(unsafe) private static var pendingUpdates: [ProviderRuntimeUpdate] = []

    static func takeRuntimeUpdates() -> [ProviderRuntimeUpdate] {
        updatesLock.lock(); defer { updatesLock.unlock() }
        let taken = pendingUpdates
        pendingUpdates = []
        return taken
    }

    private static func enqueue(_ update: ProviderRuntimeUpdate) {
        updatesLock.lock()
        pendingUpdates.append(update)
        updatesLock.unlock()
    }

     

     
     
    nonisolated(unsafe) static var scheduler: (Trigger) -> Void = { trigger in
        Task.detached(priority: .utility) {
            _ = await run(trigger: trigger)
        }
    }

     
     
    static func noteActivation(pending: [String], profileID: String) {
        guard !pending.isEmpty else { return }
        HakoLogStore.shared.append(
            "provider first-load: \(pending.count) rule set(s) staged empty by the switch; retry scheduled  profile=\(profileID)",
            stream: .app, level: .info
        )
        scheduler(.activation)
    }

    static func kick(trigger: Trigger) {
        scheduler(trigger)
    }

     
     
    static func tunnelIsUp(container: URL) -> Bool {
        HakoWidgetMailboxStore(root: container).readSnapshot()?.phase == .connected
    }

     
    @discardableResult
    static func run(
        trigger: Trigger,
        container: URL? = HakoAppIdentifiers.appGroupContainer,
        tunnelUp: Bool? = nil,
        now: Date = Date()
    ) async -> Outcome {
        var outcome = Outcome()
        guard let container,
              let store = try? ConfigResourceStore(containerURL: container),
              let active = try? store.activePointer(),
              let providersDir = try? store.activeProvidersDirectory(),
              let catalog = ProviderCatalog.load(providersDir: providersDir)
        else { return outcome }
        let working = container.appendingPathComponent("working")
        let profileStore = ProfileStore(fileURL: working.appendingPathComponent("store/profiles.json"))
        guard let profile = profileStore.load().first(where: { $0.id == active.profileID }) else { return outcome }

        let up = tunnelUp ?? tunnelIsUp(container: container)
        var loadedInCore: Set<String> = []
        if up, let probe = loadedRuleProvidersInCore {
            loadedInCore = await probe()
        }
        let owed = select(entries: catalog.entries)
        let wanted = select(entries: catalog.entries, loadedInCore: loadedInCore).map(\.name)
        outcome.skippedLoadedInCore = owed.count - wanted.count
        if outcome.skippedLoadedInCore > 0 {
            HakoLogStore.shared.append(
                "provider first-load: the core already loaded \(outcome.skippedLoadedInCore) rule set(s); not fetching those",
                stream: .app, level: .info
            )
        }
        guard !wanted.isEmpty else { return outcome }
        let (claimed, busy) = inFlight.claim(wanted)
        outcome.skippedInFlight = busy
        if busy > 0, trigger == .connected { requestRerunAfterInFlight() }
        guard !claimed.isEmpty else { return outcome }
        defer {
            inFlight.release(claimed)
            if takeRerunRequest() {
                Task.detached(priority: .utility) { _ = await run(trigger: .connected, container: container, now: Date()) }
            }
        }

        let budget = budget(for: trigger, tunnelUp: up)
        HakoLogStore.shared.append(
            "provider first-load: trigger=\(trigger.rawValue) budget=\(budget == .quick ? "quick" : "patient") tunnel=\(up ? "up" : "down") providers=\(claimed.count) busy=\(busy)",
            stream: .app, level: .info
        )
        let credentials = CredentialStore()
        let downloader = ResourceDownloader()
        var refreshed = 0
        var failed = claimed.count
         
         
         
        let coordinator = ProfileActivationCoordinator(
            store: store, profileStore: profileStore, credentials: credentials,
            downloader: downloader, coreHomeDir: working,
            compileRuleSets: false, activator: { _ in }, now: { now }
        )
        do {
            let round = try await coordinator.refreshPendingProviders(
                profile: profile, names: claimed, fetchBudget: budget
            )
            for update in round.runtimeUpdates.values { enqueue(update) }
             
             
             
             
            refreshed = round.runtimeUpdates.count
            failed = claimed.count - refreshed
        } catch {
            HakoLogStore.shared.append(
                "provider first-load: round not published  \(error.localizedDescription)",
                stream: .app, level: .info
            )
        }
        outcome.attempted = claimed.count
        outcome.updated = refreshed
        outcome.failed = failed
        if refreshed > 0 {
            NotificationCenter.default.post(name: didRefreshNotification, object: nil)
        }
        HakoLogStore.shared.append(
            "provider first-load: done trigger=\(trigger.rawValue) refreshed=\(refreshed) pending=\(failed)",
            stream: .app, level: .info
        )
        return outcome
    }
}
