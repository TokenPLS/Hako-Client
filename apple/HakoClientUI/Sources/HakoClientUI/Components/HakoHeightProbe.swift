import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoHeightProbeModifier: ViewModifier {
    let label: String
    let count: Int
    let step: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: Int(geo.size.height / step)) { _ in
                        emit(geo.size.height)
                    }
                    .onAppear { emit(geo.size.height) }
            }
        )
    }

    @MainActor
    private func emit(_ height: CGFloat) {
        HakoPerf.emit("\(label) h=\(Int(height)) n=\(count)")
    }
}

public extension View {
     
     
     
     
     
     
    func hakoHeightProbe(
        _ label: String,
        count: Int,
        step: CGFloat = 50
    ) -> some View {
        modifier(
            HakoHeightProbeModifier(label: label, count: count, step: step)
        )
    }
}
