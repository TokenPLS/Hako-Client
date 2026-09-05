import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct InvalidDomainSite: Equatable {
     
    enum Locator: Equatable {
         
        case index(Int)
         
         
        case key(String)
    }

     
     
     
     
     
     
     
    enum Reason: String, Equatable {
        case trailingDot = "trailing-dot"
        case whitespace
        case empty
        case emptySegment = "empty-segment"
        case barePlus = "bare-plus"
        case plusOutsideLeadingLabel = "plus-outside-leading-label"
        case starInsideLabel = "star-inside-label"
        case other
    }

     
     
    let field: String
    let locator: Locator
     
     
     
    let entry: String
    let reason: Reason

     
     
     
     
     
     
     
    static func sites(fromJSON json: String) -> [InvalidDomainSite]? {
        guard let data = json.data(using: .utf8),
            let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        return rows.compactMap { row in
            guard let field = row["field"] as? String,
                let entry = row["entry"] as? String
            else { return nil }
            let locator: Locator
            if let index = row["index"] as? Int {
                locator = .index(index)
            } else if let key = row["key"] as? String {
                locator = .key(key)
            } else {
                return nil
            }
            return .init(
                field: field,
                locator: locator,
                entry: entry,
                reason: Reason(rawValue: row["reason"] as? String ?? "") ?? .other
            )
        }
    }
}
