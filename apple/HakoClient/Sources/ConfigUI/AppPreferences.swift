import Hako
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .simplifiedChinese: return "Simplified Chinese"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return Locale(identifier: Locale.preferredLanguages.first ?? "en")
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case system
    case blue
    case indigo
    case purple
    case green
    case orange
    case pink

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System Dynamic"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        }
    }

    var color: Color {
        switch self {
        case .system: return .accentColor
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        }
    }
}

enum AppPreferences {
    static let languageKey = "app.language"
    static let themeModeKey = "app.themeMode"
    static let accentKey = "app.accent"
    static let pureBlackKey = "app.pureBlack"



     
     
     
     
     
     
     
     
     
     
     
     
     
    static func publishBundleLanguage(_ language: AppLanguage) {
        let standard = UserDefaults.standard
        switch language {
        case .system:
             
             
            standard.removeObject(forKey: bundleLanguageKey)
        case .english:
            standard.set(["en"], forKey: bundleLanguageKey)
        case .simplifiedChinese:
            standard.set(["zh-Hans"], forKey: bundleLanguageKey)
        }
    }

    static let bundleLanguageKey = "AppleLanguages"

    static func language(from defaults: UserDefaults = GlobalConfig.appGroupDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: languageKey) ?? "") ?? .system
    }

    static func themeMode(from defaults: UserDefaults = GlobalConfig.appGroupDefaults) -> AppThemeMode {
        AppThemeMode(rawValue: defaults.string(forKey: themeModeKey) ?? "") ?? .system
    }

    static func accent(from defaults: UserDefaults = GlobalConfig.appGroupDefaults) -> AppAccent {
        AppAccent(rawValue: defaults.string(forKey: accentKey) ?? "") ?? .system
    }

    static func pureBlack(from defaults: UserDefaults = GlobalConfig.appGroupDefaults) -> Bool {
        defaults.bool(forKey: pureBlackKey)
    }


}

final class AppPreferencesModel: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: AppPreferences.languageKey)
            AppPreferences.publishBundleLanguage(language)
        }
    }
    @Published var themeMode: AppThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: AppPreferences.themeModeKey) }
    }
    @Published var accent: AppAccent {
        didSet { defaults.set(accent.rawValue, forKey: AppPreferences.accentKey) }
    }
    @Published var pureBlack: Bool {
        didSet { defaults.set(pureBlack, forKey: AppPreferences.pureBlackKey) }
    }



    private let defaults: UserDefaults

    init(defaults: UserDefaults = GlobalConfig.appGroupDefaults) {
        self.defaults = defaults
        language = AppPreferences.language(from: defaults)
        themeMode = AppPreferences.themeMode(from: defaults)
        accent = AppPreferences.accent(from: defaults)
        pureBlack = AppPreferences.pureBlack(from: defaults)


    }

    func resetToDefaults() {
        language = .system
        themeMode = .system
        accent = .system
        pureBlack = false


    }
}

struct AppBuildInfo: Equatable {
    let appVersion: String
    let buildNumber: String
    let coreVersion: String
    let sourceRevision: String

    var versionLine: String { "\(appVersion) (\(buildNumber))" }

    static func current(bundle: Bundle = .main, coreVersion: String = HakoVersion()) -> AppBuildInfo {
        resolve(info: bundle.infoDictionary ?? [:], coreVersion: coreVersion)
    }

    static func resolve(info: [String: Any], coreVersion: String) -> AppBuildInfo {
        let version = nonempty(info["CFBundleShortVersionString"] as? String) ?? "—"
        let build = nonempty(info["CFBundleVersion"] as? String) ?? "—"
        let revision = nonempty(info["HakoSourceRevision"] as? String) ?? "—"
        return AppBuildInfo(
            appVersion: version,
            buildNumber: build,
            coreVersion: nonempty(coreVersion) ?? "—",
            sourceRevision: revision
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
