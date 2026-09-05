import Foundation
import SwiftUI

 
 
 
 
 
 
 
 
enum HakoBackupDataScope: Equatable {
     
    case ordinary
     
    case review(URL)
     
     
    case reviewUnavailable
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum BackupSandbox {
     
     
     
    static func workingDirectory(
        scope: HakoBackupDataScope,
        appGroupContainer: URL?
    ) -> URL? {
        switch scope {
        case .ordinary:
            return appGroupContainer?.appendingPathComponent("working")
        case .review(let container):
            return container.appendingPathComponent("working")
        case .reviewUnavailable:
            return nil
        }
    }

     
     
     
     
     
    static func usesFixtureICloud(
        scope: HakoBackupDataScope,
        uiTestingEnabled: Bool
    ) -> Bool {
        switch scope {
        case .ordinary:
            return uiTestingEnabled
        case .review, .reviewUnavailable:
            return true
        }
    }
}

 
 
 
struct HakoBackupDataScopeKey: EnvironmentKey {
    static let defaultValue: HakoBackupDataScope = .ordinary
}

extension EnvironmentValues {
    var hakoBackupDataScope: HakoBackupDataScope {
        get { self[HakoBackupDataScopeKey.self] }
        set { self[HakoBackupDataScopeKey.self] = newValue }
    }
}
