import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoDeferredDraftHost<Value, Content: View>: View {
    @Binding private var source: Value
    private let content: (Binding<Value>) -> Content
    @State private var local: Value

    public init(
        source: Binding<Value>,
        @ViewBuilder content: @escaping (Binding<Value>) -> Content
    ) {
        _source = source
        self.content = content
        _local = State(initialValue: source.wrappedValue)
    }

    public var body: some View {
        content($local)
            .onDisappear {
                source = local
            }
    }
}
