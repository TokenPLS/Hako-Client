import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVSubscriptionsScreen: View {
    @Binding var store: HakoTVSubscriptionStore
     
    var onOpen: (HakoTVSubscription.ID) -> Void = { _ in }
     
    var onAdd: () -> Void = {}

    private enum Explained: Hashable {
        case subscription(HakoTVSubscription.ID)
        case add
    }

    @State private var explained: Explained = .add

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            list
            explanation
        }
        .task {
             
             
             
            if let current = store.current {
                explained = .subscription(current.id)
            }
        }
    }

    private var list: some View {
        List {
            Section("Profiles") {
                if store.subscriptions.isEmpty {
                     
                     
                    Text("No profiles on this Apple TV")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.subscriptions) { subscription in
                    row(subscription)
                }
            }
            Section {
                Button(action: onAdd) {
                    LabeledContent("Add a profile", value: "")
                }
                .onHakoTVFocus { explained = .add }
                .accessibilityIdentifier("tvos.subscriptions.add")
            }
        }
        .listStyle(.grouped)
        .safeAreaPadding(.horizontal, 44)
        .frame(maxWidth: .infinity)
    }

    private func row(_ subscription: HakoTVSubscription) -> some View {
        let isCurrent = subscription.id == store.current?.id
        return Button {
            onOpen(subscription.id)
        } label: {
            LabeledContent {
                if isCurrent {
                    Image(systemName: HakoSymbol.checkmark.rawValue)
                        .accessibilityLabel("In use")
                }
            } label: {
                Text(subscription.title)
                if let host = Self.subtitle(for: subscription) {
                    Text(host)
                }
            }
        }
        .onHakoTVFocus { explained = .subscription(subscription.id) }
        .accessibilityIdentifier("tvos.subscriptions.\(subscription.title)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

     
     
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(explainedLabel)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(explainedDetail)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.18), value: explained)
    }

    private var explainedLabel: String {
        switch explained {
        case .subscription: String(localized: "Profile")
        case .add: String(localized: "Add a profile")
        }
    }

    private var explainedDetail: String {
        switch explained {
        case .subscription(let id):
            Self.explanation(isCurrent: id == store.current?.id)
        case .add:
            Self.addExplanation
        }
    }

     

     
     
    static func subtitle(for subscription: HakoTVSubscription) -> String? {
        let name = subscription.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return subscription.displayURL.host
    }

     
     
    static func explanation(isCurrent: Bool) -> String {
        isCurrent
            ? String(localized: "The profile in use. Press to see its address or remove it.")
            : String(localized: "Remembered but not in use. Press to use it instead, or to remove it.")
    }

     
    static var addExplanation: String {
        String(localized: "Type a profile address, here or on your iPhone. The address is what this Apple TV remembers; what it points at is fetched again whenever it is needed.")
    }
}
