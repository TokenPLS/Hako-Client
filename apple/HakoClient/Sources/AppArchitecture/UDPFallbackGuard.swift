import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum UDPFallbackPolicy: String, Codable, CaseIterable, Sendable {
     
    case off
     
    case quic
     
    case quicAllPorts
     
    case allUDP
}

enum UDPFallbackGuard {

     
     
     
     
     
     
     
     
    static func rule(for policy: UDPFallbackPolicy) -> String? {
        switch policy {
        case .off:
            nil
        case .quic:
            "AND,((NETWORK,udp),(DST-PORT,443)),REJECT"
        case .quicAllPorts:
            "AND,((NETWORK,udp),(DST-PORT,443/80)),REJECT"
        case .allUDP:
            "NETWORK,udp,REJECT"
        }
    }

     
    struct Coverage: Equatable {
         
        let ruleText: String
         
        let index: Int
         
        let precedesMatch: Bool
    }

     
     
     
     
     
     
    static func ruleToInject(
        policy: UDPFallbackPolicy,
        existingRules: [String]
    ) -> String? {
        guard let rule = rule(for: policy) else { return nil }
        guard existingCoverage(for: policy, in: existingRules) == nil else {
            return nil
        }
        return rule
    }

     
     
     
     
    static func displayCoverage(
        for policy: UDPFallbackPolicy,
        input: ConfigTransforms.UDPFallbackGuardInput
    ) -> Coverage? {
        guard let top = existingCoverage(for: policy, in: input.rules) else { return nil }
        for list in input.subRules.values
        where existingCoverage(for: policy, in: list) == nil {
            return nil
        }
        return top
    }

    static func existingCoverage(
        for policy: UDPFallbackPolicy,
        in rules: [String]
    ) -> Coverage? {
        guard let needed = requirement(of: policy) else { return nil }
        let matchIndex = rules.firstIndex { ruleType(of: $0) == "MATCH" }
        for (index, text) in rules.enumerated() {
            guard let covered = rejectedUDPPorts(in: text),
                  satisfies(covered, needed) else { continue }
            return Coverage(
                ruleText: text,
                index: index,
                precedesMatch: matchIndex.map { index < $0 } ?? false
            )
        }
        return nil
    }

     
    private enum RejectedPorts {
        case allPorts
        case ranges([ClosedRange<Int>])

        func contains(_ port: Int) -> Bool {
            switch self {
            case .allPorts: true
            case let .ranges(ranges): ranges.contains { $0.contains(port) }
            }
        }
    }

     
    private static func requirement(
        of policy: UDPFallbackPolicy
    ) -> RejectedPorts? {
        switch policy {
        case .off: nil
        case .quic: .ranges([443...443])
        case .quicAllPorts: .ranges([80...80, 443...443])
        case .allUDP: .allPorts
        }
    }

    private static func satisfies(
        _ covered: RejectedPorts, _ needed: RejectedPorts
    ) -> Bool {
        switch needed {
        case .allPorts:
            if case .allPorts = covered { return true }
            return false
        case let .ranges(required):
            return required.allSatisfy { range in
                range.allSatisfy { covered.contains($0) }
            }
        }
    }

     
    private static func ruleType(of rule: String) -> String {
        let trimmed = rule.trimmingCharacters(in: .whitespaces)
        guard let comma = trimmed.firstIndex(of: ",") else {
            return trimmed.uppercased()
        }
        return String(trimmed[..<comma])
            .trimmingCharacters(in: .whitespaces).uppercased()
    }

     
     
     
     
     
     
     
    private static func rejectedUDPPorts(in rule: String) -> RejectedPorts? {
        var body = rule.trimmingCharacters(in: .whitespaces)
         
         
         
         
         
         
         
         
         
         
        if body.hasSuffix(",REJECT-DROP") {
            body = String(body.dropLast(",REJECT-DROP".count))
        } else if body.hasSuffix(",REJECT") {
            body = String(body.dropLast(",REJECT".count))
        } else {
            return nil
        }

        let compact = body
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        if compact.uppercased() == "NETWORK,UDP" { return .allPorts }

        guard compact.uppercased().hasPrefix("AND,(("),
              compact.hasSuffix("))") else { return nil }
        let inner = String(
            compact.dropFirst("AND,((".count).dropLast("))".count)
        )
        let parts = inner.components(separatedBy: "),(")
        guard parts.count == 2 else { return nil }

        var sawUDP = false
        var ports: RejectedPorts?
        for part in parts {
            guard let comma = part.firstIndex(of: ",") else { return nil }
            let type = String(part[..<comma]).uppercased()
            let payload = String(part[part.index(after: comma)...])
            switch type {
            case "NETWORK" where payload.uppercased() == "UDP":
                sawUDP = true
            case "DST-PORT":
                 
                 
                 
                 
                 
                 
                 
                 
                 
                let effective = payload
                    .components(separatedBy: ",")
                    .first ?? payload
                ports = .ranges(parsePortRanges(effective))
            default:
                return nil
            }
        }
        guard sawUDP, let ports else { return nil }
        return ports
    }

     
     
     
     
     
     
    private static func parsePortRanges(_ payload: String) -> [ClosedRange<Int>] {
        payload
            .components(separatedBy: "/")
            .compactMap { token -> ClosedRange<Int>? in
                let piece = token.trimmingCharacters(in: .whitespaces)
                guard !piece.isEmpty else { return nil }
                let bounds = piece.components(separatedBy: "-")
                if bounds.count == 2,
                   let low = port(bounds[0]), let high = port(bounds[1]),
                   low <= high {
                    return low...high
                }
                guard let single = port(piece) else { return nil }
                return single...single
            }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private static func port(_ token: String) -> Int? {
        guard let value = Int(token.trimmingCharacters(in: .whitespaces)),
              (0...Int(UInt16.max)).contains(value)
        else { return nil }
        return value
    }
}
