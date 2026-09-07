import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVConnectionDetailScreen: View {
     
    enum Liveness: Equatable { case live, ended, unconfirmed }

     
     
     
     
    struct Field: Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

     
     
     
    struct Model: Equatable {
        private(set) var connection: HakoActivityConnectionSnapshot
        private(set) var liveness: Liveness
        private(set) var lastObservedAt: Date?
        private(set) var observation = HakoTVObservation()
        private var generation: UInt64?

        init(_ seed: HakoActivityConnectionSnapshot, observedAt: Date? = nil, generation: UInt64? = nil) {
            connection = seed
            liveness = .live
            lastObservedAt = observedAt
            self.generation = generation
        }

        mutating func observe(_ connections: [HakoActivityConnectionSnapshot], observation: HakoTVObservation,
                              generation: UInt64, isConnected: Bool, endedGeneration: UInt64? = nil) {
            if let held = self.generation, held == endedGeneration { liveness = .ended; return }
            if let held = self.generation, held != generation {
                self.observation.waitForUpdate()
                if liveness != .ended { liveness = .unconfirmed }
                return
            }
            guard isConnected else {
                self.observation.waitForUpdate()
                if liveness != .ended { liveness = .unconfirmed }
                return
            }
            self.generation = generation
            self.observation = observation
            guard observation.hasRuntimeSample, observation.confirmsCurrentValue else {
                 
                if liveness != .ended { liveness = .unconfirmed }
                return
            }
            if let fresh = connections.first(where: { $0.id == connection.id }) {
                connection = fresh
                lastObservedAt = observation.lastSuccess
                liveness = .live
            } else {
                liveness = .ended
            }
        }

        func displayedFields(now: Date) -> [Field] {
            let fields = HakoTVConnectionDetailScreen.fields(for: connection, now: liveness == .live ? now : (lastObservedAt ?? now))
            guard liveness != .live else { return fields }
            return fields.compactMap { field in
                guard field.label == String(localized: "Duration") else { return field }
                guard lastObservedAt != nil else { return nil }
                return Field(label: String(localized: "Last observed duration"), value: field.value)
            }
        }

        mutating func update(from connections: [HakoActivityConnectionSnapshot]) {
            guard let fresh = connections.first(where: { $0.id == connection.id }) else {
                liveness = .ended
                return
            }
            connection = fresh
            liveness = .live
        }
    }

    @Binding var state: HakoTVProductState
     
     
    let seed: HakoActivityConnectionSnapshot

    @State private var model: Model
    @State private var clockNow = Date()
    @Environment(\.hakoTVPollingPresentation) private var pollingPresentation
    private var clockActive: Bool {
        pollingPresentation.active && pollingPresentation.page == .connectionDetail && model.liveness == .live
    }

    init(state: Binding<HakoTVProductState>, seed: HakoActivityConnectionSnapshot,
         observedAt: Date? = nil, generation: UInt64? = nil) {
        _state = state
        self.seed = seed
        _model = State(initialValue: Model(seed, observedAt: observedAt ?? state.wrappedValue.observations.connections.lastSuccess,
                                           generation: generation ?? state.wrappedValue.observations.generation))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.connection.destination)
                .font(.title2)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(Self.statusWord(model.liveness))
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(model.liveness == .ended ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            HakoTVObservationNote(observation: model.observation)
            List {
                 
                 
                ForEach(model.displayedFields(now: clockNow)) { field in
                    LabeledContent(field.label) {
                        Text(field.value)
                            .accessibilityIdentifier("tvos.connection.field.\(field.id)")
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .listStyle(.grouped)
            .safeAreaPadding(.horizontal, 24)
            .safeAreaPadding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: clockActive) {
            guard clockActive else { return }
            await HakoTVDisplayClock.run { clockNow = $0 }
        }
        .onChange(of: state.observations.connections, initial: true) { _, _ in observeConnection() }
        .onChange(of: state.observations.generation) { _, _ in observeConnection() }
        .onChange(of: state.isConnected) { _, _ in observeConnection() }
        .onChange(of: state.observations.lastEndedGeneration) { _, _ in observeConnection() }
    }

    private func observeConnection() {
        model.observe(state.connections, observation: state.observations.connections,
                      generation: state.observations.generation, isConnected: state.isConnected,
                      endedGeneration: state.observations.lastEndedGeneration)
    }

     

    static func statusWord(_ liveness: Liveness) -> String {
        switch liveness {
        case .live: String(localized: "Live")
        case .ended: String(localized: "Ended")
        case .unconfirmed: String(localized: "Current status not confirmed")
        }
    }

     
     
     
     
     
     
    static func fields(for connection: HakoActivityConnectionSnapshot, now: Date) -> [Field] {
        var fields: [Field] = []
        func add(_ label: String, _ value: String) {
            guard !value.isEmpty else { return }
            fields.append(Field(label: label, value: value))
        }
        add(String(localized: "Proxy chain"), connection.chains.joined(separator: " → "))
        add(String(localized: "Rule"), connection.ruleDescription)
        add(String(localized: "Destination"), connection.destination)
        add(String(localized: "Source"), connection.source)
        add(String(localized: "Network"), connection.network)
        add(String(localized: "DNS mode"), connection.dnsMode)
        add(String(localized: "Upload"), HakoTVBytes.text(connection.upload))
        add(String(localized: "Download"), HakoTVBytes.text(connection.download))
        if let start = connection.start {
            add(String(localized: "Duration"), HakoConnectionDuration.text(secondsElapsed: Int(now.timeIntervalSince(start))))
        }
        return fields
    }
}
