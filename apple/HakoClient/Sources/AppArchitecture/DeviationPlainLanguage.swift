import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum DeviationPlainLanguage {

     
     
     
     
     
     
    static func whatHappened(_ deviation: ConfigDeviation, locale: Locale) -> HakoDisplayText {
        if deviation.effect == .matchesEverything {
            return .copy("Matches every connection here, whatever it was meant to match.")
        }
        if deviation.effect == .neverMatches {
            return .copy("Kept, but nothing here can match it — the next rule decides.")
        }
        if let added = deviation.appendedEntries, added > 0 {
            return .format("The app added %@ rule(s) to the ones you wrote.", ["\(added)"])
        }
        switch deviation.category {
        case .stripped:
            return .copy("Not used on this platform. What you wrote is left out.")
        case .forced:
             
             
             
             
            if let appended = deviation.appendedEntries, appended > 0 {
                return .formatCopy(
                    "This app added %@ after what you wrote; yours are all still there.",
                    [String(format: HakoCopy.string("%d entries", locale: locale), appended)]
                )
            }
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            if deviation.isAppWide {
                return .copy("What ran here is the app's own setting, not this file's value.")
            }
            return deviation.recoverable && !deviation.overriddenAsUnrecoverable
                ? .copy("The app starts from a different value than the core would. Yours still wins if you set it.")
                : .copy("This platform decides this one; what you wrote is not used.")
        case .unavailable where deviation.honoured == true:
             
             
             
             
            return .copy("This app applies this before the core starts, so what you wrote takes effect.")
        case .unavailable:
            return .copy("This platform has nothing to do this with, so it does nothing.")
        case let .other(word):
             
             
            return .verbatim(word)
        }
    }

     
     
     
     
     
     
    static func whatToDo(_ deviation: ConfigDeviation, locale: Locale) -> HakoDisplayText? {
         
         
         
         
         
         
         
         
         
         
         
         
         
        if deviation.appendedEntries != nil {
            return .copy("Cover this traffic in your own rules and the app adds nothing.")
        }
         
         
         
         
         
         
         
         
        if deviation.isThisAppsDoing, !deviation.overriddenAsUnrecoverable,
           Self.appOffersAControl(for: deviation.configKey) {
            return .copy("This one is an app setting; change it in the app rather than in this file.")
        }
        if deviation.recoverable, !deviation.overriddenAsUnrecoverable {
             
             
             
             
             
             
            if deviation.isThisAppsDoing {
                return .copy("This app decides this one; the value in this file is not what runs.")
            }
            return .copy("Set it explicitly and your value is used.")
        }
        if deviation.honoured == true {
             
            return .copy("Keep it — this app reads it even though the core does not.")
        }
        if deviation.category == .stripped || deviation.category == .unavailable {
            return .copy("Nothing to do — you can leave it or remove it.")
        }
         
         
         
         
        return .copy("This one is decided by the platform; there is nothing to change.")
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func valuePair(_ deviation: ConfigDeviation, locale: Locale) -> HakoDisplayText? {
        let running = runningValue(deviation, locale: locale)
        guard !running.isEmpty else { return nil }
        guard deviation.readerWroteIt else {
            return .formatCopy("Running with: %@", [running])
        }
        return .formatCopy("You wrote %@ · running with %@", [readerValue(deviation), running])
    }

     
     
     
     
     
     
     
     
     
    static func runningValue(_ deviation: ConfigDeviation, locale: Locale) -> String {
        if let value = scalar(deviation.effective(locale: locale)) { return value }
        if deviation.effect == .matchesEverything {
            return HakoCopy.string("matches every connection", locale: locale)
        }
        if deviation.effect == .neverMatches {
            return HakoCopy.string("kept, but nothing here matches it", locale: locale)
        }
        switch deviation.category {
        case .stripped: return HakoCopy.string("not present", locale: locale)
        case .unavailable: return HakoCopy.string("present, and nothing reads it", locale: locale)
        case .forced: return HakoCopy.string("the value this platform uses", locale: locale)
        case let .other(word): return word
        }
    }

     
     
    static func appOffersAControl(for configKey: String) -> Bool {
        let offered = OverrideEntryCount.renderedKeys
        if offered.contains(configKey) { return true }
        var path = configKey
        while let dot = path.lastIndex(of: ".") {
            path = String(path[path.startIndex..<dot])
            if offered.contains(path) { return true }
        }
        return false
    }

     
     
     
     
    static func readerValue(_ deviation: ConfigDeviation) -> String {
        deviation.given.isEmpty ? "—" : deviation.given
    }

     
     
     
    static func scalar(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains(" ") { return trimmed }
         
         
         
         
         
         
         
         
         
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let head = trimmed[trimmed.startIndex..<colon]
            .trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty, !head.contains(" ") else { return nil }
        return head
    }
}
