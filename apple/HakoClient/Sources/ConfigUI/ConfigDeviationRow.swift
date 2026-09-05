import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ConfigDeviationRow: View {

    @Environment(\.locale) private var locale
    let deviation: ConfigDeviation
     
     
    var identifierPrefix: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.compact) {
             
             
             
             
             
            if deviation.effect?.isLoud == true {
                Image(systemName: HakoSymbol.exclamationmarkTriangleFill.rawValue)
                    .foregroundStyle(Color.orange)
                    .accessibilityIdentifier(identifierPrefix + ".loud")
            }
            body(for: deviation)
        }
         
         
         
         
        .accessibilityIdentifier(
            identifierPrefix + "." + deviation.title.replacingOccurrences(of: " ", with: "-")
        )
    }

    private func body(for deviation: ConfigDeviation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
             
             
            Text(hako: .verbatim(deviation.title))
                .font(.subheadline)
             
             
             
             
             
            Text(hako: DeviationPlainLanguage.whatHappened(deviation, locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let pair = DeviationPlainLanguage.valuePair(deviation, locale: locale) {
                Text(hako: pair)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        identifierPrefix + ".given."
                            + deviation.title.replacingOccurrences(of: " ", with: "-")
                    )
            }
            if let action = DeviationPlainLanguage.whatToDo(deviation, locale: locale) {
                 
                 
                Text(hako: action)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
             
             
             
             
             
             
             
             
             
             
             
        }
    }

}

 
 
 
 
 
 
 
 
 
 
 
 
struct ConfigDeviationSection: View {
    let report: ConfigDeviationReport?
     
     
    let fields: [String]
    var identifierPrefix: String

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static let visibleBeforeShowAll = 4
    @State private var revealed = false

    private var shown: [ConfigDeviation] {
        revealed ? matches : Array(matches.prefix(Self.visibleBeforeShowAll))
    }

    private var matches: [ConfigDeviation] {
        guard let report else { return [] }
        return Self.rows(in: report, fields: fields)
    }

     
     
     
     
     
     
     
    static func rows(
        in report: ConfigDeviationReport,
        fields: [String]
    ) -> [ConfigDeviation] {
        report.deviations.filter { claims(fields, $0.configKey) }
    }

     
     
     
     
     
     
     
    static func claims(_ keys: [String], _ key: String) -> Bool {
        keys.contains { claim in
            claim.hasSuffix(".") ? key.hasPrefix(claim) : key == claim
        }
    }

    var body: some View {
         
         
         
         
         
        if !matches.isEmpty {
            Section {
                ForEach(shown) { deviation in
                    ConfigDeviationRow(deviation: deviation, identifierPrefix: identifierPrefix)
                }
                if shown.count < matches.count {
                    Button {
                        revealed = true
                    } label: {
                        Text(hako: .format(
                            "Show all %@ fields",
                            ["\(matches.count)"]
                        ))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier(identifierPrefix + ".show-all")
                }
            } header: {
                 
                 
                 
                Text(hako: .format(
                    "What the Running Core Did (%@)",
                    ["\(matches.count)"]
                ))
                    .accessibilityIdentifier(identifierPrefix + ".heading")
            } footer: {
                Text("Reported by the core that is running, about the fields on this page. Editing them changes the next start, not this one.")
            }
        }
    }
}
