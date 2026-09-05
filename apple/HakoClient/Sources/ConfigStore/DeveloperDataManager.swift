import Foundation

 
 
 
struct DeveloperDataManager {
    static let appGroupIdentifier = HakoAppIdentifiers.appGroup

    private let containerURL: URL
    private let defaults: UserDefaults
    private let credentials: CredentialStore
    private let fileManager: FileManager

    init?(
        containerURL: URL? = HakoAppIdentifiers.appGroupContainer,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults,
        credentials: CredentialStore = CredentialStore(),
        fileManager: FileManager = .default
    ) {
        guard let containerURL else { return nil }
        self.containerURL = containerURL
        self.defaults = defaults
        self.credentials = credentials
        self.fileManager = fileManager
    }

    func cacheBytes() -> Int64 {
        cacheArtifacts().reduce(0) { $0 + allocatedBytes(at: $1) }
    }

     
     
     
     
    @discardableResult
    func pruneCache() throws -> Int64 {
        let before = cacheBytes()
        for artifact in cacheArtifacts() where fileManager.fileExists(atPath: artifact.path) {
            try fileManager.removeItem(at: artifact)
        }
        URLCache.shared.removeAllCachedResponses()
        return before
    }

     
     
     
     
    func resetAllLocalData() throws {
        let preserved = Set(["Library", ".com.apple.mobile_container_manager.metadata.plist"])
        for entry in try fileManager.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil,
            options: []
        ) where !preserved.contains(entry.lastPathComponent) {
            try fileManager.removeItem(at: entry)
        }
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        try credentials.removeAll()
        URLCache.shared.removeAllCachedResponses()
    }

    private func cacheArtifacts() -> [URL] {
        var artifacts: [URL] = []
        let temp = containerURL.appendingPathComponent("temp", isDirectory: true)
        if fileManager.fileExists(atPath: temp.path) { artifacts.append(temp) }

        let store = containerURL.appendingPathComponent("working/store", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: store,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return artifacts }
        for case let url as URL in enumerator where url.lastPathComponent.hasPrefix(".tmp-") {
            artifacts.append(url)
            enumerator.skipDescendants()
        }
        return artifacts
    }

    private func allocatedBytes(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let childValues = try? child.resourceValues(
                forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
            ), childValues.isRegularFile == true else { continue }
            total += Int64(childValues.totalFileAllocatedSize ?? childValues.fileAllocatedSize ?? 0)
        }
        return total
    }
}
