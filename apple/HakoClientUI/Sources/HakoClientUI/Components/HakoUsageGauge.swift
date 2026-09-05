import SwiftUI

 
 
 
 
 
 
 
 
 
 
struct HakoUsageGauge: View {
    let fraction: Double

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        let fill: Color = fraction >= 1 ? .red : .accentColor
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(fill.opacity(0.22))
                Capsule()
                    .fill(fill)
                     
                     
                     
                    .frame(width: max(
                        6, proxy.size.width * CGFloat(clamped)
                    ))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text(hako: .copy("Subscription usage")))
        .accessibilityValue(Text(hako: .format(
            "%@ percent", ["\(Int(fraction * 100))"]
        )))
    }
}
