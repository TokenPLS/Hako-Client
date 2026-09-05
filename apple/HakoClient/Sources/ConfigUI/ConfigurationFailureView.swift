import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
 
struct ConfigurationFailureView: View {
    let failure: ConfigurationFailure
    let recover: (ConfigurationRecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.row) {
             
             
            HakoStatusMessage(text: .copy(failure.title), kind: .error)
            Text(hako: failure.displayMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
             
             
            ForEach(
                Array(failure.providerFailures.enumerated()),
                id: \.offset
            ) { _, item in
                Text(verbatim: ProfileSwitchFailureText.detailLine(item))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("configuration.failure.provider")
            }
            if failure.preservesLastKnownGood {
                Text("The last known good configuration remains published.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(actionButtons) { action in
                 
                 
                 
                 
                 
                 
                Button { recover(action) } label: { Text(hako: .copy(action.title)) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("configuration.failure.\(action.rawValue)")
            }
            if failure.recoveryActions.contains(.viewDiagnostics) {
                DisclosureGroup("Safe diagnostics") {
                    Text(failure.diagnosticCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("configuration.failure.diagnostic")
                    Button {
#if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            failure.diagnosticCode,
                            forType: .string
                        )
#else
                        UIPasteboard.general.string = failure.diagnosticCode
#endif
                    } label: {
                        Label(
                            "Copy Diagnostic Code",
                            systemImage: HakoSymbol.docOnDoc.name
                        )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("configuration.failure.copy-diagnostic")
                }
            }
        }
    }

    private var actionButtons: [ConfigurationRecoveryAction] {
        failure.recoveryActions.filter { $0 != .viewDiagnostics }
    }
}
