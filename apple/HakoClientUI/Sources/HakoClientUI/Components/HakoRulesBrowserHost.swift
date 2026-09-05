import SwiftUI

 
 
 
 
public struct HakoRulesBrowserHost<Modern: View, Legacy: View>: View {
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
        #else
        legacy()
        #endif
    }
}
