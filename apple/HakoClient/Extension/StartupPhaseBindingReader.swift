import Foundation
import Hako

 
 
 
enum StartupPhaseBindingReader {
    static func read(_ request: StartupPhaseReadRequest) throws -> Data {
        let result = HakoStartupPhaseTracePage(request.cursor, request.throughCursor, Int64(request.maxBytes))
        guard result.utf8.count <= 65_536 else { throw StartupPhasePage.Invalid.envelope }
        return Data(result.utf8)
    }
}
