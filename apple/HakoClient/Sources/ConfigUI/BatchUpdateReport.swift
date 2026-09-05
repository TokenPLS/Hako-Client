import HakoClientUI
import SwiftUI

enum BatchUpdateState: String, Equatable {
    case updated
    case unchanged
    case failed

    var title: String {
        switch self {
        case .updated: return "Updated"
        case .unchanged: return "Up to Date"
        case .failed: return "Failed"
        }
    }
}

struct BatchUpdateItem: Equatable, Identifiable {
    let id: String
    let label: String
    var state: BatchUpdateState
    var message: String?
    var failure: ConfigurationFailure?
}

struct BatchUpdateReport: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let expectedCount: Int
    var items: [BatchUpdateItem] = []
    var wasCancelled = false

    var updatedCount: Int { items.filter { $0.state == .updated }.count }
    var unchangedCount: Int { items.filter { $0.state == .unchanged }.count }
    var failedCount: Int { items.filter { $0.state == .failed }.count }
    var completedCount: Int { items.count }

     
     
     
     
     
     
     
    func summary(locale: Locale) -> String {
        var parts = [
            HakoCopy.format("%d updated", locale: locale, updatedCount),
            HakoCopy.format("%d unchanged", locale: locale, unchangedCount),
        ]
        if failedCount > 0 {
            parts.append(HakoCopy.format("%d failed", locale: locale, failedCount))
        }
        if wasCancelled {
            parts.append(HakoCopy.string("cancelled", locale: locale))
        }
        return parts.joined(separator: " · ")
    }

    mutating func record(_ item: BatchUpdateItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }
}

struct BatchUpdateReportView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    let report: BatchUpdateReport
    let isRunning: Bool
    let cancel: () -> Void
    let retry: (String) -> Void
    let dismiss: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HakoFeatureNavigationContainer {
            List {
                Section {
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                        Text(hako: .verbatim(report.summary(locale: locale)))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if isRunning {
                            ProgressView(value: Double(report.completedCount),
                                         total: Double(max(report.expectedCount, 1)))
                             
                             
                            Text("\(report.completedCount) of \(report.expectedCount) complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, HakoTheme.Spacing.tight)
                }

                Section("Results") {
                    if report.items.isEmpty, !isRunning {
                        Text("Nothing needed an update.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(report.items) { item in
                        HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
                            Image(systemName: symbol(for: item.state))
                                .foregroundStyle(tint(for: item.state))
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                Text(item.label)
                                    .font(.body.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(hako: item.failure?.displayMessage
                                    ?? item.message.map { .copy($0) }
                                    ?? .copy(item.state.title))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let failure = item.failure {
                                    Text(failure.diagnosticCode)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: HakoTheme.Spacing.compact)
                            if item.state == .failed, !isRunning {
                                Button("Try Again") { retry(item.id) }
                                    .buttonStyle(.borderless)
                                    .accessibilityIdentifier("batch.retry.\(item.id)")
                            }
                        }
                        .padding(.vertical, HakoTheme.Spacing.tight)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("batch.result.\(item.id)")
                    }
                }
            }
            .hakoInsetGroupedListStyle()
            .hakoPageTitle(.copy(report.title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isRunning {
                        Button("Cancel", role: .cancel, action: cancel)
                            .accessibilityIdentifier("batch.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        if !isRunning {
                            Button("Done", action: dismiss)
                                .accessibilityIdentifier("batch.done")
                        }
                    }
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .interactiveDismissDisabled(isRunning)
         
         
         
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(primaryTitle: "Done", onPrimary: dismiss)
            }
        }
    }

    private func symbol(for state: BatchUpdateState) -> String {
        switch state {
        case .updated: return "checkmark.circle.fill"
        case .unchanged: return "equal.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func tint(for state: BatchUpdateState) -> Color {
        switch state {
        case .updated: return .green
        case .unchanged: return .secondary
        case .failed: return .red
        }
    }
}
