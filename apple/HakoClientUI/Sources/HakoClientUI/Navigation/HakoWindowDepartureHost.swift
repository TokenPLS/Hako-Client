#if os(macOS)
import Combine
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoWindowDepartureHost<Content: View, WindowGuard: View>: View {
    private let content: Content
    private let windowGuard: (HakoWindowDepartureController) -> WindowGuard
    @StateObject private var controller = HakoWindowDepartureController()

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder windowGuard: @escaping (HakoWindowDepartureController) -> WindowGuard
    ) {
        self.content = content()
        self.windowGuard = windowGuard
    }

    public var body: some View {
        let departureGuard = controller.departureGuard
        content
            .environment(\.hakoRootDepartureGuard, departureGuard)
            .environment(\.hakoProductModalDismiss, { [controller] in controller.closeWindow() })
            .background(windowGuard(controller))
            .alert(
                "Save your changes?",
                isPresented: Binding(
                    get: { departureGuard.isPromptPresented },
                    set: { _ in }
                )
            ) {
                Button("Save") { departureGuard.saveAndLeave() }
                Button("Discard", role: .destructive) { departureGuard.discardAndLeave() }
                Button("Keep Editing", role: .cancel) { departureGuard.keepEditing() }
            } message: {
                Text("This page has changes that have not been saved.")
            }
    }
}

 
 
 
@MainActor
public final class HakoWindowDepartureController: ObservableObject {
    let departureGuard = HakoRootDepartureGuard()
     
     
    public var closeWindow: () -> Void = {}
    private var forwarding: AnyCancellable?

    public init() {
        forwarding = departureGuard.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        departureGuard.dirtyRegistrationDidChange = { [weak self] in
            self?.objectWillChange.send()
        }
    }

     
    public var hasUnsavedChanges: Bool { departureGuard.hasDirtyRegistration }

     
     
     
    public func shouldClose() -> Bool {
        guard departureGuard.hasDirtyRegistration else { return true }
        departureGuard.requestDeparture { [weak self] in self?.closeWindow() }
        return false
    }
}
#endif
