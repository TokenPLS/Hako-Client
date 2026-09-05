import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
 
 
enum GeoSiteCompiler {
     
     
     
    static func prepare(finalYAML: String) {
        var error: NSError?
         
         
         
        let summary = HakoPrepareGeoSiteCache(finalYAML, &error)
        guard error == nil else {
            HakoLogStore.shared.append(
                "geosite compile skipped  reason=\(error?.localizedDescription ?? "unknown")",
                stream: .app,
                level: .warning
            )
            return
        }
        HakoLogStore.shared.append(summary, stream: .app)
    }
}

extension GeoSiteCompiler {
     
     
     
    static func prepareRulePayloads(in directory: URL, plan: RemoteResourcePlan) {
        let texts = plan.providers
            .filter { $0.kind == "rule" }
            .compactMap { provider -> String? in
                let url = directory.appendingPathComponent(provider.path)
                guard let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8) else { return nil }
                return text
            }
        guard !texts.isEmpty else { return }
        prepare(finalYAML: texts.joined(separator: "\n"))
    }
}
