import Foundation

enum StartupConfigurationRecoveryKind: Equatable {
    case current
    case regenerated
    case lastKnownGood
    case builtInSafety

    var userNotice: String? {
        switch self {
        case .current, .regenerated:
            return nil
        case .lastKnownGood:
            return "Clash could not rebuild the saved runtime revision with this client version. Your source profile was kept unchanged, and Clash started its validated last known-good runtime. Try syncing or reapplying the profile later."
        case .builtInSafety:
            return "Clash could not rebuild the saved runtime revision or start its last known-good runtime. Your source profile was kept unchanged, and a built-in safety configuration is blocking traffic. Please report this client runtime-generation failure."
        }
    }
}

struct StartupConfigurationPreparation: Equatable {
    let configuration: StoredConfiguration
    let recovery: StartupConfigurationRecoveryKind

    var userNotice: String? { recovery.userNotice }
}

enum ActiveRevisionMigrationError: LocalizedError {
    case builtInSafetyConfigurationInvalid(String)
    case configurationChangedRepeatedly

    var errorDescription: String? {
        switch self {
        case .builtInSafetyConfigurationInvalid(let reason):
            return "The built-in safety configuration failed validation: \(reason)"
        case .configurationChangedRepeatedly:
            return "The active configuration changed repeatedly while Clash was validating it. Try again."
        }
    }
}

 
 
 
final class ActiveRevisionMigrator {
    static let safetyProfileID = "00000000-0000-0000-0000-000000000001"
    static let safetyYAML = """
    mode: rule
    log-level: warning
    find-process-mode: off
    tun:
      strict-route: true
    dns:
      enable: true
      ipv6: false
      enhanced-mode: fake-ip
      default-nameserver:
        - 223.5.5.5
      nameserver:
        - rcode://refused
    proxies: []
    proxy-groups: []
    rules:
      - MATCH,REJECT
    """

    private let store: ConfigResourceStore
    private let preflight: (String) -> PreflightOutcome
    private let rebuild: (ActiveConfigurationPointer) async throws -> ActiveConfigurationPointer
    private let maximumAttempts: Int

    init(
        store: ConfigResourceStore,
        maximumAttempts: Int = 4,
        preflight: @escaping (String) -> PreflightOutcome = PreflightService.check,
        rebuild: @escaping (ActiveConfigurationPointer) async throws -> ActiveConfigurationPointer
    ) {
        self.store = store
        self.maximumAttempts = max(1, maximumAttempts)
        self.preflight = preflight
        self.rebuild = rebuild
    }

    func prepareForStart() async throws -> StartupConfigurationPreparation {
        for _ in 0..<maximumAttempts {
            var expectedPointer = try store.activePointer()
            if let currentPointer = expectedPointer {
                let active = try store.loadConfiguration(
                    profileID: currentPointer.profileID,
                    revision: currentPointer.revision
                )
                if validates(active) {
                    return StartupConfigurationPreparation(
                        configuration: active,
                        recovery: .current
                    )
                }

                guard try store.activePointer() == currentPointer else { continue }
                do {
                    let rebuiltPointer = try await rebuild(currentPointer)
                    guard try store.activePointer() == rebuiltPointer else { continue }
                    let rebuilt = try store.loadConfiguration(
                        profileID: rebuiltPointer.profileID,
                        revision: rebuiltPointer.revision
                    )
                    if validates(rebuilt) {
                        return StartupConfigurationPreparation(
                            configuration: rebuilt,
                            recovery: .regenerated
                        )
                    }
                    expectedPointer = rebuiltPointer
                } catch {
                     
                     
                }
            }

            if let lastKnownGood = try store.lastKnownGoodPointer(),
               lastKnownGood != expectedPointer {
                let fallback = try store.loadConfiguration(
                    profileID: lastKnownGood.profileID,
                    revision: lastKnownGood.revision
                )
                if validates(fallback) {
                    if try store.activateIfCurrentMatches(
                        expectedPointer,
                        replacement: lastKnownGood
                    ) {
                        return StartupConfigurationPreparation(
                            configuration: fallback,
                            recovery: .lastKnownGood
                        )
                    }
                    continue
                }
            }

            guard try store.activePointer() == expectedPointer else { continue }
            let safetyOutcome = preflight(Self.safetyYAML)
            guard safetyOutcome.ok else {
                throw ActiveRevisionMigrationError.builtInSafetyConfigurationInvalid(
                    safetyOutcome.errorMessage ?? "preflight failed"
                )
            }
            let installed = try store.install(
                Data(Self.safetyYAML.utf8),
                profileID: Self.safetyProfileID,
                activate: false
            )
            let safetyPointer = ActiveConfigurationPointer(
                profileID: installed.profileID,
                revision: installed.revision
            )
            if try store.activateIfCurrentMatches(
                expectedPointer,
                replacement: safetyPointer
            ) {
                let safety = try store.loadConfiguration(
                    profileID: safetyPointer.profileID,
                    revision: safetyPointer.revision
                )
                return StartupConfigurationPreparation(
                    configuration: safety,
                    recovery: .builtInSafety
                )
            }
        }
        throw ActiveRevisionMigrationError.configurationChangedRepeatedly
    }

    private func validates(_ configuration: StoredConfiguration) -> Bool {
        guard let yaml = configuration.text else { return false }
        return preflight(yaml).ok
    }
}
