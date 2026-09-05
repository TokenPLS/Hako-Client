import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 

 
 
 
 
 
 
 
 
 
 
 
enum ParsedProfileSource {
    private static let lock = NSLock()
    private static var recent: [(key: Int, length: Int, root: [String: Any])] = []

     
     
    static func root(of yaml: String) throws -> [String: Any]? {
        let key = yaml.hashValue
        let length = yaml.utf8.count
        lock.lock()
        if let hit = recent.first(where: { $0.key == key && $0.length == length }) {
            lock.unlock()
            return hit.root
        }
        lock.unlock()
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard let data = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        lock.lock()
        recent.removeAll { $0.key == key && $0.length == length }
        recent.insert((key, length, root), at: 0)
        if recent.count > 2 { recent.removeLast() }
        lock.unlock()
        return root
    }

     
    static func node(at keyPath: String, in root: [String: Any]) -> Any? {
        var node = root
        let parts = keyPath.split(separator: ".").map(String.init)
        for (index, part) in parts.enumerated() {
            guard let next = node[part] else { return nil }
            if index == parts.count - 1 { return next }
            guard let child = next as? [String: Any] else { return nil }
            node = child
        }
        return nil
    }

    static func node(at keyPath: String, in yaml: String) throws -> Any? {
        guard let root = try root(of: yaml) else { return nil }
        return node(at: keyPath, in: root)
    }
}

extension InheritedBool {
    static func base(of keyPath: String, in yaml: String) throws -> InheritedBase {
        guard let root = try ParsedProfileSource.root(of: yaml) else { return .unset }
        return base(of: keyPath, inRoot: root)
    }

     
     
    static func base(of keyPath: String, inRoot root: [String: Any]) -> InheritedBase {
        guard let value = ParsedProfileSource.node(at: keyPath, in: root) as? Bool else { return .unset }
        return .profile(value)
    }
}

extension InheritedText {
    static func base(ofText keyPath: String, in yaml: String) throws -> InheritedTextBase {
        guard let root = try ParsedProfileSource.root(of: yaml) else { return .unset }
        return base(ofText: keyPath, inRoot: root)
    }

    static func base(ofText keyPath: String, inRoot root: [String: Any]) -> InheritedTextBase {
        guard let node = ParsedProfileSource.node(at: keyPath, in: root) else { return .unset }
        let text: String
        if let s = node as? String { text = s }
        else if let n = node as? NSNumber { text = n.stringValue }
        else { return .unset }
        if text.isEmpty, UpstreamTextDefault.pinned(for: keyPath).sentinelMeansDefault { return .profileUsesDefault }
        return .profile(text)
    }
}

extension InheritedNumber {
    static func base(ofNumber keyPath: String, in yaml: String) throws -> InheritedNumberBase {
        guard let root = try ParsedProfileSource.root(of: yaml) else { return .unset }
        return base(ofNumber: keyPath, inRoot: root)
    }

    static func base(ofNumber keyPath: String, inRoot root: [String: Any]) -> InheritedNumberBase {
        guard let node = ParsedProfileSource.node(at: keyPath, in: root) else { return .unset }
        let number: Int
        if let n = node as? NSNumber { number = n.intValue }
        else if let s = node as? String, let n = Int(s) { number = n }
        else { return .unset }
        if number == 0, UpstreamNumberDefault.pinned(for: keyPath).sentinelMeansDefault { return .profileUsesDefault }
        return .profile(number)
    }
}

extension HakoDNSInheritedBases {
     
     
     
    static func read(sourceYAML: String) -> HakoDNSInheritedBases {
        var bases = HakoDNSInheritedBases()
        guard let root = (try? ParsedProfileSource.root(of: sourceYAML)) ?? nil else {
            for key in boolKeyPaths { bases.bools[key] = .unset }
            for key in textKeyPaths { bases.texts[key] = .unset }
            for key in numberKeyPaths { bases.numbers[key] = .unset }
            for key in listKeyPaths { bases.lists[key] = .unset }
            bases.profileEnablesDNS = .unset
            return bases
        }
        for key in boolKeyPaths { bases.bools[key] = InheritedBool.base(of: key, inRoot: root) }
        for key in textKeyPaths { bases.texts[key] = InheritedText.base(ofText: key, inRoot: root) }
        for key in numberKeyPaths { bases.numbers[key] = InheritedNumber.base(ofNumber: key, inRoot: root) }
        for key in listKeyPaths { bases.lists[key] = InheritedList.base(ofList: key, inRoot: root) }
        bases.profileEnablesDNS = InheritedBool.base(of: "dns.enable", inRoot: root)
        return bases
    }
}
