import CryptoKit
import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProfileSourceStore {
     
     
    struct Snapshot {
        let captured: Data?
        let digest: String?
    }

    static func directory(workingDirectory: URL, profileID: String) -> URL {
        workingDirectory.appendingPathComponent("store/\(profileID)", isDirectory: true)
    }

     
     
     
    static func runnableURL(workingDirectory: URL, profileID: String) -> URL {
        directory(workingDirectory: workingDirectory, profileID: profileID)
            .appendingPathComponent("source.yaml")
    }

    static func capturedURL(workingDirectory: URL, profileID: String) -> URL {
        directory(workingDirectory: workingDirectory, profileID: profileID)
            .appendingPathComponent("source.original")
    }

     
    static func digestURL(workingDirectory: URL, profileID: String) -> URL {
        directory(workingDirectory: workingDirectory, profileID: profileID)
            .appendingPathComponent("source.original.digest")
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func store(
        document: String, derivedFrom original: Data,
        workingDirectory: URL, profileID: String
    ) throws {
        let documentBytes = Data(document.utf8)
        try FileManager.default.createDirectory(
            at: directory(workingDirectory: workingDirectory, profileID: profileID),
            withIntermediateDirectories: true
        )
         
         
        try place(
            documentBytes,
            at: runnableURL(workingDirectory: workingDirectory, profileID: profileID)
        )
        guard original != documentBytes else {
            try discardCapture(workingDirectory: workingDirectory, profileID: profileID)
            return
        }
         
         
         
        try place(
            original,
            at: capturedURL(workingDirectory: workingDirectory, profileID: profileID)
        )
        try place(
            Data(digest(of: documentBytes).utf8),
            at: digestURL(workingDirectory: workingDirectory, profileID: profileID)
        )
    }

     
     
     
     
     
     
     
     
     
    static func capturedText(workingDirectory: URL, profileID: String) -> String? {
        guard let runnable = try? Data(
            contentsOf: runnableURL(workingDirectory: workingDirectory, profileID: profileID)
        ) else { return nil }
        guard describesCurrentDocument(
            runnable: runnable, workingDirectory: workingDirectory, profileID: profileID
        ), let captured = try? Data(
            contentsOf: capturedURL(workingDirectory: workingDirectory, profileID: profileID)
        ), let text = String(data: captured, encoding: .utf8) else {
            return String(data: runnable, encoding: .utf8)
        }
        return text
    }

     
     
     
    static func describesCurrentDocument(
        runnable: Data, workingDirectory: URL, profileID: String
    ) -> Bool {
        guard let recorded = try? String(
            contentsOf: digestURL(workingDirectory: workingDirectory, profileID: profileID),
            encoding: .utf8
        ) else { return false }
        return recorded.trimmingCharacters(in: .whitespacesAndNewlines) == digest(of: runnable)
    }

     
    static func snapshot(workingDirectory: URL, profileID: String) -> Snapshot {
        Snapshot(
            captured: try? Data(
                contentsOf: capturedURL(workingDirectory: workingDirectory, profileID: profileID)
            ),
            digest: try? String(
                contentsOf: digestURL(workingDirectory: workingDirectory, profileID: profileID),
                encoding: .utf8
            )
        )
    }

     
     
     
     
     
    static func restore(
        _ snapshot: Snapshot, workingDirectory: URL, profileID: String
    ) {
        try? place(
            snapshot.captured,
            at: capturedURL(workingDirectory: workingDirectory, profileID: profileID)
        )
        try? place(
            snapshot.digest.map { Data($0.utf8) },
            at: digestURL(workingDirectory: workingDirectory, profileID: profileID)
        )
    }

    private static func discardCapture(workingDirectory: URL, profileID: String) throws {
        try place(nil, at: capturedURL(workingDirectory: workingDirectory, profileID: profileID))
        try place(nil, at: digestURL(workingDirectory: workingDirectory, profileID: profileID))
    }

    private static func digest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func place(_ data: Data?, at url: URL) throws {
        guard let data else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
