import Hako
import HakoClientUI
import SwiftUI

struct STUNTestView: View {
    @ObservedObject var model: STUNTestModel

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                     
                     
                     
                    TextField(
                        text: $model.server,
                        prompt: Text(verbatim: "stun.example.org:3478")
                    ) {
                        Text("Server")
                    }
                        .accessibilityIdentifier("stun.server")
                    .disabled(model.isRunning)
                } else {
                TextField("Server", text: $model.server)
                    .accessibilityIdentifier("stun.server.compact")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .disabled(model.isRunning)
                }

                Picker("Outbound", selection: $model.selectedOutbound) {
                    ForEach(model.outboundOptions) { option in
                        Text(hako: .copy(option.title)).tag(option.name)
                    }
                }
                    .accessibilityIdentifier("stun.outbound")
                .disabled(model.isRunning)
            } header: {
                Text("Configuration")
            } footer: {
                Text("Follow Rules uses the active routing mode and rules. Selecting an outbound tests that exact UDP-capable proxy or group. Results describe UDP egress for diagnostics only and never change routing.")
            }

            Section("Action") {
                 
                 
                if model.isRunning {
                    Button(role: .destructive) { model.cancel() } label: {
                        Text("Cancel Test")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .hakoSecondaryActionButtonStyle()
                    .hakoCapsuleButtonBorderShape()
                    .controlSize(.regular)
                    .accessibilityIdentifier("stun.cancel")
                } else {
                    Button { model.start() } label: {
                        Text("Start Test")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .hakoPrimaryActionButtonStyle()
                    .hakoCapsuleButtonBorderShape()
                    .controlSize(.regular)
                    .accessibilityIdentifier("stun.start")
                }
            }

            if model.phase >= 0 || !model.lastError.isEmpty {
                Section("Results") {
                    if !model.lastError.isEmpty {
                        HakoStatusMessage(text: .verbatim(model.lastError), kind: .error)
                    }
                    STUNResultRow(
                        title: "External address",
                        value: model.externalAddress.isEmpty ? "—" : model.externalAddress,
                        active: model.isRunning && model.phase == HakoSTUNPhaseBinding
                    )
                    .accessibilityIdentifier("stun.result.externalAddress")
                    STUNResultRow(
                        title: "Address family",
                        value: model.externalAddressFamily == HakoSTUNAddressFamilyUnknown
                            ? "—" : HakoFormatSTUNAddressFamily(model.externalAddressFamily),
                        active: false
                    )
                    STUNResultRow(
                        title: "Latency",
                        value: model.externalAddress.isEmpty ? "—" : "\(model.latencyMilliseconds) ms",
                        active: model.isRunning && model.phase == HakoSTUNPhaseBinding
                    )
                    if model.phase == HakoSTUNPhaseDone && !model.natTypeSupported {
                        STUNResultRow(
                            title: "NAT type detection",
                            value: "Unsupported by server",
                            active: false
                        )
                    } else {
                        STUNResultRow(
                            title: "NAT mapping",
                            value: model.natMapping == HakoNATMappingUnknown
                                ? "—" : HakoFormatNATMapping(model.natMapping),
                            active: model.isRunning && model.phase == HakoSTUNPhaseNATMapping
                        )
                        STUNResultRow(
                            title: "NAT filtering",
                            value: model.natFiltering == HakoNATFilteringUnknown
                                ? "—" : HakoFormatNATFiltering(model.natFiltering),
                            active: model.isRunning && model.phase == HakoSTUNPhaseNATFiltering
                        )
                    }
                }
            }
        }
        
        .hakoPageTitle("STUN Test")
        .task { await model.refreshOutbounds() }
        .onDisappear {
            if model.isRunning { model.cancel() }
        }
    }
}

private struct STUNResultRow: View {
    let title: String
    let value: String
    let active: Bool

    var body: some View {
        HStack {
            Text(hako: .copy(title))
            Spacer()
            if active { ProgressView().controlSize(.small) }
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}


