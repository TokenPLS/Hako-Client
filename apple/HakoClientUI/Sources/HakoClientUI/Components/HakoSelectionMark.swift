import SwiftUI

 
 
 
 
public struct HakoSelectionMark: View {
    public let isSelected: Bool

     
     
     
     
     
     
     
     
     
     
     
    public let tint: Color?

    public init(isSelected: Bool, tint: Color? = nil) {
        self.isSelected = isSelected
        self.tint = tint
    }

    public var body: some View {
        Image(systemName: HakoSymbol.checkmark.rawValue)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint))
            .opacity(isSelected ? 1 : 0)
            .frame(width: 20, height: 22, alignment: .top)
            .accessibilityLabel("Selected")
            .accessibilityHidden(!isSelected)
    }
}
