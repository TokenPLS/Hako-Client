import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoDNSExplain: Equatable, Sendable {
     
     
     
     
     
     
     
     
     
     
    public enum Source: String, Codable, Sendable, CaseIterable {
         
         
         
        case cache
        case policy
        case fallback
        case main
        case rcode
         
        case hosts
         
         
        case fakeIP = "fake-ip"
         
         
         
         
        case ipv6Disabled = "ipv6-disabled"
    }

    public struct CacheState: Equatable, Sendable {
         
         
         
         
         
         
         
         
         
         
        public let secondsRemaining: Int?
        public let isHit: Bool

        public init(isHit: Bool, secondsRemaining: Int?) {
            self.isHit = isHit
            self.secondsRemaining = secondsRemaining
        }

        public var isStale: Bool {
            isHit && (secondsRemaining ?? 0) < 0
        }
    }

    public let source: Source
     
     
    public let matchedRule: String?
     
    public let candidates: [String]
    public let cache: CacheState?
     
     
     
     
     
     
     
     
     
     
    public let answeredBy: String?
     
     
     
     
    public let answer: [String]

    public init(
        source: Source,
        matchedRule: String? = nil,
        candidates: [String] = [],
        cache: CacheState? = nil,
        answeredBy: String? = nil,
        answer: [String] = []
    ) {
        self.source = source
        self.matchedRule = matchedRule
        self.candidates = candidates
        self.cache = cache
        self.answeredBy = answeredBy
        self.answer = answer
    }
}

public extension HakoDNSExplain {
     
     
     
     
     
     
     
     
     
     
     
    static func decode(
        _ json: String,
        now: Date = Date()
    ) -> HakoDNSExplain? {
        struct Payload: Decodable {
            struct Cache: Decodable {
                let hit: Bool?
                let expiresAt: String?
                let stale: Bool?
            }
            let source: String?
            let matchedRule: String?
            let candidates: [String]?
            let probed: Bool?
            let cache: Cache?
            let answeredBy: String?
            let answer: [String]?
        }
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(
                Payload.self,
                from: data
              ),
              let raw = payload.source,
              let source = Source(rawValue: raw)
        else { return nil }

        var cache: CacheState?
        if let hit = payload.cache?.hit {
            var remaining: Int?
            if let stamp = payload.cache?.expiresAt,
               let expiry = Self.instant(stamp)
            {
                remaining = Int(expiry.timeIntervalSince(now).rounded())
                 
                 
                 
                 
                 
                if payload.cache?.stale == true, (remaining ?? 0) >= 0 {
                    remaining = -1
                }
            }
            cache = CacheState(isHit: hit, secondsRemaining: remaining)
        }

        return HakoDNSExplain(
            source: source,
            matchedRule: payload.matchedRule,
            candidates: payload.candidates ?? [],
            cache: cache,
            answeredBy: payload.probed == true ? payload.answeredBy : nil,
            answer: payload.probed == true ? (payload.answer ?? []) : []
        )
    }

     
     
     
     
     
     
     
    var probedResult: HakoDNSQueryResult? {
        guard !answer.isEmpty else { return nil }
        return HakoDNSQueryResult(
            answers: answer.map { line in
                let fields = line.split(
                    separator: "\t",
                    omittingEmptySubsequences: true
                ).map(String.init)
                guard fields.count >= 5 else {
                    return HakoDNSQueryAnswer(
                        name: nil,
                        type: nil,
                        ttl: nil,
                        data: line
                    )
                }
                return HakoDNSQueryAnswer(
                    name: fields[0],
                    type: nil,
                    ttl: Int(fields[1]),
                    data: fields[4...].joined(separator: " ")
                )
            },
            errorMessage: nil
        )
    }

    private static func instant(_ value: String) -> Date? {
        HakoInstant.parse(value)
    }

     
     
     
     
    var reason: HakoDisplayText {
        switch source {
        case .cache:
            return .copy("Answered from the cache; no resolver was asked")
        case .hosts:
            return .copy("Answered by a hosts entry; no resolver was asked")
        case .fakeIP:
            return .copy("Answered by Fake-IP; no resolver was asked")
        case .ipv6Disabled:
            return .copy("IPv6 is off in this profile, so AAAA is answered empty without asking")
        case .policy:
            guard let matchedRule, !matchedRule.isEmpty else {
                return .copy("Matched a nameserver-policy entry")
            }
            return .format(
                "nameserver-policy matched %@",
                [matchedRule]
            )
        case .fallback:
            return .copy("This domain is routed to the fallback resolvers")
        case .main:
            return .copy("No policy matched, so the main resolvers answer")
        case .rcode:
            return .copy(
                "An rcode rule answers this name without asking any resolver"
            )
        }
    }

     
     
     
     
    func cacheSentence(
        durationText: (Int) -> String
    ) -> HakoDisplayText? {
        guard let cache, cache.isHit else { return nil }
        guard let remaining = cache.secondsRemaining else {
            return .copy("Cached")
        }
        if remaining < 0 {
            return .format(
                "Expired %@ ago, still in use while it refreshes",
                [durationText(-remaining)]
            )
        }
        return .format("Cached, %@ left", [durationText(remaining)])
    }

     
     
     
     
     
     
    var attributionSentence: HakoDisplayText? {
        guard let answeredBy, !answeredBy.isEmpty else { return nil }
        guard candidates.count > 1 else {
            return .format("Answered by %@", [answeredBy])
        }
        return .format(
            "%@ resolvers raced; %@ answered first",
            ["\(candidates.count)", answeredBy]
        )
    }
}
