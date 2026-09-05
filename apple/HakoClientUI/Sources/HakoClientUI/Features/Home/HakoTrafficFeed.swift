import Combine
import SwiftUI

 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoTrafficFeed: ObservableObject {
    @Published public var traffic: AppleClientTrafficSnapshot

    public init(traffic: AppleClientTrafficSnapshot) {
        self.traffic = traffic
    }
}

private struct HakoTrafficFeedKey: EnvironmentKey {
    static let defaultValue: HakoTrafficFeed? = nil
}

public extension EnvironmentValues {
     
    var hakoTrafficFeed: HakoTrafficFeed? {
        get { self[HakoTrafficFeedKey.self] }
        set { self[HakoTrafficFeedKey.self] = newValue }
    }
}
