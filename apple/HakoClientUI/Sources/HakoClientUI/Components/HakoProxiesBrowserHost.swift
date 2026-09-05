import SwiftUI

 
 
 
 
 
 
public struct HakoProxiesBrowserHost<Modern: View, Legacy: View>: View {
    private let modern: () -> Modern
    private let legacy: () -> Legacy

    public init(
        @ViewBuilder modern: @escaping () -> Modern,
        @ViewBuilder legacy: @escaping () -> Legacy
    ) {
        self.modern = modern
        self.legacy = legacy
    }

    public var body: some View {
        #if os(iOS)
        modern()
            .listStyle(.insetGrouped)
            .modifier(HakoProxiesHomeCardRhythm())
        #else
        legacy()
        #endif
    }
}

#if os(iOS)
 
 
 
 
 
 
private struct HakoProxiesHomeCardRhythm: ViewModifier {
     
     
     
     
     
     
    private static let toolbarSafeAreaPadding: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .listSectionSpacing(HakoTheme.Spacing.section)
                .contentMargins(
                    .top,
                    HakoTheme.Spacing.section - Self.toolbarSafeAreaPadding,
                    for: .scrollContent
                )
        } else if #available(iOS 17.0, *) {
             
             
             
             
            content.listSectionSpacing(HakoTheme.Spacing.section)
        } else {
            content
        }
    }
}
#endif
