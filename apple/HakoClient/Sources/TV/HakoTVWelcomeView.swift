import SwiftUI

 
 
 
 
 
struct HakoTVWelcomeView: View {
    let onAddSubscription: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HakoTVBrandMark()
            Text("Clash")
                .font(.largeTitle)
            Text("Add a profile to get started. Type its address here, or on your iPhone when the keyboard appears there.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
            Button("Add a profile", action: onAddSubscription)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
         
         
         
         
         
    }
}
