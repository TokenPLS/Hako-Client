import SwiftUI
import os

 
 
 
 
 
 
 
struct HakoDismissPlacement: Equatable {
     
     
     
    let depth: Int?
    let isPushedPage: Bool
    let hostContext: HakoNavigationHostContext
     
     
     
    let insideModal: Bool

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var dismisses: Bool {
        if isPushedPage { return true }
        if insideModal { return true }
        guard let depth else { return true }
        if depth > 0 { return true }
        return hostContext == .modal
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoDismissHandle {
    private var action: (() -> Void)?
    private var placement = HakoDismissPlacement(
        depth: nil, isPushedPage: false, hostContext: .standalone, insideModal: false
    )

    public init() {}

     
     
    public func callAsFunction() {


        guard placement.dismisses else { return }
        action?()
    }

    func bind(_ action: @escaping () -> Void, placement: HakoDismissPlacement) {


        self.action = action
        self.placement = placement
    }


}

 
 
 
 
 
 
 
 
 
 
private struct HakoDismissCapture: View {
    let handle: HakoDismissHandle
    @Environment(\.dismiss) private var dismiss
     
     
    @Environment(\.hakoNavigationDepth) private var navigationDepth
    @Environment(\.hakoIsPushedPage) private var isPushedPage
    @Environment(\.hakoNavigationHostContext) private var hostContext
    @Environment(\.hakoInsideModalPresentation) private var insideModal

    var body: some View {
         
         
         
        let _ = handle.bind(
            { dismiss() },
            placement: HakoDismissPlacement(
                depth: navigationDepth,
                isPushedPage: isPushedPage,
                hostContext: hostContext,
                insideModal: insideModal
            )
        )
        Color.clear.frame(width: 0, height: 0).allowsHitTesting(false)
    }
}

public extension View {
     
     
    func hakoCapturesDismiss(_ handle: HakoDismissHandle) -> some View {
        background(HakoDismissCapture(handle: handle))
    }
}
