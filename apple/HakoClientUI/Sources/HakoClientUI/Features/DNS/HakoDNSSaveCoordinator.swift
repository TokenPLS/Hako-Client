import Foundation

 
 
 
@MainActor
final class HakoDNSSaveCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case awaitingWarning
        case committing
    }

    enum Outcome {
        case saved(HakoDNSOverrideDraft)
        case failed(String)
        case cancelled
    }

    typealias Preflight = @MainActor (
        HakoDNSOverrideDraft
    ) async -> String?
    typealias Commit = @MainActor (
        HakoDNSOverrideDraft
    ) async throws -> Void

    @Published private(set) var phase = Phase.idle
    @Published private(set) var warning: String?

    private var task: Task<Void, Never>?
    private var candidate: HakoDNSOverrideDraft?
    private var commit: Commit?
    private var completion: ((Outcome) -> Void)?

    var isBusy: Bool {
        phase == .checking || phase == .committing
    }

    @discardableResult
    func save(
        draft: HakoDNSOverrideDraft,
        preflight: @escaping Preflight,
        commit: @escaping Commit,
        completion: @escaping (Outcome) -> Void
    ) -> Bool {
        guard phase == .idle else { return false }
        phase = .checking
        candidate = draft
        self.commit = commit
        self.completion = completion
        task = Task { [weak self] in
            guard let self else { return }
            let warning = await preflight(draft)
            guard !Task.isCancelled, phase == .checking else { return }
            if let warning {
                self.warning = warning
                phase = .awaitingWarning
            } else {
                await commitCandidate()
            }
        }
        return true
    }

    func saveAnyway() {
        guard phase == .awaitingWarning else { return }
        warning = nil
        task = Task { [weak self] in
            await self?.commitCandidate()
        }
    }

    func keepEditing() {
        guard phase == .awaitingWarning else { return }
        finish(.cancelled)
    }

     
     
    func cancel() {
        guard phase == .checking || phase == .awaitingWarning else { return }
        task?.cancel()
        finish(.cancelled)
    }

    private func commitCandidate() async {
        guard let candidate, let commit else {
            finish(.failed("The DNS save transaction was incomplete."))
            return
        }
        phase = .committing
        do {
            try await commit(candidate)
            finish(.saved(candidate))
        } catch {
            finish(.failed(error.localizedDescription))
        }
    }

    private func finish(_ outcome: Outcome) {
        let completion = completion
        task = nil
        candidate = nil
        commit = nil
        self.completion = nil
        warning = nil
        phase = .idle
        completion?(outcome)
    }
}
