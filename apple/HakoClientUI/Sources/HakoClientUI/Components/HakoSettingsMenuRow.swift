import SwiftUI

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoSettingsMenuRow(
        _ title: String,
        subtitle: HakoDisplayText? = nil,
        adopt: HakoInlineRowAction? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(hako: .copy(title))
                    .foregroundStyle(.primary)
                if let subtitle {
                     
                     
                     
                    HStack(spacing: HakoTheme.Spacing.compact) {
                        Text(hako: subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let adopt {
                            HakoInlineRowActionLink(action: adopt)
                        }
                    }
                }
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
             
             
             
            self.modifier(HakoMenuHoverHighlight())
        }
        .frame(maxWidth: .infinity)
    }
}


 
 
 
 
 
 
 
 
 
 
public struct HakoInlineRowAction {
    public let title: HakoDisplayText
    public let identifier: String
    public let perform: () -> Void

    public init(title: HakoDisplayText, identifier: String, perform: @escaping () -> Void) {
        self.title = title
        self.identifier = identifier
        self.perform = perform
    }
}

public struct HakoInlineRowActionLink: View {
    let action: HakoInlineRowAction

    public init(action: HakoInlineRowAction) {
        self.action = action
    }

    public var body: some View {
        Button(action: action.perform) {
            Text(hako: action.title)
                .font(.footnote)
        }
         
         
         
        #if os(macOS)
        .buttonStyle(.link)
        #else
        .buttonStyle(.borderless)
        #endif
        .accessibilityIdentifier(action.identifier)
    }
}
