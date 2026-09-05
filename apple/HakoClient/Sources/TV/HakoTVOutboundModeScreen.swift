import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVOutboundModeScreen: View {
    @Binding var state: HakoTVProductState
     
     
     
    var onSelect: ((HakoTVOutboundMode) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Outbound mode")
                .font(.largeTitle)
            Spacer(minLength: 0)
            cards
            Text(Self.footer(mode: state.outboundMode, isConnected: state.isConnected))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: 40) {
            ForEach(HakoTVOutboundMode.allCases, id: \.self) { mode in
                card(for: mode)
            }
        }
         
         
         
        .fixedSize(horizontal: false, vertical: true)
    }

    private func card(for mode: HakoTVOutboundMode) -> some View {
        Button {
            if let onSelect {
                onSelect(mode)
            } else {
                Self.select(mode, in: &state)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(mode.title)
                        .font(.title2)
                    if state.outboundMode == mode {
                         
                         
                         
                        Image(systemName: HakoSymbol.checkmark.rawValue)
                            .font(.title3)
                            .accessibilityLabel("In force")
                    }
                }
                Text(mode.kernelToken)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                Text(mode.explanation)
                    .font(.body)
                    .foregroundStyle(.secondary)
                     
                     
                     
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("tvos.outbound.\(mode.rawValue)")
        .accessibilityAddTraits(state.outboundMode == mode ? .isSelected : [])
    }

     

     
     
    static func select(_ mode: HakoTVOutboundMode, in state: inout HakoTVProductState) {
        state.outboundMode = mode
    }

     
     
     
     
    static func footer(mode: HakoTVOutboundMode, isConnected: Bool) -> String {
        if isConnected {
            return String(localized: "Currently in force: \(mode.title) · changing this takes effect immediately, without reconnecting")
        }
        return String(localized: "\(mode.title) · applies when the tunnel connects")
    }
}
