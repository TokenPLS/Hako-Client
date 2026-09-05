import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoMacSettingsMetrics {
     
     
     
     
     
     
     
     
    public static func rowVerticalInset(touch: CGFloat) -> CGFloat {
        HakoPlatformLayout.pageUsesSystemSettingsIdiom ? 0 : touch
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static let listRowMinHeight: CGFloat = 36

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static let headerControlHeight: CGFloat = 22
}

public enum HakoMacSettingsType {
     
    public static let title: Font = .body
     
     
    public static let value: Font = .body
     
    public static let mono: Font = .body.monospaced()
     
    public static let footnote: Font = .callout
}

 
public struct HakoMacToggleRow: View {
    private let title: HakoDisplayText
    @Binding private var isOn: Bool
     
     
     
     
    private let identifier: String?

    public init(_ title: HakoDisplayText, isOn: Binding<Bool>, identifier: String? = nil) {
        self.title = title
        _isOn = isOn
        self.identifier = identifier
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Text(hako: title).font(HakoMacSettingsType.title)
        }
        .modifier(HakoOptionalIdentifier(identifier: identifier))
    }
}

 
 
 
public struct HakoMacNavigationRowLabel: View {
    private let title: HakoDisplayText
    private let subtitle: HakoDisplayText?
    private let value: HakoDisplayText?

    public init(
        _ title: HakoDisplayText,
        subtitle: HakoDisplayText? = nil,
        value: HakoDisplayText? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }

    public var body: some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hako: title).font(HakoMacSettingsType.title)
                if let subtitle {
                    Text(hako: subtitle)
                        .font(HakoMacSettingsType.value)
                        .foregroundStyle(.secondary)
                }
            }
            if let value {
                Spacer(minLength: HakoTheme.Spacing.compact)
                Text(hako: value)
                    .font(HakoMacSettingsType.value)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

 
 
public struct HakoMacActionRow<Trailing: View>: View {
    private let title: HakoDisplayText
    private let actionTitle: HakoDisplayText
    private let action: () -> Void
    private let trailing: () -> Trailing

    public init(
        _ title: HakoDisplayText,
        actionTitle: HakoDisplayText,
        action: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.trailing = trailing
    }

    @ViewBuilder
    public var body: some View {
         
         
         
        if #available(iOS 16.0, macOS 13.0, *) {
        LabeledContent {
            trailing()
            Button(action: action) {
                Text(hako: actionTitle)
            }
            .buttonStyle(.bordered)
             
             
             
             
             
            .tint(.primary)
        } label: {
            Text(hako: title).font(HakoMacSettingsType.title)
        }
        }
    }
}

extension HakoMacActionRow where Trailing == EmptyView {
    public init(
        _ title: HakoDisplayText,
        actionTitle: HakoDisplayText,
        action: @escaping () -> Void
    ) {
        self.init(title, actionTitle: actionTitle, action: action) {
            EmptyView()
        }
    }
}

 
 
 
 
 
 
 
 
public struct HakoMacFieldRow: View {
    private let label: HakoDisplayText
    private let prompt: String
    @Binding private var text: String
    private let mono: Bool
     
    private let identifier: String?

    public init(
        _ label: HakoDisplayText,
        prompt: String,
        text: Binding<String>,
        monospaced: Bool = false,
        identifier: String? = nil
    ) {
        self.label = label
        self.prompt = prompt
        _text = text
        self.mono = monospaced
        self.identifier = identifier
    }

    public var body: some View {
         
         
         
         
         
         
        TextField(
            text: $text,
            prompt: Text(prompt),
            label: { Text(hako: label) }
        )
        .labelsHidden()
        .font(mono ? HakoMacSettingsType.mono : HakoMacSettingsType.value)
        .modifier(HakoOptionalIdentifier(identifier: identifier))
    }
}

 
 
 
 
 
 
 
public struct HakoMacListAddRow: View {
    private let title: HakoDisplayText
    private let action: () -> Void

    public init(_ title: HakoDisplayText, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label {
                Text(hako: title)
            } icon: {
                Image(systemName: HakoSymbol.plus.rawValue)
            }
        }
        .hakoMacListAddChrome()
    }
}

 
 
 
 
 
 
 
 
public struct HakoMacDeletableRow<Content: View>: View {
    private let onDelete: () -> Void
    private let content: () -> Content
    @State private var hovering = false

    public init(
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDelete = onDelete
        self.content = content
    }

    public var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            HStack(spacing: HakoTheme.Spacing.compact) {
                content()
                Spacer(minLength: HakoTheme.Spacing.compact)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(
                            hovering
                                ? AnyShapeStyle(Color.red)
                                : AnyShapeStyle(.secondary)
                        )
                }
                .buttonStyle(.borderless)
                .onHover { hovering = $0 }
                .accessibilityLabel(Text(hako: .copy("Remove")))
            }
        } else {
            content()
        }
    }
}

 
 
 

extension View {
     
     
     
     
    @ViewBuilder
    public func hakoIdiomFormPickerStyle() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            self
        } else {
            pickerStyle(.segmented)
        }
    }
}

extension View {
     
     
     
     
     
     
     
     
    @ViewBuilder
    public func hakoLabelsHiddenInSettingsIdiom() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            labelsHidden()
        } else {
            self
        }
    }

     
     
    @ViewBuilder
    public func hakoMacSettingsFootnote() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            font(HakoMacSettingsType.footnote)
        } else {
            self
        }
    }
}

extension View {
     
     
     
    @ViewBuilder
    public func hakoMacFormActionChrome() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            buttonStyle(.bordered).tint(.primary)
        } else {
            self
        }
    }
}

extension View {
     
     
     
    @ViewBuilder
    public func hakoMacListAddChrome() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.primary)
        } else {
            self
        }
    }
}


 
 
 
 
 
 
 
 
 
 
@ViewBuilder
public func hakoPromptField(
    _ placeholder: String,
    text: Binding<String>,
     
     
     
    identifier: String? = nil
) -> some View {
    if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
       #available(iOS 16.0, macOS 13.0, *) {
         
         
         
         
         
        TextField(
            text: text,
            prompt: Text(verbatim: placeholder),
            axis: .vertical,
            label: { EmptyView() }
        )
        .lineLimit(1...4)
        .labelsHidden()
        .modifier(HakoOptionalIdentifier(identifier: identifier))
    } else {
        TextField(placeholder, text: text)
            .modifier(HakoOptionalIdentifier(identifier: identifier))
    }
}
