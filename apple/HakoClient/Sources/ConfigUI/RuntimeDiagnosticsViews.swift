import HakoClientUI
import SwiftUI

typealias ClashRule = HakoRuntimeRule

extension HakoRuntimeRule {
    var proxy: String { target }
}

enum ClashRulesPayload {
    static func decode(_ data: Data?) -> [ClashRule] {
        HakoRuntimeRulesPayload.decode(data)
    }
}

typealias DNSQueryAnswer = HakoDNSQueryAnswer

extension HakoDNSQueryAnswer {
    var TTL: Int? { ttl }
}

struct DNSQueryResponse: Decodable {
    let Answer: [DNSQueryAnswer]?
}

 
struct ActiveRulesView: View {
    @ObservedObject var command: ClashCommandClient

    var body: some View {
        HakoActiveRulesView(
            rules: command.rules,
            isConnected: command.isConnected,
            refresh: {
                await command.fetchRules()
            }
        )
    }
}

 
struct DNSQueryView: View {
    @ObservedObject var command: ClashCommandClient

    var body: some View {
        HakoDNSQueryView(
            isConnected: command.isConnected,
            capabilities: HakoDNSQueryCapabilities(
                query: { name, type in
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    if let family = Self.addressFamily(for: type) {
                        let result = await Self.systemAnswer(
                            name: name,
                            type: type,
                            family: family
                        )
                        return HakoDNSResolution(
                            result: result,
                            answerSource: .systemResolver,
                            explain: await Self.explain(
                                command,
                                name: name,
                                type: type,
                                probe: false
                            )
                        )
                    }
                     
                     
                     
                    let explained = await Self.explain(
                        command,
                        name: name,
                        type: type,
                        probe: true
                    )
                     
                     
                     
                     
                    if let probed = explained?.probedResult {
                        return HakoDNSResolution(
                            result: probed,
                            answerSource: .core,
                            explain: explained
                        )
                    }
                     
                     
                    let rawResponse = await command.runDNSQuery(
                        name: name,
                        type: type
                    )
                    return HakoDNSResolution(
                        result: HakoDNSQueryResult(
                            rawResponse: rawResponse,
                            errorMessage:
                                rawResponse == nil
                                && !command.lastError.isEmpty
                                    ? command.lastError
                                    : nil
                        ),
                        answerSource: .core,
                        explain: explained
                    )
                },
                explain: { name, type in
                     
                     
                     
                    await Self.explain(
                        command,
                        name: name,
                        type: type,
                        probe: false
                    )
                },
                maintain: { action in
                    switch action {
                    case .dns:
                        await command.flushDNSCache()
                    case .fakeIP:
                        await command.flushFakeIPCache()
                    }
                    return command.lastError.isEmpty
                        ? nil
                        : command.lastError
                }
            )
        )
    }
}

extension DNSQueryView {
     
     
    static func explain(
        _ command: ClashCommandClient,
        name: String,
        type: String,
        probe: Bool
    ) async -> HakoDNSExplain? {
        guard let json = await command.explainDNS(
            name: name,
            type: type,
            probe: probe
        ) else { return nil }
        guard let explained = HakoDNSExplain.decode(json) else {
             
             
            HakoLogStore.shared.append(
                "dns explain not understood: "
                    + json.prefix(160),
                stream: .app,
                level: .warning
            )
            return nil
        }
        return explained
    }

     
    static func addressFamily(for type: String) -> Int32? {
        switch type {
        case "A": return AF_INET
        case "AAAA": return AF_INET6
        default: return nil
        }
    }

     
    static func recordCode(for type: String) -> Int {
        type == "AAAA" ? 28 : 1
    }

    static func systemAnswer(
        name: String,
        type: String,
        family: Int32
    ) async -> HakoDNSQueryResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return HakoDNSQueryResult(answers: [], errorMessage: nil)
        }
        let addresses = await Task.detached(priority: .userInitiated) {
            LocalMappingEffect.systemAddresses(for: trimmed, family: family)
        }.value
        guard !addresses.isEmpty else {
            return HakoDNSQueryResult(
                answers: [],
                errorMessage: "No address was returned for this name."
            )
        }
        return HakoDNSQueryResult(
            answers: addresses.map { address in
                HakoDNSQueryAnswer(
                    name: trimmed,
                    type: recordCode(for: type),
                     
                     
                    ttl: nil,
                    data: address
                )
            }
        )
    }
}
