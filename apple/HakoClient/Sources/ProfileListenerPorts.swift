import Foundation
import CoreFoundation

 
 
 
 
 
 
struct ProfileListenerPorts: Equatable, Sendable {
    struct Credentials: Equatable, Sendable {
        let username: String
        let password: String
    }

    let mixedPort: Int32?
    let httpPort: Int32?
    let socksPort: Int32?
    let allowLAN: Bool
     
    let credentials: Credentials?

    static func parse(yaml: String) -> ProfileListenerPorts? {
         
         
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: yaml) else { return nil }
         
         
        return parsed.memo("profile-listener-ports") {
            ParsedListener(value: decode(root: parsed.root))
        }.value
    }

    private struct ParsedListener { let value: ProfileListenerPorts? }

    private static func decode(root: [String: Any]) -> ProfileListenerPorts? {
        func port(_ key: String) -> Int32? {
            let text: String
            if let value = root[key] as? String {
                text = value
            } else if let value = root[key] as? NSNumber,
                      CFGetTypeID(value) != CFBooleanGetTypeID() {
                text = value.stringValue
            } else { return nil }
            guard let value = Int32(text), (1...65535).contains(value) else { return nil }
            return value
        }
        let mixed = port("mixed-port")
        let http = port("port")
        let socks = port("socks-port")
        guard mixed != nil || http != nil || socks != nil else { return nil }
        let allowLAN: Bool
        if let value = root["allow-lan"] as? String {
            allowLAN = ["true", "yes", "on"].contains(value.lowercased())
        } else if let value = root["allow-lan"] as? NSNumber,
                  CFGetTypeID(value) == CFBooleanGetTypeID() {
            allowLAN = value.boolValue
        } else { allowLAN = false }
        var credentials: Credentials?
        if let entry = (root["authentication"] as? [Any])?.first as? String,
           let separator = entry.firstIndex(of: ":") {
            credentials = Credentials(
                username: String(entry[..<separator]),
                password: String(entry[entry.index(after: separator)...])
            )
        }
        return ProfileListenerPorts(
            mixedPort: mixed, httpPort: http, socksPort: socks,
            allowLAN: allowLAN, credentials: credentials
        )
    }
}

 
 
 
 
struct ProxyTerminalListener: Equatable {
    enum Source: Equatable {
        case share
        case profile
    }

    let source: Source
    let httpPort: Int32?
    let socksPort: Int32?
    let username: String
     
     
    let password: String
    let lanReachable: Bool
}


extension ProxyTerminalListener {
     
     
     
    func host(forExternalMachine external: Bool, addresses: [String]) -> String? {
        external ? (lanReachable ? addresses.first : nil) : "127.0.0.1"
    }
}

 
 
 
 
 
@MainActor
final class PreparedProfileListener {
    enum State: Equatable {
        case preparing
        case ready(ProfileListenerPorts?)
    }

    private var hasInput = false
    private var input: String?
    private var state: State = .ready(nil)
    private var generation: UInt64 = 0
    private(set) var task: Task<Void, Never>?
    private let parse: @Sendable (String) -> ProfileListenerPorts?
    private let didChange: @MainActor () -> Void

    init(
        parse: @escaping @Sendable (String) -> ProfileListenerPorts? = { ProfileListenerPorts.parse(yaml: $0) },
        didChange: @escaping @MainActor () -> Void
    ) {
        self.parse = parse
        self.didChange = didChange
    }

    deinit { task?.cancel() }

    func read(yaml: String?) -> State {
        guard !hasInput || input != yaml else { return state }
        hasInput = true
        input = yaml
        generation &+= 1
        task?.cancel()
        task = nil
        guard let yaml else {
            state = .ready(nil)
            return state
        }
        state = .preparing
        let expectedGeneration = generation
        let parse = parse
        task = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { parse(yaml) }.value
            guard !Task.isCancelled, let self,
                  self.generation == expectedGeneration else { return }
            self.state = .ready(result)
            self.task = nil
            self.didChange()
        }
        return state
    }
}
