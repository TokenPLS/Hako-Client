import Foundation

 
 
 
 
 
enum ScriptSettings {
    private static let enabledKey = "script.enabled"
    private static let bodyKey = "script.body"

    static let template = """
    // Edit the full configuration object and return it.
    function main(config) {
      // config['log-level'] = 'warning'
      // config.rules = ['MATCH,DIRECT', ...(config.rules ?? [])]
      return config
    }
    """

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func enabled(from d: UserDefaults = appGroupDefaults) -> Bool {
        d.bool(forKey: enabledKey)
    }

    static func body(from d: UserDefaults = appGroupDefaults) -> String {
        d.string(forKey: bodyKey) ?? template
    }

    static func save(enabled: Bool, body: String, in d: UserDefaults = appGroupDefaults) {
        d.set(enabled, forKey: enabledKey)
        d.set(body, forKey: bodyKey)
    }

     
     
    static func apply(toConfigYAML yaml: String,
                      profileName: String = "",
                      d: UserDefaults = appGroupDefaults) throws -> String {
        guard enabled(from: d) else { return yaml }
        return try apply(
            body: body(from: d), toConfigYAML: yaml, profileName: profileName
        )
    }

    static func apply(
        body: String, toConfigYAML yaml: String, profileName: String = ""
    ) throws -> String {
        let configJSON = try ConfigTransforms.yamlToJSON(yaml)
        let rewritten = try ScriptEngine.run(
            script: body, configJSON: configJSON, profileName: profileName
        )
        return try ConfigTransforms.jsonToYAML(rewritten)
    }
}
