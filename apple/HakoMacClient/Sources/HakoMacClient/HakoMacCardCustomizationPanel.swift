import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoMacCardCustomizationPanel: View {
     
    let favorites: [HakoHomeCard]
     
     
    let commit: ([HakoHomeCard]) -> Void

    @State private var cards: [HakoHomeCard]
    @Environment(\.dismiss) private var dismiss
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss) private var modalDismiss

    private func close() {
        if let modalDismiss {
            modalDismiss()
        } else {
            dismiss()
        }
    }

    init(
        favorites: [HakoHomeCard],
        commit: @escaping ([HakoHomeCard]) -> Void
    ) {
        self.favorites = favorites
        self.commit = commit
        _cards = State(initialValue: HakoHomeCatalog.normalized(favorites))
    }

    private var available: [HakoHomeCard] {
        HakoHomeCatalog.optionalCards.filter { !cards.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            list
            footer
        }
         
         
        .frame(width: 460, height: 520)
        .accessibilityIdentifier("home.cards.customization")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hako: .copy("Customize Cards"))
                .font(.headline)
            Text(hako: .copy(
                "Outbound Mode, Proxies, and Rules always stay on Home."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var list: some View {
        Form {
            Section {
                ForEach(cards, id: \.self) { card in
                    row(card) {
                         
                         
                         
                         
                         
                        rowButton(.chevronUp) { move(card, by: -1) }
                            .disabled(cards.first == card)
                            .accessibilityIdentifier(
                                "home.cards.moveUp.\(card.rawValue)"
                            )
                        rowButton(.chevronDown) { move(card, by: 1) }
                            .disabled(cards.last == card)
                            .accessibilityIdentifier(
                                "home.cards.moveDown.\(card.rawValue)"
                            )
                        if !HakoHomeCatalog.requiredCards.contains(card) {
                            rowButton(.minusCircle) {
                                cards.removeAll { $0 == card }
                            }
                            .accessibilityIdentifier(
                                "home.cards.remove.\(card.rawValue)"
                            )
                        }
                    }
                    .accessibilityIdentifier(
                        "home.cards.favorite.\(card.rawValue)"
                    )
                }
            } header: {
                Text(hako: .copy("On Home"))
            }

            if !available.isEmpty {
                Section {
                    ForEach(available, id: \.self) { card in
                        row(card) {
                            rowButton(.plusCircle) { cards.append(card) }
                                .accessibilityIdentifier(
                                    "home.cards.available.\(card.rawValue)"
                                )
                        }
                    }
                } header: {
                    Text(hako: .copy("Available"))
                }
            }
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .formStyle(.grouped)
    }

    private func row(
        _ card: HakoHomeCard,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 8) {
            HakoSymbolImage(symbol: card.symbol)
                .foregroundStyle(.tint)
                .frame(width: 18)
            Text(hako: .copy(card.title))
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 2)
    }

     
     
     
     
    private func move(_ card: HakoHomeCard, by offset: Int) {
        guard let from = cards.firstIndex(of: card) else { return }
        let to = from + offset
        guard cards.indices.contains(to) else { return }
        cards.swapAt(from, to)
    }

    private func rowButton(
        _ symbol: HakoSymbol,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HakoSymbolImage(symbol: symbol)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
    }

    private var footer: some View {
        HStack {
            Button(HakoCopy.key("Reset")) {
                cards = HakoHomeCatalog.defaultCards
            }
            Spacer()
            Button(HakoCopy.key("Cancel")) {
                close()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("home.cards.customization.cancel")
            Button(HakoCopy.key("Done")) {
                commit(HakoHomeCatalog.normalized(cards))
                close()
            }
            .buttonStyle(.borderedProminent)
             
             
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }
}
