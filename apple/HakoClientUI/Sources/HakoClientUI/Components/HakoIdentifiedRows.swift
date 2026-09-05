import Foundation
 
 
 
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoIdentifiedRows: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public let id: UUID
         
         
         
        public let index: Int
    }

    private var ids: [UUID]

    public init(count: Int = 0) {
        ids = (0..<count).map { _ in UUID() }
    }

     
     
     
     
     
     
     
    public mutating func rows(for values: [some Any]) -> [Row] {
        if ids.count != values.count {
            ids = values.map { _ in UUID() }
        }
        return ids.enumerated().map { Row(id: $1, index: $0) }
    }

     
     
     
    public func index(of id: UUID) -> Int? {
        ids.firstIndex(of: id)
    }

     
     
     
     
     
     
    public func current(for values: [some Any]) -> [Row] {
        guard ids.count == values.count else {
            return values.indices.map { Row(id: UUID(), index: $0) }
        }
        return ids.enumerated().map { Row(id: $1, index: $0) }
    }

     
     
     
    public mutating func resync(count: Int) {
        guard ids.count != count else { return }
        ids = (0..<count).map { _ in UUID() }
    }

     
     
    public mutating func update<Value>(
        _ id: UUID, in values: inout [Value], to newValue: Value
    ) {
        guard let index = index(of: id) else { return }
        values[index] = newValue
    }

    public mutating func remove<Value>(
        _ id: UUID, from values: inout [Value]
    ) {
        guard let index = index(of: id) else { return }
        ids.remove(at: index)
        values.remove(at: index)
    }

    public mutating func removeOffsets<Value>(
        _ offsets: IndexSet, from values: inout [Value]
    ) {
        ids.remove(atOffsets: offsets)
        values.remove(atOffsets: offsets)
    }

    public mutating func append<Value>(
        _ value: Value, to values: inout [Value]
    ) {
        ids.append(UUID())
        values.append(value)
    }

    public mutating func move<Value>(
        fromOffsets source: IndexSet, toOffset destination: Int,
        in values: inout [Value]
    ) {
        ids.move(fromOffsets: source, toOffset: destination)
        values.move(fromOffsets: source, toOffset: destination)
    }

     
    public mutating func swapAt<Value>(
        _ i: Int, _ j: Int, in values: inout [Value]
    ) {
        guard ids.indices.contains(i), ids.indices.contains(j) else { return }
        ids.swapAt(i, j)
        values.swapAt(i, j)
    }
}
