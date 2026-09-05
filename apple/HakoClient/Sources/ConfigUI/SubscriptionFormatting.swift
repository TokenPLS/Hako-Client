import SwiftUI

enum SubscriptionExpiryStatus: Equatable {
    case never
    case active
    case expiringSoon
    case expiresToday
    case expired
}

struct SubscriptionExpiryPresentation: Equatable {
    let status: SubscriptionExpiryStatus
    let text: String
}

extension SubscriptionInfo {
    var usedBytes: Int64 {
        let (sum, overflow) = upload.addingReportingOverflow(download)
        return max(0, overflow ? Int64.max : sum)
    }

    var usageFraction: Double? {
        guard total > 0 else { return nil }
        return min(max(Double(usedBytes) / Double(total), 0), 1)
    }

     
     
    var remainingBytes: Int64? {
        guard total > 0 else { return nil }
        return max(0, total - usedBytes)
    }

     
     
    static func compactBytes(_ bytes: Int64) -> String {
        let units = ["K", "M", "G", "T"]
        var value = Double(bytes) / 1024
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        let text = value < 100
            ? String(format: "%.1f", value)
            : String(format: "%.0f", value)
        return text.replacingOccurrences(of: ".0", with: "") + units[unit]
    }

     
     
     
     
    var usageSummary: String {
        let used = ByteCountFormatter.string(usedBytes)
        var summary = total > 0 ? "\(used) / \(ByteCountFormatter.string(total))" : used
        if expire > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            summary += " · expires \(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expire))))"
        }
        return summary
    }

    func expiryPresentation(now: Date = Date()) -> SubscriptionExpiryPresentation {
        guard expire > 0 else {
            return SubscriptionExpiryPresentation(status: .never, text: "No expiry")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expire))
        let start = calendar.startOfDay(for: now)
        let expiryStart = calendar.startOfDay(for: expiryDate)
        let days = calendar.dateComponents([.day], from: start, to: expiryStart).day ?? 0

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        let date = formatter.string(from: expiryDate)
        if days < 0 {
            return SubscriptionExpiryPresentation(status: .expired, text: "Expired \(date)")
        }
        if days == 0 {
            return SubscriptionExpiryPresentation(status: .expiresToday, text: "Expires today")
        }
        if days <= 7 {
            return SubscriptionExpiryPresentation(
                status: .expiringSoon,
                text: "Expires in \(days) day\(days == 1 ? "" : "s")"
            )
        }
        return SubscriptionExpiryPresentation(status: .active, text: "Expires \(date)")
    }
}

struct SubscriptionInfoView: View {
    let info: SubscriptionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
             
             
             
             
            summaryLine
                .font(.system(size: 10))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let fraction = info.usageFraction {
                ProgressView(value: fraction)
                     
                     
                     
                    .tint(fraction >= 1 ? Color.red : nil)
                    .accessibilityLabel("Subscription usage")
                    .accessibilityValue("\(Int(fraction * 100)) percent")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryLine: Text {
        var line = Text(
            "↑:\(SubscriptionInfo.compactBytes(info.upload)),↓:\(SubscriptionInfo.compactBytes(info.download))"
        )
        if info.total > 0 {
            line = line + Text(",TOT:\(SubscriptionInfo.compactBytes(info.total))")
        }
        if info.expire > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let date = formatter.string(
                from: Date(timeIntervalSince1970: TimeInterval(info.expire))
            )
            line = line + Text(",EXPIRE:\(date)").foregroundColor(expiryTint)
        }
        return line
    }

    private var expiry: SubscriptionExpiryPresentation {
        info.expiryPresentation()
    }

    private var expiryTint: Color {
        switch expiry.status {
        case .expired, .expiresToday: return .red
        case .expiringSoon: return .orange
        case .never, .active: return .secondary
        }
    }
}

enum SubscriptionURLPresentation {
     
     
     
     
     
     
    static func hostDescription(
        _ rawValue: String,
        locale: Locale
    ) -> String {
        guard let host = URLComponents(string: rawValue)?.host, !host.isEmpty else {
            return HakoCopy.string("Subscription", locale: locale)
        }
        return host
    }

     
     
     
     
    static func autoLabel(for rawValue: String) -> String {
        guard let host = URLComponents(string: rawValue)?.host else { return "Subscription" }
        let parts = host.split(separator: ".")
        guard parts.count >= 2 else { return host }
        return String(parts[parts.count - 2])
    }

     
    static func safeDescription(_ rawValue: String) -> String {
        guard var components = URLComponents(string: rawValue) else {
            return "Remote subscription"
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        let pathSegments = components.path.split(
            separator: "/", omittingEmptySubsequences: false
        ).map { segment -> String in
            let text = String(segment)
            let isOpaqueToken = text.count >= 16 && text.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
            }
            return isOpaqueToken ? "…" : text
        }
        components.path = pathSegments.joined(separator: "/")
        return components.url?.absoluteString
            .replacingOccurrences(of: "%E2%80%A6", with: "…")
            ?? "Remote subscription"
    }
}
