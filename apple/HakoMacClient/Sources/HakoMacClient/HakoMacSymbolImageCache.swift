import AppKit
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
enum HakoMacSymbolImageCache {
    private static var images: [String: NSImage?] = [:]
    private static var lookups: [String: Int] = [:]

    static func image(for symbol: HakoSymbol) -> NSImage? {
        image(named: symbol.rawValue)
    }

    static func image(named name: String) -> NSImage? {
        if let cached = images[name] {
            return cached
        }
        lookups[name, default: 0] += 1
        let found = Bundle.module.image(forResource: NSImage.Name(name))
        images[name] = found
        return found
    }

     
     
     
    static func drawsSomething(_ symbol: HakoSymbol, fallback: String) -> Bool {
        if image(for: symbol) != nil { return true }
        return NSImage(systemSymbolName: fallback, accessibilityDescription: nil) != nil
    }

     

    static func resetForTesting() {
        images.removeAll()
        lookups.removeAll()
    }

    static func lookupCountForTesting(_ symbol: HakoSymbol) -> Int {
        lookups[symbol.rawValue] ?? 0
    }

    static func lookupCountForTesting(named name: String) -> Int {
        lookups[name] ?? 0
    }

    static func imageForTesting(named name: String) -> NSImage? {
        image(named: name)
    }

     
    static func probeMissForTesting() -> String {
        "hako.symbol.that.does.not.exist"
    }
}
