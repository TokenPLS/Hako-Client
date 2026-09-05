import Foundation

 
 
 
 
 
 
public enum HakoPerfExperiment {
     
     
     
     
     
     
     
     
     
    public static let suppressesGlass = ProcessInfo.processInfo
        .arguments.contains("--hako-perf-no-glass")

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static let freezesTrafficFigures = ProcessInfo.processInfo
        .arguments.contains("--hako-perf-freeze-traffic")

     
     
     
     
     
     
     
     
    public static let suppressesDurationTick = ProcessInfo.processInfo
        .arguments.contains("--hako-perf-no-duration-tick")
}
