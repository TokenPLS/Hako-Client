import Foundation

 
 
 
 
 
 
 
 
 
 
struct HomeResourceCounts: Equatable, Sendable {
    let proxyProviders: Int
    let ruleProviders: Int
    let supportingFiles: Int
    let hasResources: Bool

    var providers: Int { proxyProviders + ruleProviders }

     
     
    static func make(profile: Profile?, sourceYAML: String?) -> HomeResourceCounts? {
        guard let profile, let sourceYAML,
              let summary = try? ProfileResourceSummary(
                  profile: profile,
                  sourceYAML: sourceYAML
              )
        else { return nil }
        return HomeResourceCounts(
            proxyProviders: summary.proxyProviderCount,
            ruleProviders: summary.ruleProviderCount,
            supportingFiles: summary.supportingFileCount,
            hasResources: summary.hasResources
        )
    }
}
