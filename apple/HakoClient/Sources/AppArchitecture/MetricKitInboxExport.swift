import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum MetricKitInboxExport {
    static let launchFlag = "--hako-export-metrickit"

     
     
    static let exportFolderName = "metrickit-export"



     
     
     
     
    @discardableResult
    static func mirror(
        from source: URL,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws -> Int {
         
        try? fileManager.removeItem(at: destination)
        try fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true
        )
        let files = (try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.isRegularFileKey]
        )) ?? []
        var copied = 0
        for file in files where
            (try? file.resourceValues(forKeys: [.isRegularFileKey])
                .isRegularFile) == true
        {
            try fileManager.copyItem(
                at: file,
                to: destination.appendingPathComponent(file.lastPathComponent)
            )
            copied += 1
        }
        return copied
    }
}
