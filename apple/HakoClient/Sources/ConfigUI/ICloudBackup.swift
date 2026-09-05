import Foundation

 
 
 
 
struct ICloudBackupStore {
    static let filePrefix = "Hako-backup-"
    static let fileSuffix = ".json"

    enum EntryKind: String, Equatable {
        case current
        case conflict
        case history

        var title: String {
            switch self {
            case .current: return "Current"
            case .conflict: return "Conflict"
            case .history: return "Previous Version"
            }
        }
    }

    struct VersionSnapshot: Equatable {
        let identifier: String
        let url: URL
        let kind: EntryKind
        let modifiedAt: Date?
    }

     
     
    struct Entry: Equatable, Identifiable {
        let fileName: String
        let url: URL
        let logicalURL: URL
        let downloaded: Bool
        let modifiedAt: Date?
        let byteCount: Int64?
        let kind: EntryKind
        let versionIdentifier: String?

        var id: String {
            [fileName, kind.rawValue, versionIdentifier ?? "current"].joined(separator: "|")
        }
    }

    enum StoreError: LocalizedError {
        case invalidEntry
        case readOnlyVersion

        var errorDescription: String? {
            switch self {
            case .invalidEntry:
                return "That iCloud backup is no longer available. Refresh the list and try again."
            case .readOnlyVersion:
                return "Previous iCloud versions cannot be deleted directly. Restore one or keep a conflict copy instead."
            }
        }
    }

    enum RestoreOutcome: Equatable {
        case restored(BackupArchive)
        case downloading(String)
        case unavailable(String)
        case empty
    }

    let documentsDir: URL
    private let versionSnapshots: (URL) -> [VersionSnapshot]
    private let downloadRequester: (URL) throws -> Void
    private let conflictResolver: (URL) throws -> Void

    init(
        documentsDir: URL,
        versionSnapshots: @escaping (URL) -> [VersionSnapshot] = ICloudBackupStore.systemVersions,
        downloadRequester: @escaping (URL) throws -> Void = ICloudBackupStore.systemDownload,
        conflictResolver: @escaping (URL) throws -> Void = ICloudBackupStore.systemResolveConflicts
    ) {
        self.documentsDir = documentsDir
        self.versionSnapshots = versionSnapshots
        self.downloadRequester = downloadRequester
        self.conflictResolver = conflictResolver
    }

     
     
     
    static func defaultContainer() -> ICloudBackupStore? {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return ICloudBackupStore(documentsDir: root.appendingPathComponent("Documents"))
    }

    static func fileName(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return filePrefix + formatter.string(from: date) + fileSuffix
    }

    @discardableResult
    func backUp(_ archive: BackupArchive, at date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(
            at: documentsDir,
            withIntermediateDirectories: true
        )
        let target = uniqueTarget(for: Self.fileName(at: date))
        try Self.coordinatedWrite(try archive.encoded(), to: target)
        return target
    }

     
     
     
    func list() -> [Entry] {
        guard let names = try? FileManager.default
            .contentsOfDirectory(atPath: documentsDir.path) else { return [] }
        var entries: [Entry] = []
        for name in names {
            let diskURL = documentsDir.appendingPathComponent(name)
            if name.hasPrefix(Self.filePrefix), name.hasSuffix(Self.fileSuffix) {
                let current = entry(
                    fileName: name,
                    url: diskURL,
                    logicalURL: diskURL,
                    downloaded: true,
                    kind: .current,
                    identifier: nil,
                    modifiedAt: nil
                )
                entries.append(current)
                entries.append(contentsOf: versionSnapshots(diskURL).compactMap { version in
                    guard version.kind != .current else { return nil }
                    return entry(
                        fileName: name,
                        url: version.url,
                        logicalURL: diskURL,
                        downloaded: true,
                        kind: version.kind,
                        identifier: version.identifier,
                        modifiedAt: version.modifiedAt
                    )
                })
                continue
            }
            if name.hasPrefix("." + Self.filePrefix),
               name.hasSuffix(Self.fileSuffix + ".icloud") {
                let realName = String(name.dropFirst().dropLast(".icloud".count))
                entries.append(entry(
                    fileName: realName,
                    url: diskURL,
                    logicalURL: documentsDir.appendingPathComponent(realName),
                    downloaded: false,
                    kind: .current,
                    identifier: nil,
                    modifiedAt: nil
                ))
            }
        }
        return entries.sorted(by: Self.sortEntries)
    }

    func restoreLatest() throws -> RestoreOutcome {
        guard let newest = list().first else { return .empty }
        return try restore(newest)
    }

     
     
     
    func restore(_ entry: Entry) throws -> RestoreOutcome {
        guard let current = list().first(where: { $0.id == entry.id && $0.url == entry.url }) else {
            throw StoreError.invalidEntry
        }
        guard current.downloaded else {
            do {
                try downloadRequester(current.logicalURL)
                return .downloading(current.fileName)
            } catch {
                return .unavailable(current.fileName)
            }
        }
        return .restored(try BackupArchive.decode(Self.coordinatedRead(from: current.url)))
    }

     
     
     
    func resolveConflict(_ entry: Entry) throws {
        guard let current = list().first(where: { $0.id == entry.id && $0.url == entry.url }),
              current.kind == .conflict else {
            throw StoreError.invalidEntry
        }
        try Self.coordinatedWrite(
            try Self.coordinatedRead(from: current.url),
            to: current.logicalURL
        )
        try conflictResolver(current.logicalURL)
    }

     
     
    func delete(_ entry: Entry) throws {
        guard let current = list().first(where: { $0.id == entry.id && $0.url == entry.url }) else {
            throw StoreError.invalidEntry
        }
        guard current.kind == .current else { throw StoreError.readOnlyVersion }
        let coordinatedTarget = current.downloaded ? current.url : current.logicalURL
        var coordinationError: NSError?
        var deletionError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: coordinatedTarget,
            options: .forDeleting,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    try FileManager.default.removeItem(at: coordinatedURL)
                } else {
                     
                     
                    try FileManager.default.removeItem(at: current.url)
                }
            }
            catch { deletionError = error }
        }
        if let deletionError { throw deletionError }
        if let coordinationError { throw coordinationError }
    }

    private func uniqueTarget(for fileName: String) -> URL {
        let initial = documentsDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        let stem = String(fileName.dropLast(Self.fileSuffix.count))
        var suffix = 2
        while true {
            let candidate = documentsDir.appendingPathComponent(
                "\(stem)-\(suffix)\(Self.fileSuffix)"
            )
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }

    private func entry(
        fileName: String,
        url: URL,
        logicalURL: URL,
        downloaded: Bool,
        kind: EntryKind,
        identifier: String?,
        modifiedAt: Date?
    ) -> Entry {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return Entry(
            fileName: fileName,
            url: url,
            logicalURL: logicalURL,
            downloaded: downloaded,
            modifiedAt: modifiedAt ?? attributes?[.modificationDate] as? Date,
            byteCount: downloaded ? (attributes?[.size] as? NSNumber)?.int64Value : nil,
            kind: kind,
            versionIdentifier: identifier
        )
    }

    private static func sortEntries(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.fileName != rhs.fileName { return lhs.fileName > rhs.fileName }
        let rank: [EntryKind: Int] = [.current: 0, .conflict: 1, .history: 2]
        if rank[lhs.kind] != rank[rhs.kind] {
            return (rank[lhs.kind] ?? 99) < (rank[rhs.kind] ?? 99)
        }
        if lhs.modifiedAt != rhs.modifiedAt {
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
        return lhs.id < rhs.id
    }

    private static func coordinatedRead(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            readResult = Result { try Data(contentsOf: coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        return try readResult?.get() ?? { throw CocoaError(.fileReadUnknown) }()
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try data.write(
                    to: coordinatedURL,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            } catch {
                writeError = error
            }
        }
        if let writeError { throw writeError }
        if let coordinationError { throw coordinationError }
    }

    private static func systemDownload(_ url: URL) throws {
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey])
         
         
        guard values?.isUbiquitousItem == true else { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    private static func systemVersions(for url: URL) -> [VersionSnapshot] {
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        let conflictURLs = Set(conflicts.map { $0.url.standardizedFileURL })
        var snapshots = conflicts.map { version in
            let versionURL = version.url
            return VersionSnapshot(
                identifier: versionIdentifier(version, fallbackURL: versionURL),
                url: versionURL,
                kind: .conflict,
                modifiedAt: version.modificationDate
            )
        }
        let history = NSFileVersion.otherVersionsOfItem(at: url) ?? []
        snapshots.append(contentsOf: history.compactMap { version in
            let versionURL = version.url
            guard !conflictURLs.contains(versionURL.standardizedFileURL) else { return nil }
            return VersionSnapshot(
                identifier: versionIdentifier(version, fallbackURL: versionURL),
                url: versionURL,
                kind: .history,
                modifiedAt: version.modificationDate
            )
        })
        return snapshots
    }

    private static func versionIdentifier(_ version: NSFileVersion, fallbackURL: URL) -> String {
        let identifier = String(describing: version.persistentIdentifier)
        return identifier.isEmpty ? fallbackURL.standardizedFileURL.path : identifier
    }

    private static func systemResolveConflicts(at url: URL) throws {
        for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] {
            version.isResolved = true
        }
        try NSFileVersion.removeOtherVersionsOfItem(at: url)
    }
}


