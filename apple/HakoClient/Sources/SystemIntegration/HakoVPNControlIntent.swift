import AppIntents
import NetworkExtension

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, *)
struct HakoVPNControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set Clash VPN"

     
     
    static var openAppWhenRun: Bool { false }

    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "VPN Connected")
    var value: Bool

    func perform() async throws -> some IntentResult {
         
         
         
        if await HakoVPNControlDriver.apply(connect: value) {
            return .result()
        }
         
         
         
         
        HakoSystemActionDispatch.enqueue(.vpn(value ? .connect : .disconnect))
        return .result()
    }
}

 
 
 
 
 
 
 
 
 
 
 
protocol HakoTunnelHandle: AnyObject {
    var isEnabled: Bool { get }
    var status: NEVPNStatus { get }
    func start() throws
    func stop()
     
     
     
     
     
    func enable() async throws
}

@available(iOS 16.0, *)
extension NETunnelProviderManager: HakoTunnelHandle {
    var status: NEVPNStatus { connection.status }
    func start() throws { try connection.startVPNTunnel() }
    func stop() { connection.stopVPNTunnel() }
    func enable() async throws {
        isEnabled = true
        try await saveToPreferences()
        try await loadFromPreferences()
    }
}

@available(iOS 16.0, *)
enum HakoVPNControlDriver {
     
     
    static var loadHandles: () async throws -> [any HakoTunnelHandle] = {
        try await NETunnelProviderManager.loadAllFromPreferences()
    }

     
     
     
     
     
    static var log: (String) -> Void = { line in
        HakoLogStore.shared.append("control: \(line)", stream: .app, level: .warning)
    }

     
     
     
     
     
     
    @discardableResult
    static func apply(connect: Bool) async -> Bool {
         
         
         
        let step = connect ? "start" : "stop"
        guard let handle = await installed(step) else { return false }
        guard connect else {
            handle.stop()
            log("\(step): asked")
            return true
        }
        if !handle.isEnabled {
             
             
            log("\(step): configuration disabled -- enabling")
            do {
                try await handle.enable()
                log("\(step): enabled")
            } catch {
                log("\(step): enabling refused  \(describe(error))")
                return false
            }
        }
        do {
            try handle.start()
            log("\(step): asked")
            return true
        } catch let error as NEVPNError where error.code == .configurationStale {
            log("\(step): \(describe(error)) -- loading again")
            let again = "\(step) again"
            guard let fresh = await installed(again) else { return false }
            do {
                try fresh.start()
                log("\(again): asked")
                return true
            } catch {
                log("\(again): \(describe(error))")
                return false
            }
        } catch {
            log("\(step): \(describe(error))")
            return false
        }
    }

     
     
    static func toggle() async -> Bool? {
        guard let active = await isActive() else { return nil }
        return await apply(connect: !active) ? !active : nil
    }

     
     
     
     
    static func currentStatus() async -> NEVPNStatus? {
        await installed("status", journal: false)?.status
    }

     
     
     
     
     
    static func isActive(journal: Bool = true) async -> Bool? {
        await state(journal: journal)?.active
    }

     
     
     
    static func state(journal: Bool = true) async -> (active: Bool, controllable: Bool)? {
        guard let handle = await installed("read", journal: journal) else { return nil }
        let active: Bool
        switch handle.status {
        case .connected, .connecting, .reasserting: active = true
        case .disconnected, .disconnecting, .invalid: active = false
        @unknown default: active = false
        }
        return (active, handle.isEnabled)
    }

     
     
     
     
    private static func installed(_ step: String, journal: Bool = true) async -> (any HakoTunnelHandle)? {
        let handles: [any HakoTunnelHandle]
        do {
            handles = try await loadHandles()
        } catch {
            log("\(step): load failed  \(describe(error))")
            return nil
        }
        let chosen = handles.first(where: { $0.isEnabled }) ?? handles.first
        if journal {
            var line = "\(step): managers=\(handles.count) enabled=\(handles.filter(\.isEnabled).count)"
            if let chosen { line += " status=\(word(chosen.status))" }
            log(line)
        }
        return chosen
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) [\(nsError.domain)#\(nsError.code)]"
    }

    private static func word(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}
