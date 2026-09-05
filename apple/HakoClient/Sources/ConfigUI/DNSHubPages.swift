import HakoClientUI
import SwiftUI

 
 
 
 

 
 
enum DNSFieldRows {
     
     
     
     
     
     
     
     
     
     
     
    static func overrideMenuRow(
        _ title: String,
        _ selection: Binding<ProfileBooleanOverride>,
        inherited: InheritedBase,
        upstreamDefault: Bool,
        identifier: String
    ) -> some View {
        let state = InheritedBool(
            base: inherited,
            override: selection.wrappedValue.boolValue,
            upstreamDefault: upstreamDefault
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let adopt: HakoInlineRowAction? = {
            guard state.profileDisagrees else { return nil }
            return HakoInlineRowAction(
                title: .copy("Use the profile's value"),
                identifier: "adopt-profile.\(identifier)"
            ) {
                selection.wrappedValue = .profileDefault
            }
        }()
        return menuRow(
            title: title,
            value: state.primaryTitle,
            subtitle: state.sourceLine,
            adopt: adopt,
            identifier: identifier
        ) {
            Picker(
                HakoCopy.key(title),
                selection: selection
            ) {
                 
                 
                Text(hako: state.followTitle)
                    .tag(
                        ProfileBooleanOverride
                            .profileDefault
                    )
                Text(HakoCopy.key("On"))
                    .tag(
                        ProfileBooleanOverride.enabled
                    )
                Text(HakoCopy.key("Off"))
                    .tag(
                        ProfileBooleanOverride.disabled
                    )
            }
             
             
             
             
             
             
             
             
             
             
             
             
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }


    static func menuRow<Content: View>(
        title: String,
        value: HakoDisplayText,
        subtitle: HakoDisplayText? = nil,
        adopt: HakoInlineRowAction? = nil,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
#if os(macOS)
        Menu {
             
             
             
             
             
             
             
             
             
             
             
            content()
                .pickerStyle(.inline)
        } label: {
             
             
             
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(hako: value)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .lineLimit(1)
                Image(
                    systemName:
                        HakoSymbol.chevronUpChevronDown.name
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(
                 
                 
                minHeight: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    ? 0
                    : HakoClientUI.HakoTheme.Control.fullWidthRowMinHeight
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(
                subtitle.map { Text(hako: value) + Text(verbatim: ", ") + Text(hako: $0) }
                    ?? Text(hako: value)
            )
            .accessibilityIdentifier(identifier)
        }
        .buttonStyle(.plain)
         
         
         
        .id("\(identifier)-\(value.rawValue)")
        .fixedSize()
        .hakoSettingsMenuRow(title, subtitle: subtitle, adopt: adopt)
        .transaction {
            $0.animation = nil
        }
#else
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(HakoCopy.key(title))
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
            Menu {
                content()
            } label: {
                HStack(spacing: 4) {
                    Text(hako: value)
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )
                        .lineLimit(1)
                    Image(
                        systemName:
                            HakoSymbol
                                .chevronUpChevronDown.name
                    )
                    .font(.caption2)
                }
            }
            .id(value.rawValue)
            .transaction {
                $0.animation = nil
            }
             
             
             
             
            .accessibilityValue(
                subtitle.map { Text(hako: value) + Text(verbatim: ", ") + Text(hako: $0) }
                    ?? Text(hako: value)
            )
            .accessibilityIdentifier(identifier)
        }
#endif
    }
}

 
 
struct DNSHubRow: View {
    let title: String
    let detail: String
    var value: String?

    var body: some View {
#if os(macOS)
         
         
         
         
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.row
        ) {
            Text(HakoCopy.key(title))
            Spacer(minLength: HakoTheme.Spacing.compact)
            if let value {
                Text(hako: .copy(value))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6.5)
#else
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.row
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HakoCopy.key(title))
                if !detail.isEmpty {
                    Text(HakoCopy.key(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if let value {
                Text(hako: .copy(value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
#endif
    }
}
