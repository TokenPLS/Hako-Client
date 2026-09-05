import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum ShareImportSymbol: String {
    case document = "doc.badge.plus"
}

private enum ShareImportError: LocalizedError {
    case missingYAML

    var errorDescription: String? {
        "The shared item does not contain a YAML configuration."
    }
}

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        preferredContentSize = CGSize(width: 0, height: 330)

        let content = ShareImportView(
            importAction: { [weak self] in try await self?.importConfiguration() },
            cancelAction: { [weak self] in self?.cancel() }
        )
        let hosting = UIHostingController(rootView: content)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    private func importConfiguration() async throws {
        let data = try await loadYAMLData()
        guard let inbox = ProfileShareInbox() else { throw ProfileShareInboxError.unavailable }
        try inbox.enqueue(data)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadYAMLData() async throws -> Data {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.yaml.identifier)
        }) else { throw ShareImportError.missingYAML }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.yaml.identifier) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw ShareImportError.missingYAML }
                    continuation.resume(returning: try Data(contentsOf: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}

private struct ShareImportView: View {
    let importAction: () async throws -> Void
    let cancelAction: () -> Void

    @State private var isWorking = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: ShareImportSymbol.document.rawValue)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Import Configuration")
                    .font(.title2.weight(.semibold))
                Text("Clash will copy this YAML into protected storage and validate it with Mihomo the next time the app opens.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Clash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancelAction)
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: startImport)
                        .disabled(isWorking)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func startImport() {
        isWorking = true
        errorMessage = ""
        Task { @MainActor in
            do {
                try await importAction()
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
