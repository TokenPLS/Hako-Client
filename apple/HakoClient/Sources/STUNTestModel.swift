import Foundation
import Hako

struct STUNOutboundOption: Identifiable, Equatable {
    let name: String
    let title: String

    var id: String { name }
}

@MainActor
final class STUNTestModel: ObservableObject {
    @Published var server = HakoSTUNDefaultServer
    @Published var selectedOutbound = ""
    @Published private(set) var outboundOptions = [
        STUNOutboundOption(name: "", title: "Follow Rules")
    ]
    @Published private(set) var phase: Int32 = -1
    @Published private(set) var externalAddress = ""
    @Published private(set) var externalAddressFamily: Int32 = HakoSTUNAddressFamilyUnknown
    @Published private(set) var latencyMilliseconds: Int32 = 0
    @Published private(set) var natMapping: Int32 = HakoNATMappingUnknown
    @Published private(set) var natFiltering: Int32 = HakoNATFilteringUnknown
    @Published private(set) var natTypeSupported = false
    @Published private(set) var isRunning = false
    @Published private(set) var lastError = ""

    private weak var command: ClashCommandClient?
    private var session: HakoSTUNTestSession?
    private var handler: Handler?
    private var startTask: Task<Void, Never>?
    private var generation: UInt64 = 0

     
     
     
     
     
     
     
     
     
    var summary: String {
        if isRunning { return "Testing…" }
        if !lastError.isEmpty { return lastError }
        guard !externalAddress.isEmpty else { return "" }
        if natTypeSupported, natMapping != HakoNATMappingUnknown {
            return "\(HakoFormatNATMapping(natMapping)) · \(HakoFormatSTUNAddressFamily(externalAddressFamily))"
        }
        return HakoFormatSTUNAddressFamily(externalAddressFamily)
    }

    func bind(command: ClashCommandClient) {
        self.command = command
    }

    func refreshOutbounds() async {
        guard let command else { return }
        if command.proxiesData == nil, command.isConnected {
            await command.refreshMetadata()
        }
        outboundOptions = Self.outboundOptions(from: command.proxiesData)
        if !outboundOptions.contains(where: { $0.name == selectedOutbound }) {
            selectedOutbound = ""
        }
    }

    func start() {
        guard !isRunning, let command, command.isConnected else {
            lastError = "Connect Clash before running a STUN test."
            return
        }
        resetResult()
        isRunning = true
        generation &+= 1
        let token = generation
        let callback = Handler(owner: self, token: token)
        handler = callback
        let requestedServer = server
        let requestedOutbound = selectedOutbound
        startTask = Task { [weak self] in
            do {
                let newSession = try await command.startSTUNTest(
                    server: requestedServer,
                    outbound: requestedOutbound,
                    handler: callback
                )
                guard let self, self.generation == token, self.isRunning else {
                    await Self.close(newSession)
                    return
                }
                self.session = newSession
                self.startTask = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.generation == token else { return }
                 
                 
                 
                self.fail(
                    UDPEgressDiagnosis.presentable(
                        error.localizedDescription,
                        outbound: requestedOutbound
                    ),
                    token: token
                )
            }
        }
    }

    func cancel() {
        generation &+= 1
        isRunning = false
        startTask?.cancel()
        startTask = nil
        handler = nil
        let oldSession = session
        session = nil
        if let oldSession {
            Task { await Self.close(oldSession) }
        }
    }

    static func outboundOptions(from data: Data?) -> [STUNOutboundOption] {
        var options = [STUNOutboundOption(name: "", title: "Follow Rules")]
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let proxies = root["proxies"] as? [String: Any]
        else { return options }
         
         
        let excluded = BuiltinProxyName.all.subtracting([BuiltinProxyName.direct])
        let names = proxies.compactMap { name, raw -> String? in
            guard !excluded.contains(name),
                  let proxy = raw as? [String: Any],
                  (proxy["udp"] as? Bool) != false
            else { return nil }
            return name
        }
        for name in names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            options.append(STUNOutboundOption(name: name, title: name))
        }
        return options
    }

    private func resetResult() {
        phase = -1
        externalAddress = ""
        externalAddressFamily = HakoSTUNAddressFamilyUnknown
        latencyMilliseconds = 0
        natMapping = HakoNATMappingUnknown
        natFiltering = HakoNATFilteringUnknown
        natTypeSupported = false
        lastError = ""
    }

    private func apply(_ progress: HakoSTUNTestProgress, token: UInt64) {
        guard generation == token, isRunning else { return }
        phase = progress.phase
        if !progress.externalAddr.isEmpty { externalAddress = progress.externalAddr }
        if progress.externalAddressFamily != HakoSTUNAddressFamilyUnknown {
            externalAddressFamily = progress.externalAddressFamily
        }
        if progress.latencyMs >= 0 { latencyMilliseconds = progress.latencyMs }
        natMapping = progress.natMapping
        natFiltering = progress.natFiltering
    }

    private func finish(_ result: HakoSTUNTestResult, token: UInt64) {
        guard generation == token, isRunning else { return }
        phase = HakoSTUNPhaseDone
        externalAddress = result.externalAddr
        externalAddressFamily = result.externalAddressFamily
        latencyMilliseconds = result.latencyMs
        natMapping = result.natMapping
        natFiltering = result.natFiltering
        natTypeSupported = result.natTypeSupported
        isRunning = false
        session = nil
        handler = nil
        startTask = nil
    }

    private func fail(_ message: String, token: UInt64) {
        guard generation == token else { return }
        lastError = message
        isRunning = false
        session = nil
        handler = nil
        startTask = nil
    }

    private nonisolated static func close(_ session: HakoSTUNTestSession) async {
        await Task.detached {
            try? session.close()
        }.value
    }

    private final class Handler: NSObject, HakoSTUNTestHandlerProtocol {
        weak var owner: STUNTestModel?
        let token: UInt64

        init(owner: STUNTestModel, token: UInt64) {
            self.owner = owner
            self.token = token
        }

        func onProgress(_ progress: HakoSTUNTestProgress?) {
            guard let progress else { return }
            Task { @MainActor [weak owner] in owner?.apply(progress, token: token) }
        }

        func onResult(_ result: HakoSTUNTestResult?) {
            guard let result else { return }
            Task { @MainActor [weak owner] in owner?.finish(result, token: token) }
        }

        func onError(_ message: String?) {
            Task { @MainActor [weak owner] in
                owner?.fail(message ?? "STUN test failed.", token: token)
            }
        }
    }
}


