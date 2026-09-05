import Foundation

 
 
 
 
struct LegacyRelayMigration: Codable, Equatable, Hashable, Identifiable {
    let groupName: String
    let members: [String]

    var id: String { groupName }
}

enum LegacyRelayMigrationBlocker: String, Codable, Equatable, Hashable {
    case implicitGlobalConsumer
    case externalConsumer
    case dynamicConsumer
    case dynamicRelay
    case nonRawMember
    case missingMember
    case duplicateMember
    case duplicateName
    case existingDialerProxy

    var explanation: String {
        switch self {
        case .implicitGlobalConsumer:
            return "The implicit GLOBAL group can select an internal hop, so changing that proxy would affect routes outside this relay."
        case .externalConsumer:
            return "An internal hop is referenced outside this relay, so an in-place migration would change other routes."
        case .dynamicConsumer:
            return "An include-all group can select internal hops dynamically, so isolation cannot be proven."
        case .dynamicRelay:
            return "This relay uses a provider or dynamic membership and cannot be converted to a fixed proxy chain safely."
        case .nonRawMember:
            return "Every relay member must be a top-level raw proxy; groups, providers, and built-in targets require manual rebuilding."
        case .missingMember:
            return "At least one relay member is missing from the generated proxy inventory."
        case .duplicateMember:
            return "The relay repeats a member, so its hop order is ambiguous."
        case .duplicateName:
            return "The generated configuration has duplicate proxy or group names."
        case .existingDialerProxy:
            return "A relay member already has dialer-proxy, so overwriting it would discard an existing chain."
        }
    }
}

struct LegacyRelayAssessment: Equatable, Identifiable {
    let groupName: String
    let members: [String]
    let blocker: LegacyRelayMigrationBlocker?

    var id: String { groupName }
    var pathDescription: String {
        members.map(LegacyRelayPrivacy.safeLabel).joined(separator: " → ")
    }
}

enum LegacyRelayMigrationError: LocalizedError, Equatable {
    case confirmationRequired(
        group: String,
        members: [String],
        blocker: LegacyRelayMigrationBlocker?
    )
    case unsafeMigration(
        group: String,
        members: [String],
        blocker: LegacyRelayMigrationBlocker
    )
    case staleConfirmation(
        group: String,
        expectedMembers: [String],
        actualMembers: [String]
    )
    case duplicateConfirmation(group: String)

    var errorDescription: String? {
        switch self {
        case let .confirmationRequired(group, members, blocker):
            let base = Self.summary(group: group, members: members)
            if let blocker {
                return LegacyRelayPrivacy.bounded(
                    "\(base) Automatic migration is unavailable. \(blocker.explanation) Open Proxy Chains to rebuild it manually."
                )
            }
            return LegacyRelayPrivacy.bounded(
                "\(base) Open Proxy Chains to review and explicitly enable a TCP-only runtime migration. The downloaded source will not be changed."
            )
        case let .unsafeMigration(group, members, blocker):
            return LegacyRelayPrivacy.bounded(
                "\(Self.summary(group: group, members: members)) Migration remains blocked. \(blocker.explanation)"
            )
        case let .staleConfirmation(group, _, actualMembers):
            return LegacyRelayPrivacy.bounded(
                "Legacy relay group \(LegacyRelayPrivacy.safeLabel(group)) changed to \(Self.path(actualMembers)). Review and confirm the refreshed chain again."
            )
        case .duplicateConfirmation(let group):
            return LegacyRelayPrivacy.bounded(
                "Legacy relay group \(LegacyRelayPrivacy.safeLabel(group)) has duplicate migration confirmations. Remove the duplicate before retrying."
            )
        }
    }

    private static func summary(group: String, members: [String]) -> String {
        "Legacy relay group \(LegacyRelayPrivacy.safeLabel(group)) uses the removed relay chain \(path(members))."
    }

    private static func path(_ members: [String]) -> String {
        let labels = members.map(LegacyRelayPrivacy.safeLabel)
        return labels.isEmpty ? "(empty)" : labels.joined(separator: " → ")
    }
}

private enum LegacyRelayPrivacy {
    private static let sensitiveMarkers = [
        "://", "token=", "password", "passwd", "secret", "auth=", "key=", "@"
    ]

    static func safeLabel(_ raw: String) -> String {
        let cleaned = raw
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()
        guard !cleaned.isEmpty,
              !sensitiveMarkers.contains(where: lower.contains) else {
            return "[private proxy]"
        }
        let prefix = String(cleaned.prefix(64))
        return cleaned.count > prefix.count ? "\(prefix)…" : prefix
    }

    static func bounded(_ message: String) -> String {
        String(message.prefix(512))
    }
}

 
 
 
enum LegacyRelayMigrationEngine {
    static func assess(_ yaml: String) throws -> [LegacyRelayAssessment] {
        let root = try rootObject(yaml)
        return assessments(in: root)
    }

    static func apply(
        _ migrations: [LegacyRelayMigration],
        to yaml: String
    ) throws -> String {
        var document = try ConfigTransforms.ParsedDocument(yaml: yaml)
        guard try apply(migrations, to: &document.root) else { return yaml }
        return try document.serialized()
    }

     
     
     
    @discardableResult
    static func apply(
        _ migrations: [LegacyRelayMigration],
        to root: inout [String: Any]
    ) throws -> Bool {
        let findings = assessments(in: root)
        guard !findings.isEmpty else { return false }

        var migrationByGroup: [String: LegacyRelayMigration] = [:]
        for migration in migrations {
            guard migrationByGroup[migration.groupName] == nil else {
                throw LegacyRelayMigrationError.duplicateConfirmation(
                    group: migration.groupName
                )
            }
            migrationByGroup[migration.groupName] = migration
        }

        for finding in findings {
            guard let migration = migrationByGroup[finding.groupName] else {
                throw LegacyRelayMigrationError.confirmationRequired(
                    group: finding.groupName,
                    members: finding.members,
                    blocker: finding.blocker
                )
            }
            guard migration.members == finding.members else {
                throw LegacyRelayMigrationError.staleConfirmation(
                    group: finding.groupName,
                    expectedMembers: migration.members,
                    actualMembers: finding.members
                )
            }
            if let blocker = finding.blocker {
                throw LegacyRelayMigrationError.unsafeMigration(
                    group: finding.groupName,
                    members: finding.members,
                    blocker: blocker
                )
            }
        }

        guard var proxies = root["proxies"] as? [[String: Any]],
              var groups = root["proxy-groups"] as? [[String: Any]] else {
             
             
            throw ConfigTransformsError.invalidConfiguration(
                "legacy relay runtime collections are invalid"
            )
        }
        let proxyIndex = Dictionary(uniqueKeysWithValues: proxies.enumerated().compactMap {
            index, row in (row["name"] as? String).map { ($0, index) }
        })
        let groupIndex = Dictionary(uniqueKeysWithValues: groups.enumerated().compactMap {
            index, row in (row["name"] as? String).map { ($0, index) }
        })

        for finding in findings {
            for index in finding.members.indices.dropFirst() {
                guard let proxyPosition = proxyIndex[finding.members[index]] else {
                    throw LegacyRelayMigrationError.unsafeMigration(
                        group: finding.groupName,
                        members: finding.members,
                        blocker: .missingMember
                    )
                }
                proxies[proxyPosition]["dialer-proxy"] = finding.members[index - 1]
            }
            guard let position = groupIndex[finding.groupName],
                  let leaf = finding.members.last else {
                throw LegacyRelayMigrationError.unsafeMigration(
                    group: finding.groupName,
                    members: finding.members,
                    blocker: .missingMember
                )
            }
            groups[position]["type"] = "select"
            groups[position]["proxies"] = [leaf]
             
             
            groups[position]["disable-udp"] = true
        }

        root["proxies"] = proxies
        root["proxy-groups"] = groups
         
         
         
        let inventory = try ProxyChainSpec.inventory(from: root)
        try ProxyChainSpec().validate(in: inventory)
        return true
    }

    private static func assessments(
        in root: [String: Any]
    ) -> [LegacyRelayAssessment] {
        let proxyRows = root["proxies"] as? [[String: Any]] ?? []
        let groupRows = root["proxy-groups"] as? [[String: Any]] ?? []
        let relayRows = groupRows.filter {
            (($0["type"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "relay"
        }
        guard !relayRows.isEmpty else { return [] }

        let proxyNames = proxyRows.compactMap { normalizedString($0["name"]) }
        let groupNames = groupRows.compactMap { normalizedString($0["name"]) }
        let allNames = proxyNames + groupNames
        let duplicateName = Set(allNames).count != allNames.count
        let explicitGlobal = groupNames.contains("GLOBAL")
        let rawProxyCounts = Dictionary(grouping: proxyNames, by: { $0 })
            .mapValues(\.count)
        let groupNameSet = Set(groupNames)
        let builtinNames = BuiltinProxyName.all

        return relayRows.enumerated().map { index, relay in
            let group = normalizedString(relay["name"])
                ?? "Legacy relay \(index + 1)"
            let members = stringArray(relay["proxies"])
            let downstream = Set(members.dropFirst())
            let blocker: LegacyRelayMigrationBlocker?

            if duplicateName {
                blocker = .duplicateName
            } else if hasDynamicMembership(relay) {
                blocker = .dynamicRelay
            } else if members.isEmpty
                        || members.contains(where: { rawProxyCounts[$0] == nil
                            && !builtinNames.contains($0)
                            && !groupNameSet.contains($0) }) {
                blocker = .missingMember
            } else if Set(members).count != members.count {
                blocker = .duplicateMember
            } else if members.contains(where: {
                builtinNames.contains($0) || groupNameSet.contains($0)
                    || rawProxyCounts[$0] != 1
            }) {
                blocker = .nonRawMember
            } else if memberHasDialer(members, proxyRows: proxyRows) {
                blocker = .existingDialerProxy
            } else if !explicitGlobal && !downstream.isEmpty {
                blocker = .implicitGlobalConsumer
            } else if groupRows.contains(where: {
                normalizedString($0["name"]) != group
                    && hasIncludeAllProxyMembership($0)
            }) && !downstream.isEmpty {
                blocker = .dynamicConsumer
            } else if hasExternalReference(
                downstream,
                relayGroup: group,
                root: root,
                proxyRows: proxyRows,
                groupRows: groupRows,
                relayMembers: Set(members)
            ) {
                blocker = .externalConsumer
            } else {
                blocker = nil
            }

            return LegacyRelayAssessment(
                groupName: group,
                members: members,
                blocker: blocker
            )
        }
    }

    private static func rootObject(_ yaml: String) throws -> [String: Any] {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard let root = try JSONSerialization.jsonObject(
            with: Data(json.utf8)
        ) as? [String: Any] else {
            throw ConfigTransformsError.invalidConfiguration(
                "legacy relay runtime root is not an object"
            )
        }
        return root
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringArray(_ value: Any?) -> [String] {
        (value as? [Any] ?? []).compactMap(normalizedString)
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value.lowercased() == "true" }
        return false
    }

    private static func hasDynamicMembership(_ group: [String: Any]) -> Bool {
        !stringArray(group["use"]).isEmpty
            || bool(group["include-all"])
            || bool(group["include-all-proxies"])
            || bool(group["include-all-providers"])
    }

    private static func hasIncludeAllProxyMembership(
        _ group: [String: Any]
    ) -> Bool {
        bool(group["include-all"]) || bool(group["include-all-proxies"])
    }

    private static func memberHasDialer(
        _ members: [String],
        proxyRows: [[String: Any]]
    ) -> Bool {
        let memberSet = Set(members)
        return proxyRows.contains { row in
            guard let name = normalizedString(row["name"]),
                  memberSet.contains(name) else { return false }
            return normalizedString(row["dialer-proxy"]) != nil
        }
    }

    private static func hasExternalReference(
        _ downstream: Set<String>,
        relayGroup: String,
        root: [String: Any],
        proxyRows: [[String: Any]],
        groupRows: [[String: Any]],
        relayMembers: Set<String>
    ) -> Bool {
        guard !downstream.isEmpty else { return false }

         
         
         
        for row in proxyRows {
            guard let name = normalizedString(row["name"]),
                  !relayMembers.contains(name) else { continue }
            if containsReference(row, targets: downstream) { return true }
        }

        for row in groupRows {
            guard normalizedString(row["name"]) != relayGroup else { continue }
            if containsReference(row, targets: downstream) { return true }
        }

        var remaining = root
        remaining.removeValue(forKey: "proxies")
        remaining.removeValue(forKey: "proxy-groups")
        return containsReference(remaining, targets: downstream)
    }

    private static func containsReference(
        _ value: Any,
        targets: Set<String>
    ) -> Bool {
        if let string = value as? String {
            if targets.contains(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return true
            }
            let tokens = string.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return tokens.contains(where: targets.contains)
        }
        if let array = value as? [Any] {
            return array.contains { containsReference($0, targets: targets) }
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.contains {
                containsReference($0, targets: targets)
            }
        }
        return false
    }
}
