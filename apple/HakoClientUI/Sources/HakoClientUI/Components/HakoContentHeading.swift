import SwiftUI

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoContentHeading(_ title: HakoDisplayText, watchAs: String? = nil) -> some View {
        modifier(HakoContentHeadingModifier(title: title))
             
             
             
             
             
            .hakoFrameWatch(title.frameWatchLabel(overriddenBy: watchAs))
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoRootHeading(_ title: HakoDisplayText, watchAs: String? = nil) -> some View {
        modifier(HakoRootHeadingModifier(title: title, watchAs: watchAs))
    }
}

 
 
 
 
private struct HakoContentHeadingModifier: ViewModifier {
    @Environment(\.hakoShellDrawsRootHeading)
    private var railOwnsHeading

    let title: HakoDisplayText

    func body(content: Content) -> some View {
        if railOwnsHeading {
            content.navigationTitle("")
        } else {
            content
                .navigationTitle("")
                .environment(\.hakoRegularRootLargeTitle, title.rawValue)
        }
    }
}

 
 
 
 
 
private struct HakoRootHeadingModifier: ViewModifier {
    @Environment(\.hakoShellDrawsRootHeading)
    private var railOwnsHeading

    let title: HakoDisplayText
    let watchAs: String?

    func body(content: Content) -> some View {
         
         
         
         
         
        if railOwnsHeading {
            content.navigationTitle("")
                .hakoFrameWatch(title.frameWatchLabel(overriddenBy: watchAs))
        } else {
            content.hakoPageTitle(title, watchAs: watchAs)
        }
    }
}

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoPageTitle(_ title: HakoDisplayText, watchAs: String? = nil) -> some View {
        navigationTitle(Text(hako: title))
            .modifier(HakoInlinePageTitle())
             
             
             
             
             
             
            .hakoFrameWatch(title.frameWatchLabel(overriddenBy: watchAs))
    }
}

private struct HakoInlinePageTitle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 17.0, *) {
            content.toolbarTitleDisplayMode(.inline)
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
#else
        content
#endif
    }
}
