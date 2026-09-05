import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVProviderCatalog: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
         
        let kind: String
        let name: String
         
        let updatedAt: Date
         
         
         
         
         
         
         
        let failure: String?

         
         
         
         
        var id: String { "\(kind):\(name)" }
    }

    var entries: [Entry]

    static let fileName = "providers.json"

    var readyCount: Int { entries.filter { $0.failure == nil }.count }

    func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: directory.appendingPathComponent(Self.fileName), options: .atomic)
    }

     
     
     
     
    static func read(from directory: URL) -> HakoTVProviderCatalog? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(HakoTVProviderCatalog.self, from: data)
    }

     
     
     
    static func isSidecar(_ path: String) -> Bool {
        (path as NSString).lastPathComponent == fileName
    }

    static func providerFileCount(in paths: [String]) -> Int {
        paths.filter { !isSidecar($0) }.count
    }
}

extension HakoTVProviderCatalog.Entry {
     
     
     
     
     
    static var prototype: [HakoTVProviderCatalog.Entry] {
        let now = Date()
        return [
            .init(kind: "rule", name: "streaming", updatedAt: now.addingTimeInterval(-18 * 60), failure: nil),
            .init(kind: "rule", name: "ads", updatedAt: now.addingTimeInterval(-18 * 60), failure: nil),
            .init(kind: "proxy", name: "nodes", updatedAt: now.addingTimeInterval(-18 * 60), failure: nil),
            .init(
                kind: "rule", name: "apple",
                updatedAt: now.addingTimeInterval(-22 * 60),
                failure: "download failed: The request timed out."
            ),
        ]
    }
}
