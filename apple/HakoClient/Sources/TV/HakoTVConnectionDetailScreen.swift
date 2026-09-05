import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVConnectionDetailScreen: View {
     
    enum Liveness: Equatable { case live, ended }

     
     
     
     
    struct Field: Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

     
     
     
    struct Model: Equatable {
        private(set) var connection: HakoActivityConnectionSnapshot
        private(set) var liveness: Liveness

        init(_ seed: HakoActivityConnectionSnapshot) {
            connection = seed
            liveness = .live
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

    init(state: Binding<HakoTVProductState>, seed: HakoActivityConnectionSnapshot) {
        _state = state
        self.seed = seed
        _model = State(initialValue: Model(seed))
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
            List {
                 
                 
                 
                 
                 
                 
                 
                 
                ForEach(Self.fields(for: model.connection, now: Date())) { field in
                    LabeledContent(field.label) {
                        Text(field.value)
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
        .onChange(of: state.connections) { _, connections in
            model.update(from: connections)
        }
    }

     

    static func statusWord(_ liveness: Liveness) -> String {
        switch liveness {
        case .live: String(localized: "Live")
        case .ended: String(localized: "Ended")
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
