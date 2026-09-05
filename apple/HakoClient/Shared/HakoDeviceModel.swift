import Darwin
import Foundation

 
 
 
 
 
 
 
 
 
enum HakoDeviceModel {
     
     
     
     
     
    static var identifier: String {
        #if os(macOS)
        if let model = sysctlString("hw.model"), isToken(model) { return model }
         
        return platformFallback
        #else
        #if targetEnvironment(simulator)
         
         
        if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], isToken(model) {
            return model
        }
        #endif
        let machine = unameField { $0.machine }
        return isToken(machine) ? machine : platformFallback
        #endif
    }

     
     
    static var platformFallback: String {
        #if os(macOS)
        "macOS"
        #elseif os(tvOS)
        "tvOS"
        #else
        "iOS"
        #endif
    }

     
     
    static var kernelName: String? {
        let name = unameField { $0.sysname }
        return isToken(name) ? name : nil
    }

     
    static var darwinRelease: String? {
        let release = unameField { $0.release }
        return isToken(release) ? release : nil
    }

     
     
    static var userAgentTail: String? {
        guard let kernelName, let darwinRelease else { return nil }
        return "\(kernelName)/\(darwinRelease) \(identifier)"
    }

     
     
     
    static func appToken(version: String, build: String) -> String {
        let trimmedBuild = build.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedBuild.isEmpty ? "v\(version)" : "v\(version).\(trimmedBuild)"
    }

    private static func isToken(_ s: String) -> Bool {
        !s.isEmpty && !s.contains(where: { $0 == " " || $0.isNewline })
    }

     
    private static func unameField<T>(_ field: (utsname) -> T) -> String {
        var info = utsname()
        guard uname(&info) == 0 else { return "" }
        var tuple = field(info)
        return withUnsafePointer(to: &tuple) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return String(cString: value)
    }
}
