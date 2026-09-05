import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoMacPoolFreeze: Equatable {
    let frozen: Bool
    let epoch: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }
}

 
 
 
struct HakoMacFrozenPoolContent<Content: View>: View, Equatable {
    let freeze: HakoMacPoolFreeze
    @ViewBuilder let content: () -> Content

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.freeze == rhs.freeze
    }

    var body: some View {
        content()
    }
}
