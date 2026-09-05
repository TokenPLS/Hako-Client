import BackgroundTasks
import Foundation

 
 
enum ProfilesDueForRefresh {
    static func select(profiles: [Profile], now: Date) -> [Profile] {
        profiles.filter { profile in
            guard profile.autoUpdate, case .url = profile.source else { return false }
            guard let last = profile.lastUpdatedAt else { return true }
            return last.addingTimeInterval(TimeInterval(profile.updateIntervalHours) * 3600) <= now
        }
    }
}

 
 
 
 
 
 
enum ProvidersDueForRefresh {
    static func select(
        entries: [ProviderCatalog.Entry],
        now: Date
    ) -> [ProviderCatalog.Entry] {
        entries.filter { entry in
            guard let seconds = entry.updateIntervalSeconds, seconds > 0,
                  let lastUpdatedAt = entry.lastUpdatedAt else {
                return false
            }
            return lastUpdatedAt.addingTimeInterval(TimeInterval(seconds)) <= now
        }
    }

    static func nextEligibility(
        entries: [ProviderCatalog.Entry],
        now: Date
    ) -> Date? {
        entries.compactMap { entry -> Date? in
            guard let seconds = entry.updateIntervalSeconds, seconds > 0,
                  let lastUpdatedAt = entry.lastUpdatedAt else {
                return nil
            }
            return max(now, lastUpdatedAt.addingTimeInterval(TimeInterval(seconds)))
        }.min()
    }
}

enum BackgroundRefreshPolicy {
#if os(macOS)
    static let explanation = "macOS refreshes eligible resources while Clash is running. Low Data, metered, offline, no-DNS and no-route paths are deferred according to the user's network policy. Downloads are saved for the next reload or start."
#else
    static let explanation = "iOS schedules background refresh on a best-effort basis. The interval is the earliest eligibility, not a guaranteed time. Low Data, metered, offline, no-DNS and no-route paths are deferred according to the user's network policy. Downloads are saved for the next reload or start."
#endif

    static func earliestEligibility(afterHours hours: Int, from date: Date = Date()) -> Date {
        date.addingTimeInterval(TimeInterval(max(1, hours)) * 3600)
    }
}

struct BackgroundRefreshOutcome: Equatable {
    var attempted = 0
    var updated = 0
    var unchanged = 0
    var failed = 0
     
     
     
     
    var sideDeferred = 0
    var cancelled = false
    var deferredReason: String? = nil
    var nextEligibleAt: Date? = nil

    var isSuccessful: Bool { !cancelled && failed == 0 }
    var isDeferred: Bool { deferredReason != nil }

     
     
     
     
    mutating func record(_ error: Error) {
        if SideUpdateDeferral.isDeferred(error) {
            sideDeferred += 1
        } else {
            failed += 1
        }
    }
}

 
 
 
 
enum BackgroundRefresh {
    static let identifier = HakoAppIdentifiers.backgroundRefreshTask

    static func register(handler: @escaping () async -> BackgroundRefreshOutcome) {
#if os(macOS)
         
         
        _ = handler
#else
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let work = Task {
                let outcome = await handler()
                schedule(earliest: outcome.nextEligibleAt ?? nextEligibility())
                task.setTaskCompleted(success: outcome.isSuccessful)
            }
            task.expirationHandler = { work.cancel() }
        }
#endif
    }

    static func schedule(afterHours: Int) {
        schedule(earliest: BackgroundRefreshPolicy.earliestEligibility(
            afterHours: afterHours
        ))
    }

    static func schedule(earliest date: Date) {
#if os(macOS)
        _ = date
#else
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = date
        try? BGTaskScheduler.shared.submit(request)
#endif
    }

     
     
    static func nextEligibility(
        now: Date = Date(),
        containerURL: URL? = nil
    ) -> Date {
        let fallback = BackgroundRefreshPolicy.earliestEligibility(
            afterHours: 4,
            from: now
        )
        let container = containerURL ?? HakoAppIdentifiers.appGroupContainer
        guard let container,
              let store = try? ConfigResourceStore(containerURL: container),
              let providersDir = try? store.activeProvidersDirectory(),
              let entries = ProviderCatalog.load(providersDir: providersDir)?.entries,
              let providerEligibility = ProvidersDueForRefresh.nextEligibility(
                entries: entries,
                now: now
              ) else {
            return fallback
        }
        return min(fallback, providerEligibility)
    }

     
     
     
     
    static let foregroundScanInterval: TimeInterval = 20 * 60

    static let foregroundScanKey = "backgroundRefresh.lastForegroundScan"

     
     
     
    static func shouldScanOnForeground(
        now: Date = Date(),
        lastScan: Date?,
        minimumInterval: TimeInterval = foregroundScanInterval
    ) -> Bool {
        guard let lastScan else { return true }
        let elapsed = now.timeIntervalSince(lastScan)
        return elapsed >= minimumInterval
    }

     
     
     
     
     
     
     
    @discardableResult
     
     
     
     
    static func scanOnForegroundIfDue(
        now: Date = Date(),
        defaults: UserDefaults = GlobalConfig.appGroupDefaults,
        refresh: (Date) async -> BackgroundRefreshOutcome = {
            await refreshDueProfiles(now: $0)
        }
    ) async -> Bool {
        let last = defaults.object(forKey: foregroundScanKey) as? Date
        guard shouldScanOnForeground(now: now, lastScan: last) else {
            return false
        }
        let outcome = await refresh(now)
         
         
         
         
         
        guard outcome.deferredReason == nil else { return false }
        defaults.set(now, forKey: foregroundScanKey)
        return true
    }

     
     
     
     
    static func refreshDueProfiles(
        now: Date = Date(),
        pathSnapshot: NetworkPathSnapshot? = nil,
        pathSettings: NetworkPathPolicySettings = .load()
    ) async -> BackgroundRefreshOutcome {
        var outcome = BackgroundRefreshOutcome()
        guard let container = HakoAppIdentifiers.appGroupContainer,
            let store = try? ConfigResourceStore(containerURL: container)
        else {
            outcome.failed = 1
            return outcome
        }
        let snapshot: NetworkPathSnapshot
        if let pathSnapshot {
            snapshot = pathSnapshot
        } else {
            snapshot = await NetworkPathProbe.current()
        }
        let pathDecision = NetworkPathPolicy.automaticRefresh(
            snapshot: snapshot,
            settings: pathSettings
        )
        guard pathDecision.action == .allow else {
            outcome.deferredReason = pathDecision.message
            return outcome
        }
        let working = container.appendingPathComponent("working")
        let profileStore = ProfileStore(fileURL: working.appendingPathComponent("store/profiles.json"))
        let credentials = CredentialStore()
        let downloader = ResourceDownloader()
        let active = try? store.activePointer()
        let profiles = profileStore.load()
        let dueProfiles = ProfilesDueForRefresh.select(profiles: profiles, now: now)
        let dueProfileIDs = Set(dueProfiles.map(\.id))

         
         
         
        if let active,
           !dueProfileIDs.contains(active.profileID),
           let activeProfile = profiles.first(where: { $0.id == active.profileID }),
           let providersDir = try? store.activeProvidersDirectory(),
           let catalog = ProviderCatalog.load(providersDir: providersDir) {
             
             
            let due = ProvidersDueForRefresh.select(entries: catalog.entries, now: now).map(\.name)
            if !due.isEmpty {
                if Task.isCancelled {
                    outcome.cancelled = true
                    return outcome
                }
                outcome.attempted += due.count
                do {
                    let coordinator = ProfileActivationCoordinator(
                        store: store,
                        profileStore: profileStore,
                        credentials: credentials,
                        downloader: downloader,
                        coreHomeDir: working,
                         
                         
                        compileRuleSets: false,
                        activator: { _ in },
                        now: { now }
                    )
                    let round = try await coordinator.refreshProviders(named: due, profile: activeProfile)
                    outcome.updated += round.runtimeUpdates.count
                } catch is CancellationError {
                    outcome.cancelled = true
                    return outcome
                } catch {
                    outcome.record(error)
                }
            }
        }

         
         
         
        let firstLoad = await ProviderFirstLoadRetry.run(trigger: .scan, container: container, now: now)
        outcome.attempted += firstLoad.attempted
        outcome.updated += firstLoad.updated

         
         
        if GeoResourceSettings.isAutoUpdateDue(
            enabled: GeoResourceSettings.autoUpdateEnabled(),
            intervalHours: GeoResourceSettings.autoUpdateIntervalHours(),
            lastSync: GeoResourceSettings.lastSync(), now: now) {
            var allGeoSucceeded = true
            for resource in GeoResource.allCases {
                if Task.isCancelled {
                    outcome.cancelled = true
                    return outcome
                }
                outcome.attempted += 1
                let geoPlan = RemoteResourcePlan(
                    providers: [],
                    geodata: [.init(
                        kind: resource.planKind,
                        url: GeoResourceSettings.url(for: resource)
                    )],
                    notices: [],
                    errors: []
                )
                do {
                    try await GeodataManager(downloader: downloader).stage(
                        plan: geoPlan,
                        homeDir: working,
                        maxBytesEach: ProfileActivationCoordinator.maxGeodataBytes
                    )
                    outcome.updated += 1
                } catch is CancellationError {
                    outcome.cancelled = true
                    return outcome
                } catch {
                    allGeoSucceeded = false
                    outcome.failed += 1
                }
            }
            if allGeoSucceeded {
                GeoResourceSettings.recordSync(at: now)
            }
        }

        for profile in dueProfiles {
            if Task.isCancelled {
                outcome.cancelled = true
                return outcome
            }
            outcome.attempted += 1
            do {
                if profile.id == active?.profileID {
                    let coordinator = ProfileActivationCoordinator(
                        store: store, profileStore: profileStore, credentials: credentials,
                        downloader: downloader, coreHomeDir: working,
                         
                         
                        compileRuleSets: false,
                        activator: { _ in })
                    let before = try? store.activePointer()
                    let pointer = try await coordinator.activate(profile: profile, sourceYAML: nil)
                    if before?.revision == pointer.revision {
                        outcome.unchanged += 1
                    } else {
                        outcome.updated += 1
                    }
                } else {
                    let subscriptions = SubscriptionManager(
                        downloader: downloader,
                        credentials: credentials
                    )
                    let result = try await SubscriptionSourceRefresher.refresh(
                        profile: profile,
                        manager: subscriptions,
                        profileStore: profileStore,
                        credentials: credentials,
                        workingDirectory: working,
                        now: now
                    )
                    if result == .unchanged {
                        outcome.unchanged += 1
                    } else {
                        outcome.updated += 1
                    }
                }
            } catch is CancellationError {
                outcome.cancelled = true
                return outcome
            } catch {
                 
                 
                 
                 
                outcome.record(error)
            }
        }
        outcome.nextEligibleAt = nextEligibility(now: now, containerURL: container)
        return outcome
    }
}
