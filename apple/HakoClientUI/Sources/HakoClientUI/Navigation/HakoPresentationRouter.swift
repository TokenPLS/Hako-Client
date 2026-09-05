#if os(macOS)
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoPushAuthority {
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func canPush(
        hostContext: HakoNavigationHostContext,
        depth: Int?
    ) -> Bool {
        switch hostContext {
        case .standalone, .modal:
            return true
        case .regularDetail:
            return (depth ?? 0) == 0
        }
    }
}

extension HakoPushAuthority {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func trace(
        _ site: String,
        _ hostContext: HakoNavigationHostContext,
        _ depth: Int?
    ) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1"
        else { return }
        let verdict = canPush(hostContext: hostContext, depth: depth)
        FileHandle.standardError.write(
            "[nav] \(site) host=\(hostContext) depth=\(depth.map(String.init) ?? "nil") canPush=\(verdict)\n"
                .data(using: .utf8)!
        )
    }
}

 
 
 
 
 
public enum HakoPushAuthorityProbe {
    public static func trace(_ site: String, mayPush: Bool, hasPusher: Bool) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1"
        else { return }
        FileHandle.standardError.write(
            "[nav] \(site) mayPush=\(mayPush) hasPusher=\(hasPusher)\n"
                .data(using: .utf8)!
        )
    }
}

public extension EnvironmentValues {
     
     
     
     
     
     
     
     
     
     
     
     
    var hakoDoorMayPush: Bool {
        HakoPushAuthority.canPush(
            hostContext: hakoNavigationHostContext,
            depth: hakoNavigationDepth
        )
    }
}
#endif
