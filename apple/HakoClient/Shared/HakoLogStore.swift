import Foundation

 
 
 
 
 
 
 
 
public enum HakoLogStream: String, CaseIterable, Sendable {
     
    case core
     
    case app

     
     
     
     
    public var filePrefix: String { rawValue }

     
    public var bytesPerDay: Int {
        switch self {
        case .core: return 20 * 1024 * 1024
        case .app: return 1024 * 1024
        }
    }

     
     
     
     
    public var bytesPerFile: Int {
        switch self {
        case .core: return 20 * 1024 * 1024
        case .app: return 1024 * 1024
        }
    }
}

 
 
 
 
 
 
public enum HakoLogRetention: String, CaseIterable, Sendable {
    case oneDay
    case sevenDays
    case thirtyDays

    public var title: String {
        switch self {
        case .oneDay: return "1 day"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        }
    }

    public var window: TimeInterval {
        switch self {
        case .oneDay: return 86_400
        case .sevenDays: return 7 * 86_400
        case .thirtyDays: return 30 * 86_400
        }
    }
}

 
 
 
 
 
 
public enum HakoLogSettings {
    public static let recordingKey = "logs.recording"

    public static func isRecording(from defaults: UserDefaults) -> Bool {
        defaults.object(forKey: recordingKey) as? Bool ?? true
    }

    public static func setRecording(_ value: Bool, in defaults: UserDefaults) {
        defaults.set(value, forKey: recordingKey)
    }

    public static let retentionKey = "logs.retention"

    public static func retention(from defaults: UserDefaults) -> HakoLogRetention {
        (defaults.string(forKey: retentionKey))
            .flatMap(HakoLogRetention.init(rawValue:)) ?? .sevenDays
    }

    public static func setRetention(
        _ value: HakoLogRetention,
        in defaults: UserDefaults
    ) {
        defaults.set(value.rawValue, forKey: retentionKey)
    }

     
     
     
    public static let severityFilterKey = "logs.levels"

     
     
     
     
     
    public static func severityFilter(from defaults: UserDefaults) -> [String] {
        (defaults.stringArray(forKey: severityFilterKey) ?? [])
            .filter { HakoLogLevel(rawValue: $0) != nil }
    }

    public static func setSeverityFilter(
        _ levels: [String],
        in defaults: UserDefaults
    ) {
        defaults.set(levels, forKey: severityFilterKey)
    }
}

public enum HakoLogLevel: String, Sendable {
    case error
    case warning
    case info
    case debug
}

 
 
 
 
 
 
 
 
 
 
 
public final class HakoLogStore: @unchecked Sendable {
    public static let shared = HakoLogStore()

    private let directory: URL?
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "network.hako.logstore")
    private let clock: () -> Date
    private let settings: UserDefaults?
     
     
     
     
    private var preparedDirectory = false
    private var lastPruneKey: [HakoLogStream: String] = [:]

    public init(
        directory: URL? = HakoLogStore.defaultDirectory(),
        fileManager: FileManager = .default,
        clock: @escaping () -> Date = Date.init,
        settings: UserDefaults? = HakoLogStore.defaultSettings()
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.clock = clock
        self.settings = settings
    }

    public static func defaultSettings() -> UserDefaults? {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
    }

    public static func defaultDirectory() -> URL? {
        HakoAppIdentifiers.appGroupContainer?.appendingPathComponent("logs", isDirectory: true)
    }

     
     
    public func append(
        _ message: String,
        stream: HakoLogStream = .app,
        level: HakoLogLevel = .info
    ) {
         
         
        if let settings, !HakoLogSettings.isRecording(from: settings) { return }
         
         
         
         
        guard !message.isEmpty else { return }
        let now = clock()
        let stamped = "\(Self.timestamp(now))  \(level.rawValue.uppercased())  \(message)\n"
        let day = Self.day(now)
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if isStartingUp() {
            queue.sync {
                write(stamped, stream: stream, on: day)
                pruneExpired(stream, now: now)
            }
            return
        }
        queue.async { [weak self] in
            self?.write(stamped, stream: stream, on: day)
            self?.pruneExpired(stream, now: now)
        }
    }

     
     
     
    private let startupLock = NSLock()
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var startingUp = Bundle.main.bundlePath.hasSuffix(".appex")

    private func isStartingUp() -> Bool {
        startupLock.lock()
        defer { startupLock.unlock() }
        return startingUp
    }

    public func markTunnelEstablished() {
        startupLock.lock()
        startingUp = false
        startupLock.unlock()
    }

    public func markStartingUp() {
        startupLock.lock()
        startingUp = true
        startupLock.unlock()
    }

     
     
     
     
     
    public func flush() {
        queue.sync {}
    }

     
     
     
     
     
     
     
     
     
     
     
    public func clear() {
        guard let directory else { return }
        queue.sync {
            for stream in HakoLogStream.allCases {
                for url in files(for: stream) {
                    try? fileManager.removeItem(at: url)
                }
            }
            try? fileManager.removeItem(at: directory)
            preparedDirectory = false
            lastPruneKey.removeAll()
        }
    }

     
     
     
     
     
     
    public static let readBudgetPerStream = 8 * 1024 * 1024

     
     
     
    public func read(_ stream: HakoLogStream) -> String {
        queue.sync {
            var pieces: [String] = []
            var budget = Self.readBudgetPerStream
            var omitted = 0
             
             
            for url in files(for: stream).reversed() {
                if budget <= 0 {
                    omitted += ((try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
                    continue
                }
                autoreleasepool {
                    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
                     
                    let cost = text.utf8.count
                    if cost <= budget {
                        budget -= cost
                        pieces.append(text)
                    } else {
                         
                         
                         
                         
                         
                         
                         
                        let bytes = Array(text.utf8.suffix(budget))
                        if let newline = bytes.firstIndex(of: 0x0A), newline + 1 < bytes.count {
                            let kept = String(decoding: bytes[(newline + 1)...], as: UTF8.self)
                            omitted += cost - kept.utf8.count
                            pieces.append(kept)
                        } else {
                            omitted += cost
                        }
                        budget = 0
                    }
                }
            }
            var body = pieces.reversed().joined()
            if omitted > 0 {
                body = "===== \(omitted / 1024) KiB of older lines omitted (read is bounded at \(Self.readBudgetPerStream / 1024 / 1024) MiB per stream) =====\n" + body
            }
            return body
        }
    }





     
     
     
     
     
     
     
     
    public static func isDayFileName(_ name: String) -> Bool {
        HakoLogStream.allCases.contains { stream in
            let prefix = stream.filePrefix + "-"
            guard name.hasPrefix(prefix), name.hasSuffix(".log") else { return false }
            let day = String(name.dropFirst(prefix.count).dropLast(".log".count))
            guard let parsed = dayFormatter.date(from: day) else { return false }
            return dayFormatter.string(from: parsed) == day
        }
    }



     
     
     
     
     
     
    private static let generationLock = NSLock()
    private static var mirrorGeneration = 0
    static var currentGeneration: Int {
        generationLock.lock(); defer { generationLock.unlock() }
        return mirrorGeneration
    }


     
     
     
     
     
     
     
     
     
     
    static func isOurMirrorCopy(at url: URL) -> Bool {
        guard isDayFileName(url.lastPathComponent),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        let head = try? handle.read(upToCount: 512)
        try? handle.close()
        guard let data = head else { return false }

         
         
         
         
         
         
         
        let line = Array(data.prefix(while: { $0 != 0x0A }))
        let stampEnd = timestampWidth
        guard line.count > stampEnd + 2, line[0..<stampEnd].allSatisfy({ $0 < 0x80 }),
              line[stampEnd] == 0x20, line[stampEnd + 1] == 0x20 else { return false }
        let stamp = String(decoding: line[0..<stampEnd], as: UTF8.self)
        guard let parsed = formatter.date(from: stamp), formatter.string(from: parsed) == stamp else { return false }

        let levelStart = stampEnd + 2
        let levelBytes = Array(line[levelStart...].prefix(while: { $0 != 0x20 }))
        guard !levelBytes.isEmpty, levelBytes.allSatisfy({ $0 < 0x80 }),
              HakoLogLevel(rawValue: String(decoding: levelBytes, as: UTF8.self).lowercased()) != nil else { return false }
         
        let afterLevel = levelStart + levelBytes.count
        guard line.count > afterLevel + 1, line[afterLevel] == 0x20, line[afterLevel + 1] == 0x20 else { return false }
        return true
    }

     
     
    static let stagingPrefix = ".hako-mirror-"

     
     
     
     
     
     
     
     
    private static func removeStagingOrphans(in directory: URL) {


    }

     
     
     
     
     
     
     
     
     
    public static let mirrorDirectoryName = "HakoLogs"





     
     
     
     
     
     
     
     
     
    public func tail(_ stream: HakoLogStream, limit: Int = 400) -> [String] {
        queue.sync {
            var collected: [String] = []
            for url in files(for: stream).reversed() where collected.count < limit {
                collected = Self.lastLines(limit - collected.count, of: url)
                    + collected
            }
            return Array(collected.suffix(limit))
        }
    }

     
     
     
     
     
     
     
     
     
     
    private static func lastLines(_ count: Int, of url: URL) -> [String] {
        guard count > 0,
              let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd(), end > 0 else { return [] }

        let chunkSize: UInt64 = 128 * 1024
        var offset = end
        var buffer = Data()
        var newlines = 0
         
         
        while offset > 0, newlines <= count {
            let readSize = min(chunkSize, offset)
            offset -= readSize
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let chunk = try? handle.read(upToCount: Int(readSize)),
                  !chunk.isEmpty else { break }
            newlines += chunk.reduce(into: 0) { if $1 == 0x0A { $0 += 1 } }
            buffer = chunk + buffer
        }
        if offset > 0 {
            guard let cut = buffer.firstIndex(of: 0x0A) else { return [] }
            buffer = buffer[buffer.index(after: cut)...]
        }
        guard let text = String(data: buffer, encoding: .utf8) else { return [] }
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(count)
            .map(String.init)
    }

     
     
     
     
     
     
    public func mergedTail(limit: Int = 400) -> [String] {
        let merged = HakoLogStream.allCases
            .flatMap { tail($0, limit: limit) }
            .sorted { lhs, rhs in
                 
                 
                lhs.prefix(Self.timestampWidth) < rhs.prefix(Self.timestampWidth)
            }
        return Array(merged.suffix(limit))
    }

    private static let timestampWidth = 24

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @discardableResult
    public func writeExport(to destination: URL) -> Bool {
        let fileManager = self.fileManager
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            return false
        }
        guard let handle = try? FileHandle(forWritingTo: destination) else { return false }
        defer { try? handle.close() }
        let urls = queue.sync { HakoLogStream.allCases.map { ($0, files(for: $0)) } }
        for (index, entry) in urls.enumerated() {
            let header = (index == 0 ? "" : "\n") + "===== \(entry.0.rawValue) =====\n"
            try? handle.write(contentsOf: Data(header.utf8))
            for url in entry.1 {
                guard let reader = try? FileHandle(forReadingFrom: url) else { continue }
                defer { try? reader.close() }
                while let chunk = try? reader.read(upToCount: 256 * 1024), !chunk.isEmpty {
                    try? handle.write(contentsOf: chunk)
                }
            }
        }
        return true
    }

    public func removeAll() {
        queue.sync {
            guard let directory else { return }
            try? fileManager.removeItem(at: directory)
             
            preparedDirectory = false
            lastPruneKey = [:]
        }
    }

     

    private func write(_ line: String, stream: HakoLogStream, on day: String) {
        guard let directory else { return }
        prepareDirectoryIfNeeded(at: directory)
        let url = url(for: stream, day: day)
        let data = Data(line.utf8)
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let existing = (attributes?[.size] as? Int) ?? 0
         
         
         
         
         
        if existing + data.count > stream.bytesPerDay {
            dropOldestHalf(of: url)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            if !createFile(at: url, contents: data) {
                 
                 
                 
                 
                preparedDirectory = false
                prepareDirectoryIfNeeded(at: directory)
                _ = createFile(at: url, contents: data)
            }
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    private func prepareDirectoryIfNeeded(at directory: URL) {
        guard !preparedDirectory else { return }
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [
                 
                 
                 
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
            ]
        )
        excludeFromBackup(directory)
        preparedDirectory = true
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func excludeFromBackup(_ directory: URL) {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    @discardableResult
    private func createFile(at url: URL, contents data: Data) -> Bool {
        fileManager.createFile(
            atPath: url.path,
            contents: data,
            attributes: [
                .protectionKey:
                    FileProtectionType.completeUntilFirstUserAuthentication,
            ]
        )
    }

     
     
    private func dropOldestHalf(of url: URL) {
         
         
         
         
         
         
         
         
         
         
        let temporary = url.appendingPathExtension("rotating")
        guard let source = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? source.close() }
        guard let size = try? source.seekToEnd(), size > 0 else { return }

        try? fileManager.removeItem(at: temporary)
        guard fileManager.createFile(atPath: temporary.path, contents: nil),
              let sink = try? FileHandle(forWritingTo: temporary) else {
            try? fileManager.removeItem(at: temporary)
            return
        }
        defer { try? sink.close() }

         
         
        try? source.seek(toOffset: size / 2)
        var alignedToLine = false
        while true {
            guard let chunk = try? source.read(upToCount: Self.rotationChunkBytes),
                  !chunk.isEmpty else { break }
            var payload = chunk
            if !alignedToLine {
                guard let newline = payload.firstIndex(of: 0x0A) else { continue }
                payload = payload[payload.index(after: newline)...]
                alignedToLine = true
            }
            try? sink.write(contentsOf: payload)
        }
        try? sink.close()
        try? source.close()
        _ = try? fileManager.replaceItemAt(url, withItemAt: temporary)
        try? fileManager.removeItem(at: temporary)
    }

     
    private static let rotationChunkBytes = 256 * 1024

     
     
     
     
     
     
     
    public func composition(of stream: HakoLogStream = .core) -> String {
        queue.sync {
            let url = url(for: stream, day: Self.day(clock()))
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            guard let handle = try? FileHandle(forReadingFrom: url) else {
                return "core-log bytes=\(size ?? 0) (unreadable)"
            }
            defer { try? handle.close() }
            var counts: [String: Int] = [:]
            var carry = Data()
            var lines = 0
            while let chunk = try? handle.read(upToCount: Self.rotationChunkBytes),
                  !chunk.isEmpty {
                carry.append(chunk)
                while let newline = carry.firstIndex(of: 0x0A) {
                    let raw = carry[carry.startIndex..<newline]
                    carry = carry[carry.index(after: newline)...]
                    lines += 1
                    guard let stored = String(data: raw, encoding: .utf8) else { continue }
                    let text = stored
                     
                     
                    let shape = text.split(separator: " ", omittingEmptySubsequences: true)
                        .dropFirst(3).prefix(4).joined(separator: " ")
                    counts[String(shape.prefix(60)), default: 0] += 1
                }
            }
            let top = counts.sorted { $0.value > $1.value }.prefix(3)
                .map { "\($0.value)× \($0.key)" }
                .joined(separator: " | ")
            return "core-log bytes=\(size ?? 0) lines=\(lines) top=[\(top)]"
        }
    }

     
     
     
     
     
    private func pruneExpired(_ stream: HakoLogStream, now: Date) {
        guard let settings, directory != nil else { return }
        let window = HakoLogSettings.retention(from: settings).window
        let key = "\(Self.day(now))|\(window)"
        guard lastPruneKey[stream] != key else { return }
        lastPruneKey[stream] = key
        let cutoff = Self.day(now.addingTimeInterval(-window))
        for url in files(for: stream) {
            let name = url.deletingPathExtension().lastPathComponent
            let day = String(name.dropFirst(stream.filePrefix.count + 1))
            guard day < cutoff else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

     
    private func files(for stream: HakoLogStream) -> [URL] {
        guard let directory else { return [] }
        let all = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return all
            .filter {
                $0.lastPathComponent.hasPrefix("\(stream.filePrefix)-")
                    && $0.pathExtension == "log"
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

     
     
     
     
     
    public static func mirrorableFileNames(
        now: Date = Date()
    ) -> [String] {
        [now, now.addingTimeInterval(-86_400)].flatMap { date in
            HakoLogStream.allCases.map {
                "\($0.filePrefix)-\(day(date)).log"
            }
        }
    }

    private func url(for stream: HakoLogStream, day: String) -> URL {
        (directory ?? URL(fileURLWithPath: "/dev/null"))
            .appendingPathComponent("\(stream.filePrefix)-\(day).log")
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter
    }()

    private static func timestamp(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
