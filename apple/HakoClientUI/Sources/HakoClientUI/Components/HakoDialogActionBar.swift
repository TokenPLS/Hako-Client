import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoDialogActionBar: View {
    private let resetTitle: String?
    private let resetDisabled: Bool
    private let onReset: (() -> Void)?
    private let cancelTitle: String
    private let onCancel: () -> Void
    private let confirmTitle: String
    private let confirmDisabled: Bool
    private let onConfirm: () -> Void

    public init(
        resetTitle: String? = nil,
        resetDisabled: Bool = false,
        onReset: (() -> Void)? = nil,
        cancelTitle: String = "Cancel",
        onCancel: @escaping () -> Void,
        confirmTitle: String = "Done",
        confirmDisabled: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        self.resetTitle = resetTitle
        self.resetDisabled = resetDisabled
        self.onReset = onReset
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.confirmTitle = confirmTitle
        self.confirmDisabled = confirmDisabled
        self.onConfirm = onConfirm
    }

    public var body: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            if let resetTitle, let onReset {
                Button(role: .destructive, action: onReset) {
                    Text(HakoCopy.key(resetTitle))
                }
                .disabled(resetDisabled)
                .accessibilityIdentifier("hako.dialog.reset")
            }
            Spacer(minLength: 0)
            Button(role: .cancel, action: onCancel) {
                Text(HakoCopy.key(cancelTitle))
            }
            .accessibilityIdentifier("hako.dialog.cancel")
            Button(action: onConfirm) {
                Text(HakoCopy.key(confirmTitle))
            }
            .disabled(confirmDisabled)
             
             
             
             
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("hako.dialog.confirm")
        }
        .modifier(HakoDialogActionBarSurface())
    }
}

 
 
 
private struct HakoDialogActionBarSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.automatic)
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .padding(.vertical, HakoTheme.Spacing.row)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    Rectangle().fill(.bar)
                    Divider()
                }
                .ignoresSafeArea(edges: .bottom)
            }
    }
}
