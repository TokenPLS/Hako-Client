import Foundation
import Hako
import OSLog

enum ProxyImportContext: String {
    case singleNode
    case nodeBundle
    case subscriptionBody
    case configuration
}

struct ProxyImportIssue: Equatable {
    let index: Int
    let scheme: String
    let code: String
    let message: String

     
     
     
     
     
     
    var alsoNotHonoured: [String] = []

     
     
     
     
     
     
    var line: Int?

     
     
     
     
     
     
     
     
    var proxy: String = ""
}

 
 
 
 
struct ProxyPayloadShape {
    let isConfiguration: Bool
    let hasInlineProxies: Bool
    let hasProxyProviders: Bool
    let recognizedKeys: [String]
    let unrecognizedKeys: [String]
}

struct ProxyImportResult {
    let format: String
    let context: ProxyImportContext
    let proxies: [[String: Any]]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    let skipped: [ProxyImportIssue]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    let notHonoured: [ProxyImportIssue]

     
     
     
     
     
     
     
     
     
     
     
     
    let identities: [String]
    let shape: ProxyPayloadShape?

    var issues: [ProxyImportIssue] {
        skipped
    }

     
     
     
     
     
    func duplicateNodeOffsets() -> [Int] {
        guard !identities.isEmpty, identities.count == proxies.count else { return [] }
        var seen = Set<String>()
        return identities.enumerated().compactMap {
            seen.insert($0.element).inserted ? nil : $0.offset
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func explanation(for issue: ProxyImportIssue) -> String {
        guard !issue.alsoNotHonoured.isEmpty else { return issue.message }
        return issue.message + "; " + issue.alsoNotHonoured.joined(separator: "; ")
    }

     
     
     
     
     
    var sentence: String {
        let folded = duplicateNodeOffsets().count
        var clauses: [String] = []
        if !skipped.isEmpty {
            clauses.append(String(format: String(localized: "%d not imported"), skipped.count))
        }
        if folded > 0 {
            clauses.append(String(format: String(localized: "%d duplicate"), folded))
        }
        clauses.append(String(
            format: String(localized: "%d imported"), proxies.count - folded
        ))
        return clauses.joined(separator: " · ")
    }

    func fieldsLeftBehind() -> [String: [ProxyImportIssue]] {
        Dictionary(grouping: notHonoured.filter { !$0.proxy.isEmpty }, by: \.proxy)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    func summarySentence(renamed: [(from: String, to: String)] = [],
                         duplicatesFolded: Int = 0) -> String {
        var parts: [String] = []
        parts.append("\(proxies.count) imported")
        if !issues.isEmpty { parts.append("\(issues.count) skipped") }
        if duplicatesFolded > 0 { parts.append("\(duplicatesFolded) duplicates not imported") }
        if !renamed.isEmpty {
            let shown = renamed.prefix(3)
                .map { "\($0.from) → \($0.to)" }
                .joined(separator: ", ")
            let more = renamed.count > 3 ? " and \(renamed.count - 3) more" : ""
            parts.append("renamed \(shown)\(more)")
        }
        if !notHonoured.isEmpty { parts.append("\(notHonoured.count) fields did not carry over") }
        return parts.joined(separator: " · ")
    }
}

enum ProxyImportBridgeError: LocalizedError {
    case bridgeReturnedNil(String)
    case invalidResult
    case rejected([ProxyImportIssue])

    var errorDescription: String? {
        switch self {
        case .bridgeReturnedNil(let message):
            return message
        case .invalidResult:
            return "The share link could not be read."
        case .rejected(let issues):
             
             
             
             
             
             
            guard let first = issues.first else {
                return "That text does not contain a node share link."
            }
            return first.message
        }
    }
}

 
 
 
enum ProxyImportBridge {
    static func inspect(_ data: Data, context: ProxyImportContext) throws -> ProxyImportResult {
        var error: NSError?
        guard let box = HakoInspectProxyPayloadForIOS(data, context.rawValue, &error) else {
            throw error.map { ProxyImportBridgeError.bridgeReturnedNil($0.localizedDescription) }
                ?? ProxyImportBridgeError.bridgeReturnedNil("The share link could not be read.")
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(box.value.utf8))
                as? [String: Any],
              let format = root["format"] as? String,
              let rawContext = root["context"] as? String,
              let decodedContext = ProxyImportContext(rawValue: rawContext),
              let proxies = root["proxies"] as? [[String: Any]] else {
            throw ProxyImportBridgeError.invalidResult
        }
        return ProxyImportResult(
            format: format,
            context: decodedContext,
            proxies: proxies,
             
             
             
             
             
            skipped: issues(root["skipped"])
                + issues(root["rejectedRecords"])
                + issues(root["recognizedUnsupported"]),
            notHonoured: issues(root["notHonoured"]),
            identities: root["identities"] as? [String] ?? [],
            shape: shape(root["payloadShape"])
        )
    }

     
     
     
     
     
     

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func derivedSubscriptionYAML(from source: Data) throws -> String {
        try derivedSubscription(from: source).yaml
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func derivedSubscription(
        from source: Data
    ) throws -> (yaml: String, kept: Int, skipped: [ProxyImportIssue]) {
        guard let text = String(data: source, encoding: .utf8) else {
            throw SubscriptionError.notUTF8
        }
        var sourceValidationError: Error?
        var validated = false
        do {
            try ConfigTransforms.validateSource(text)
            validated = true
        } catch {
            sourceValidationError = error
        }
        let inspected = Result { try inspect(source, context: .subscriptionBody) }

        if validated {
             
             
             
             
             
             
             
             
            if let shape = try? inspected.get().shape, shape.isConfiguration {
                return (text, 0, [])
            }
        }

        let result: ProxyImportResult
        do {
            result = try inspected.get()
        } catch {
             
             
             
             
             
             
            throw validated ? error : (sourceValidationError ?? error)
        }
        guard !result.proxies.isEmpty else {
            throw result.issues.isEmpty
                ? (sourceValidationError ?? ProxyImportBridgeError.invalidResult)
                : ProxyImportBridgeError.rejected(result.issues)
        }
        log(skipped: result.issues, keeping: result.proxies.count)
        log(notHonoured: result.notHonoured)
        let data = try JSONSerialization.data(withJSONObject: ["proxies": result.proxies])
        let yaml = try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
        return (yaml, result.proxies.count, result.issues)
    }

     
     
     
    private static func log(skipped issues: [ProxyImportIssue], keeping kept: Int) {
        guard !issues.isEmpty else { return }
        for issue in issues {
            let line = "record \(issue.index) (\(issue.scheme)): \(issue.code) -- \(issue.message)"
            capabilityLog.error(
                """
                proxy import: subscription kept \(kept) node(s) and skipped \
                \(issues.count) -- \(line, privacy: .public)
                """
            )
        }
    }

     
     
    static func log(notHonoured: [ProxyImportIssue]) {
        for issue in notHonoured {
            capabilityLog.notice(
                "proxy import: field left behind -- \(issue.message, privacy: .public)"
            )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let profilePasteNodeSchemes: Set<String> = {
        do {
            guard let schemes = try capabilityDocument()["schemes"] as? [[String: Any]] else {
                throw ProxyImportBridgeError.invalidResult
            }
            return Set(schemes.compactMap { item in
                guard item["pasteRole"] as? String == "node" else { return nil }
                return item["scheme"] as? String
            })
        } catch {
            let reason = error.localizedDescription
            capabilityLog.error(
                """
                proxy import: the Core capability registry is unreadable, so no \
                pasted scheme routes as a node -- \(reason, privacy: .public)
                """
            )
            return []
        }
    }()

    private static let capabilityLog = Logger(
        subsystem: "org.example.hako", category: "proxyimport")

    private static func capabilityDocument() throws -> [String: Any] {
        guard let box = HakoProxyImportCapabilitiesForIOS() else {
            throw ProxyImportBridgeError.bridgeReturnedNil(
                "The share link could not be read."
            )
        }
        guard let root = try JSONSerialization.jsonObject(with: Data(box.value.utf8))
                as? [String: Any] else {
            throw ProxyImportBridgeError.invalidResult
        }
        return root
    }

     
     
     
    private static func shape(_ raw: Any?) -> ProxyPayloadShape? {
        guard let d = raw as? [String: Any],
              let isConfiguration = d["isConfiguration"] as? Bool else { return nil }
        return ProxyPayloadShape(
            isConfiguration: isConfiguration,
            hasInlineProxies: d["hasInlineProxies"] as? Bool ?? false,
            hasProxyProviders: d["hasProxyProviders"] as? Bool ?? false,
            recognizedKeys: d["recognizedKeys"] as? [String] ?? [],
            unrecognizedKeys: d["unrecognizedKeys"] as? [String] ?? []
        )
    }

    private static func issues(_ raw: Any?) -> [ProxyImportIssue] {
        guard let items = raw as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let index = item["index"] as? Int,
                  let scheme = item["scheme"] as? String,
                  let code = item["code"] as? String,
                  let message = item["message"] as? String else { return nil }
            return ProxyImportIssue(
                index: index, scheme: scheme, code: code, message: message,
                alsoNotHonoured: item["alsoNotHonoured"] as? [String] ?? [],
                line: item["line"] as? Int,
                 
                 
                 
                 
                 
                proxy: item["proxy"] as? String ?? ""
            )
        }
    }
}
