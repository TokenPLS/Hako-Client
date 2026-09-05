import SwiftUI
import HakoClientUI

 
 
 
 
 
 
 
struct DNSTrimManageView: View {
     
     
     
    let policyKeys: [(String, Int64?)]
    let filterEntries: [(String, Int64?)]
    @State var droppedKeys: Set<String>
    @State var droppedEntries: Set<String>
    let onSave: (Set<String>, Set<String>) -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            if !policyKeys.isEmpty {
                Section {
                    ForEach(policyKeys, id: \.0) { key, bytes in
                        Toggle(isOn: binding(key, in: $droppedKeys)) {
                            row(key, bytes)
                        }
                        .accessibilityIdentifier("dns.trim.policy.\(key)")
                    }
                } header: {
                     
                    Text(hako: .verbatim("nameserver-policy"))
                        .textCase(nil)
                }
            }
            if !filterEntries.isEmpty {
                Section {
                    ForEach(filterEntries, id: \.0) { entry, bytes in
                        Toggle(isOn: binding(entry, in: $droppedEntries)) {
                            row(entry, bytes)
                        }
                        .accessibilityIdentifier("dns.trim.filter.\(entry)")
                    }
                } header: {
                    Text(hako: .verbatim("fake-ip-filter"))
                        .textCase(nil)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                onSave(droppedKeys, droppedEntries)
                dismiss()
            } label: {
                Text(hako: .copy("Save and Retry"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .hakoCapsuleButtonBorderShape()
            .controlSize(.large)
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            .padding(.horizontal, HakoTheme.Spacing.section)
            .padding(.bottom, HakoTheme.Spacing.compact)
            .accessibilityIdentifier("dns.trim.save")
        }
        .navigationTitle(
            HakoCopy.string(for: .copy("Manage DNS Routing"), locale: locale)
        )
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                HakoSheetCloseButton { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    droppedKeys = []
                    droppedEntries = []
                } label: {
                    Text(hako: .copy("Restore All"))
                        .font(.subheadline)
                }
                .disabled(droppedKeys.isEmpty && droppedEntries.isEmpty)
            }
        }
        .hakoCapturesDismiss(dismiss)
    }

    @ViewBuilder
    private func row(_ name: String, _ bytes: Int64?) -> some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Text(hako: .verbatim(name))
                .font(.subheadline.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if let bytes {
                Text(hako: .verbatim(
                    HakoStartupExplanation.megabytes(bytes)
                ))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }

    private func binding(
        _ name: String, in set: Binding<Set<String>>
    ) -> Binding<Bool> {
        Binding(
            get: { !set.wrappedValue.contains(name) },
            set: { keeps in
                if keeps { set.wrappedValue.remove(name) }
                else { set.wrappedValue.insert(name) }
            }
        )
    }
}

 
 
 
 
 
 
 
 
struct ProviderLoadDetailView: View {
    struct Row: Equatable, Identifiable {
        let name: String
         
        let bytes: Int64?
         
         
        var isEstimate: Bool = false
         
        var isSubscription: Bool = false
        var id: String { name }
    }

    let rows: [Row]
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.locale) private var locale

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        HStack {
            Text(hako: .verbatim(row.name))
                .font(.subheadline)
            Spacer(minLength: 0)
            if let bytes = row.bytes {
                Text(hako: .verbatim(
                    (row.isEstimate ? "≈ " : "")
                        + HakoStartupExplanation.megabytes(bytes)
                ))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        List {
            let subscriptions = rows.filter(\.isSubscription)
            let groups = rows.filter { !$0.isSubscription }
            if !subscriptions.isEmpty {
                Section {
                    ForEach(subscriptions) { row in rowView(row) }
                } header: {
                     
                    Text(hako: .verbatim("proxy-providers"))
                        .textCase(nil)
                }
            }
            if !groups.isEmpty {
                Section {
                    ForEach(groups) { row in rowView(row) }
                } header: {
                    Text(hako: .verbatim("proxy-groups"))
                        .textCase(nil)
                }
            }
            Section {
            } footer: {
                Text(hako: .copy("What each source cost to load this start. Temporary parse memory is returned by the system after startup."))
            }
        }
        .navigationTitle(
            HakoCopy.string(for: .copy("Provider Load"), locale: locale)
        )
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                HakoSheetCloseButton { dismiss() }
            }
        }
        .hakoCapturesDismiss(dismiss)
    }
}
