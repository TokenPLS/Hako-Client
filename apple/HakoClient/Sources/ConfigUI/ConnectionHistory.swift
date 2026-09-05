import Foundation

 
 
 
 
 
struct ConnectionHistory {
    struct Entry: Identifiable, Equatable {
        var connection: HakoConnection
        var firstSeen: Date
        var lastSeen: Date
        var closedAt: Date?

        var id: String { connection.id }
        var isActive: Bool { closedAt == nil }
    }

    let capacity: Int
    private(set) var entries: [Entry] = []

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

     
     
     
     
     
     
     
     
    private var indexByID: [String: Int] = [:]

    mutating func record(_ live: [HakoConnection], at now: Date) {
        var liveIDs = Set<String>()
        liveIDs.reserveCapacity(live.count)

        for connection in live {
            liveIDs.insert(connection.id)
            if let position = indexByID[connection.id] {
                entries[position].connection = connection
                entries[position].lastSeen = now
                entries[position].closedAt = nil
            } else {
                indexByID[connection.id] = entries.count
                entries.append(Entry(connection: connection, firstSeen: now,
                                     lastSeen: now, closedAt: nil))
            }
        }
         
        for position in entries.indices
        where entries[position].isActive
            && !liveIDs.contains(entries[position].id) {
            entries[position].closedAt = now
        }

         
         
         
         
         
         
        if !live.isEmpty {
            entries.sort {
                if $0.lastSeen != $1.lastSeen { return $0.lastSeen > $1.lastSeen }
                if $0.firstSeen != $1.firstSeen { return $0.firstSeen > $1.firstSeen }
                return $0.id > $1.id
            }
        }
        evictIfNeeded()
        reindex()
    }

    private mutating func evictIfNeeded() {
        guard entries.count > capacity else { return }
         
         
         
         
         
        var overflow = entries.count - capacity
        var kept: [Entry] = []
        kept.reserveCapacity(entries.count)
        for entry in entries.reversed() {
            if overflow > 0, !entry.isActive {
                overflow -= 1
                continue
            }
            kept.append(entry)
        }
        entries = kept.reversed()
         
         
         
    }

    private mutating func reindex() {
        indexByID.removeAll(keepingCapacity: true)
        indexByID.reserveCapacity(entries.count)
        for (position, entry) in entries.enumerated() {
            indexByID[entry.id] = position
        }
    }
}
