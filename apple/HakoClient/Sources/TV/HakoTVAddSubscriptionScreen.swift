import HakoClientKit
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVAddSubscriptionScreen: View {
    @Binding var store: HakoTVSubscriptionStore
     
     
    var onAdded: () -> Void = {}

    @State private var urlText = ""
    @State private var nameText = ""
    @State private var refusal: String?

    static var whatHappens: String {
        String(localized: "The URL is what gets remembered. The configuration behind it is downloaded again whenever this Apple TV needs it.")
    }
    static var whatHappensDetail: String {
        String(localized: "tvOS guarantees 500 KB of storage and may discard the rest. A link survives that; a file does not.")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            form
            explanation
        }
         
         
         
         
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Profile URL")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            TextField("Profile URL", text: $urlText, prompt: Text("https://example.com/provider.yaml"))
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .onSubmit(add)
                .accessibilityIdentifier("tvos.subscription.url")
            Text("Type on your phone instead — the keyboard is already waiting there.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let refusal {
                 
                 
                Text(refusal.localizedForTelevision)
                    .font(.body)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("tvos.subscription.refusal")
            }
            Text("Name")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            TextField("Name", text: $nameText, prompt: Text("Optional"))
                .textInputAutocapitalization(.words)
                .onSubmit(add)
                .accessibilityIdentifier("tvos.subscription.name")
            Button("Add profile", action: add)
                .padding(.top, 8)
                .accessibilityIdentifier("tvos.subscription.add")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What happens")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(Self.whatHappens)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(Self.whatHappensDetail)
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func add() {
        if let refusal = Self.refusal(for: urlText) {
             
             
             
            self.refusal = refusal
            return
        }
        do {
            try store.add(urlString: urlText, name: nameText)
            refusal = nil
            onAdded()
        } catch {
            refusal = error.localizedDescription
        }
    }

     

     
    static func refusal(for urlText: String) -> String? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            return ProfileValidationError.invalidRemoteURL.errorDescription
        }
        do {
            _ = try Profile.RemoteSource(requestURL: url)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
