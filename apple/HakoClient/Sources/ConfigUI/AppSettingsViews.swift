import HakoClientUI
import SwiftUI

 
 
private enum AppearanceDoor: String, Identifiable {
    case language
    var id: String { rawValue }
}

struct AppearanceSettingsView: View {
    @ObservedObject var preferences: AppPreferencesModel
    let usesRegularDetailLayout: Bool
    @State private var doorSelection: AppearanceDoor?

    private var languageDestination: some View {
        LanguageSelectionView(
            selection: $preferences.language
        )
        .hakoRegularDetailPageLayout(
            enabled: usesRegularDetailLayout
        )
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                 
                 
                 
                 
                 
                 
                 
                 
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Picker(
                        "Language",
                        selection: $preferences.language
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .accessibilityIdentifier("appearance.language")
                } else {
                    HakoDoorLink(
                        AppearanceDoor.language,
                        selection: $doorSelection
                    ) {
                        languageDestination
                    } label: {
                        HStack {
                            Text("Language")
                            Spacer()
                            Text(preferences.language.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("appearance.language")
                }
            } footer: {
                 
                 
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Text(
                        "The language changes when Clash reopens. System Default follows the language selected in System Settings."
                    )
                } else {
                    Text(
                        "Changes apply immediately. System Default follows the language selected in iOS Settings."
                    )
                }
            }

            Section {
                Picker(
                    "Theme Mode",
                    selection: $preferences.themeMode
                ) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .hakoIdiomFormPickerStyle()
                .accessibilityIdentifier("appearance.theme")

                Picker(
                    "Accent Color",
                    selection: $preferences.accent
                ) {
                    ForEach(AppAccent.allCases) { accent in
                        Label {
                            Text(accent.title)
                        } icon: {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 12, height: 12)
                        }
                        .tag(accent)
                    }
                }
                .accessibilityIdentifier("appearance.accent")

                 
                 
                 
                 
                 
                 
                 
                if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Toggle(
                        "Pure Black in Dark Mode",
                        isOn: $preferences.pureBlack
                    )
                    .accessibilityIdentifier("appearance.pureBlack")
                }
            } header: {
                Text("Theme")
            } footer: {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Text(
                        "System Dynamic uses the app's native adaptive tint."
                    )
                } else {
                    Text(
                        "System Dynamic uses the app's native adaptive tint. Pure black affects dark backgrounds while preserving semantic surfaces and contrast."
                    )
                }
            }

            Section {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Label(
                        "Text size follows the system text size and accessibility settings.",
                        systemImage: HakoSymbol.infoCircle.name
                    )
                    .foregroundStyle(.secondary)
                } else {
                    Label(
                        "Text size follows iOS Dynamic Type and accessibility settings.",
                        systemImage: HakoSymbol.infoCircle.name
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        
        .hakoDoorPresenter(
            selection: $doorSelection,
            title: { _ in "Language" }
        ) { _ in
            languageDestination
        }
        .hakoPageTitle("Appearance")
    }
}

private struct LanguageSelectionView: View {
    @Environment(\.presentationMode)
    private var presentationMode
    @Binding var selection: AppLanguage

    private var pickerSelection: Binding<AppLanguage?> {
        Binding(
            get: { nil },
            set: { value in
                guard let value else { return }
                selection = value
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        )
    }

    var body: some View {
        Group {
             
             
             
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                List(selection: pickerSelection) {
                    Section {
                        ForEach(AppLanguage.allCases) { language in
                            HStack {
                                Text(language.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection == language {
                                    Image(
                                        systemName:
                                            HakoSymbol.checkmark.rawValue
                                    )
                                    .foregroundStyle(.tint)
                                }
                            }
                            .tag(language)
                            .accessibilityIdentifier(
                                "appearance.language.\(language.rawValue)"
                            )
                        }
                    }
                }
            } else {
                List {
                    Section {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                selection = language
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack(spacing: HakoTheme.Spacing.row) {
                                    HakoSelectionMark(
                                        isSelected: selection == language
                                    )
                                    Text(language.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                            .accessibilityIdentifier(
                                "appearance.language.\(language.rawValue)"
                            )
                        }
                    }
                }
            }
        }
#if os(macOS)
        .listStyle(.inset)
#else
        .hakoInsetGroupedListStyle()
#endif
        .hakoMacSettingsList(minRowHeight: 30)
        .hakoPageTitle("Language")
    }
}


