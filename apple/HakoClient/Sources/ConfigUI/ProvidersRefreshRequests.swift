import Combine
import Foundation
import SwiftUI

 
 
 
 
 
 
 
 
 
@MainActor
public final class ProvidersRefreshRequests: ObservableObject {
    @Published public private(set) var token = 0

    public init() {}

    public func request() {
        token &+= 1
    }
}

enum ProvidersRefreshRequestPolicy {
     
     
    static func fires(requested: Int, honored: Int, loaded: Bool) -> Bool {
        loaded && requested != honored && requested != 0
    }
}

private struct ProvidersRefreshRequestsKey: EnvironmentKey {
    static let defaultValue: ProvidersRefreshRequests? = nil
}

extension EnvironmentValues {
     
     
    var hakoProvidersRefreshRequests: ProvidersRefreshRequests? {
        get { self[ProvidersRefreshRequestsKey.self] }
        set { self[ProvidersRefreshRequestsKey.self] = newValue }
    }
}
