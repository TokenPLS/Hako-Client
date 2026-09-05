import Foundation

 
 
enum ProfileReorder {
    static func apply(_ profiles: [Profile], from source: IndexSet, to destination: Int) -> [Profile] {
        var reordered = profiles
        reordered.move(fromOffsets: source, toOffset: destination)
        for index in reordered.indices {
            reordered[index].order = index
        }
        return reordered
    }
}
