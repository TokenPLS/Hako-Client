import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoRowDivider: View {
    private let leadingInset: CGFloat?

     
     
     
    public init(leadingInset: CGFloat? = nil) {
        self.leadingInset = leadingInset
    }

    @ViewBuilder
    public var body: some View {
        if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            if let leadingInset {
                Divider().padding(.leading, leadingInset)
            } else {
                Divider()
            }
        }
    }
}
