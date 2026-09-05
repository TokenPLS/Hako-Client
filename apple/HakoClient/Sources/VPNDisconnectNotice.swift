import Foundation
import NetworkExtension
import UserNotifications

 
 
 
 
 
 
 
 
enum VPNDisconnectNotice {
    static let identifier = "vpn.disconnect-notice"

     
     
     
     
     
     
     
     
     
    static func shouldPost(
        tunnelWasUp: Bool,
        current: NEVPNStatus,
        userInitiated: Bool,
        enabled: Bool
    ) -> Bool {
        guard enabled, !userInitiated else { return false }
        guard current == .disconnected else { return false }
        return tunnelWasUp
    }

     
     
     
    struct Tracker {
        private(set) var tunnelWasUp = false

         
        mutating func observe(
            _ status: NEVPNStatus,
            userInitiated: Bool,
            enabled: Bool
        ) -> Bool {
            switch status {
            case .connected, .reasserting:
                tunnelWasUp = true
                return false
            case .disconnected:
                let post = VPNDisconnectNotice.shouldPost(
                    tunnelWasUp: tunnelWasUp,
                    current: .disconnected,
                    userInitiated: userInitiated,
                    enabled: enabled
                )
                tunnelWasUp = false
                return post
            default:
                 
                 
                 
                return false
            }
        }
    }

     
     
     
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

     
     
     
    private static let presenter = ForegroundPresenter()

    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .list, .sound])
        }
    }

    static func post() {
        UNUserNotificationCenter.current().delegate = presenter
        let content = UNMutableNotificationContent()
        content.title = String(localized: "VPN disconnected")
        content.body = String(localized: "The tunnel stopped without a request from Clash.")
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
