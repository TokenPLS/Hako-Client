import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVUserAgentScreen: View {
    @State private var selected: ClientUserAgent.Preset
    @State private var focused: ClientUserAgent.Preset?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = ClientUserAgent.appGroupDefaults) {
        self.defaults = defaults
        _selected = State(initialValue: ClientUserAgent.preset(from: defaults))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            List {
                Section("User-Agent") {
                    ForEach(ClientUserAgent.Preset.allCases) { preset in
                        Button {
                            ClientUserAgent.save(preset: preset, in: defaults)
                            selected = preset
                        } label: {
                            HStack {
                                Text(preset.label)
                                Spacer()
                                if preset == selected {
                                    Image(systemName: HakoSymbol.checkmark.rawValue)
                                }
                            }
                        }
                        .onHakoTVFocus { focused = preset }
                        .accessibilityIdentifier("tvos.userAgent.\(preset.rawValue)")
                    }
                }
            }
            .listStyle(.grouped)
            .safeAreaPadding(.horizontal, 44)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 20) {
                let shown = focused ?? selected
                Text(shown.label)
                    .font(.title2)
                Text(shown.value)
                    .font(.body)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tvos.userAgent.value")
                if shown == .hako {
                    Text("The core's own name, with this Apple TV behind it. Keep this unless a panel of yours answers better to another client.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 44)
        }
        .navigationTitle("User-Agent")
    }
}
