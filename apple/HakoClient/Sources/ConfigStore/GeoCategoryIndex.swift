import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum GeoCategoryIndex {
     
     
     
    static func coreHomeDir(
        containerProvider: (String) -> URL? = { _ in
            HakoAppIdentifiers.appGroupContainer
        }
    ) -> URL? {
        containerProvider(HakoAppIdentifiers.appGroup)?
            .appendingPathComponent("working", isDirectory: true)
    }

     
     
     
     
    static func activeURL(
        for resource: GeoResource,
        homeDir: URL?,
        bundle: Bundle = .main
    ) -> URL? {
        if let homeDir {
            let candidate = homeDir.appendingPathComponent(resource.fileName)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        let name = resource.fileName as NSString
        return bundle.url(
            forResource: name.deletingPathExtension,
            withExtension: name.pathExtension
        )
    }
}

 
 
 
 
enum GeoCategoryParser {
    static func categories(from data: Data) -> [String] {
        let bytes = [UInt8](data)
        var top = ProtoReader(bytes, from: 0, to: bytes.count)
        var out = Set<String>()
        while !top.atEnd {
            guard let tag = top.tag() else { break }
            if tag.field == 1, tag.wire == 2 {
                guard let entry = top.lengthDelimited() else { break }
                if let code = countryCode(bytes: bytes, in: entry) {
                    out.insert(code)
                }
            } else if !top.skip(wire: tag.wire) {
                break
            }
        }
        return out.sorted()
    }

     
    private static func countryCode(bytes: [UInt8], in range: Range<Int>) -> String? {
        var reader = ProtoReader(bytes, from: range.lowerBound, to: range.upperBound)
        while !reader.atEnd {
            guard let tag = reader.tag() else { return nil }
            if tag.field == 1, tag.wire == 2 {
                guard let value = reader.lengthDelimited() else { return nil }
                let code = String(decoding: bytes[value], as: UTF8.self)
                return code.isEmpty ? nil : code.lowercased()
            }
            if !reader.skip(wire: tag.wire) { return nil }
        }
        return nil
    }
}

 
 
 
private struct ProtoReader {
    private let bytes: [UInt8]
    private var index: Int
    private let end: Int

    init(_ bytes: [UInt8], from: Int, to: Int) {
        self.bytes = bytes
        self.index = from
        self.end = to
    }

    var atEnd: Bool { index >= end }

    mutating func varint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < end {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    mutating func tag() -> (field: UInt64, wire: UInt64)? {
        guard let raw = varint() else { return nil }
        return (raw >> 3, raw & 0x7)
    }

     
    mutating func lengthDelimited() -> Range<Int>? {
        guard let length = varint() else { return nil }
        let start = index
        let stop = start &+ Int(length)
        guard length <= UInt64(end - start), stop >= start, stop <= end else { return nil }
        index = stop
        return start..<stop
    }

     
     
    mutating func skip(wire: UInt64) -> Bool {
        switch wire {
        case 0: return varint() != nil
        case 1: index &+= 8; return index <= end
        case 2: return lengthDelimited() != nil
        case 5: index &+= 4; return index <= end
        default: return false
        }
    }
}

 
 
 
 
actor GeoCategoryCache {
    static let shared = GeoCategoryCache()

    private var memo: [String: [String]] = [:]

    func categories(
        for resource: GeoResource,
        homeDir: URL? = GeoCategoryIndex.coreHomeDir(),
        bundle: Bundle = .main
    ) -> [String] {
        guard resource == .geoip || resource == .geosite else { return [] }
        guard let url = GeoCategoryIndex.activeURL(for: resource, homeDir: homeDir, bundle: bundle),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        else { return [] }

        let size = (attributes[.size] as? NSNumber)?.intValue ?? -1
        let mtime = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(size)|\(mtime)"
        if let cached = memo[key] { return cached }

        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
        let categories = GeoCategoryParser.categories(from: data)
        memo[key] = categories
        return categories
    }
}
