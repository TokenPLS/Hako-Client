import HakoClientKit
import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
struct HakoMacProfilePicker: View {
    let profiles: [HakoProfileSnapshot]
    let select: (Profile.ID) -> Void

     
     
    private enum Metrics {
        static let rowHeight: CGFloat = 24
        static let horizontalInset: CGFloat = HakoTheme.Spacing.row
        static let checkmarkColumn: CGFloat = 16
        static let minimumWidth: CGFloat = 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hako: "Profiles")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, Metrics.horizontalInset)
                .padding(.top, HakoTheme.Spacing.row)
                .padding(.bottom, HakoTheme.Spacing.compact)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(profiles, id: \.id) { profile in
                    row(for: profile)
                }
            }
            .padding(.vertical, HakoTheme.Spacing.tight)

        }
        .frame(minWidth: Metrics.minimumWidth, alignment: .leading)
        .fixedSize()
    }

    private func row(for profile: HakoProfileSnapshot) -> some View {
        Button {
            select(profile.id)
        } label: {
            HStack(spacing: HakoTheme.Spacing.compact) {
                 
                 
                 
                 
                 
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .opacity(profile.isCurrent ? 1 : 0)
                    .frame(width: Metrics.checkmarkColumn, alignment: .leading)
                 
                Text(verbatim: profile.label)
                Spacer(minLength: HakoTheme.Spacing.row)
                if profile.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, Metrics.horizontalInset)
            .frame(height: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(HakoMacMenuRowButtonStyle())
        .disabled(profile.isBusy)
    }
}

 
 
private struct HakoMacMenuRowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovering ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: HakoTheme.Radius.control - 3)
                    .fill(Color.accentColor)
                    .opacity(isHovering ? 1 : 0)
                    .padding(.horizontal, HakoTheme.Spacing.tight)
            )
            .onHover { isHovering = $0 }
    }
}
