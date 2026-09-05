import Combine
import Foundation

enum ProfileInstallLinkError: LocalizedError, Equatable {
    case unsupportedLink
    case missingSubscription
    case unusableSubscription
    case unsupportedFile
    case fileTooLarge
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedLink:
            return "This configuration link is not supported."
        case .missingSubscription:
            return "The configuration link does not contain a subscription URL."
        case .unusableSubscription:
            return "The configuration link does not contain a usable subscription address."
        case .unsupportedFile:
            return "That file is not a configuration Clash can read."
        case .fileTooLarge:
            return "The configuration file exceeds the 16 MB import limit."
        case .unreadableFile:
            return "That file is not a text configuration. Choose a different one."
        }
    }
}

enum ProfileImportRequest: Equatable {
    case subscription(String)
    case configuration(fileName: String, yaml: String)
}

enum FlClashInstallLink {
     
     
     
     
     
     
     
     
     
     
    private static let schemes: Set<String> = ["clash", "clashmeta", "flclash"]

    static func subscriptionURL(from link: URL) throws -> String {
        guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              schemes.contains(scheme),
              components.host?.lowercased() == "install-config" else {
            throw ProfileInstallLinkError.unsupportedLink
        }
        guard let raw = components.queryItems?.first(where: { $0.name == "url" })?.value,
              !raw.isEmpty else {
            throw ProfileInstallLinkError.missingSubscription
        }
         
         
         
         
        guard let subscription = URLComponents(string: raw),
              subscription.scheme != nil,
              subscription.host != nil else {
            throw ProfileInstallLinkError.unusableSubscription
        }
        return raw
    }

     
     
     
     
     
     
    static func isLocalOrigin(_ raw: String) -> Bool {
        guard let host = URLComponents(string: raw)?.host?.lowercased() else { return false }
        if host == "localhost" || host == "::1" || host == "[::1]" || host == "0.0.0.0" { return true }
        return host.hasPrefix("127.")
    }
}

@MainActor
final class ProfileImportRouter: ObservableObject {
     
     
     
     
     
     
     
    @Published private(set) var pendingConfirmation: String?
    @Published private(set) var pendingImport: ProfileImportRequest?
    @Published private(set) var errorMessage = ""
    private var queue: [ProfileImportRequest] = []
    private let inbox: ProfileShareInbox?
    private let fetchLocalOrigin: (URL) async throws -> Data

    init(
        inbox: ProfileShareInbox? = ProfileShareInbox(),
        fetchLocalOrigin: @escaping (URL) async throws -> Data = { url in
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            return try await URLSession.shared.data(for: request).0
        }
    ) {
        self.inbox = inbox
        self.fetchLocalOrigin = fetchLocalOrigin
    }

    func open(_ link: URL) {
        errorMessage = ""
        HakoLogStore.shared.append(
            "install link arrived  pendingBefore=\(pendingConfirmation != nil)  link=\(link.absoluteString)",
            stream: .app, level: .warning)
        do {
            if link.isFileURL {
                 
                 
                try importFile(link)
            } else {
                pendingConfirmation =
                    try FlClashInstallLink.subscriptionURL(from: link)
            }
        } catch {
            errorMessage = importMessage(error)
        }
    }

    func acceptPendingConfirmation() {
        guard let url = pendingConfirmation else { return }
        HakoLogStore.shared.append("install link accepted  \(url)", stream: .app, level: .warning)
        pendingConfirmation = nil
        guard FlClashInstallLink.isLocalOrigin(url), let local = URL(string: url) else {
            publish(.subscription(url))
            return
        }
         
        let fileName = local.lastPathComponent.hasSuffix(".yaml")
            || local.lastPathComponent.hasSuffix(".yml")
            ? local.lastPathComponent
            : "\(local.host ?? "local")-import.yaml"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try await self.fetchLocalOrigin(local)
                try self.importData(data, fileName: fileName)
            } catch {
                self.errorMessage = self.importMessage(error)
            }
        }
    }

    func declinePendingConfirmation() {
        HakoLogStore.shared.append(
            "install link declined  hadPending=\(pendingConfirmation != nil)",
            stream: .app, level: .warning)
        pendingConfirmation = nil
    }

     
     
     
     
     
     
     
     
    nonisolated static func confirmationText(for url: URL) -> String {
        url.absoluteString
    }

    nonisolated static func confirmationText(for raw: String) -> String {
        raw
    }

     
     
     
    nonisolated static func confirmationIsLocalConfiguration(_ raw: String) -> Bool {
        FlClashInstallLink.isLocalOrigin(raw)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func take() -> ProfileImportRequest? {
        if isEmitting {
            guard !takenWhileEmitting, let current = emitting else { return nil }
            takenWhileEmitting = true
            return current
        }
        guard let current = pendingImport else { return nil }
         
         
         
         
         
         
        emit(nil)
        if !queue.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.advanceIfIdle() }
        }
        return current
    }

    private var isEmitting = false
    private var takenWhileEmitting = false
    private var emitting: ProfileImportRequest?

    private func advance() {
        emit(queue.isEmpty ? nil : queue.removeFirst())
    }

    private func advanceIfIdle() {
        guard pendingImport == nil, !isEmitting, !queue.isEmpty else { return }
        advance()
    }

     
     
    private func emit(_ next: ProfileImportRequest?) {
        isEmitting = true
        emitting = next
        pendingImport = next
        isEmitting = false
        emitting = nil
        if takenWhileEmitting {
            takenWhileEmitting = false
            advance()
        }
    }

    func importSharedFiles() {
        guard let inbox else { return }
        do {
            var failures: [String] = []
            for shared in try inbox.dequeueAll() {
                do {
                    try importData(shared.data, fileName: "Shared Configuration.yaml")
                } catch {
                     
                     
                    failures.append(importMessage(error))
                }
            }
            errorMessage = failures.joined(separator: "\n")
        } catch {
            errorMessage = importMessage(error)
        }
    }

    private func importFile(_ url: URL) throws {
         
         
         
         
         
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values?.fileSize, size > ProfileShareInbox.defaultMaximumBytes {
            throw ProfileInstallLinkError.fileTooLarge
        }
        try importData(Data(contentsOf: url), fileName: url.lastPathComponent)
    }

    private func importData(_ data: Data, fileName: String) throws {
        guard !data.isEmpty, data.count <= ProfileShareInbox.defaultMaximumBytes else {
            throw data.isEmpty
                ? ProfileInstallLinkError.unreadableFile
                : ProfileInstallLinkError.fileTooLarge
        }
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ProfileInstallLinkError.unreadableFile
        }
        try ConfigTransforms.validateSource(yaml)
        publish(.configuration(fileName: fileName, yaml: yaml))
    }

    private func publish(_ request: ProfileImportRequest) {
        if pendingImport == nil, !isEmitting {
            emit(request)
        } else {
            queue.append(request)
        }
        errorMessage = ""
    }

    private func importMessage(_ error: Error) -> String {
        if let install = error as? ProfileInstallLinkError {
            return install.localizedDescription
        }
        return ConfigurationFailureClassifier.classify(
            error,
            context: .localImport,
            preservesLastKnownGood: false
        )?.localizedDescription ?? "The configuration could not be imported."
    }
}
