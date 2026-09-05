import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoLazyView<Content: View>: View {
    private let build: () -> Content

    public init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    public var body: some View {
        HakoDeferredPageContent {
            build()
        } placeholder: {
            HakoPageLoadingPlaceholder(title: .copy("Loading"))
        }
    }
}
