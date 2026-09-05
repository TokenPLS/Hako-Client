import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum GlobalModeConfirmation {

    enum Verdict: Equatable {
         
        case confirmed
         
         
        case refused
         
         
         
        case notYetKnown
    }

     
     
     
     
     
     
    static func verdict(
        groupCount: Int,
        selectionConfirmed: Bool
    ) -> Verdict {
        guard groupCount > 0 else { return .notYetKnown }
        return selectionConfirmed ? .confirmed : .refused
    }
}
