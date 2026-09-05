import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoStartupExplanation: Equatable, Sendable {
     
     
     
     
     
     
     
     
    public let resource: String?
    public let footprintBytes: Int64
    public let budgetBytes: Int64
     
     
     
     
     
     
     
    public let stage: String?
     
     
    public let failureReason: String?
     
     
     
     
    public let sawCriticalPressure: Bool

    public init(
        resource: String?,
        footprintBytes: Int64,
        budgetBytes: Int64,
        stage: String? = nil,
        failureReason: String? = nil,
        sawCriticalPressure: Bool = false
    ) {
        self.resource = resource.flatMap { $0.isEmpty ? nil : $0 }
        self.footprintBytes = footprintBytes
        self.budgetBytes = budgetBytes
        self.stage = stage.flatMap { $0.isEmpty ? nil : $0 }
        self.failureReason = failureReason
        self.sawCriticalPressure = sawCriticalPressure
    }
     
     
     
     
     
     
     
     
     
     
    public func corrected(
        footprintBytes newFootprint: Int64,
        budgetBytes newBudget: Int64
    ) -> HakoStartupExplanation {
         
         
         
         
        return HakoStartupExplanation(
            resource: resource,
            footprintBytes: max(newFootprint, footprintBytes),
            budgetBytes: newBudget > 0 ? newBudget : budgetBytes,
            stage: stage,
            failureReason: failureReason,
            sawCriticalPressure: true
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    public static func decode(
        _ json: String
    ) -> HakoStartupExplanation? {
        struct Payload: Decodable {
            let resource: String?
            let stage: String?
            let completed: Bool?
            let footprintBytes: Int64?
            let budgetBytes: Int64?
            let failureReason: String?
        }
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }

         
         
        guard payload.completed != true else { return nil }

         
         
         
         
         
         
         
         
         
         
         
         
         
        guard let footprint = payload.footprintBytes, footprint > 0
        else { return nil }

        return HakoStartupExplanation(
            resource: payload.resource,
            footprintBytes: footprint,
            budgetBytes: payload.budgetBytes ?? 0,
            stage: payload.stage,
            failureReason: payload.failureReason
        )
    }

}

public extension HakoStartupExplanation {
     
     
     
     
     
     
     
     
     
     
     
     
    var wasNearItsBudget: Bool {
        budgetBytes > 0
            && Double(footprintBytes) >= Double(budgetBytes) * 0.8
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var stoppedWithoutSayingWhy: Bool {
        (failureReason ?? "").isEmpty
    }

     
     
     
     
     
    var memoryWasTheStory: Bool {
        stoppedWithoutSayingWhy && sawCriticalPressure
    }


     
     
     
    var summary: HakoDisplayText {
        guard memoryWasTheStory else {
             
            return .copy("Couldn’t connect: the tunnel stopped while starting up")
        }
        guard let resource else {
            return .copy("Couldn’t connect: not enough memory")
        }
        if resource.hasPrefix("geoip:") {
            return .copy("Couldn’t connect: GEOIP rules need too much memory")
        }
        if resource.hasPrefix("geosite:") {
            return .copy("Couldn’t connect: GEOSITE categories need too much memory")
        }
        return .copy("Couldn’t connect: not enough memory")
    }

     
     
     
     
     
     
    var detail: HakoDisplayText {
        guard memoryWasTheStory else {
            guard let resource else {
                return .format(
                    "The system stopped the tunnel while it was starting. It was using %@ at the time.",
                    [Self.megabytes(footprintBytes)]
                )
            }
            return .format(
                "The system stopped the tunnel while it was loading %@. It was using %@ at the time.",
                [resource, Self.megabytes(footprintBytes)]
            )
        }
        guard let resource else {
            return .format(
                "The system stopped the tunnel while it was starting. It was using %@ at the time.",
                [Self.megabytes(footprintBytes)]
            )
        }
         
         
         
         
         
        _ = resource
        return .format(
            "The system stopped the tunnel while it was starting. It was using %@ at the time.",
            [Self.megabytes(footprintBytes)]
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func wayOut(named: Int? = nil) -> HakoDisplayText? {
        guard memoryWasTheStory else { return nil }
        guard let resource else {
             
             
             
             
             
             
             
             
             
             
             
             
            guard let stage else { return nil }
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            if stage == "apply:profile"
                || stage.hasPrefix("apply:rule-provider")
            {
                return .copy(
                    "Most of this start’s memory went to loading rule sets. A large domain rule set costs many times its file size while it loads, so a single big one can be more than the whole tunnel is allowed — switching off the ones you don’t route on is what lowers this step."
                )
            }
            if stage.hasPrefix("apply:proxy-providers") {
                return .copy(
                    "Most of this start’s memory went to loading the nodes from your proxy subscriptions — every subscription’s full node list loads at start. Removing subscriptions you don’t use, or narrowing one with a proxy-provider filter, lowers this step directly."
                )
            }
            if stage.hasPrefix("parse:dns") || stage.hasPrefix("parse:rules")
                || stage.hasPrefix("apply:rules")
            {
                 
                return .copy(
                    "What usually fills a tunnel’s memory is the number of GEOIP countries and GEOSITE categories a profile names — each one loads its whole list, whether or not your traffic reaches it."
                )
            }
            return nil
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if resource.hasPrefix("rule-provider:") {
            return .copy(
                "Most of this start’s memory went to loading rule sets. A large domain rule set costs many times its file size while it loads, so a single big one can be more than the whole tunnel is allowed — switching off the ones you don’t route on is what lowers this step."
            )
        }
        if resource.hasPrefix("proxy-provider:") {
            return .copy(
                "Most of this start’s memory went to loading the nodes from your proxy subscriptions — every subscription’s full node list loads at start. Removing subscriptions you don’t use, or narrowing one with a proxy-provider filter, lowers this step directly."
            )
        }
        if resource.hasPrefix("geoip:") {
            guard let named, named > 1 else {
                return .copy(
                    "Use fewer GEOIP rules. Every country you write a GEOIP rule for loads that country’s whole address list into memory — even the ones your traffic never reaches. Most profiles only need one or two, such as GEOIP,CN."
                )
            }
             
             
             
            return .format(
                "This profile names %@ countries. Every one of them loads that country’s whole address list into memory — even the ones your traffic never reaches. Most profiles only need one or two, such as GEOIP,CN.",
                ["\(named)"]
            )
        }
        if resource.hasPrefix("geosite:") {
            guard let named, named > 1 else {
                return .copy(
                    "Use fewer GEOSITE categories. Every category you name loads its whole domain list into memory — even the ones your traffic never reaches. Keeping the handful you actually route on is usually enough."
                )
            }
            return .format(
                "This profile names %@ categories. Every one of them loads its whole domain list into memory — even the ones your traffic never reaches. Keeping the handful you actually route on is usually enough.",
                ["\(named)"]
            )
        }
        return nil
    }

     
     
    static func megabytes(_ bytes: Int64) -> String {
        if abs(bytes) < 1_048_576 {
            return "\(bytes / 1024) KB"
        }
        return megabytesOnly(bytes)
    }

    private static func megabytesOnly(_ bytes: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let value = Double(bytes) / (1024 * 1024)
        let number = formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.1f", value)
        return "\(number) MB"
    }
}
