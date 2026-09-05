import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoTVSubscriptionSeed {
    struct Seed: Equatable {
        let urlString: String
        let name: String
    }

    static let environmentKey = "HAKO_TV_SUBSCRIPTION_URL"
    static let bundledFixtureName = "subscription"
    static let bundledFixtureExtension = "url"

     
    static func parse(_ text: String) -> Seed? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard let first = lines.first else { return nil }
        return Seed(urlString: first, name: lines.dropFirst().first ?? "")
    }

     
    static func candidate(environment: [String: String], bundledText: String?) -> Seed? {
        if let fromEnvironment = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromEnvironment.isEmpty {
            return Seed(urlString: fromEnvironment, name: "")
        }
        return bundledText.flatMap(parse)
    }

     
     
    @discardableResult
    static func apply(_ seed: Seed, to store: inout HakoTVSubscriptionStore) -> Bool {
        guard store.subscriptions.isEmpty else { return false }
        do {
            try store.add(urlString: seed.urlString, name: seed.name)
            return true
        } catch {
            return false
        }
    }

     
    static func seedIfEmpty(
        _ store: inout HakoTVSubscriptionStore,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) {
        let bundledText = bundle
            .url(forResource: bundledFixtureName, withExtension: bundledFixtureExtension)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        guard let seed = candidate(environment: environment, bundledText: bundledText) else { return }
        apply(seed, to: &store)
    }
}
