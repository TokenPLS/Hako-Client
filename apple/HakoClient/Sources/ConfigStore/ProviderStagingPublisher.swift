import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProviderStagingPublisher {
     
     
     
     
     
     
#if os(macOS)
    private static let extensionRuntimeProfile = HakoRuntimeProfileMacOSPacketTunnel
#else
    private static let extensionRuntimeProfile = HakoRuntimeProfileIOSPacketTunnel
#endif

     
     
     
     
     
     
     
     
     
     
    static func publish(
        finalYAML: String,
        providerCount: Int,
        compileRuleSets: Bool
    ) {
        guard providerCount > 0 else { return }
        let started = DispatchTime.now().uptimeNanoseconds
        var error: NSError?
        let staged = HakoStageProvidersForPublish(
            finalYAML,
            Self.extensionRuntimeProfile,
            compileRuleSets,
            &error
        )
        let elapsed = (DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        guard staged, error == nil else {
             
             
             
             
            HakoLogStore.shared.append(
                "provider staging not published  reason=\(error?.localizedDescription ?? "unknown")",
                stream: .app,
                level: .warning
            )
            return
        }
        HakoLogStore.shared.append(
            "provider staging published  providers=\(providerCount)"
                + " compile=\(compileRuleSets) in=\(elapsed)ms",
            stream: .app
        )
    }
}
