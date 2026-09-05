import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVEditSubscriptionScreen: View {
    @Binding var store: HakoTVSubscriptionStore
    let id: HakoTVSubscription.ID
     
     
     
     
    var onDone: (HakoTVSubscription.ID?) -> Void = { _ in }

    @State private var nameText: String
    @State private var addressText: String
    @State private var refusal: String?

    init(
        store: Binding<HakoTVSubscriptionStore>,
        id: HakoTVSubscription.ID,
        onDone: @escaping (HakoTVSubscription.ID?) -> Void = { _ in }
    ) {
        _store = store
        self.id = id
        self.onDone = onDone
        _nameText = State(initialValue: Self.seedName(for: id, in: store.wrappedValue))
        _addressText = State(initialValue: Self.seedAddress(for: id, in: store.wrappedValue))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            form
            explanation
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Name")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            TextField("Name", text: $nameText, prompt: Text("Optional"))
                .textInputAutocapitalization(.words)
                .onSubmit(save)
                .accessibilityIdentifier("tvos.subscription.edit.name")
            Text("Address")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            TextField("Address", text: $addressText)
                .textInputAutocapitalization(.never)
                .onSubmit(save)
                .accessibilityIdentifier("tvos.subscription.edit.address")
            Text("Type on your phone instead — the keyboard is already waiting there.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let refusal {
                Text(hako: .verbatim(refusal))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tvos.subscription.edit.refusal")
            }
            Button("Save", action: save)
                .padding(.top, 8)
                .accessibilityIdentifier("tvos.subscription.edit.save")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What happens")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(Self.whatHappens(addressChanged: addressIsBeingChanged))
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

     
     
    private var addressIsBeingChanged: Bool {
        addressText.trimmingCharacters(in: .whitespacesAndNewlines)
            != Self.seedAddress(for: id, in: store)
    }

    private func save() {
        do {
            let addressChanged = try store.edit(id, name: nameText, urlString: addressText)
            refusal = nil
             
             
            let saved = URL(string: addressText.trimmingCharacters(in: .whitespacesAndNewlines))
            onDone(addressChanged ? saved : nil)
        } catch {
             
             
             
            refusal = error.localizedDescription
        }
    }

     

     
     
     
     
     
     
     
     
    static func refreshTarget(
        newAddress: HakoTVSubscription.ID?, in store: HakoTVSubscriptionStore
    ) -> HakoTVSubscription? {
        guard let newAddress, store.current?.id == newAddress else { return nil }
        return store.subscriptions.first { $0.id == newAddress }
    }

     
    static func seedName(for id: HakoTVSubscription.ID, in store: HakoTVSubscriptionStore) -> String {
        store.subscriptions.first { $0.id == id }?.name ?? ""
    }

     
     
    static func seedAddress(for id: HakoTVSubscription.ID, in store: HakoTVSubscriptionStore) -> String {
        store.subscriptions.first { $0.id == id }?.requestURL.absoluteString ?? ""
    }

     
     
     
    static func whatHappens(addressChanged: Bool) -> String {
        if addressChanged {
            String(localized: "The new address replaces the old one. What was downloaded from the old address is no longer used, and the new address is downloaded as soon as you save.")
        } else {
            String(localized: "The name is only what this Apple TV calls the address. The address itself, and what is downloaded from it, do not change.")
        }
    }
}
