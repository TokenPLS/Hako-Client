import Darwin
import Foundation
import Hako
import Network
import NetworkExtension

 
 
 
 
 
enum ApplePacketTunnelPlatform {
    case iOS
    case macOS
    case tvOS
}

 
 
 
 
 
 
 
 
 
 
 
 
struct ApplePacketTunnelRuntimePolicy: Equatable {
    let runtimeProfile: String
     
    let memoryLimit: Int64?
     
     
     
     
     
    let maxProcs: Int

    static var current: Self {
#if os(macOS)
        resolve(for: .macOS)
#elseif os(tvOS)
        resolve(for: .tvOS)
#else
        resolve(for: .iOS)
#endif
    }

    static func resolve(for platform: ApplePacketTunnelPlatform) -> Self {
        switch platform {
        case .macOS:
            Self(runtimeProfile: "macosPacketTunnel", memoryLimit: nil, maxProcs: 0)
        case .iOS:
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            Self(runtimeProfile: "iosPacketTunnel", memoryLimit: nil, maxProcs: 4)
        case .tvOS:
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            Self(runtimeProfile: "tvosPacketTunnel", memoryLimit: nil, maxProcs: 4)
        }
    }

    func apply(to options: HakoSetupOptions) {
        options.runtimeProfile = runtimeProfile
        if let memoryLimit {
            options.memoryLimit = memoryLimit
        }
        options.maxProcs = maxProcs
    }
}

