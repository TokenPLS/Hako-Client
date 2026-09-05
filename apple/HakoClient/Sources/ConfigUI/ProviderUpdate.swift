import Foundation
import HakoClientUI

enum ProviderRuntimeCatalogError: LocalizedError, Equatable {
    case unavailable
    case invalidName
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Live provider status is unavailable. Connect Clash and try again."
        case .invalidName:
            return "The provider name is invalid."
        case .invalidResponse:
            return "Clash Core returned an invalid provider status response."
        }
    }
}

struct ProxyProviderRuntime: Equatable {
    struct Proxy: Equatable, Identifiable {
        let name: String
        let type: String?
        let alive: Bool?
        let latestDelayMilliseconds: Int?
         
         
        var measuredAt: Date?

        var id: String { name }
    }

    let name: String
    let vehicleType: String?
    let updatedAt: Date?
    let hasHealthCheck: Bool
    let proxies: [Proxy]

    var healthyCount: Int { proxies.filter { $0.alive == true }.count }
    var unhealthyCount: Int { proxies.filter { $0.alive == false }.count }
}

struct RuleProviderRuntime: Equatable {
    let name: String
    let vehicleType: String?
    let updatedAt: Date?
    let behavior: String?
    let format: String?
    let ruleCount: Int
}

struct ProviderRuntimeSummary: Equatable {
    let vehicleType: String?
    let updatedAt: Date?
    let entryCount: Int
    let healthyCount: Int?
    let unhealthyCount: Int?
    let healthCheckAvailable: Bool
}

struct ProviderRuntimeCatalog: Equatable {
    var proxyProviders: [String: ProxyProviderRuntime]
    var ruleProviders: [String: RuleProviderRuntime]

    static let empty = ProviderRuntimeCatalog(proxyProviders: [:], ruleProviders: [:])

    func summary(name: String, kind: String?) -> ProviderRuntimeSummary? {
        switch kind?.lowercased() {
        case "proxy":
            guard let provider = proxyProviders[name] else { return nil }
            return ProviderRuntimeSummary(
                vehicleType: provider.vehicleType,
                updatedAt: provider.updatedAt,
                entryCount: provider.proxies.count,
                healthyCount: provider.healthyCount,
                unhealthyCount: provider.unhealthyCount,
                healthCheckAvailable: provider.hasHealthCheck
            )
        case "rule":
            guard let provider = ruleProviders[name] else { return nil }
            return ProviderRuntimeSummary(
                vehicleType: provider.vehicleType,
                updatedAt: provider.updatedAt,
                entryCount: provider.ruleCount,
                healthyCount: nil,
                unhealthyCount: nil,
                healthCheckAvailable: false
            )
        default:
            return nil
        }
    }
}

enum ProviderRuntimeCatalogParser {
    private struct ProxyEnvelope: Decodable {
        let providers: [String: ProxyPayload]
    }

    private struct RuleEnvelope: Decodable {
        let providers: [String: RulePayload]
    }

    private struct ProxyPayload: Decodable {
        let name: String?
        let vehicleType: String?
        let updatedAt: String?
        let testUrl: String?
        let proxies: [ProxyPayloadEntry]?
    }

    private struct ProxyPayloadEntry: Decodable {
        let name: String?
        let type: String?
        let alive: Bool?
        let history: [DelayPayload]?
    }

    private struct DelayPayload: Decodable {
        let delay: Int?
         
         
         
         
        let time: String?
    }

    private struct RulePayload: Decodable {
        let name: String?
        let vehicleType: String?
        let updatedAt: String?
        let behavior: String?
        let format: String?
        let ruleCount: Int?
    }

    static func catalog(proxyJSON: String, ruleJSON: String) throws -> ProviderRuntimeCatalog {
        do {
            let decoder = JSONDecoder()
            let proxyEnvelope = try decoder.decode(
                ProxyEnvelope.self,
                from: Data(proxyJSON.utf8)
            )
            let ruleEnvelope = try decoder.decode(
                RuleEnvelope.self,
                from: Data(ruleJSON.utf8)
            )
            var proxyProviders: [String: ProxyProviderRuntime] = [:]
            for (fallbackName, payload) in proxyEnvelope.providers {
                let provider = try proxyProvider(payload: payload, fallbackName: fallbackName)
                proxyProviders[provider.name] = provider
            }
            var ruleProviders: [String: RuleProviderRuntime] = [:]
            for (fallbackName, payload) in ruleEnvelope.providers {
                let provider = try ruleProvider(payload: payload, fallbackName: fallbackName)
                ruleProviders[provider.name] = provider
            }
            return ProviderRuntimeCatalog(
                proxyProviders: proxyProviders,
                ruleProviders: ruleProviders
            )
        } catch let error as ProviderRuntimeCatalogError {
            throw error
        } catch {
             
             
            throw ProviderRuntimeCatalogError.invalidResponse
        }
    }

    static func proxyDetail(json: String, fallbackName: String) throws -> ProxyProviderRuntime {
        guard !fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderRuntimeCatalogError.invalidName
        }
        do {
            let payload = try JSONDecoder().decode(ProxyPayload.self, from: Data(json.utf8))
            return try proxyProvider(payload: payload, fallbackName: fallbackName)
        } catch let error as ProviderRuntimeCatalogError {
            throw error
        } catch {
            throw ProviderRuntimeCatalogError.invalidResponse
        }
    }

    private static func proxyProvider(
        payload: ProxyPayload,
        fallbackName: String
    ) throws -> ProxyProviderRuntime {
        let name = normalizedName(payload.name, fallback: fallbackName)
        guard !name.isEmpty else { throw ProviderRuntimeCatalogError.invalidResponse }
        let proxies = (payload.proxies ?? []).compactMap { proxy -> ProxyProviderRuntime.Proxy? in
             
            guard let name = proxy.name, !name.isEmpty else { return nil }
            let delay = proxy.history?
                .compactMap(\.delay)
                .last(where: { $0 > 0 })
            return ProxyProviderRuntime.Proxy(
                name: name,
                type: proxy.type,
                alive: proxy.alive,
                latestDelayMilliseconds: delay,
                measuredAt: proxy.history?.last.flatMap { parseDate($0.time) }
            )
        }
        return ProxyProviderRuntime(
            name: name,
            vehicleType: payload.vehicleType,
            updatedAt: parseDate(payload.updatedAt),
            hasHealthCheck: !(payload.testUrl ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            proxies: proxies
        )
    }

    private static func ruleProvider(
        payload: RulePayload,
        fallbackName: String
    ) throws -> RuleProviderRuntime {
        let name = normalizedName(payload.name, fallback: fallbackName)
        guard !name.isEmpty else { throw ProviderRuntimeCatalogError.invalidResponse }
        return RuleProviderRuntime(
            name: name,
            vehicleType: payload.vehicleType,
            updatedAt: parseDate(payload.updatedAt),
            behavior: payload.behavior,
            format: payload.format,
            ruleCount: max(payload.ruleCount ?? 0, 0)
        )
    }

     
     
     
    private static func normalizedName(_ name: String?, fallback: String) -> String {
        let primary = name ?? ""
        return primary.isEmpty ? fallback : primary
    }

     
     
     
     
     
     
     
    private static func parseDate(_ value: String?) -> Date? {
        HakoInstant.parse(value)
    }
}

 
 
 
enum NativeProviderRuntimeDispatcher {
    static func catalog(
        proxy: () throws -> String,
        rule: () throws -> String
    ) throws -> ProviderRuntimeCatalog {
        try ProviderRuntimeCatalogParser.catalog(
            proxyJSON: proxy(),
            ruleJSON: rule()
        )
    }

    static func healthCheck(
        name: String,
        health: (String) throws -> Void,
        detail: (String) throws -> String
    ) throws -> ProxyProviderRuntime {
         
         
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderRuntimeCatalogError.invalidName
        }
        try health(name)
        return try ProviderRuntimeCatalogParser.proxyDetail(
            json: detail(name),
            fallbackName: name
        )
    }
}

 
 
 
 
 
 
struct ProviderCatalog: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let name: String
        let kind: String    
        let url: String
        let path: String    
        let count: Int?
        let subscriptionInfo: SubscriptionInfo?
         
        let updateIntervalSeconds: Int64?
         
        let lastUpdatedAt: Date?
         
         
         
         
         
         
        let loadFailure: String?
         
         
         
         
         
         
         
         
        let payloadURL: String?

        init(
            name: String,
            kind: String,
            url: String,
            path: String,
            count: Int? = nil,
            subscriptionInfo: SubscriptionInfo? = nil,
            updateIntervalSeconds: Int64? = nil,
            lastUpdatedAt: Date? = nil,
            loadFailure: String? = nil,
            payloadURL: String? = nil
        ) {
            self.name = name
            self.kind = kind
            self.url = url
            self.path = path
            self.count = count
            self.subscriptionInfo = subscriptionInfo
            self.updateIntervalSeconds = updateIntervalSeconds
            self.lastUpdatedAt = lastUpdatedAt
            self.loadFailure = loadFailure
            self.payloadURL = payloadURL
        }
    }
    var entries: [Entry]

     
     
    static let fileName = "providers.json"

    func write(providersDir: URL) throws {
        try FileManager.default.createDirectory(at: providersDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: providersDir.appendingPathComponent(Self.fileName),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func load(providersDir: URL) -> ProviderCatalog? {
        guard let data = try? Data(contentsOf: providersDir.appendingPathComponent(fileName)) else {
            return nil
        }
        return try? JSONDecoder().decode(ProviderCatalog.self, from: data)
    }

    static func from(
        plan: RemoteResourcePlan,
        entryCounts: [String: Int] = [:],
        subscriptionInfo: [String: SubscriptionInfo] = [:],
        lastUpdatedAt: [String: Date] = [:],
        loadFailures: [String: String] = [:],
        payloadSourceURLs: [String: String] = [:]
    ) -> ProviderCatalog {
        ProviderCatalog(entries: plan.providers.map {
            Entry(
                name: $0.name,
                kind: $0.kind,
                url: $0.url,
                path: $0.path,
                count: entryCounts[$0.name],
                subscriptionInfo: subscriptionInfo[$0.name],
                updateIntervalSeconds: $0.updateIntervalSeconds,
                lastUpdatedAt: lastUpdatedAt[$0.name],
                loadFailure: loadFailures[$0.name],
                 
                 
                 
                 
                payloadURL: payloadSourceURLs[$0.path]
            )
        })
    }
}
