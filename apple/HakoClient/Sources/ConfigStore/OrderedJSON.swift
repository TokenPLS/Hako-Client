import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
indirect enum OrderedJSON: Equatable {
    case object([(key: String, value: OrderedJSON)])
    case array([OrderedJSON])
    case string(String)
     
    case scalar(String)

    static func == (lhs: OrderedJSON, rhs: OrderedJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.object(l), .object(r)):
            return l.count == r.count
                && zip(l, r).allSatisfy { $0.key == $1.key && $0.value == $1.value }
        case let (.array(l), .array(r)):
            return l == r
        case let (.string(l), .string(r)):
            return l == r
        case let (.scalar(l), .scalar(r)):
            return l == r
        default:
            return false
        }
    }
}

extension OrderedJSON {
    enum ParseError: Error, Equatable {
        case unexpectedEnd
        case unexpectedCharacter(Character, at: Int)
        case invalidNumber(at: Int)
        case invalidEscape(at: Int)
        case trailingContent(at: Int)
    }

     
    static func parse(_ text: String) throws -> OrderedJSON {
        var parser = Parser(Array(text.unicodeScalars))
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.isAtEnd else { throw ParseError.trailingContent(at: parser.index) }
        return value
    }

     
    func serialized() -> String {
        var out = ""
        write(into: &out)
        return out
    }

    private func write(into out: inout String) {
        switch self {
        case let .object(pairs):
            out.append("{")
            for (offset, pair) in pairs.enumerated() {
                if offset > 0 { out.append(",") }
                OrderedJSON.writeString(pair.key, into: &out)
                out.append(":")
                pair.value.write(into: &out)
            }
            out.append("}")
        case let .array(items):
            out.append("[")
            for (offset, item) in items.enumerated() {
                if offset > 0 { out.append(",") }
                item.write(into: &out)
            }
            out.append("]")
        case let .string(value):
            OrderedJSON.writeString(value, into: &out)
        case let .scalar(token):
            out.append(token)
        }
    }

    private static func writeString(_ value: String, into out: inout String) {
        out.append("\"")
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out.append("\\\"")
            case "\\": out.append("\\\\")
            case "\u{08}": out.append("\\b")
            case "\u{0C}": out.append("\\f")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            case let s where s.value < 0x20:
                out.append(String(format: "\\u%04x", s.value))
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        out.append("\"")
    }

     

    private struct Parser {
        private let scalars: [Unicode.Scalar]
        private(set) var index = 0

        init(_ scalars: [Unicode.Scalar]) { self.scalars = scalars }

        var isAtEnd: Bool { index >= scalars.count }

        mutating func skipWhitespace() {
            while index < scalars.count {
                switch scalars[index] {
                case " ", "\t", "\n", "\r": index += 1
                default: return
                }
            }
        }

        private func peek() -> Unicode.Scalar? {
            index < scalars.count ? scalars[index] : nil
        }

        mutating func parseValue() throws -> OrderedJSON {
            skipWhitespace()
            guard let c = peek() else { throw ParseError.unexpectedEnd }
            switch c {
            case "{": return try parseObject()
            case "[": return try parseArray()
            case "\"": return .string(try parseStringLiteral())
            case "t", "f", "n": return .scalar(try parseKeyword())
            case "-", "0"..."9": return .scalar(try parseNumber())
            default: throw ParseError.unexpectedCharacter(Character(c), at: index)
            }
        }

        private mutating func expect(_ scalar: Unicode.Scalar) throws {
            skipWhitespace()
            guard peek() == scalar else {
                if let c = peek() { throw ParseError.unexpectedCharacter(Character(c), at: index) }
                throw ParseError.unexpectedEnd
            }
            index += 1
        }

        private mutating func parseObject() throws -> OrderedJSON {
            index += 1  
            var pairs: [(key: String, value: OrderedJSON)] = []
            skipWhitespace()
            if peek() == "}" { index += 1; return .object(pairs) }
            while true {
                skipWhitespace()
                guard peek() == "\"" else {
                    if let c = peek() { throw ParseError.unexpectedCharacter(Character(c), at: index) }
                    throw ParseError.unexpectedEnd
                }
                let key = try parseStringLiteral()
                try expect(":")
                let value = try parseValue()
                pairs.append((key: key, value: value))
                skipWhitespace()
                switch peek() {
                case ",": index += 1
                case "}": index += 1; return .object(pairs)
                case let c?: throw ParseError.unexpectedCharacter(Character(c), at: index)
                case nil: throw ParseError.unexpectedEnd
                }
            }
        }

        private mutating func parseArray() throws -> OrderedJSON {
            index += 1  
            var items: [OrderedJSON] = []
            skipWhitespace()
            if peek() == "]" { index += 1; return .array(items) }
            while true {
                items.append(try parseValue())
                skipWhitespace()
                switch peek() {
                case ",": index += 1
                case "]": index += 1; return .array(items)
                case let c?: throw ParseError.unexpectedCharacter(Character(c), at: index)
                case nil: throw ParseError.unexpectedEnd
                }
            }
        }

        private mutating func parseKeyword() throws -> String {
            for keyword in ["true", "false", "null"] {
                let scalarsOfKeyword = Array(keyword.unicodeScalars)
                if matches(scalarsOfKeyword) {
                    index += scalarsOfKeyword.count
                    return keyword
                }
            }
            throw ParseError.unexpectedCharacter(Character(scalars[index]), at: index)
        }

        private func matches(_ candidate: [Unicode.Scalar]) -> Bool {
            guard index + candidate.count <= scalars.count else { return false }
            for (offset, scalar) in candidate.enumerated() where scalars[index + offset] != scalar {
                return false
            }
            return true
        }

        private mutating func parseNumber() throws -> String {
            let start = index
            if peek() == "-" { index += 1 }
            while let c = peek(), ("0"..."9").contains(c) { index += 1 }
            if peek() == "." {
                index += 1
                while let c = peek(), ("0"..."9").contains(c) { index += 1 }
            }
            if peek() == "e" || peek() == "E" {
                index += 1
                if peek() == "+" || peek() == "-" { index += 1 }
                while let c = peek(), ("0"..."9").contains(c) { index += 1 }
            }
            guard index > start else { throw ParseError.invalidNumber(at: start) }
            return String(String.UnicodeScalarView(scalars[start..<index]))
        }

        private mutating func parseStringLiteral() throws -> String {
            index += 1  
            var value = String.UnicodeScalarView()
            while let c = peek() {
                index += 1
                switch c {
                case "\"":
                    return String(value)
                case "\\":
                    guard let escape = peek() else { throw ParseError.unexpectedEnd }
                    index += 1
                    switch escape {
                    case "\"": value.append("\"")
                    case "\\": value.append("\\")
                    case "/": value.append("/")
                    case "b": value.append("\u{08}")
                    case "f": value.append("\u{0C}")
                    case "n": value.append("\n")
                    case "r": value.append("\r")
                    case "t": value.append("\t")
                    case "u": value.append(try parseUnicodeEscape())
                    default: throw ParseError.invalidEscape(at: index - 1)
                    }
                default:
                    value.append(c)
                }
            }
            throw ParseError.unexpectedEnd
        }

        private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
            func readHex4() throws -> UInt32 {
                guard index + 4 <= scalars.count else { throw ParseError.unexpectedEnd }
                var code: UInt32 = 0
                for _ in 0..<4 {
                    let digit = scalars[index]
                    guard let hex = digit.hexDigitValue else {
                        throw ParseError.invalidEscape(at: index)
                    }
                    code = code * 16 + UInt32(hex)
                    index += 1
                }
                return code
            }
            let first = try readHex4()
             
            if (0xD800...0xDBFF).contains(first) {
                guard index + 1 < scalars.count, scalars[index] == "\\", scalars[index + 1] == "u" else {
                    throw ParseError.invalidEscape(at: index)
                }
                index += 2
                let second = try readHex4()
                guard (0xDC00...0xDFFF).contains(second) else { throw ParseError.invalidEscape(at: index) }
                let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                guard let scalar = Unicode.Scalar(combined) else { throw ParseError.invalidEscape(at: index) }
                return scalar
            }
            guard let scalar = Unicode.Scalar(first) else { throw ParseError.invalidEscape(at: index) }
            return scalar
        }
    }
}

private extension Unicode.Scalar {
    var hexDigitValue: Int? {
        switch self {
        case "0"..."9": return Int(value - 0x30)
        case "a"..."f": return Int(value - 0x61 + 10)
        case "A"..."F": return Int(value - 0x41 + 10)
        default: return nil
        }
    }
}

 

extension OrderedJSON {
     
    func topLevelValue(_ key: String) -> OrderedJSON? {
        guard case let .object(pairs) = self else { return nil }
        return pairs.first { $0.key == key }?.value
    }

     
     
    func settingTopLevel(_ key: String, to value: OrderedJSON) -> OrderedJSON {
        guard case var .object(pairs) = self else { return self }
        if let existing = pairs.firstIndex(where: { $0.key == key }) {
            pairs[existing] = (key: key, value: value)
        } else {
            pairs.append((key: key, value: value))
        }
        return .object(pairs)
    }
}

 

extension OrderedJSON {
     
     
     
     
     
    func canonicalSerialized(preservingOrderForKeys: Set<String>) -> String {
        var out = ""
        writeCanonical(sortKeys: true, preservingOrderForKeys: preservingOrderForKeys, into: &out)
        return out
    }

    private func writeCanonical(
        sortKeys: Bool,
        preservingOrderForKeys keys: Set<String>,
        into out: inout String
    ) {
        switch self {
        case let .object(pairs):
            let ordered = sortKeys ? pairs.sorted { $0.key < $1.key } : pairs
            out.append("{")
            for (offset, pair) in ordered.enumerated() {
                if offset > 0 { out.append(",") }
                OrderedJSON.string(pair.key).write(into: &out)  
                out.append(":")
                 
                pair.value.writeCanonical(
                    sortKeys: keys.contains(pair.key) ? false : true,
                    preservingOrderForKeys: keys,
                    into: &out
                )
            }
            out.append("}")
        case let .array(items):
            out.append("[")
            for (offset, item) in items.enumerated() {
                if offset > 0 { out.append(",") }
                item.writeCanonical(sortKeys: sortKeys, preservingOrderForKeys: keys, into: &out)
            }
            out.append("]")
        case .string, .scalar:
            write(into: &out)
        }
    }
}

 

extension OrderedJSON {
     
     
     
     
    var foundationValue: Any {
        switch self {
        case let .object(pairs):
            var dict: [String: Any] = [:]
            for pair in pairs { dict[pair.key] = pair.value.foundationValue }
            return dict
        case let .array(items):
            return items.map { $0.foundationValue }
        case let .string(value):
            return value
        case let .scalar(token):
            switch token {
            case "true": return true
            case "false": return false
            case "null": return NSNull()
            default:
                if let int = Int(token) { return int }
                if let double = Double(token) { return double }
                return token
            }
        }
    }

     
     
     
    static func from(foundation value: Any) -> OrderedJSON {
        switch value {
        case let node as OrderedJSON:
            return node
        case let string as String:
            return .string(string)
        case is NSNull:
            return .scalar("null")
         
         
         
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            return .scalar(number.boolValue ? "true" : "false")
        case let number as NSNumber:
            if let int = number as? Int, Double(int) == number.doubleValue {
                return .scalar(String(int))
            }
            return .scalar(String(describing: number))
        case let array as [Any]:
            return .array(array.map { OrderedJSON.from(foundation: $0) })
        case let dict as [String: Any]:
            return .object(dict.keys.sorted().map { (key: $0, value: OrderedJSON.from(foundation: dict[$0]!)) })
        default:
            return .string(String(describing: value))
        }
    }

     
    func node(at path: [String]) -> OrderedJSON? {
        var node: OrderedJSON? = self
        for key in path { node = node?.topLevelValue(key) }
        return node
    }

     
    func orderedObject(at path: [String]) -> [(key: String, value: OrderedJSON)]? {
        guard case let .object(pairs)? = node(at: path) else { return nil }
        return pairs
    }

     
     
     
    func setting(path: [String], to value: OrderedJSON?) -> OrderedJSON {
        guard let head = path.first else { return value ?? self }
        let base: OrderedJSON = { if case .object = self { return self } else { return .object([]) } }()
        let child = base.topLevelValue(head) ?? .object([])
        if path.count == 1 {
            guard let value else { return base.removingTopLevel(head) }
            return base.settingTopLevel(head, to: value)
        }
        let updatedChild = child.setting(path: Array(path.dropFirst()), to: value)
         
        if case let .object(pairs) = updatedChild, pairs.isEmpty {
            return base.removingTopLevel(head)
        }
        return base.settingTopLevel(head, to: updatedChild)
    }

    func removingTopLevel(_ key: String) -> OrderedJSON {
        guard case let .object(pairs) = self else { return self }
        return .object(pairs.filter { $0.key != key })
    }
}

extension OrderedJSON {
     
     
     
     
     
     
     
     
     
    func reorderingMappings(following source: OrderedJSON) -> OrderedJSON {
        switch (self, source) {
        case let (.object(pairs), .object(sourcePairs)):
             
             
            var position: [String: Int] = [:]
            position.reserveCapacity(pairs.count)
            for (index, pair) in pairs.enumerated() where position[pair.key] == nil {
                position[pair.key] = index
            }
            var ordered: [(key: String, value: OrderedJSON)] = []
            ordered.reserveCapacity(pairs.count)
            var placed = Set<Int>()
            for sourcePair in sourcePairs {
                guard let index = position[sourcePair.key], !placed.contains(index) else { continue }
                placed.insert(index)
                ordered.append((
                    key: pairs[index].key,
                    value: pairs[index].value.reorderingMappings(following: sourcePair.value)
                ))
            }
            for (index, pair) in pairs.enumerated() where !placed.contains(index) {
                ordered.append(pair)
            }
            return .object(ordered)
        case let (.array(items), .array(sourceItems)):
            var paired = items
            for index in 0..<min(items.count, sourceItems.count) {
                paired[index] = items[index].reorderingMappings(following: sourceItems[index])
            }
            return .array(paired)
        default:
            return self
        }
    }
}
