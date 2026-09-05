import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ProviderCompileVerdicts: Equatable, Sendable {
    enum Verdict: Equatable, Sendable {
         
         
         
         
        case compiled(behavior: String?)
         
        case notCompilable(reason: String)
    }

     
    struct Blocked: Equatable, Identifiable {
        let name: String
        let reason: String
        var id: String { name }
    }

     
    var ruleProviders: [String: Verdict] = [:]
     
     
     
     
    var entryCounts: [String: Int] = [:]

     
    var blockedRuleProviders: [Blocked] {
        ruleProviders.compactMap { name, verdict in
            guard case .notCompilable(let reason) = verdict else { return nil }
            return Blocked(name: name, reason: reason)
        }
        .sorted { $0.name < $1.name }
    }

    func blockedReason(ruleProvider name: String) -> String? {
        guard case .notCompilable(let reason)? = ruleProviders[name] else {
            return nil
        }
        return reason
    }

    static func load(coreHome: URL) -> ProviderCompileVerdicts {
        let manifest = coreHome
            .appendingPathComponent("provider-runtime")
            .appendingPathComponent("staged-manifest.json")
        guard let data = try? Data(contentsOf: manifest) else {
             
            return ProviderCompileVerdicts()
        }
        return parse(data)
    }

    static func parse(_ data: Data) -> ProviderCompileVerdicts {
        guard
            let root = (try? JSONSerialization.jsonObject(with: data))
                as? [String: Any],
            let entries = root["entries"] as? [String: Any]
        else {
             
            return ProviderCompileVerdicts()
        }
        let separator = Character(UnicodeScalar(0))
        var verdicts: [String: Verdict] = [:]
        var counts: [String: Int] = [:]
        for (key, value) in entries {
            guard let cut = key.firstIndex(of: separator),
                  key[key.startIndex..<cut] == "rule"
            else { continue }
            let name = String(key[key.index(after: cut)...])
            guard !name.isEmpty,
                  let record = value as? [String: Any]
            else { continue }
            if let count = record["count"] as? Int, count > 0 {
                counts[name] = count
            }
            guard let verdict = record["compileVerdict"] as? String
            else { continue }
            switch verdict {
            case "compiled":
                verdicts[name] = .compiled(
                    behavior: record["compiledBehavior"] as? String
                )
            case "notCompilable":
                verdicts[name] = .notCompilable(
                    reason: (record["compileReason"] as? String) ?? ""
                )
            default:
                 
                 
                continue
            }
        }
        return ProviderCompileVerdicts(ruleProviders: verdicts, entryCounts: counts)
    }
}
