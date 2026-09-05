import Darwin
import Foundation
import Hako

enum ProxyShareProtocol: String, CaseIterable, Hashable {
    case http
    case socks5
}

struct ProxyShareStatus: Equatable {
    let enabled: Bool
    let port: Int32
    let protocols: [ProxyShareProtocol]
    let authenticationRequired: Bool

    static let disabled = ProxyShareStatus(
        enabled: false,
        port: 0,
        protocols: [],
        authenticationRequired: false
    )
}

struct ProxyShareConfiguration: Equatable {
    let port: Int32
    let username: String
    let password: String
}

enum ProxyShareError: Error, Equatable {
    case apiUnavailable
    case invalidResponse
    case invalidPort
    case missingUsername
    case malformedUsername
    case usernameTooLong
    case passwordTooShort
    case passwordTooLong
    case malformedPassword
    case portInUse
    case listenerConflict
    case timedOut
    case coreRejected
    case credentialStore
    case credentialRecovery
    case operationInProgress
}

enum ProxyShareCredentialPolicy {
    static let minimumPasswordBytes = Int(HakoProxyShareMinimumPasswordBytes)

    static var passwordByteRangeDescription: String {
        "\(minimumPasswordBytes)–\(HakoProxyShareMaximumCredentialBytes) bytes"
    }

     
     
     
     
     
    static var invalidPasswordDescription: String {
        "That password is too short."
    }
}

extension ProxyShareError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .apiUnavailable:
            return "Connect Clash before sharing the proxy on your local network."
        case .invalidResponse:
            return "Clash returned an invalid LAN proxy status. Sharing remains unavailable."
        case .invalidPort:
            return "Choose a port from 1024 through 65535."
        case .missingUsername:
            return "Enter a username for the shared proxy."
        case .malformedUsername:
            return "A username cannot begin or end with a space, contain a colon, or contain hidden characters."
        case .usernameTooLong:
            return "That username is too long. Choose a shorter one."
        case .passwordTooShort:
            return ProxyShareCredentialPolicy.invalidPasswordDescription
        case .passwordTooLong:
            return "That password is too long. Choose a shorter one."
        case .malformedPassword:
            return "A password cannot contain hidden characters."
        case .portInUse:
            return "That port is already in use. Choose another port and try again."
        case .listenerConflict:
            return "Another local listener conflicts with LAN proxy sharing."
        case .timedOut:
            return "Clash did not confirm the LAN proxy change in time."
        case .coreRejected:
            return "Clash could not apply the LAN proxy setting. Check the port and try again."
        case .credentialStore:
            return "The LAN proxy credentials could not be saved securely on this device."
        case .credentialRecovery:
            return "The previous LAN proxy credentials could not be restored securely. Reset them before trying again."
        case .operationInProgress:
            return "Wait for the current LAN proxy change to finish."
        }
    }
}

enum ProxyShareFailureClassifier {
    static func classify(_ error: Error) -> ProxyShareError {
        if let error = error as? ProxyShareError { return error }
        if error is CancellationError { return .timedOut }
        let description = error.localizedDescription.lowercased()
         
         
         
         
         
         
         
         
         
        if description.contains("address already in use") ||
            description.contains("bind: address in use") ||
            description.contains("proxy-share port") {
            return .portInUse
        }
        if description.contains("conflicts with an existing local listener") {
            return .listenerConflict
        }
        if description.contains("requires a running service") ||
            description.contains("not connected") ||
            description.contains("unavailable") {
            return .apiUnavailable
        }
        return .coreRejected
    }
}

enum ProxyShareStatusParser {
    private static let forbiddenKeys: Set<String> = [
        "auth", "authorization", "credential", "credentials", "password",
        "secret", "token", "username",
    ]

    static func parse(_ json: String) throws -> ProxyShareStatus {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data),
              let object = root as? [String: Any],
              !object.keys.contains(where: { forbiddenKeys.contains($0.lowercased()) }),
              let enabled = object["enabled"] as? Bool
        else {
            throw ProxyShareError.invalidResponse
        }
        guard enabled else { return .disabled }
        guard let portNumber = object["port"] as? NSNumber,
              CFGetTypeID(portNumber) != CFBooleanGetTypeID(),
              let authenticationRequired = object["authenticationRequired"] as? Bool,
              authenticationRequired,
              let rawProtocols = object["protocols"] as? [String]
        else {
            throw ProxyShareError.invalidResponse
        }
        let port = portNumber.intValue
        guard port >= Int(HakoProxyShareMinimumPort),
              port <= Int(HakoProxyShareMaximumPort),
              rawProtocols.count == ProxyShareProtocol.allCases.count
        else {
            throw ProxyShareError.invalidResponse
        }
        let protocols = rawProtocols.compactMap {
            ProxyShareProtocol(rawValue: $0.lowercased())
        }
        guard Set(protocols) == Set(ProxyShareProtocol.allCases),
              protocols.count == ProxyShareProtocol.allCases.count
        else {
            throw ProxyShareError.invalidResponse
        }
        return ProxyShareStatus(
            enabled: true,
            port: Int32(port),
            protocols: ProxyShareProtocol.allCases,
            authenticationRequired: true
        )
    }
}

enum ProxyShareValidator {
    static func validate(
        portText: String,
        username: String,
        password: String
    ) throws -> ProxyShareConfiguration {
        guard !portText.isEmpty,
              portText.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains),
              let port = Int32(portText),
              port >= HakoProxyShareMinimumPort,
              port <= HakoProxyShareMaximumPort
        else {
            throw ProxyShareError.invalidPort
        }
         
         
         
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername.isEmpty {
            throw ProxyShareError.missingUsername
        }
        if username != trimmedUsername
            || username.contains(":")
            || containsControlCharacter(username) {
            throw ProxyShareError.malformedUsername
        }
        if username.utf8.count > Int(HakoProxyShareMaximumCredentialBytes) {
            throw ProxyShareError.usernameTooLong
        }
        if containsControlCharacter(password) {
            throw ProxyShareError.malformedPassword
        }
        if password.utf8.count < ProxyShareCredentialPolicy.minimumPasswordBytes {
            throw ProxyShareError.passwordTooShort
        }
        if password.utf8.count > Int(HakoProxyShareMaximumCredentialBytes) {
            throw ProxyShareError.passwordTooLong
        }
        return ProxyShareConfiguration(
            port: port,
            username: username,
            password: password
        )
    }

    private static func containsControlCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
    }
}

enum LANAddressFamily: Int, Equatable {
    case ipv4 = 4
    case ipv6 = 6
}

struct LANInterfaceAddress: Equatable {
    let name: String
    let address: String
    let family: LANAddressFamily
    let isUp: Bool
}

enum LANAddressInventory {
    static func current() -> [String] {
        displayAddresses(from: systemRecords())
    }

    static func displayAddresses(from records: [LANInterfaceAddress]) -> [String] {
        let candidates = records.filter {
            $0.isUp && isPhysicalLANInterface($0.name) && isLocal($0)
        }.sorted { lhs, rhs in
            if lhs.family != rhs.family { return lhs.family.rawValue < rhs.family.rawValue }
            let lhsRank = interfaceRank(lhs.name)
            let rhsRank = interfaceRank(rhs.name)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.address < rhs.address
        }

        var seen = Set<String>()
        return candidates.compactMap { record in
            let display: String
            if record.family == .ipv6, isIPv6LinkLocal(record.address) {
                let unscoped = record.address
                    .split(separator: "%", maxSplits: 1)
                    .first
                    .map(String.init) ?? record.address
                display = "\(unscoped)%\(record.name)"
            } else {
                display = record.address
            }
            return seen.insert(display).inserted ? display : nil
        }
    }

    private static func systemRecords() -> [LANInterfaceAddress] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }
        var records: [LANInterfaceAddress] = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard let address = interface.ifa_addr else { continue }
            let family: LANAddressFamily
            switch Int32(address.pointee.sa_family) {
            case AF_INET: family = .ipv4
            case AF_INET6: family = .ipv6
            default: continue
            }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else { continue }
            records.append(LANInterfaceAddress(
                name: String(cString: interface.ifa_name),
                address: String(cString: host),
                family: family,
                isUp: (Int32(interface.ifa_flags) & IFF_UP) != 0
            ))
        }
        return records
    }

    private static func isPhysicalLANInterface(_ name: String) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("bridge")
    }

    private static func interfaceRank(_ name: String) -> Int {
        if name == "en0" { return 0 }
        if name.hasPrefix("en") { return 1 }
        return 2
    }

    private static func isLocal(_ record: LANInterfaceAddress) -> Bool {
        switch record.family {
        case .ipv4: return isIPv4PrivateOrLinkLocal(record.address)
        case .ipv6: return isIPv6ULA(record.address) || isIPv6LinkLocal(record.address)
        }
    }

    private static func isIPv4PrivateOrLinkLocal(_ address: String) -> Bool {
        var value = in_addr()
        guard inet_pton(AF_INET, address, &value) == 1 else { return false }
        let host = UInt32(bigEndian: value.s_addr)
        let first = UInt8((host >> 24) & 0xff)
        let second = UInt8((host >> 16) & 0xff)
        return first == 10 ||
            (first == 172 && (16...31).contains(second)) ||
            (first == 192 && second == 168) ||
            (first == 169 && second == 254)
    }

    private static func isIPv6ULA(_ address: String) -> Bool {
        guard let bytes = ipv6Bytes(address) else { return false }
        return bytes[0] & 0xfe == 0xfc
    }

    private static func isIPv6LinkLocal(_ address: String) -> Bool {
        guard let bytes = ipv6Bytes(address) else { return false }
        return bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
    }

    private static func ipv6Bytes(_ address: String) -> [UInt8]? {
        let rawAddress = address.split(separator: "%", maxSplits: 1).first.map(String.init) ?? address
        var value = in6_addr()
        guard inet_pton(AF_INET6, rawAddress, &value) == 1 else { return nil }
        return withUnsafeBytes(of: value) { Array($0) }
    }
}

struct ProxyShareCredentials: Equatable {
    let username: String
    let password: String
}

struct ProxyShareCredentialSnapshot {
    fileprivate let username: Data?
    fileprivate let password: Data?
}

final class ProxyShareCredentialVault {
    private static let usernameKey = "runtime.proxy-share.username"
    private static let passwordKey = "runtime.proxy-share.password"
    private let store: CredentialStore

    init(store: CredentialStore = CredentialStore()) {
        self.store = store
    }

    func load() -> ProxyShareCredentials? {
        guard let usernameData = store.get(Self.usernameKey),
              let passwordData = store.get(Self.passwordKey),
              let username = String(data: usernameData, encoding: .utf8),
              let password = String(data: passwordData, encoding: .utf8)
        else { return nil }
        return ProxyShareCredentials(username: username, password: password)
    }

    func snapshot() -> ProxyShareCredentialSnapshot {
        ProxyShareCredentialSnapshot(
            username: store.get(Self.usernameKey),
            password: store.get(Self.passwordKey)
        )
    }

    func replace(username: String, password: String) throws {
        let previous = snapshot()
        do {
            try store.set(Data(username.utf8), for: Self.usernameKey)
            try store.set(Data(password.utf8), for: Self.passwordKey)
        } catch {
            try? restore(previous)
            throw ProxyShareError.credentialStore
        }
    }

    func restore(_ snapshot: ProxyShareCredentialSnapshot) throws {
        do {
            try restore(snapshot.username, key: Self.usernameKey)
            try restore(snapshot.password, key: Self.passwordKey)
        } catch {
            throw ProxyShareError.credentialRecovery
        }
    }

    func remove() throws {
        let previous = snapshot()
        do {
            try store.remove(Self.usernameKey)
            try store.remove(Self.passwordKey)
        } catch {
            try? restore(previous)
            throw ProxyShareError.credentialStore
        }
    }

    private func restore(_ data: Data?, key: String) throws {
        if let data {
            try store.set(data, for: key)
        } else {
            try store.remove(key)
        }
    }
}

struct ProxySharePreferences {
    private static let portKey = "proxyShare.port"
    static let defaultPort: Int32 = 7890
    let defaults: UserDefaults

     
     
     
    init(defaults: UserDefaults = UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard) {
        self.defaults = defaults
    }

    func port() -> Int32 {
        let value = defaults.integer(forKey: Self.portKey)
        guard value >= Int(HakoProxyShareMinimumPort),
              value <= Int(HakoProxyShareMaximumPort)
        else { return Self.defaultPort }
        return Int32(value)
    }

    func save(port: Int32) {
        defaults.set(Int(port), forKey: Self.portKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.portKey)
    }
}

@MainActor
protocol ProxyShareCommanding: AnyObject {
     
     
     
    var proxyShareAPIReady: Bool { get }
     
     
     
     
     
     
     
     
    var proxyShareAPIClientReady: Bool { get }
    func fetchProxyShareStatus() async throws -> ProxyShareStatus
    func startProxyShare(_ configuration: ProxyShareConfiguration) async throws -> ProxyShareStatus
    func stopProxyShare() async throws -> ProxyShareStatus
}

enum ProxySharePhase: Equatable {
    case unavailable
    case loading
    case disabled
    case starting
    case running
    case stopping
    case failed

    var isBusy: Bool {
        switch self {
        case .loading, .starting, .stopping: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .unavailable: return "VPN Required"
        case .loading: return "Checking"
        case .disabled: return "Off"
        case .starting: return "Starting"
        case .running: return "Running"
        case .stopping: return "Stopping"
        case .failed: return "Needs Attention"
        }
    }
}

private final class ProxyShareTimeoutGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var completed = false

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func installTasks(operation: Task<Void, Never>, timeout: Task<Void, Never>) {
        lock.lock()
        if completed {
            lock.unlock()
            operation.cancel()
            timeout.cancel()
            return
        }
        operationTask = operation
        timeoutTask = timeout
        lock.unlock()
    }

    func resolve(_ result: Result<Value, Error>, fromTimeout: Bool = false) {
        lock.lock()
        guard !completed, let continuation else {
            lock.unlock()
            return
        }
        completed = true
        self.continuation = nil
        let operationTask = self.operationTask
        let timeoutTask = self.timeoutTask
        lock.unlock()
        if fromTimeout {
            operationTask?.cancel()
        } else {
            timeoutTask?.cancel()
        }
        continuation.resume(with: result)
    }
}

@MainActor
final class ProxyShareModel: ObservableObject {
    @Published private(set) var phase: ProxySharePhase = .unavailable
    @Published private(set) var status: ProxyShareStatus = .disabled
    @Published private(set) var errorMessage = ""
    @Published private(set) var savedUsername = ""
    @Published private(set) var hasSavedPassword = false
    @Published private(set) var rememberedPort: Int32
    @Published private(set) var localAddresses: [String] = []

    private weak var command: ProxyShareCommanding?
    private let vault: ProxyShareCredentialVault
    private let preferences: ProxySharePreferences
    private let addressProvider: () -> [String]
    private let timeoutNanoseconds: UInt64
    private var apiReady = false
    private var generation: UInt64 = 0

    init(
        vault: ProxyShareCredentialVault = ProxyShareCredentialVault(),
        preferences: ProxySharePreferences = ProxySharePreferences(),
        addressProvider: @escaping () -> [String] = LANAddressInventory.current,
        timeoutNanoseconds: UInt64 = 5_000_000_000
    ) {
        self.vault = vault
        self.preferences = preferences
        self.addressProvider = addressProvider
        self.timeoutNanoseconds = timeoutNanoseconds
        rememberedPort = preferences.port()
        refreshCredentialSummary()
        refreshAddresses()
    }

    func bind(command: ProxyShareCommanding) {
        self.command = command
        updateAPIAvailability(command.proxyShareAPIReady)
    }

    func updateAPIAvailability(_ ready: Bool) {
         
         
         
         
         
        let effectiveReady = ready && command?.proxyShareAPIClientReady == true
        guard effectiveReady != apiReady else { return }
        apiReady = effectiveReady
        generation &+= 1
        refreshAddresses()
        if effectiveReady {
            phase = .disabled
            errorMessage = ""
        } else {
            phase = .unavailable
            status = .disabled
            errorMessage = ""
        }
    }

    func refreshAddresses() {
        localAddresses = addressProvider()
    }

    func refresh() async {
        refreshAddresses()
        refreshCredentialSummary()
        guard apiReady, let command, command.proxyShareAPIReady else {
            phase = .unavailable
            status = .disabled
            return
        }
        guard !phase.isBusy else { return }
        generation &+= 1
        let token = generation
        phase = .loading
        errorMessage = ""
        do {
            let fetched = try await performWithTimeout {
                try await command.fetchProxyShareStatus()
            }
            guard token == generation, apiReady else { return }
            apply(status: fetched)
        } catch {
            guard token == generation, apiReady else { return }
            publish(error: error)
        }
    }

    @discardableResult
    func start(portText: String, username: String, password: String) async -> Bool {
        guard apiReady, let command, command.proxyShareAPIReady else {
            errorMessage = ProxyShareError.apiUnavailable.localizedDescription
            phase = .unavailable
            return false
        }
        guard !phase.isBusy else {
            errorMessage = ProxyShareError.operationInProgress.localizedDescription
            return false
        }
         
         
         
         
         
         
         
         
        let configuration: ProxyShareConfiguration
        do {
            configuration = try ProxyShareValidator.validate(
                portText: portText,
                username: username,
                password: password
            )
        } catch {
            publish(error: error)
            return false
        }

        let previousCredentials = vault.snapshot()
        do {
            try vault.replace(
                username: configuration.username,
                password: configuration.password
            )
        } catch {
            publish(error: error)
            return false
        }

        generation &+= 1
        let token = generation
        phase = .starting
        errorMessage = ""
        do {
            let started = try await performWithTimeout {
                try await command.startProxyShare(configuration)
            }
            guard started.enabled,
                  started.port == configuration.port,
                  started.authenticationRequired,
                  Set(started.protocols) == Set(ProxyShareProtocol.allCases)
            else { throw ProxyShareError.invalidResponse }
            guard token == generation, apiReady else { return false }
            preferences.save(port: configuration.port)
            refreshCredentialSummary()
            apply(status: started)
            return true
        } catch {
            let boundedError = ProxyShareFailureClassifier.classify(error)
            if boundedError == .timedOut {
                _ = try? await performWithTimeout {
                    try await command.stopProxyShare()
                }
            }
            do {
                try vault.restore(previousCredentials)
            } catch {
                guard token == generation, apiReady else { return false }
                publish(error: ProxyShareError.credentialRecovery)
                return false
            }
            refreshCredentialSummary()
            guard token == generation, apiReady else { return false }
            publish(error: boundedError)
            return false
        }
    }

    @discardableResult
    func stop() async -> Bool {
        guard apiReady, let command, command.proxyShareAPIReady else {
            errorMessage = ProxyShareError.apiUnavailable.localizedDescription
            phase = .unavailable
            status = .disabled
            return false
        }
        guard !phase.isBusy else {
            errorMessage = ProxyShareError.operationInProgress.localizedDescription
            return false
        }
        generation &+= 1
        let token = generation
        phase = .stopping
        errorMessage = ""
        do {
            let stopped = try await performWithTimeout {
                try await command.stopProxyShare()
            }
            guard !stopped.enabled else { throw ProxyShareError.invalidResponse }
            guard token == generation, apiReady else { return false }
            apply(status: .disabled)
            return true
        } catch {
            guard token == generation, apiReady else { return false }
            publish(error: error)
            return false
        }
    }

    @discardableResult
    func reset() async -> Bool {
        if status.enabled, apiReady, !(await stop()) { return false }
        do {
            try vault.remove()
            preferences.reset()
            rememberedPort = ProxySharePreferences.defaultPort
            refreshCredentialSummary()
            errorMessage = ""
            phase = apiReady ? .disabled : .unavailable
            status = .disabled
            return true
        } catch {
            publish(error: error)
            return false
        }
    }

    private func apply(status: ProxyShareStatus) {
        self.status = status
        if status.enabled {
            rememberedPort = status.port
            preferences.save(port: status.port)
        }
        phase = status.enabled ? .running : .disabled
        errorMessage = ""
    }

    private func refreshCredentialSummary() {
        let credentials = vault.load()
        savedUsername = credentials?.username ?? ""
        hasSavedPassword = credentials != nil
    }

    private func publish(error: Error) {
        let bounded = ProxyShareFailureClassifier.classify(error)
        errorMessage = bounded.localizedDescription
        phase = .failed
    }

    private func performWithTimeout<Value>(
        _ operation: @escaping @MainActor () async throws -> Value
    ) async throws -> Value {
        let gate = ProxyShareTimeoutGate<Value>()
        return try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)
            let operationTask = Task { @MainActor in
                do {
                    gate.resolve(.success(try await operation()))
                } catch {
                    gate.resolve(.failure(error))
                }
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    gate.resolve(.failure(ProxyShareError.timedOut), fromTimeout: true)
                } catch {
                     
                }
            }
            gate.installTasks(operation: operationTask, timeout: timeoutTask)
        }
    }
}


