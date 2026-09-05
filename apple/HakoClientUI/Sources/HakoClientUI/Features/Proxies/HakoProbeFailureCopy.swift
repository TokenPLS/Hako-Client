import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoProbeFailureCopy {
     
     
    public enum Authority: String, Sendable, CaseIterable {
         
        case errno
         
        case kind
         
        case prose
    }

     
     
     
     
     
     
    public struct CategoryBadge: Sendable {
        public let category: String
        public let authority: Authority
         
        public let badge: String

        public init(category: String, authority: Authority, badge: String) {
            self.category = category
            self.authority = authority
            self.badge = badge
        }
    }

     
     
    public static let neutralBadge = "Failed"

     
     
    public static let rows: [CategoryBadge] = [
         
        CategoryBadge(category: "connection-refused", authority: .errno, badge: "Refused"),
         
         
         
        CategoryBadge(category: "address-unavailable", authority: .errno, badge: "No route"),
        CategoryBadge(category: "unreachable", authority: .errno, badge: "No route"),
        CategoryBadge(category: "timeout", authority: .errno, badge: "Timeout"),
        CategoryBadge(category: "connection-reset", authority: .errno, badge: "Dropped"),
        CategoryBadge(category: "connection-closed", authority: .errno, badge: "Dropped"),

         
        CategoryBadge(category: "canceled", authority: .kind, badge: "Stopped"),
        CategoryBadge(category: "unexpected-status", authority: .kind, badge: "Bad HTTP"),
        CategoryBadge(category: "write-failed", authority: .kind, badge: "Dropped"),
        CategoryBadge(category: "read-failed", authority: .kind, badge: "Dropped"),
        CategoryBadge(category: "dial-failed", authority: .kind, badge: "No route"),

         
         
         
         
        CategoryBadge(category: "dns", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "tls", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "authentication", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "proxy-service-unavailable", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "proxy-bad-gateway", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "proxy-connect-unsupported", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "proxy-connect-rejected", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "network-unreachable", authority: .prose, badge: neutralBadge),
         
         
         
         
         
        CategoryBadge(category: "delay-test-failed", authority: .prose, badge: neutralBadge),
        CategoryBadge(category: "other", authority: .prose, badge: neutralBadge),
    ]

    private static let index: [String: CategoryBadge] = Dictionary(
        uniqueKeysWithValues: rows.map { ($0.category, $0) }
    )

     
     
     
     
     
     
     
     
     
    public static func badge(for category: String) -> String {
        guard let row = index[category], row.authority != .prose else {
            return neutralBadge
        }
        return row.badge
    }

     
     
    public static func isCoreAsserted(_ category: String) -> Bool {
        guard let row = index[category] else { return false }
        return row.authority != .prose
    }
}
