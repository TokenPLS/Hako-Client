import SwiftUI

 
 
 
 
 
 
 
 
 
public struct HakoSettingsToggleRow: View {
    private let title: Text
     
     
     
     
     
    private let identifier: String?
    @Binding private var isOn: Bool

     
     
    public init(_ title: Text, isOn: Binding<Bool>, identifier: String? = nil) {
        self.title = title
        _isOn = isOn
        self.identifier = identifier
    }

    public var body: some View {
        row.hakoFieldIdentifier(identifier)
    }

    @ViewBuilder
    private var row: some View {
#if os(macOS)
        HStack {
            title
            Spacer(minLength: HakoTheme.Spacing.row)
            Toggle(isOn: $isOn) {
                title
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAction {
            isOn.toggle()
        }
#else
        Toggle(isOn: $isOn) {
            title
        }
#endif
    }
}
