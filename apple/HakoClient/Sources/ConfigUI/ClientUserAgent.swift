import Foundation
import Hako

 
 
 
 
 
 
 
 
enum ClientUserAgent {
    enum Preset: String, CaseIterable, Identifiable {
        case hako
        case flclash
        case clashVerge
        case clashForWindows

        var id: String { rawValue }

        var label: String {
            switch self {
            case .hako: return "Clash (Default)"
            case .flclash: return "FlClash"
            case .clashVerge: return "Clash Verge"
            case .clashForWindows: return "Clash for Windows"
            }
        }

        var value: String {
            switch self {
            case .hako:
                let app = Bundle.main
                    .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                let build = Bundle.main
                    .object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
                 
                 
                 
                 
                 
                let head = "clash.meta/\(HakoVersion()) Hako/\(HakoDeviceModel.appToken(version: app, build: build))"
                guard let tail = HakoDeviceModel.userAgentTail else { return head }
                return head + " " + tail
            case .flclash:
                 
                return "FlClash/v0.8.94 clash-verge Platform/android"
            case .clashVerge:
                 
                return "clash-verge/v2.4.2"
            case .clashForWindows:
                 
                return "ClashforWindows/0.19.23"
            }
        }
    }

    static let presetKey = "ua.preset"
    private static let maximumBytes = 512

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func preset(from d: UserDefaults = appGroupDefaults) -> Preset {
        Preset(rawValue: d.string(forKey: presetKey) ?? "") ?? .hako
    }

    static func save(preset: Preset, in d: UserDefaults = appGroupDefaults) {
        d.set(preset.rawValue, forKey: presetKey)
    }

     
     
    static func resolved(configYAML: String, fallback: String) -> String {
        guard let json = try? ConfigTransforms.yamlToJSON(configYAML),
              let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let root = object as? [String: Any],
              let value = sanitized(root["global-ua"] as? String) else {
            return fallback
        }
        return value
    }

     
     
     
    static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...maximumBytes).contains(candidate.utf8.count),
              candidate.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        return candidate
    }
}
