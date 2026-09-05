import SwiftUI

extension View {
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoAlwaysEditing() -> some View {
#if os(macOS)
        self
#else
        environment(\.editMode, .constant(.active))
#endif
    }

     
     
     
     
     
     
    @ViewBuilder
    func hakoBackButtonHidden(_ hidden: Bool) -> some View {
#if os(macOS)
        self
#else
        navigationBarBackButtonHidden(hidden)
#endif
    }
}

extension View {
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoEditorFormContainer<Rows: View>(
        @ViewBuilder rows: () -> Rows
    ) -> some View {
#if os(macOS)
        Form { rows() }
            .formStyle(.grouped)
#else
        List { rows() }
#endif
    }
}
