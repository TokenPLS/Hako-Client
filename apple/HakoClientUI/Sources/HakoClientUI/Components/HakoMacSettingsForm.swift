import SwiftUI

extension View {
     
     
     
     
     
     
     
    @ViewBuilder
    public func hakoMacSettingsForm() -> some View {
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           #available(iOS 16.0, macOS 13.0, *) {
            formStyle(.grouped)
                 
                 
                 
                 
                .environment(\.defaultMinListRowHeight, 0)
        } else {
            self
        }
    }
}

 
 
 
 
 
public struct HakoMacSettingsFormContainer<Content: View>: View {
    private let content: () -> Content
    private let restoreDefaults: (() -> Void)?
    private let scopeFooter: HakoDisplayText?

     
     
     
     
     
     
     
     
     
     
     
     
    public init(
        restoreDefaults: (() -> Void)? = nil,
        scopeFooter: HakoDisplayText? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.restoreDefaults = restoreDefaults
        self.scopeFooter = scopeFooter
        self.content = content
    }

    public var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           #available(iOS 16.0, macOS 13.0, *) {
            Form {
                content()
                scopeSection
                restoreSection
            }
                .formStyle(.grouped)
                .environment(\.defaultMinListRowHeight, 0)
        } else {
            Form {
                content()
                scopeSection
                restoreSection
            }
        }
    }

    @ViewBuilder
    private var scopeSection: some View {
        if let scopeFooter {
            Section {
            } footer: {
                Text(hako: scopeFooter)
                    .accessibilityIdentifier("overrides.scope-footer")
            }
        }
    }

    @ViewBuilder
    private var restoreSection: some View {
        if let restoreDefaults {
            Section {
                Button(action: restoreDefaults) {
                    Text(HakoCopy.key("Restore profile values"))
                }
                .accessibilityIdentifier("overrides.restore-profile-values")
            }
        }
    }
}

extension View {
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    public func hakoMacSettingsList(
        minRowHeight: CGFloat = 0
    ) -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            listStyle(.inset)
                .environment(\.defaultMinListRowHeight, minRowHeight)
        } else {
            self
        }
    }
}

 
 
 
 
 
 
 
public struct HakoMacSettingsContainer<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           #available(iOS 16.0, macOS 13.0, *) {
            Form(content: content)
                .formStyle(.grouped)
                .environment(\.defaultMinListRowHeight, 0)
        } else {
            List(content: content)
        }
    }
}


extension View {
     
     
     
     
     
    @ViewBuilder
    public func hakoModalListMargins() -> some View {
        modifier(HakoModalListMarginsModifier())
    }
}

private struct HakoModalListMarginsModifier: ViewModifier {
    @Environment(\.hakoNavigationHostContext) private var hostContext
    @Environment(\.hakoInsideModalPresentation) private var insideModal

    func body(content: Content) -> some View {
        if hostContext == .modal || insideModal {
            content.padding(.horizontal, HakoTheme.Spacing.standard)
        } else {
            content
        }
    }
}
