import SwiftUI

struct HakoDNSHubRow: View {
    let title: String
    let detail: String
    let value: String?
     
     
     
     
    var inlineDetail = false

    var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
            HakoMacNavigationRowLabel(
                .copy(title),
                subtitle: inlineDetail && !detail.isEmpty
                    ? .copy(detail) : nil,
                value: value.map { .copy($0) }
            )
        } else {
            legacyBody
        }
    }

    @ViewBuilder
    private var legacyBody: some View {
#if os(macOS)
         
         
         
         
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.row
        ) {
            Text(hako: .copy(title))
            Spacer(minLength: HakoTheme.Spacing.compact)
            if let value {
                Text(hako: .copy(value))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6.5)
#else
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.row
        ) {
            VStack(alignment: .leading, spacing: 2) {
                 
                 
                 
                 
                 
                 
                Text(hako: .copy(title))
                if !detail.isEmpty {
                    Text(hako: .copy(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if let value {
                Text(hako: .copy(value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
#endif
    }
}
