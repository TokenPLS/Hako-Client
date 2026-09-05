import Foundation

struct ProxyGroupDetailRow: Equatable, Identifiable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}

struct ProxyGroupDetailSection: Equatable, Identifiable, Sendable {
    let title: String
    let rows: [ProxyGroupDetailRow]

    var id: String { title }
}

struct ProxyGroupConfigurationDetails: Equatable, Sendable {
    let scenarioID: String
    let typeID: String
    let displayName: String
    let summary: String
    let memberSource: String
    let sections: [ProxyGroupDetailSection]

    var visibleText: String {
        ([displayName, summary, memberSource] + sections.flatMap { section in
            [section.title] + section.rows.flatMap { [$0.label, $0.value] }
        }).joined(separator: " ")
    }
}

struct ProxyGroupSpecification: Equatable, Sendable {
    let typeID: String
    let displayName: String
    let summary: String
    let aliases: [String]
}

 
 
 
enum ProxyGroupConfigurationCatalog {
    static let formalTypeIDs = ["select", "url-test", "fallback", "load-balance"]

    static let formalScenarioIDs = [
        "manual-explicit",
        "manual-provider",
        "manual-mixed",
        "fastest-explicit",
        "fastest-provider",
        "fallback-explicit",
        "fallback-provider",
        "load-balance-consistent-hashing",
        "load-balance-round-robin",
        "load-balance-sticky-sessions",
        "include-all",
        "include-all-proxies",
        "include-all-providers",
        "nested-groups",
        "filtered-empty-fallback",
        "hidden-presentation",
    ]

    static let specifications: [ProxyGroupSpecification] = [
        .init(
            typeID: "select",
            displayName: "Manual Selection",
            summary: "Uses the route selected by the user and keeps that choice until it changes.",
            aliases: ["selector"]
        ),
        .init(
            typeID: "url-test",
            displayName: "Fastest Available",
            summary: "Measures available routes and automatically uses the lowest-latency result.",
            aliases: ["urltest", "url test"]
        ),
        .init(
            typeID: "fallback",
            displayName: "Ordered Fallback",
            summary: "Uses the first healthy route in configured order and falls back when it fails.",
            aliases: []
        ),
        .init(
            typeID: "load-balance",
            displayName: "Load Balance",
            summary: "Distributes connections across healthy routes using the configured strategy.",
            aliases: ["loadbalance", "load balance"]
        ),
    ]

    private static let lookup: [String: ProxyGroupSpecification] = {
        var result: [String: ProxyGroupSpecification] = [:]
        for specification in specifications {
            for value in [specification.typeID, specification.displayName] + specification.aliases {
                result[normalize(value)] = specification
            }
        }
        return result
    }()

    static func specification(for rawType: String) -> ProxyGroupSpecification? {
        lookup[normalize(rawType)]
    }

    static func details(
        for mapping: [String: Any],
        knownGroupNames: Set<String> = []
    ) -> ProxyGroupConfigurationDetails? {
        guard let rawType = mapping["type"] as? String,
              let specification = specification(for: rawType) else { return nil }

        let source = memberSource(mapping, knownGroupNames: knownGroupNames)
        var sections = [
            ProxyGroupDetailSection(title: "Overview", rows: [
                .init(label: "Group Type", value: specification.displayName),
                .init(label: "Behavior", value: behavior(mapping, typeID: specification.typeID)),
            ]),
        ]

        let memberRows = memberRows(mapping, source: source)
        if !memberRows.isEmpty {
            sections.append(.init(title: "Members", rows: memberRows))
        }

        let selectionRows = selectionRows(mapping, typeID: specification.typeID)
        if !selectionRows.isEmpty {
            sections.append(.init(title: "Selection", rows: selectionRows))
        }

        let healthRows = healthRows(mapping, typeID: specification.typeID)
        if !healthRows.isEmpty {
            sections.append(.init(title: "Health Check", rows: healthRows))
        }

        let presentationRows = presentationRows(mapping)
        if !presentationRows.isEmpty {
            sections.append(.init(title: "Presentation", rows: presentationRows))
        }

        return ProxyGroupConfigurationDetails(
            scenarioID: mapping["hako-scenario-id"] as? String
                ?? "runtime-\(specification.typeID)",
            typeID: specification.typeID,
            displayName: specification.displayName,
            summary: specification.summary,
            memberSource: source,
            sections: sections
        )
    }

     
     
    static let simulatedConfigurations: [[String: Any]] = [
        [
            "hako-scenario-id": "manual-explicit",
            "name": "Manual Choice",
            "type": "select",
            "proxies": ["Singapore 01", "Tokyo 02", "DIRECT"],
            "default-selected": "Tokyo 02",
            "disable-udp": false,
        ],
        [
            "hako-scenario-id": "manual-provider",
            "name": "Provider Choice",
            "type": "select",
            "use": ["Airport A"],
            "filter": "HK|SG|JP",
            "exclude-filter": "Maintenance",
            "exclude-type": "HTTP|SOCKS5",
            "empty-fallback": "COMPATIBLE",
        ],
        [
            "hako-scenario-id": "manual-mixed",
            "name": "Mixed Sources",
            "type": "select",
            "proxies": ["DIRECT", "Tokyo 02"],
            "use": ["Airport A", "Airport B"],
        ],
        [
            "hako-scenario-id": "fastest-explicit",
            "name": "Fastest Route",
            "type": "url-test",
            "proxies": ["Singapore 01", "Tokyo 02", "Los Angeles 03"],
            "url": "https://fixture.invalid/generate_204",
            "interval": 300,
            "timeout": 5000,
            "max-failed-times": 5,
            "lazy": true,
            "expected-status": "204",
            "tolerance": 120,
        ],
        [
            "hako-scenario-id": "fastest-provider",
            "name": "Provider Fastest",
            "type": "url-test",
            "use": ["Airport A"],
            "filter": "Premium",
            "interval": 600,
            "tolerance": 80,
        ],
        [
            "hako-scenario-id": "fallback-explicit",
            "name": "Ordered Fallback",
            "type": "fallback",
            "proxies": ["Singapore 01", "Tokyo 02", "Los Angeles 03"],
            "url": "https://fixture.invalid/generate_204",
            "interval": 300,
            "lazy": false,
            "expected-status": "200/204",
        ],
        [
            "hako-scenario-id": "fallback-provider",
            "name": "Provider Fallback",
            "type": "fallback",
            "use": ["Airport B"],
            "filter": "Stable",
            "empty-fallback": "DIRECT",
        ],
        [
            "hako-scenario-id": "load-balance-consistent-hashing",
            "name": "Consistent Hash",
            "type": "load-balance",
            "proxies": ["Singapore 01", "Tokyo 02", "Los Angeles 03"],
            "strategy": "consistent-hashing",
            "url": "https://fixture.invalid/generate_204",
            "interval": 300,
        ],
        [
            "hako-scenario-id": "load-balance-round-robin",
            "name": "Round Robin",
            "type": "load-balance",
            "proxies": ["Singapore 01", "Tokyo 02", "Los Angeles 03"],
            "strategy": "round-robin",
            "disable-udp": true,
        ],
        [
            "hako-scenario-id": "load-balance-sticky-sessions",
            "name": "Sticky Sessions",
            "type": "load-balance",
            "use": ["Airport A"],
            "strategy": "sticky-sessions",
        ],
        [
            "hako-scenario-id": "include-all",
            "name": "All Sources",
            "type": "select",
            "include-all": true,
        ],
        [
            "hako-scenario-id": "include-all-proxies",
            "name": "All Local Proxies",
            "type": "select",
            "include-all-proxies": true,
            "exclude-filter": "Deprecated",
        ],
        [
            "hako-scenario-id": "include-all-providers",
            "name": "All Providers",
            "type": "url-test",
            "include-all-providers": true,
            "filter": "Premium",
            "exclude-type": "HTTP",
            "interval": 300,
        ],
        [
            "hako-scenario-id": "nested-groups",
            "name": "Nested Policy",
            "type": "select",
            "proxies": ["Manual Choice", "Fastest Route", "DIRECT"],
        ],
        [
            "hako-scenario-id": "filtered-empty-fallback",
            "name": "Empty Fallback",
            "type": "select",
            "use": ["Airport A"],
            "filter": "Matches Nothing",
            "empty-fallback": "COMPATIBLE",
        ],
        [
            "hako-scenario-id": "hidden-presentation",
            "name": "Hidden Utility",
            "type": "select",
            "proxies": ["DIRECT"],
            "hidden": true,
            "icon": "https://fixture.invalid/icon.png",
        ],
    ]

    private static func memberSource(
        _ mapping: [String: Any],
        knownGroupNames: Set<String>
    ) -> String {
        if mapping["include-all"] as? Bool == true { return "All proxies and providers" }
        if mapping["include-all-proxies"] as? Bool == true { return "All local proxies" }
        if mapping["include-all-providers"] as? Bool == true { return "All providers" }

        let proxies = mapping["proxies"] as? [String] ?? []
        let providers = mapping["use"] as? [String] ?? []
        let nested = mapping["hako-scenario-id"] as? String == "nested-groups"
            || proxies.contains(where: knownGroupNames.contains)
        if nested, providers.isEmpty { return "Nested policy groups" }
        if !proxies.isEmpty, !providers.isEmpty { return "Explicit routes and providers" }
        if !providers.isEmpty { return "Proxy providers" }
        if !proxies.isEmpty { return "Explicit routes" }
        return "Empty fallback"
    }

    private static func memberRows(
        _ mapping: [String: Any],
        source: String
    ) -> [ProxyGroupDetailRow] {
        var rows = [ProxyGroupDetailRow(label: "Member Source", value: source)]
        appendCount(&rows, "Explicit Routes", mapping["proxies"])
        appendCount(&rows, "Proxy Providers", mapping["use"])
        appendString(&rows, "Filter", "filter", mapping)
        appendString(&rows, "Exclude Filter", "exclude-filter", mapping)
        appendString(&rows, "Excluded Types", "exclude-type", mapping)
        appendString(&rows, "Empty Fallback", "empty-fallback", mapping)
        return rows
    }

    private static func selectionRows(
        _ mapping: [String: Any],
        typeID: String
    ) -> [ProxyGroupDetailRow] {
        var rows: [ProxyGroupDetailRow] = []
        switch typeID {
        case "select":
            rows.append(.init(label: "User Selection", value: "Enabled"))
            appendString(&rows, "Default Route", "default-selected", mapping)
        case "url-test":
            rows.append(.init(label: "Algorithm", value: "Fastest available route"))
            appendNumber(&rows, "Tolerance", "tolerance", mapping, suffix: " ms")
        case "fallback":
            rows.append(.init(label: "Algorithm", value: "First available route"))
        case "load-balance":
            rows.append(.init(label: "Strategy", value: strategyTitle(mapping)))
        default:
            break
        }
        appendBool(&rows, "UDP", "disable-udp", mapping, inverted: true)
        return rows
    }

    private static func healthRows(
        _ mapping: [String: Any],
        typeID: String
    ) -> [ProxyGroupDetailRow] {
        guard typeID != "select" || mapping["url"] != nil else { return [] }
        var rows: [ProxyGroupDetailRow] = []
        if hasValue(mapping["url"]) {
            rows.append(.init(label: "Test URL", value: "Configured"))
        }
        appendNumber(&rows, "Interval", "interval", mapping, suffix: " s")
        appendNumber(&rows, "Timeout", "timeout", mapping, suffix: " ms")
        appendNumber(&rows, "Maximum Failures", "max-failed-times", mapping)
        appendBool(&rows, "Lazy Testing", "lazy", mapping)
        appendString(&rows, "Expected Status", "expected-status", mapping)
        return rows
    }

    private static func presentationRows(_ mapping: [String: Any]) -> [ProxyGroupDetailRow] {
        var rows: [ProxyGroupDetailRow] = []
        appendBool(&rows, "Hidden", "hidden", mapping)
        if hasValue(mapping["icon"]) {
            rows.append(.init(label: "Custom Icon", value: "Configured"))
        }
        return rows
    }

    private static func behavior(_ mapping: [String: Any], typeID: String) -> String {
        switch typeID {
        case "select": return "Manual route selection"
        case "url-test": return "Fastest available route"
        case "fallback": return "First available route"
        case "load-balance": return strategyTitle(mapping)
        default: return "Managed by the core"
        }
    }

    private static func strategyTitle(_ mapping: [String: Any]) -> String {
        switch (mapping["strategy"] as? String)?.lowercased() {
        case "round-robin": return "Round robin"
        case "sticky-sessions": return "Sticky sessions"
        case nil, "", "consistent-hashing": return "Consistent hashing"
        default: return "Configured strategy"
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func hasValue(_ value: Any?) -> Bool {
        switch value {
        case nil: return false
        case let string as String: return !string.isEmpty
        case let values as [Any]: return !values.isEmpty
        default: return true
        }
    }

    private static func appendString(
        _ rows: inout [ProxyGroupDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any]
    ) {
        guard let value = mapping[key] as? String, !value.isEmpty else { return }
        rows.append(.init(label: label, value: value))
    }

    private static func appendBool(
        _ rows: inout [ProxyGroupDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any],
        inverted: Bool = false
    ) {
        guard let value = mapping[key] as? Bool else { return }
        let displayed = inverted ? !value : value
        rows.append(.init(label: label, value: displayed ? "On" : "Off"))
    }

    private static func appendNumber(
        _ rows: inout [ProxyGroupDetailRow],
        _ label: String,
        _ key: String,
        _ mapping: [String: Any],
        suffix: String = ""
    ) {
        guard let value = mapping[key] as? NSNumber else { return }
        rows.append(.init(label: label, value: "\(value)\(suffix)"))
    }

    private static func appendCount(
        _ rows: inout [ProxyGroupDetailRow],
        _ label: String,
        _ value: Any?
    ) {
        guard let values = value as? [Any], !values.isEmpty else { return }
        rows.append(.init(label: label, value: "\(values.count)"))
    }
}

enum ProxyGroupConfigurationInspector {
    static func detailsByGroupName(yaml: String) -> [String: ProxyGroupConfigurationDetails] {
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: yaml) else { return [:] }
        return parsed.memo("proxies.groupDetails") { detailsByGroupName(root: parsed.root) }
    }

    static func detailsByGroupName(root: [String: Any]) -> [String: ProxyGroupConfigurationDetails] {
        guard let groups = root["proxy-groups"] as? [[String: Any]] else { return [:] }

        let names = Set(groups.compactMap { $0["name"] as? String })
         
         
        return Dictionary(groups.compactMap { mapping -> (String, ProxyGroupConfigurationDetails)? in
            guard let name = mapping["name"] as? String,
                  !name.isEmpty,
                  let details = ProxyGroupConfigurationCatalog.details(
                    for: mapping,
                    knownGroupNames: names
                  ) else { return nil }
            return (name, details)
        }, uniquingKeysWith: { first, _ in first })
    }

     
     
    static func activeConfiguredOrder() -> ConfiguredProxyOrder {
        guard let yaml = ActiveConfigurationText.current() else { return .none }
        return ConfiguredProxyOrder.read(yaml: yaml)
    }

    static func activeDetails() -> [String: ProxyGroupConfigurationDetails] {


         
         
        guard let yaml = ActiveConfigurationText.current() else { return [:] }
        return detailsByGroupName(yaml: yaml)
    }
}
