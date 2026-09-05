import CoreGraphics
import CoreText
import Foundation
import SwiftUI

 
 
 
public typealias HakoRegionalFlagImage = CGImage

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoRegionalFlag {
     
    public static let taiwan = "\u{1F1F9}\u{1F1FC}"

     
    public static let flagScale: CGFloat = 3

     
     
    public static let deviceRendersTaiwanFlag: Bool = deviceRenders(taiwan)

     

    public enum Segment: Equatable {
        case text(String)
        case taiwanFlag
    }

     
     
    public static func segments(of name: String) -> [Segment] {
        let scalars = Array(name.unicodeScalars)
        var out: [Segment] = []
        var run = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if scalars[index].value == 0x1F1F9,
               index + 1 < scalars.count,
               scalars[index + 1].value == 0x1F1FC {
                if !run.isEmpty {
                    out.append(.text(String(run)))
                    run = String.UnicodeScalarView()
                }
                out.append(.taiwanFlag)
                index += 2
            } else {
                run.append(scalars[index])
                index += 1
            }
        }
        if !run.isEmpty {
            out.append(.text(String(run)))
        }
        return out
    }

     

     
     
     
     
    public static func text(for name: String, pointSize: CGFloat = 17) -> Text {
        guard !deviceRendersTaiwanFlag,
              name.contains(taiwan),
              let image = cachedTaiwanFlag(pointSize: pointSize)
        else {
            return Text(verbatim: name)
        }
        let flag = Text(Image(decorative: image, scale: flagScale)).baselineOffset(-pointSize * 0.16)
         
         
         
        var result = Text(verbatim: "")
        for segment in segments(of: name) {
            switch segment {
            case .text(let piece): result = Text("\(result)\(Text(verbatim: piece))")
            case .taiwanFlag: result = Text("\(result)\(flag)")
            }
        }
        return result
    }

     
     
     
     
    @ViewBuilder
    public static func label(
        _ name: String,
        pointSize: CGFloat = 17,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        if !deviceRendersTaiwanFlag, name.contains(taiwan) {
            HakoRegionalFlagLabel(name: name, pointSize: pointSize, relativeTo: style)
        } else {
            Text(verbatim: name)
        }
    }

     

     
     
     
     
     
     
     
     
     
     
     
    public static func deviceRenders(_ text: String) -> Bool {
        let pointSize: CGFloat = 16
        let width = Int((pointSize * 3.2).rounded(.up))
        let height = Int((pointSize * 1.8).rounded(.up))
        guard let context = rgbaContext(width: width, height: height) else { return true }
        let font = CTFontCreateUIFontForLanguage(.system, pointSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 0, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: 2, y: pointSize * 0.45)
        CTLineDraw(line, context)
        return hasColour(context)
    }

     

     
     
     
    public static func drawnTaiwanFlag(pointSize: CGFloat) -> HakoRegionalFlagImage? {
        let scale = flagScale
        let width = (pointSize * 1.35 * scale).rounded()
        let height = (width / 1.5).rounded()
        guard width > 0, height > 0,
              let context = rgbaContext(width: Int(width), height: Int(height))
        else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

         
        let clip = CGPath(
            roundedRect: rect, cornerWidth: height * 0.12, cornerHeight: height * 0.12,
            transform: nil)
        context.addPath(clip)
        context.clip()

        context.setFillColor(CGColor(srgbRed: 0.996, green: 0.0, blue: 0.0, alpha: 1))
        context.fill(rect)

         
        let canton = CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2)
        context.setFillColor(CGColor(srgbRed: 0.0, green: 0.0, blue: 0.584, alpha: 1))
        context.fill(canton)

         
        let centre = CGPoint(x: canton.midX, y: canton.midY)
        let tip = canton.height * 0.38
        let disc = tip * 0.5
        let ring = disc * 1.18
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        for ray in 0..<12 {
            let angle = CGFloat(ray) * (.pi / 6)
            let base = ring * 1.02
            let path = CGMutablePath()
            path.move(to: point(centre, radius: tip, angle: angle))
            path.addLine(to: point(centre, radius: base, angle: angle + .pi / 12))
            path.addLine(to: point(centre, radius: base, angle: angle - .pi / 12))
            path.closeSubpath()
            context.addPath(path)
        }
        context.fillPath()
        context.setFillColor(CGColor(srgbRed: 0.0, green: 0.0, blue: 0.584, alpha: 1))
        context.fillEllipse(in: CGRect(
            x: centre.x - ring, y: centre.y - ring, width: ring * 2, height: ring * 2))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fillEllipse(in: CGRect(
            x: centre.x - disc, y: centre.y - disc, width: disc * 2, height: disc * 2))

        return context.makeImage()
    }

     
    public static func imageSize(_ image: HakoRegionalFlagImage) -> CGSize {
        CGSize(width: CGFloat(image.width) / flagScale, height: CGFloat(image.height) / flagScale)
    }

     
     
    public static func dominantChannels(of cgImage: HakoRegionalFlagImage) -> (red: Bool, blue: Bool) {
        guard let context = rgbaContext(width: cgImage.width, height: cgImage.height)
        else { return (false, false) }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard let data = context.data else { return (false, false) }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var red = false
        var blue = false
        for offset in stride(from: 0, to: cgImage.width * cgImage.height * 4, by: 4) {
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            if r > 180 && g < 80 && b < 80 { red = true }
            if b > 100 && r < 60 && g < 60 { blue = true }
            if red && blue { break }
        }
        return (red, blue)
    }

     

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var flagCache: [CGFloat: HakoRegionalFlagImage] = [:]

    private static func cachedTaiwanFlag(pointSize: CGFloat) -> HakoRegionalFlagImage? {
        let key = (pointSize * 2).rounded() / 2
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = flagCache[key] { return cached }
        let drawn = drawnTaiwanFlag(pointSize: key)
        if let drawn { flagCache[key] = drawn }
        return drawn
    }

    private static func rgbaContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func hasColour(_ context: CGContext) -> Bool {
        guard let data = context.data else { return false }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        for offset in stride(from: 0, to: context.width * context.height * 4, by: 4) {
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            if pixels[offset + 3] > 0, abs(r - g) > 24 || abs(g - b) > 24 { return true }
        }
        return false
    }

    private static func point(_ centre: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + radius * sin(angle), y: centre.y + radius * cos(angle))
    }
}

 
 
 
struct HakoRegionalFlagLabel: View {
    let name: String
    @ScaledMetric private var pointSize: CGFloat

    init(name: String, pointSize: CGFloat, relativeTo style: Font.TextStyle) {
        self.name = name
        _pointSize = ScaledMetric(wrappedValue: pointSize, relativeTo: style)
    }

    var body: some View {
        HakoRegionalFlag.text(for: name, pointSize: pointSize)
            .accessibilityLabel(Text(verbatim: name))
    }
}
