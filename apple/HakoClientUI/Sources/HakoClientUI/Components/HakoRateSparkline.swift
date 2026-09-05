import SwiftUI

 
 
 
 
 
 
struct HakoRateSparkline: View {
    struct Series {
        let values: [Double]
        let tint: Color
    }

    let series: [Series]

    var body: some View {
        Canvas { context, size in
             
             
             
            for entry in series {
                guard entry.values.count >= 2 else { continue }
                let step = size.width / CGFloat(entry.values.count - 1)
                var line = Path()
                for (index, value) in entry.values.enumerated() {
                    let point = CGPoint(
                        x: CGFloat(index) * step,
                        y: size.height - CGFloat(value) * size.height
                    )
                    index == 0
                        ? line.move(to: point)
                        : line.addLine(to: point)
                }

                var fill = line
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(
                    fill,
                    with: .linearGradient(
                        Gradient(colors: [
                            entry.tint.opacity(0.24),
                            entry.tint.opacity(0.02),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                context.stroke(
                    line,
                    with: .color(entry.tint.opacity(0.9)),
                    lineWidth: 1.5
                )
            }
        }
        .drawingGroup()
    }
}
