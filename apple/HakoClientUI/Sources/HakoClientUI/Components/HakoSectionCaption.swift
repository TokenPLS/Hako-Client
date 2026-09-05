import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
public struct HakoSectionCaption<Trailing: View>: View {
     
     
     
    private let title: HakoDisplayText
    private let trailing: Trailing

    public init(
        _ title: HakoDisplayText,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(hako: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, HakoTheme.Spacing.compact)
        .accessibilityAddTraits(.isHeader)
    }
}

public extension HakoSectionCaption where Trailing == EmptyView {
    init(_ title: HakoDisplayText) {
        self.init(title) { EmptyView() }
    }
}

 
 
 
 
public struct HakoSectionFooter: View {
    private let text: HakoDisplayText

    public init(_ text: HakoDisplayText) {
        self.text = text
    }

    public var body: some View {
        Text(hako: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HakoTheme.Spacing.compact)
    }
}
