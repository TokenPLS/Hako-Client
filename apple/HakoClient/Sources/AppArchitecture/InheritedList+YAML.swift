import Foundation
import HakoClientUI

 
 
 
 

extension InheritedList {
     
     
     
    public static func base(ofList keyPath: String, in yaml: String) throws -> InheritedListBase {
        guard let root = try ParsedProfileSource.root(of: yaml) else { return .unset }
        return base(ofList: keyPath, inRoot: root)
    }

     
    static func base(ofList keyPath: String, inRoot root: [String: Any]) -> InheritedListBase {
        guard let list = ParsedProfileSource.node(at: keyPath, in: root) as? [Any] else { return .unset }
        return .profile(list.map { ($0 as? String) ?? String(describing: $0) })
    }
}
