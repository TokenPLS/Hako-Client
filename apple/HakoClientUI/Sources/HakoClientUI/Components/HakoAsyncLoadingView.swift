import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoAsyncLoadingView: View {
    public init() {}

    public var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("page.async.loading")
    }
}
