import SwiftUI

 
 
 
@MainActor
final class HakoRootDepartureGuard: ObservableObject {
    private struct Registration {
         
         
         
         
         
         
         
        let id: UUID
        let isDirty: Bool
        let save: (@escaping (Bool) -> Void) -> Void
        let discard: () -> Void
    }

    @Published private(set) var isPromptPresented = false
    @Published private(set) var isBusy = false

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var registrations: [Registration] = []
    private var registration: Registration? { registrations.last }
     
     
    var hasDirtyRegistration: Bool { registration?.isDirty == true }
    private var pendingDeparture: (() -> Void)?

    func register(
        id: UUID,
        isDirty: Bool,
        isBusy: Bool,
        save: @escaping (@escaping (Bool) -> Void) -> Void,
        discard: @escaping () -> Void
    ) {
        let entry = Registration(
            id: id,
            isDirty: isDirty,
            save: save,
            discard: discard
        )
        let wasDirty = hasDirtyRegistration
        if let existing = registrations.firstIndex(where: { $0.id == id }) {
            registrations[existing] = entry
        } else {
            registrations.append(entry)
        }
        if wasDirty != hasDirtyRegistration {
            dirtyRegistrationDidChange?()
        }
         
         
         
         
         
         
         
         
         
        if self.isBusy != isBusy {
            self.isBusy = isBusy
        }
    }

     
     
     
     
     
     
     
     
     
     
    func unregister(id: UUID) {
        let wasDirty = hasDirtyRegistration
        registrations.removeAll { $0.id == id }
        if wasDirty != hasDirtyRegistration {
            dirtyRegistrationDidChange?()
        }
    }

     
     
     
     
     
    var dirtyRegistrationDidChange: (() -> Void)?

    func requestDeparture(_ departure: @escaping () -> Void) {
        guard let registration else {
            departure()
            return
        }
        guard !isBusy else { return }
        guard registration.isDirty else {
            registrations.removeAll()
            departure()
            return
        }
        pendingDeparture = departure
        isPromptPresented = true
    }

    func saveAndLeave() {
        guard let registration, pendingDeparture != nil else { return }
        isPromptPresented = false
         
         
         
         
        isBusy = true
        registration.save { [weak self] succeeded in
            guard let self else { return }
            guard succeeded else {
                pendingDeparture = nil
                isBusy = false
                return
            }
            let departure = pendingDeparture
            pendingDeparture = nil
            registrations.removeAll()
            departure?()
        }
    }

    func discardAndLeave() {
        guard let registration else { return }
        isPromptPresented = false
        let departure = pendingDeparture
        pendingDeparture = nil
        registration.discard()
        clearRegistration()
        departure?()
    }

    func keepEditing() {
        isPromptPresented = false
        pendingDeparture = nil
    }

     
     
     
    private func clearRegistration() {
        registrations.removeAll()
        isBusy = false
        isPromptPresented = false
    }
}

private struct HakoRootDepartureGuardKey: EnvironmentKey {
    static let defaultValue: HakoRootDepartureGuard? = nil
}

extension EnvironmentValues {
    var hakoRootDepartureGuard: HakoRootDepartureGuard? {
        get { self[HakoRootDepartureGuardKey.self] }
        set { self[HakoRootDepartureGuardKey.self] = newValue }
    }
}

 
 
 
 
 
 
 
 
 
 
 
enum HakoDeparture {
    @MainActor
    static func request(
        _ departureGuard: HakoRootDepartureGuard?,
        leave: @escaping () -> Void
    ) {
        guard let departureGuard else {
            leave()
            return
        }
        departureGuard.requestDeparture(leave)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
public extension View {
    func hakoRegistersDeparture(
        isDirty: Bool,
        isBusy: Bool = false,
        save: @escaping (@escaping (Bool) -> Void) -> Void,
        discard: @escaping () -> Void
    ) -> some View {
        modifier(
            HakoDepartureRegistration(
                isDirty: isDirty,
                isBusy: isBusy,
                save: save,
                discard: discard
            )
        )
    }
}

private struct HakoDepartureRegistration: ViewModifier {
     
     
     
     
     
    @State private var id = UUID()
    @Environment(\.hakoRootDepartureGuard) private var guardObject
    let isDirty: Bool
    let isBusy: Bool
    let save: (@escaping (Bool) -> Void) -> Void
    let discard: () -> Void

    func body(content: Content) -> some View {
         
         
         
         
         
         
         
         
         
         
         
        register()
        return content
            .onAppear { register() }
             
             
             
             
            .onDisappear { guardObject?.unregister(id: id) }
    }

    private func register() {
        guardObject?.register(
            id: id,
            isDirty: isDirty,
            isBusy: isBusy,
            save: save,
            discard: discard
        )
    }
}

