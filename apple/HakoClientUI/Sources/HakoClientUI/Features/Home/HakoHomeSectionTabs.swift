import SwiftUI

struct HakoHomeSectionTabs: View {
    @Environment(\.locale) private var locale
    @Binding var section: HakoHomeSection
     
    let separator: Color

    var body: some View {
        HakoFullWidthSegmentedPicker(
            selection: $section,
            options: HakoHomeSection.allCases.map { candidate in
                HakoFullWidthSegmentedOption(
                    selection: candidate,
                    title: HakoCopy.string(candidate.title, locale: locale),
                    accessibilityIdentifier:
                        "home.segment.\(candidate.rawValue)"
                )
            },
            role: .pageStrip,
            underlineSeparator: separator
        )
    }
}
