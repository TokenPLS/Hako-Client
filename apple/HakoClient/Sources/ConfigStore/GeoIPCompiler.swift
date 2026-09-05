import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum GeoIPCompiler {
     
     
     
     
    static func prepare(finalYAML: String) {
        compile(finalYAML, geodataMode: geodataModeEnabled(in: finalYAML))
    }

     
     
     
    static func geodataModeEnabled(in finalYAML: String) -> Bool {
        HakoGeodataModeEnabled(finalYAML)
    }

     
     
     
     
    private static func compile(_ content: String, geodataMode: Bool) {
        var error: NSError?
         
         
        let summary = HakoPrepareGeoIPCache(content, geodataMode, &error)
        guard error == nil else {
            HakoLogStore.shared.append(
                "geoip compile skipped  reason=\(error?.localizedDescription ?? "unknown")",
                stream: .app,
                level: .warning
            )
            return
        }
        HakoLogStore.shared.append(summary, stream: .app)
    }
}

extension GeoIPCompiler {
     
     
     
     
     
     
     
    static func prepareRulePayloads(in directory: URL, plan: RemoteResourcePlan, geodataMode: Bool) {
        let texts = plan.providers
            .filter { $0.kind == "rule" }
            .compactMap { provider -> String? in
                let url = directory.appendingPathComponent(provider.path)
                guard let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8) else { return nil }
                return text
            }
        guard !texts.isEmpty else { return }
        compile(texts.joined(separator: "\n"), geodataMode: geodataMode)
    }
}
