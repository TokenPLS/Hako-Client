import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoLastPreparation<Key: Equatable, Value: Sendable> {
    private final class Flight {
        var waiters: [CheckedContinuation<Value, Never>] = []
    }

    private var entry: (key: Key, value: Value)?
    private var inFlight: (key: Key, flight: Flight)?

    public init() {}

    public func value(for key: Key) -> Value? {
        entry.flatMap { $0.key == key ? $0.value : nil }
    }

    public func store(_ value: Value, for key: Key) {
        entry = (key, value)
         
         
         
        inFlight = nil
    }

     
     
     
     
     
     
     
     
    public func value(
        for key: Key,
        preparing: @escaping @MainActor () async -> Value
    ) async -> Value {
        if let cached = value(for: key) {
            return cached
        }
        if let inFlight, inFlight.key == key {
            return await wait(on: inFlight.flight)
        }

        let flight = Flight()
        inFlight = (key, flight)
        return await withCheckedContinuation { continuation in
            flight.waiters.append(continuation)
            Task { @MainActor in
                let value = await preparing()
                self.finish(value, for: key, flight: flight)
            }
        }
    }

    private func wait(on flight: Flight) async -> Value {
        await withCheckedContinuation { continuation in
            flight.waiters.append(continuation)
        }
    }

    private func finish(_ value: Value, for key: Key, flight: Flight) {
        if let current = inFlight, current.flight === flight {
            entry = (key, value)
            inFlight = nil
        }
        let waiters = flight.waiters
        flight.waiters.removeAll(keepingCapacity: false)
        waiters.forEach { $0.resume(returning: value) }
    }
}
