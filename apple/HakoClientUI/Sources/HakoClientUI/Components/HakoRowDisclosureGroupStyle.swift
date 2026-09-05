import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
public struct HakoRowDisclosureGroupStyle: DisclosureGroupStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            Button {
                 
                 
                 
                 
                 
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.tight) {
                    Image(systemName: HakoSymbol.chevronForward.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

public extension View {
     
     
     
     
     
     
    @ViewBuilder
    func hakoRowDisclosure() -> some View {
#if os(macOS)
        if #available(macOS 13.0, *) {
            disclosureGroupStyle(HakoRowDisclosureGroupStyle())
        } else {
            self
        }
#else
        self
#endif
    }
}
