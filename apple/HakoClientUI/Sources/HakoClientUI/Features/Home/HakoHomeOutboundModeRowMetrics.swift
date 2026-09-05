import SwiftUI

 
 
 
enum HakoHomeOutboundModeRowMetrics {
#if os(macOS)
    static let minimumHeight: CGFloat? =
        HakoTheme.Control.compactChoiceRowMinHeight
#else
    static let minimumHeight: CGFloat? = nil
#endif
}
