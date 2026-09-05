import SwiftUI

public extension View {
     
     
     
     
     
     
    @ViewBuilder
    func hakoGroupedList() -> some View {
#if os(iOS)
        listStyle(.insetGrouped)
#else
        self
#endif
    }
}
