import Foundation
import Hako

enum NetworkQualityRuntime: Int, CaseIterable, Identifiable {
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }
    var label: String { "\(rawValue)s" }
}

@MainActor
final class NetworkQualityModel: ObservableObject {
    @Published var configURL = HakoNetworkQualityDefaultConfigURL
    @Published var serial = false
    @Published var http3 = false
    @Published var maxRuntime: NetworkQualityRuntime = .thirty

    @Published private(set) var phase: Int32 = -1
    @Published private(set) var idleLatencyMs: Int32 = 0
    @Published private(set) var downloadCapacity: Int64 = 0
    @Published private(set) var uploadCapacity: Int64 = 0
    @Published private(set) var downloadRPM: Int32 = 0
    @Published private(set) var uploadRPM: Int32 = 0
    @Published private(set) var downloadCapacityAccuracy: Int32 = 0
    @Published private(set) var uploadCapacityAccuracy: Int32 = 0
    @Published private(set) var downloadRPMAccuracy: Int32 = 0
    @Published private(set) var uploadRPMAccuracy: Int32 = 0
    @Published private(set) var isRunning = false
    @Published private(set) var wasCancelled = false
    @Published private(set) var lastError = ""

    private var test: HakoNetworkQualityTest?
    private var handler: Handler?
    private var generation: UInt64 = 0

    let http3Available = HakoNetworkQualityHTTP3Available()

    var summary: String {
        if !lastError.isEmpty { return lastError }
        guard phase >= HakoNetworkQualityPhaseDownload else { return "—" }
        let down = downloadCapacity > 0 ? HakoFormatBitrate(downloadCapacity) : "—"
        let up = uploadCapacity > 0 ? HakoFormatBitrate(uploadCapacity) : "—"
        return "↓ \(down) · ↑ \(up)"
    }

    func start(maxRuntimeSeconds: Int32? = nil) {
        guard !isRunning, let newTest = HakoNewNetworkQualityTest() else { return }
        generation &+= 1
        let token = generation
        resetMetrics()
        isRunning = true
        let newHandler = Handler(owner: self, token: token)
        test = newTest
        handler = newHandler
        newTest.start(
            configURL,
            serial: serial,
            maxRuntimeSeconds: maxRuntimeSeconds ?? Int32(maxRuntime.rawValue),
            http3: http3,
            handler: newHandler
        )
    }

    func cancel() {
        guard isRunning else { return }
        generation &+= 1
        test?.cancel()
        test = nil
        handler = nil
        isRunning = false
        wasCancelled = true
    }

    private func resetMetrics() {
        phase = -1
        idleLatencyMs = 0
        downloadCapacity = 0
        uploadCapacity = 0
        downloadRPM = 0
        uploadRPM = 0
        downloadCapacityAccuracy = 0
        uploadCapacityAccuracy = 0
        downloadRPMAccuracy = 0
        uploadRPMAccuracy = 0
        lastError = ""
        wasCancelled = false
    }

    private func apply(_ progress: HakoNetworkQualityProgress, token: UInt64) {
        guard generation == token, isRunning else { return }
        phase = progress.phase
        idleLatencyMs = progress.idleLatencyMs
        downloadCapacity = progress.downloadCapacity
        uploadCapacity = progress.uploadCapacity
        downloadRPM = progress.downloadRPM
        uploadRPM = progress.uploadRPM
        downloadCapacityAccuracy = progress.downloadCapacityAccuracy
        uploadCapacityAccuracy = progress.uploadCapacityAccuracy
        downloadRPMAccuracy = progress.downloadRPMAccuracy
        uploadRPMAccuracy = progress.uploadRPMAccuracy
    }

    private func finish(_ result: HakoNetworkQualityResult, token: UInt64) {
        guard generation == token, isRunning else { return }
        phase = HakoNetworkQualityPhaseDone
        idleLatencyMs = result.idleLatencyMs
        downloadCapacity = result.downloadCapacity
        uploadCapacity = result.uploadCapacity
        downloadRPM = result.downloadRPM
        uploadRPM = result.uploadRPM
        downloadCapacityAccuracy = result.downloadCapacityAccuracy
        uploadCapacityAccuracy = result.uploadCapacityAccuracy
        downloadRPMAccuracy = result.downloadRPMAccuracy
        uploadRPMAccuracy = result.uploadRPMAccuracy
        test = nil
        handler = nil
        isRunning = false
    }

    private func fail(_ message: String, token: UInt64) {
        guard generation == token, isRunning else { return }
        lastError = message
        test = nil
        handler = nil
        isRunning = false
    }

    private final class Handler: NSObject, HakoNetworkQualityTestHandlerProtocol {
        weak var owner: NetworkQualityModel?
        let token: UInt64

        init(owner: NetworkQualityModel, token: UInt64) {
            self.owner = owner
            self.token = token
        }

        func onProgress(_ progress: HakoNetworkQualityProgress?) {
            guard let progress else { return }
            Task { @MainActor [weak owner, token] in owner?.apply(progress, token: token) }
        }

        func onResult(_ result: HakoNetworkQualityResult?) {
            guard let result else { return }
            Task { @MainActor [weak owner, token] in owner?.finish(result, token: token) }
        }

        func onError(_ message: String?) {
            Task { @MainActor [weak owner, token] in
                 
                 
                 
                owner?.fail(
                    UDPEgressDiagnosis.presentable(
                        message ?? "Network quality test failed"
                    ),
                    token: token
                )
            }
        }
    }
}
