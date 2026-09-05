import SwiftUI

 
 
 
public struct HakoFieldRow: View {
    private let title: String
    private let hint: String
    private let text: Binding<String>
    private let secure: Bool
    private let reveals: Binding<Bool>?
    private let monospaced: Bool
    private let suffix: String?
    private let compactValue: Bool
    private let identifier: String?
    private let subtitle: HakoDisplayText?
    @FocusState private var focused: Bool

    public init(
        _ title: String,
        hint: String,
        text: Binding<String>,
        secure: Bool = false,
        reveals: Binding<Bool>? = nil,
        monospaced: Bool = false,
        suffix: String? = nil,
        compactValue: Bool = false,
        identifier: String? = nil,
        subtitle: HakoDisplayText? = nil
    ) {
        self.title = title
        self.hint = hint
        self.text = text
        self.secure = secure
        self.reveals = reveals
        self.monospaced = monospaced
        self.suffix = suffix
        self.compactValue = compactValue
        self.identifier = identifier
        self.subtitle = subtitle
    }

    public var body: some View {
         
         
         
         
         
         
         
         
         
         
        let _ = HakoPageProbe.isEnabled
            ? HakoPageProbe.countRowEvaluation(identifier ?? title)
            : ()
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(HakoCopy.key(title))
                    .lineLimit(1)
                if let subtitle {
                     
                     
                    Text(hako: subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)
             
             
             
             
            .onTapGesture { focused = true }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                valueField
                    .hakoMacFieldValueWidth(compact: compactValue)
            } else {
                valueField
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let reveals {
                Button {
                    reveals.wrappedValue.toggle()
                } label: {
                    Image(
                        systemName:
                            (reveals.wrappedValue
                                ? HakoSymbol.eyeSlash
                                : HakoSymbol.eye).rawValue
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    reveals.wrappedValue ? "Hide value" : "Show value"
                )
            }
             
             
             
             
            if let suffix,
                HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    || !text.wrappedValue.isEmpty
            {
                Text(HakoCopy.key(suffix))
                    .foregroundStyle(.secondary)
            }
        }
#if os(macOS)
        .frame(
            maxWidth: .infinity,
             
             
            minHeight: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                ? 0
                : HakoTheme.Control.fullWidthRowMinHeight
        )
#else
        .frame(maxWidth: .infinity)
#endif
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { focused = true }
        )
         
         
         
        .onDisappear { focused = false }
        .accessibilityElement(children: .contain)
        .hakoFieldRowIdentifier(identifier)
    }

    @ViewBuilder
    private var valueField: some View {
        if secure && reveals?.wrappedValue != true {
            HakoSecureValueField(
                hint: hint,
                label: title,
                bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                text: text
            )
            .font(monospaced ? .body.monospaced() : .body)
            .focused($focused)
            .hakoFieldIdentifier(identifier)
        } else {
            HakoValueField(
                hint: hint,
                label: title,
                bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                text: text
            )
            .font(monospaced ? .body.monospaced() : .body)
            .focused($focused)
            .hakoFieldIdentifier(identifier)
        }
    }

}

 
 
extension View {
    @ViewBuilder
    func hakoFieldIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    @ViewBuilder
    func hakoFieldRowIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier("\(identifier).row")
        } else {
            self
        }
    }
}

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoMacFieldValueWidth(compact: Bool = false) -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
             
             
             
             
            frame(maxWidth: compact ? 96 : 260)
        } else {
            self
        }
    }
}
