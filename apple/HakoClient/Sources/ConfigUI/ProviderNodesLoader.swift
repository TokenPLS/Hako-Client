import Foundation

 
 
 
 
 
enum ProviderNodesLoader {
    static func load(providersDir: URL) -> [String: [ProxiesOverviewModel.Proxy]] {
        guard let catalog = ProviderCatalog.load(providersDir: providersDir) else {
            return [:]
        }
        return load(catalog: catalog, providersDir: providersDir)
    }

     
     
     
    static func load(
        catalog: ProviderCatalog,
        providersDir: URL
    ) -> [String: [ProxiesOverviewModel.Proxy]] {
        var nodes: [String: [ProxiesOverviewModel.Proxy]] = [:]
        for entry in catalog.entries where entry.kind == "proxy" {
            nodes[entry.name] = parsePayload(
                at: providersDir.appendingPathComponent(entry.path)
            )
        }
        return nodes
    }

    private static func parsePayload(at url: URL) -> [ProxiesOverviewModel.Proxy] {
        guard let yaml = try? String(contentsOf: url, encoding: .utf8),
              let json = try? ConfigTransforms.yamlToJSON(yaml),
              let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let root = value as? [String: Any],
              let proxies = root["proxies"] as? [Any] else {
            return []
        }
        return proxies.compactMap {
            guard let dict = $0 as? [String: Any],
                  let name = dict["name"] as? String, !name.isEmpty else { return nil }
            return ProxiesOverviewModel.Proxy(
                name: name,
                type: (dict["type"] as? String) ?? ""
            )
        }
    }
}
