import Foundation

 
 
 
 
 
 
 
 
 
public struct HakoWidgetInterfaceAccounting: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case wifi
        case cellular
        case wired
        case other
    }

    public private(set) var wifi = HakoWidgetBytes(up: 0, down: 0)
    public private(set) var cellular = HakoWidgetBytes(up: 0, down: 0)
     
    public private(set) var wired = HakoWidgetBytes(up: 0, down: 0)
    private var lastUp: Int64?
    private var lastDown: Int64?
    private var current: Kind = .other

    public init() {}

     
     
    public static func kind(ofInterfaceType type: String) -> Kind {
        switch type {
        case "wifi": return .wifi
        case "cellular": return .cellular
        case "wired", "wiredEthernet": return .wired
        default: return .other
        }
    }

     
     
     
    public mutating func observe(totalUp: Int64, totalDown: Int64, on kind: Kind) {
        if kind != current {
            pathChanged(to: kind, totalUp: totalUp, totalDown: totalDown)
            return
        }
        attribute(totalUp: totalUp, totalDown: totalDown, to: kind)
    }

     
     
    public mutating func pathChanged(to kind: Kind, totalUp: Int64, totalDown: Int64) {
        attribute(totalUp: totalUp, totalDown: totalDown, to: current)
        current = kind
    }

    private mutating func attribute(totalUp: Int64, totalDown: Int64, to kind: Kind) {
        defer {
            lastUp = totalUp
            lastDown = totalDown
        }
        guard let lastUp, let lastDown else { return }
        let up = totalUp >= lastUp ? totalUp - lastUp : totalUp
        let down = totalDown >= lastDown ? totalDown - lastDown : totalDown
        switch kind {
        case .wifi:
            wifi.up += up
            wifi.down += down
        case .cellular:
            cellular.up += up
            cellular.down += down
        case .wired:
            wired.up += up
            wired.down += down
        case .other:
            break
        }
    }
}
