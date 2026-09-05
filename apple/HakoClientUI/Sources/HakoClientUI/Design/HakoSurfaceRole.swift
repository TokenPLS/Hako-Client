 
 
public enum HakoSurfaceRole: String, CaseIterable, Sendable {
    case primaryPageCard
    case secondaryPageCard
    case groupedSection
    case selection
    case destructiveAction

    public var permitsNativeGlass: Bool {
        self == .primaryPageCard
    }
}

 
 
public enum HakoContentLayoutRole: String, CaseIterable, Sendable {
    case contentColumn
    case primaryRow
    case detailRow
}
