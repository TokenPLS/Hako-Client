import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoHomeTrafficScopeTabs: View {
    @Environment(\.locale) private var locale
    @Binding var scope: HakoHomeTrafficScope

    var body: some View {
        HakoFullWidthSegmentedPicker(
            selection: $scope,
            options: [
                HakoFullWidthSegmentedOption(
                    selection: .proxiedOnly,
                    title: HakoCopy.string(
                        "Proxied only",
                        locale: locale
                    ),
                    accessibilityIdentifier: "home.traffic.scope.proxied"
                ),
                HakoFullWidthSegmentedOption(
                    selection: .allTraffic,
                    title: HakoCopy.string("All traffic", locale: locale),
                    accessibilityIdentifier: "home.traffic.scope.all"
                ),
            ],
            role: .inlineControl
        )
    }
}
