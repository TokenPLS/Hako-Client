import Foundation
import JavaScriptCore

 
 
 
 
 
 
enum ScriptEngine {
    enum ScriptError: Error, Equatable, LocalizedError {
        case contextUnavailable
        case evaluationFailed(String)
        case missingMain
        case threw(String)
        case invalidResult
         
        case timedOut

        var errorDescription: String? {
            switch self {
            case .timedOut:
                return "The script ran too long and was stopped. A loop that never ends will do this."
            case .contextUnavailable: return "script engine unavailable"
            case .evaluationFailed(let message): return "script error: \(message)"
            case .missingMain: return "script must define main(config)"
            case .threw(let message): return "script threw: \(message)"
            case .invalidResult: return "script must return the config object"
            }
        }
    }

     
     
     
     
    private static let configBinding = "__hakoScriptConfig"
    private static let profileNameBinding = "__hakoScriptProfileName"

     
     
     
     
     
     
     
    static let executionLimit: TimeInterval = 5

     
     
     
     
     
     
    private static let refusedLock = NSLock()
    nonisolated(unsafe) private static var refused: Set<Int> = []

    static func hasExceededItsBound(_ script: String) -> Bool {
        refusedLock.lock()
        defer { refusedLock.unlock() }
        return refused.contains(script.hashValue)
    }

     
     
     
     
     
     
    static func run(
        script: String,
        configJSON: String,
        profileName: String = ""
    ) throws -> String {
        if hasExceededItsBound(script) { throw ScriptError.timedOut }

         
         
         
         
        final class Outcome: @unchecked Sendable {
            let lock = NSLock()
            var value: Result<String, Error>?
        }
        let outcome = Outcome()
        let finished = DispatchSemaphore(value: 0)
        let worker = Thread {
            let result: Result<String, Error>
            do {
                result = .success(try runOnCurrentThread(
                    script: script, configJSON: configJSON, profileName: profileName
                ))
            }
            catch { result = .failure(error) }
            outcome.lock.lock()
            outcome.value = result
            outcome.lock.unlock()
            finished.signal()
        }
        worker.stackSize = 1 << 20
        worker.start()

        guard finished.wait(timeout: .now() + executionLimit) == .success else {
            refusedLock.lock()
            refused.insert(script.hashValue)
            refusedLock.unlock()
            throw ScriptError.timedOut
        }
        outcome.lock.lock()
        let value = outcome.value
        outcome.lock.unlock()
        guard let value else { throw ScriptError.invalidResult }
        return try value.get()
    }

    private static func runOnCurrentThread(
        script: String, configJSON: String, profileName: String
    ) throws -> String {
        guard let context = JSContext() else { throw ScriptError.contextUnavailable }


        var thrown: String?
        context.exceptionHandler = { _, value in thrown = value?.toString() ?? "exception" }

        context.evaluateScript(script)
        if let thrown { throw ScriptError.evaluationFailed(thrown) }

        let isFunction = context
            .evaluateScript("(typeof main === 'function')")?.toBool() ?? false
        guard isFunction else { throw ScriptError.missingMain }

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        context.setObject(
            configJSON.isEmpty ? "{}" : configJSON,
            forKeyedSubscript: configBinding as NSString
        )
         
         
         
         
         
        context.setObject(
            profileName, forKeyedSubscript: profileNameBinding as NSString
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let result = context.evaluateScript("""
            (function () {
              var config = JSON.parse(\(configBinding));
              if (config !== null && typeof config === 'object' && !Array.isArray(config)
                  && config['proxy-providers'] === undefined) {
                config['proxy-providers'] = {};
              }
              var result = main(config, \(profileNameBinding));
              if (result === null || typeof result !== 'object' || Array.isArray(result)) {
                return null;
              }
              return JSON.stringify(result);
            })();
            """)
        if let thrown { throw ScriptError.threw(thrown) }

        guard let result, result.isString, let json = result.toString() else {
            throw ScriptError.invalidResult
        }
        return json
    }
}
