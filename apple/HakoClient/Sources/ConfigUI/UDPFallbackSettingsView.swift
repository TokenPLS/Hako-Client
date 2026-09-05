import HakoClientUI
import SwiftUI

 
 
 
 
 
struct UDPFallbackSettingsView: View {
     
     
    @Binding var policy: UDPFallbackPolicy?
     
     
     
     
     
    @State private var shownPolicy: UDPFallbackPolicy?
     
    let offersInherit: Bool
     
     
     
     
     
     
     
     
     
     
    let overallPolicy: UDPFallbackPolicy
     
    var profileOverride: UDPFallbackPolicy?
     
     
     
     
     
     
    var guardInput: () async -> ConfigTransforms.UDPFallbackGuardInput? = { nil }
    @State private var guardInputValue: ConfigTransforms.UDPFallbackGuardInput?

     
     
     
     
     
    static func policyInForce(
        profileOverride: UDPFallbackPolicy?,
        shown: UDPFallbackPolicy?,
        overall: UDPFallbackPolicy
    ) -> UDPFallbackPolicy {
        profileOverride ?? shown ?? overall
    }

     
     
     
    private var coverage: UDPFallbackGuard.Coverage? {
        guard let guardInputValue else { return nil }
        return UDPFallbackGuard.displayCoverage(
            for: Self.policyInForce(
                profileOverride: profileOverride,
                shown: shownPolicy,
                overall: overallPolicy
            ),
            input: guardInputValue
        )
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            if offersInherit {
                Section {
                    inheritRow
                        .accessibilityIdentifier("udp.fallback.inherit")
                } footer: {
                    Text(hako: .copy("Follows the client setting."))
                }
            }

            if let profileOverride, profileOverride != shownPolicy {
                Section {
                    Text(hako: .formatCopy(
                        "The active profile overrides this: %@ is in force.",
                        [title(of: profileOverride)]
                    ))
                    .accessibilityIdentifier("udp.fallback.profile-override")
                } footer: {
                    Text(hako: .copy(
                        "This page sets the default for every profile. Change it on the profile to take the override off."
                    ))
                }
            }

            if let coverage {
                Section {
                    Text(hako: .copy(
                        "Already covered by a rule in this configuration. Nothing is added."
                    ))
                    .accessibilityIdentifier("udp.fallback.coverage")
                    Text(verbatim: coverage.ruleText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(hako: .copy(coverageFooter(coverage)))
                }
            }

            ForEach(UDPFallbackPolicy.allCases, id: \.self) { option in
                Section {
                    row(
                        title: title(of: option),
                        isSelected: shownPolicy == option
                    ) {
                        shownPolicy = option
                        policy = option
                    }
                    .accessibilityIdentifier("udp.fallback.\(option.rawValue)")
                } footer: {
                    Text(hako: .copy(footer(of: option)))
                }
            }

            Section {
            } footer: {
                 
                Text(hako: .copy(
                    "None of these apply while the outbound carries UDP. Hysteria2, TUIC and any line with udp on — including UDP over TCP — take the rule as matched and never reach this."
                ))
            }
        }
        
        .onAppear { shownPolicy = policy }
        .task { guardInputValue = await guardInput() }
        .navigationTitle(Text(hako: .copy("UDP Fallback")))
         
         
        .hakoDetailPageInsets()
    }

     
     
     
    private var inheritRow: some View {
        row(
            title: nil,
            display: .formatCopy("Same as overall (%@)", [title(of: overallPolicy)]),
            isSelected: shownPolicy == nil
        ) {
            shownPolicy = nil
            policy = nil
        }
    }

     
    private func row(
        title: String?,
        display: HakoDisplayText? = nil,
        isSelected: Bool,
        select: @escaping () -> Void
    ) -> some View {
        Button(action: select) {
            HStack(spacing: 8) {
                 
                 
                 
                 
                Group {
                    if isSelected {
                        Image(systemName: HakoSymbol.checkmark.rawValue)
                            .font(.body)
                            .foregroundStyle(.tint)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 20)
                Text(hako: display ?? .copy(title ?? ""))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
            }
            .frame(
                maxWidth: .infinity,
                 
                 
                minHeight: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    ? 0
                    : HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
         
         
         
        .buttonStyle(.plain)
    }

    private func title(of policy: UDPFallbackPolicy) -> String {
        switch policy {
        case .quic: "Reject QUIC"
        case .quicAllPorts: "Reject QUIC on 443 and 80"
        case .allUDP: "Reject all fallthrough UDP"
        case .off: "Off"
        }
    }

    private func footer(of policy: UDPFallbackPolicy) -> String {
        switch policy {
        case .quic:
             
             
             
             
             
            "Rejects UDP on port 443 that no rule could carry. Web and API traffic falls back to HTTP/2 through the proxy instead of leaving over DIRECT. Games, FaceTime, voice calls and STUN are untouched."
        case .quicAllPorts:
            "Adds the rarely used HTTP/3 port. Same behaviour otherwise."
        case .allUDP:
            "Nothing leaks. Games, voice and video calls that relied on the fallthrough will stop working unless a rule sends them to DIRECT — they have no TCP fallback to drop to."
        case .off:
            "Traffic the outbound cannot carry leaves over DIRECT with your own address, and the connection shows no rule name. UDP applications are never interrupted."
        }
    }

    private func coverageFooter(_ coverage: UDPFallbackGuard.Coverage) -> String {
        coverage.precedesMatch
            ? "That rule runs before MATCH, so it also rejects QUIC on traffic headed for DIRECT — wider than this setting would go."
            : "This configuration already rejects the traffic this setting covers."
    }
}
