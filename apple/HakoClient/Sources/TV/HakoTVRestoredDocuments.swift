import Foundation

 
 
 
 
 
 
enum HakoTVRestoredDocuments {
    static func directory(container: URL) -> URL {
        container.appendingPathComponent("working", isDirectory: true)
            .appendingPathComponent("restored", isDirectory: true)
    }

    static func url(container: URL, profileID: String) -> URL {
        directory(container: container).appendingPathComponent("\(profileID).yaml")
    }

    static func write(_ yaml: String, container: URL, profileID: String) throws {
        try FileManager.default.createDirectory(at: directory(container: container), withIntermediateDirectories: true)
        try Data(yaml.utf8).write(to: url(container: container, profileID: profileID), options: .atomic)
    }

    static func read(container: URL, profileID: String) -> String? {
        try? String(contentsOf: url(container: container, profileID: profileID), encoding: .utf8)
    }

    static func remove(container: URL, profileID: String) {
        try? FileManager.default.removeItem(at: url(container: container, profileID: profileID))
    }
}
