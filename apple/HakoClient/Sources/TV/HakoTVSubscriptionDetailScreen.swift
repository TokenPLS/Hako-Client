import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVSubscriptionDetailScreen: View {
     
     
     
     
    enum Verb: Hashable, CaseIterable {
        case update
        case edit
        case use
        case remove

        var title: String {
            switch self {
            case .update: String(localized: "Update now")
            case .edit: String(localized: "Edit")
            case .use: String(localized: "Use this profile")
            case .remove: String(localized: "Remove")
            }
        }

        var identifier: String {
            switch self {
            case .update: "update"
            case .edit: "edit"
            case .use: "use"
            case .remove: "remove"
            }
        }
    }

    @Binding var store: HakoTVSubscriptionStore
    let id: HakoTVSubscription.ID
     
     
    var refresh: HakoTVProductState.Refresh?
     
    var onDone: () -> Void = {}
     
     
     
    var onUpdate: (() -> Void)?
     
    var onEdit: () -> Void = {}

    @State private var asksToRemove = false

    private var subscription: HakoTVSubscription? {
        store.subscriptions.first { $0.id == id }
    }

    private var isCurrent: Bool { store.current?.id == id }

    private var isUpdating: Bool {
        if case .updating(let which, _) = refresh, which == id { return true }
        return false
    }

    private var updateFailure: String? {
        if case .failed(let which, let reason) = refresh, which == id { return reason }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            actions
            explanation
        }
        .alert(Self.removeQuestion, isPresented: $asksToRemove) {
            Button(Verb.remove.title, role: .destructive) {
                store.remove(id)
                onDone()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.removeMessage(title: subscription?.title ?? ""))
        }
         
    }

    private var actions: some View {
        List {
            Section {
                ForEach(Self.verbs(isCurrent: isCurrent), id: \.self) { verb in
                    Button(role: verb == .remove ? .destructive : nil) {
                        perform(verb)
                    } label: {
                        if verb == .update {
                            HStack(spacing: 16) {
                                if isUpdating { ProgressView() }
                                Text(Self.updateRowTitle(updating: isUpdating))
                            }
                        } else {
                            Text(verb.title)
                        }
                    }
                    .disabled(verb == .update && isUpdating)
                    .accessibilityIdentifier("tvos.subscription.\(verb.identifier)")
                }
            }
        }
        .listStyle(.grouped)
        .safeAreaPadding(.horizontal, 44)
        .frame(maxWidth: .infinity)
    }

    private func perform(_ verb: Verb) {
        switch verb {
        case .update:
            if let onUpdate {
                onUpdate()
            } else {
                store.markUpdated(id, at: Date())
            }
        case .edit:
            onEdit()
        case .use:
            store.use(id)
            onDone()
        case .remove:
            asksToRemove = true
        }
    }

     
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            if let subscription {
                Text(subscription.title)
                    .font(.title2)
                 
                 
                Text(subscription.displayURL.absoluteString)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                Text(Self.status(isCurrent: isCurrent))
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(HakoTVSubscriptionUpdatedWords.text(updatedAt: subscription.updatedAt))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tvos.subscription.updated")
                if let updateFailure {
                     
                     
                     
                    Text(Self.updateFailure(updateFailure))
                        .font(.body)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("tvos.subscription.updateFailure")
                }
            } else {
                Text("This profile is no longer on this Apple TV.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

     

     
     
     
    static func verbs(isCurrent: Bool) -> [Verb] {
        isCurrent ? [.update, .edit, .remove] : [.edit, .use, .remove]
    }

    static func updateRowTitle(updating: Bool) -> String {
        updating ? String(localized: "Updating…") : Verb.update.title
    }

     
    static func updateFailure(_ reason: String) -> String {
        String(localized: "Could not update: \(reason)")
    }

    static var removeQuestion: String { String(localized: "Remove this profile?") }

     
     
     
    static func removeMessage(title: String) -> String {
        String(localized: "Remove “\(title)”? This Apple TV forgets the address. To bring it back, type it again.")
    }

     
    static func status(isCurrent: Bool) -> String {
        isCurrent
            ? String(localized: "In use. The tunnel fetches its configuration from this address.")
            : String(localized: "Not in use. The address stays remembered.")
    }
}
