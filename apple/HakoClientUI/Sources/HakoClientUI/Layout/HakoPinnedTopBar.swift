import SwiftUI

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoPinnedTopBar<Bar: View>(
        @ViewBuilder _ bar: @escaping () -> Bar
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
             
             
             
             
             
             
             
             
             
            safeAreaBar(edge: .top, spacing: 0, content: bar)
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                bar().modifier(HakoPreScrollEdgeBarGround())
            }
        }
    }

     
     
     
     
     
     
     
    @ViewBuilder
    func hakoStablePinnedTopBar<Footprint: View, Bar: View>(
        @ViewBuilder footprint: @escaping () -> Footprint,
        @ViewBuilder bar: @escaping () -> Bar
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            hakoPinnedTopBar {
                footprint()
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .overlay(alignment: .top) {
                        bar()
                    }
            }
             
             
             
             
             
             
             
            .overlay(alignment: .top) {
                 
                 
                 
                 
                bar()
                    .opacity(0.001)
                    .allowsHitTesting(true)
                    .accessibilityHidden(true)
                    .accessibilityRepresentation { Color.clear }
            }
        } else {
            hakoPinnedTopBar {
                footprint()
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .overlay(alignment: .top) {
                         
                         
                         
                         
                        bar().modifier(HakoPreScrollEdgeBarGround())
                    }
            }
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoPreScrollEdgeBarGround: ViewModifier {
    @Environment(\.hakoDetailCanvas) private var canvas
    @Environment(\.hakoRegularShellOwnsCanvas) private var shellOwnsCanvas

    func body(content: Content) -> some View {
        if shellOwnsCanvas, let canvas {
            content.background(canvas)
        } else {
            content.background(.bar)
        }
    }
}
