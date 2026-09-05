import Foundation

struct SharedProfileFile: Equatable, Sendable {
    let data: Data
}

enum ProfileShareInboxError: LocalizedError, Equatable {
    case unavailable
    case empty
    case tooLarge(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Clash's shared import storage is unavailable."
        case .empty:
            return "The shared configuration is empty."
        case .tooLarge(let maximumBytes):
            return "The shared configuration exceeds the \(maximumBytes / 1_048_576) MB limit."
        }
    }
}

 
 
 
 
struct ProfileShareInbox {
    static let appGroupIdentifier = HakoAppIdentifiers.appGroup
    static let defaultMaximumBytes = 16 * 1_048_576

    private let inboxURL: URL
    private let maximumBytes: Int
    private let fileManager: FileManager

    init?(
        containerURL: URL? = HakoAppIdentifiers.appGroupContainer,
        maximumBytes: Int = defaultMaximumBytes,
        fileManager: FileManager = .default
    ) {
        guard let containerURL else { return nil }
        self.inboxURL = containerURL.appendingPathComponent("share-inbox", isDirectory: true)
        self.maximumBytes = maximumBytes
        self.fileManager = fileManager
    }

    func enqueue(_ data: Data) throws {
        guard !data.isEmpty else { throw ProfileShareInboxError.empty }
        guard data.count <= maximumBytes else {
            throw ProfileShareInboxError.tooLarge(maximumBytes: maximumBytes)
        }
        try fileManager.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let destination = inboxURL.appendingPathComponent("\(UUID().uuidString.lowercased()).yaml")
        try data.write(
            to: destination,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func dequeueAll() throws -> [SharedProfileFile] {
        guard fileManager.fileExists(atPath: inboxURL.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var received: [SharedProfileFile] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where file.pathExtension.lowercased() == "yaml" {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            try fileManager.removeItem(at: file)
            guard !data.isEmpty, data.count <= maximumBytes else { continue }
            received.append(SharedProfileFile(data: data))
        }
        return received
    }
}
