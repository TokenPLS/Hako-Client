import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct InlineProxyRow: Identifiable, Equatable {
     
     
     
    let id: String
    let name: String
    let type: String
     
     
    let json: String

     
     
    var mapping: [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    }

     
    static func rows(from payload: [[String: Any]]) -> [InlineProxyRow] {
        zip(payload, identities(for: payload)).compactMap { mapping, id in
            guard let id,
                  let name = mapping["name"] as? String,
                  let type = mapping["type"] as? String,
                  let data = try? JSONSerialization.data(
                    withJSONObject: mapping, options: [.sortedKeys]
                  ) else { return nil }
            return InlineProxyRow(
                id: id,
                name: name,
                type: type,
                json: String(decoding: data, as: UTF8.self)
            )
        }
    }

     
     
     
     
     
     
     
    static func identities(for payload: [[String: Any]]) -> [String?] {
        var seen: [String: Int] = [:]
        return payload.map { mapping in
            guard let name = mapping["name"] as? String,
                  mapping["type"] is String,
                  JSONSerialization.isValidJSONObject(mapping) else { return nil }
             
             
             
             
            let occurrence = seen[name, default: 0]
            seen[name] = occurrence + 1
            return occurrence == 0 ? name : "\(name)#\(occurrence)"
        }
    }
}

 
 
 
 
 
 
 
 
 
enum CustomNodePayload {
     
     
    static func rows(inDefinition definition: String?) throws -> [InlineProxyRow] {
        InlineProxyRow.rows(from: try payload(inDefinition: definition))
    }

     
     
     
    static func payload(inDefinition definition: String?) throws -> [[String: Any]] {
        guard let definition else { return [] }
        guard let object = try? JSONSerialization.jsonObject(
            with: Data(definition.utf8)
        ) as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidDefinition
        }
        guard let payload = object["payload"] as? [[String: Any]] else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        return payload
    }

    static let providerName = "hako-custom"

     
     
     
     
     
     
     
    static func definition(for payload: [[String: Any]]) -> [String: Any] {
        ["type": "inline", "payload": payload]
    }

     
    static func definitionJSON(for payload: [[String: Any]]) throws -> String? {
        guard !payload.isEmpty else { return nil }
        return String(
            decoding: try JSONSerialization.data(
                withJSONObject: definition(for: payload)
            ),
            as: UTF8.self
        )
    }

     
     
     
     
     
     
     
    static func write(
        _ payload: [[String: Any]],
        into draft: inout ProfileProviderDefinitionsDraft
    ) throws {
        let definition: [String: Any] = Self.definition(for: payload)
        let json = String(
            decoding: try JSONSerialization.data(withJSONObject: definition),
            as: UTF8.self
        )
        let exists = draft.records(kind: .proxy).contains { $0.name == providerName }
        if exists {
            if payload.isEmpty {
                try draft.removeDefinition(named: providerName, kind: .proxy)
            } else {
                try draft.updateDefinition(
                    named: providerName, kind: .proxy, definitionJSON: json
                )
            }
        } else if !payload.isEmpty {
            try draft.addDefinition(
                named: providerName, kind: .proxy, definitionJSON: json
            )
        }
    }

     
     
     
     
     
     
     
    static func appending(
        _ additions: [[String: Any]],
        to existing: [[String: Any]]
    ) -> [[String: Any]] {
        var taken = Set(existing.compactMap { $0["name"] as? String })
        var payload = existing
        for var node in additions {
            guard let name = node["name"] as? String else {
                payload.append(node)
                continue
            }
            var candidate = name
            var suffix = 2
            while taken.contains(candidate) {
                candidate = "\(name) \(suffix)"
                suffix += 1
            }
            taken.insert(candidate)
            node["name"] = candidate
            payload.append(node)
        }
        return payload
    }
}
