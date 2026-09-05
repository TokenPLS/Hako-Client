import HakoClientUI
import SwiftUI

 
 
 
 
 
 
let hakoAppleRuntimeProfile: HakoAppleRuntimeProfile = {
    guard let profile = HakoAppleRuntimeProfile(rawValue: hakoAppleRuntimeProfileName) else {
         
         
         
         
        preconditionFailure("no HakoAppleRuntimeProfile for \(hakoAppleRuntimeProfileName)")
    }
    return profile
}()

extension View {
    @ViewBuilder
    func hakoStackNavigationViewStyle() -> some View {
#if os(macOS)
        self
#else
        navigationViewStyle(.stack)
#endif
    }

    @ViewBuilder
    func hakoInsetGroupedListStyle() -> some View {
#if os(macOS)
         
         
         
         
         
         
        listStyle(.inset)
            .scrollDismissesKeyboard(.immediately)
#else
        listStyle(.insetGrouped)
#endif
    }

    @ViewBuilder
    func hakoCapsuleButtonBorderShape() -> some View {
#if os(macOS)
        if #available(macOS 14.0, *) {
            buttonBorderShape(.capsule)
        } else {
            self
        }
#else
        buttonBorderShape(.capsule)
#endif
    }
}

extension ToolbarItemPlacement {
    static var hakoNavigationTrailing: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .navigationBarTrailing
#endif
    }
}

struct HakoEditButton: View {
    var body: some View {
#if os(macOS)
        EmptyView()
#else
        EditButton()
#endif
    }
}
