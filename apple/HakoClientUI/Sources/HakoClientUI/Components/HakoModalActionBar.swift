import SwiftUI

 
 
 
public struct HakoModalActionBar: View {
    private let primaryTitle: String
    private let primaryDisabled: Bool
    private let primaryHint: String?
    private let isBusy: Bool
    private let busyTitle: String?
    private let onPrimary: () -> Void

    public init(
        primaryTitle: String,
        primaryDisabled: Bool = false,
         
         
         
         
         
         
         
        primaryHint: String? = nil,
        isBusy: Bool = false,
        busyTitle: String? = nil,
        onPrimary: @escaping () -> Void
    ) {
        self.primaryTitle = primaryTitle
        self.primaryDisabled = primaryDisabled
        self.primaryHint = primaryHint
        self.isBusy = isBusy
        self.busyTitle = busyTitle
        self.onPrimary = onPrimary
    }

     
     
     
     
     
     
     
     
     
    private var label: String {
        isBusy ? (busyTitle ?? primaryTitle) : primaryTitle
    }

    public var body: some View {
        VStack(spacing: HakoTheme.Spacing.tight) {
             
             
             
             
             
             
             
             
             
             
             
             
            if primaryDisabled, let primaryHint {
                Text(hako: .formatCopy("Needs %@", [primaryHint]))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            primaryButton
        }
        .padding(
            .horizontal,
            HakoTheme.MacOS.ProductModal.contentHorizontalInset
        )
        .padding(.vertical, HakoTheme.Spacing.standard)
        .modifier(HakoModalActionBarSurface())
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
             
             
             
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                Text(HakoCopy.key(label))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Capsule())
            } else {
                Text(HakoCopy.key(label))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: HakoTheme.Control.minimumHitTarget)
                    .contentShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .background(
            Capsule().fill(
                 
                 
                primaryDisabled || isBusy
                    ? AnyShapeStyle(.tint.opacity(0.35))
                    : AnyShapeStyle(.tint)
            )
        )
        .clipShape(Capsule())
        .disabled(primaryDisabled || isBusy)
#if !os(tvOS)
        .keyboardShortcut(.defaultAction)
#endif
        .accessibilityIdentifier("hako.modal.primary")
         
         
         
         
        .accessibilityValue(
            primaryDisabled ? (primaryHint.map { HakoDisplayText.copy($0).resolved(locale: Locale.current) } ?? "") : ""
        )
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoModalActionBarSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            content
                .frame(maxWidth: .infinity)
                .background(alignment: .top) {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(.bar)
                        Divider()
                    }
                     
                     
                     
                    .ignoresSafeArea(edges: .bottom)
                }
        } else {
            content
        }
    }
}
