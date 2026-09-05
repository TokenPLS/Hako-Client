import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ThirdPartyLicenseInventory: Decodable {
    struct Module: Decodable, Identifiable, Hashable {
        let module: String
        let version: String
         
        let license: String
         
         
        let text: String
        let note: String?

        var id: String { module }

         
         
         
         
         
         
         
        var shortName: String {
            Self.shortName(forModulePath: module)
        }

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        static func shortName(forModulePath module: String) -> String {
            let parts = module.split(separator: "/")
            guard let last = parts.last else { return module }
            if parts.count >= 2,
               last.first == "v",
               let major = Int(last.dropFirst()),
               major >= 2 {
                return String(parts[parts.count - 2])
            }
            return String(last)
        }
    }

     
    let generatedBy: String
    let modules: [Module]
    let texts: [String: String]

    func text(for module: Module) -> String {
        texts[module.text] ?? "This license text is missing from the app bundle."
    }

    func module(_ path: String) -> Module? {
        modules.first { $0.module == path }
    }

     
    var licenseSummary: [(license: String, count: Int)] {
        Dictionary(grouping: modules, by: \.license)
            .map { (license: $0.key, count: $0.value.count) }
            .sorted { ($0.count, $1.license) > ($1.count, $0.license) }
    }

    static let resourceName = "ThirdPartyLicenses"

     
     
    static let shared: ThirdPartyLicenseInventory = load(from: .hakoResources)

    static func load(from bundle: Bundle) -> ThirdPartyLicenseInventory {
        guard let url = bundle.url(
            forResource: resourceName, withExtension: "json"
        ), let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(
                ThirdPartyLicenseInventory.self, from: data
            )
        else {
            return ThirdPartyLicenseInventory(
                generatedBy: "", modules: [], texts: [:]
            )
        }
        return decoded
    }
}

extension Bundle {
     
     
     
    static var hakoResources: Bundle { Bundle(for: HakoResourceMarker.self) }
}

private final class HakoResourceMarker {}
