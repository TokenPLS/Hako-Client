import Foundation

 
 
 
 
 
 
 
 
 
 
public enum BackupRecordSchema {
    public static let recordType = "HakoBackup"
    public static let kindField = "kind"
    public static let kindAuto = "auto"
    public static let archiveField = "archive"
    public static let exportedAtField = "exportedAt"
    public static let sourceDeviceField = "sourceDevice"
    public static let sourceInstallIDField = "sourceInstallID"
    public static let schemaVersionField = "schemaVersion"
     
    public static let summaryKeys = [kindField, exportedAtField, sourceDeviceField, sourceInstallIDField, schemaVersionField]
}
