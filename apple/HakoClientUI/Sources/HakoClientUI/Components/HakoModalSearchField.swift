import SwiftUI

 
 
 
 
public struct HakoModalSearchField: View {
    private let text: Binding<String>

    public init(text: Binding<String>) {
        self.text = text
    }

    public var body: some View {
#if os(macOS)
        HStack(spacing: 4) {
            Image(systemName: HakoSymbol.magnifyingglass.rawValue)
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField(
                "",
                text: text,
                prompt: Text(HakoCopy.key("Search"))
            )
            .textFieldStyle(.plain)
            .accessibilityIdentifier("hako.modal.search")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .frame(width: 200)
#else
        EmptyView()
#endif
    }
}
