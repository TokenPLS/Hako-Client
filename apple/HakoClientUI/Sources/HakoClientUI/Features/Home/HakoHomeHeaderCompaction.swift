import Combine
import Foundation

enum HakoHomeHeaderCompaction {
    static func progress(distance: CGFloat, range: CGFloat) -> CGFloat {
        guard range > 0 else { return 0 }
        return min(max(distance / range, 0), 1)
    }

    static func value(
        expanded: CGFloat,
        compact: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        let progress = min(max(progress, 0), 1)
        return expanded + (compact - expanded) * progress
    }

     
     
     
     
    static func stagedValue(
        expanded: CGFloat,
        compact: CGFloat,
        distance: CGFloat,
        after precedingReduction: CGFloat
    ) -> CGFloat {
        let reduction = max(expanded - compact, 0)
        let applied = min(max(distance - precedingReduction, 0), reduction)
        return expanded - applied
    }
}

final class HakoHomeHeaderCompactionState: ObservableObject {
    @Published private(set) var progress: CGFloat = 0

    func update(distance: CGFloat, range: CGFloat, enabled: Bool) {
        let next = enabled
            ? HakoHomeHeaderCompaction.progress(
                distance: distance,
                range: range
            )
            : 0
        guard abs(next - progress) > 0.001 else { return }
        progress = next
    }

    func reset() {
        guard progress != 0 else { return }
        progress = 0
    }
}
