import Foundation

 
 
 
enum ProfileCenterPolicy {
    static func automaticSelectionID(
        profiles: [Profile],
        activeProfileID: String?
    ) -> String? {
        guard activeProfileID == nil else { return nil }
        if profiles.contains(where: { $0.id == LocalDefaultProfileProvisioner.profileID }) {
            return LocalDefaultProfileProvisioner.profileID
        }
        return profiles.count == 1 ? profiles[0].id : nil
    }

    static func canDelete(profileID: String, activeProfileID: String?) -> Bool {
        profileID != LocalDefaultProfileProvisioner.profileID
            && profileID != activeProfileID
    }
}

 
 
 
enum ProfileLabelPolicy {
     
     
     
     
     
    static func name(given label: String, for source: Profile.Source) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch source {
        case .url(let raw):
            if let host = URL(string: raw)?.host, !host.isEmpty { return host }
            return "Subscription"
        case .file(let name):
            let stem = (name as NSString).deletingPathExtension
            return stem.isEmpty ? "Profile" : stem
        case .clipboard:
            return "Pasted Configuration"
        }
    }

     
     
     
     
     
     
     
    static func generatedNames(for source: Profile.Source) -> Set<String> {
        var names: Set<String> = ["Profile", "Subscription"]
        names.insert(name(given: "", for: source))
        if case .url(let raw) = source {
            names.insert(SubscriptionURLPresentation.autoLabel(for: raw))
        }
        return names
    }

     
     
     
     
     
     
    static func isUserAssigned(_ profile: Profile) -> Bool {
        if let recorded = profile.labelIsUserAssigned { return recorded }
        return !generatedNames(for: profile.source)
            .contains(withoutDeduplicationSuffix(profile.label))
    }

     
     
    static func withoutDeduplicationSuffix(_ label: String) -> String {
        guard label.hasSuffix(")"), let open = label.lastIndex(of: "(") else {
            return label
        }
        let digits = label[label.index(after: open)..<label.index(before: label.endIndex)]
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return label }
        return String(label[label.startIndex..<open])
    }

    static func deduplicate(_ label: String, existing: some Collection<String>) -> String {
        let taken = Set(existing)
        var candidate = label
        while taken.contains(candidate) {
            candidate = incrementingCounter(candidate)
        }
        return candidate
    }

    private static func incrementingCounter(_ label: String) -> String {
        if let open = label.lastIndex(of: "("),
           label.hasSuffix(")"),
           label.index(after: open) < label.index(before: label.endIndex),
           let number = Int(label[label.index(after: open)..<label.index(before: label.endIndex)]) {
            return "\(label[label.startIndex..<open])(\(number + 1))"
        }
        return "\(label)(1)"
    }
}

enum ProfileMetadataUpdate {
    enum ValidationError: LocalizedError, Equatable {
        case emptyName
        case unusableSubscription
        case invalidInterval

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Profile name cannot be empty."
            case .unusableSubscription:
                return "Enter a subscription address."
            case .invalidInterval:
                return "Automatic update interval must be at least 1 hour."
            }
        }
    }

     
     
     
     
     
    static func strippingSourceCredentials(from profile: Profile) -> Profile? {
        guard case let .url(raw) = profile.source else { return nil }
         
         
         
         
        guard let components = URLComponents(string: raw),
              components.user != nil
                || components.password != nil
                || components.query != nil
                || components.fragment != nil else {
            return nil
        }
        guard let bare = strippedSpelling(of: raw) else { return nil }
        var updated = profile
        updated.source = .url(bare)
        return normalizingSourceChange(previous: profile, updated: updated)
    }

     
     
     
    static func strippedSpelling(of raw: String) -> String? {
        guard var components = URLComponents(string: raw) else { return nil }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString
    }

    static func apply(
        to profile: Profile,
        label: String,
        subscriptionURL: String?,
        autoUpdate: Bool,
        updateIntervalHours: Int,
        existingLabels: Set<String> = []
    ) throws -> Profile {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { throw ValidationError.emptyName }
         
         
        guard updateIntervalHours >= 1 else {
            throw ValidationError.invalidInterval
        }

        var updated = profile
        updated.label = ProfileLabelPolicy.deduplicate(
            trimmedLabel, existing: existingLabels
        )
         
         
         
        if trimmedLabel != profile.label {
            updated.labelIsUserAssigned = true
        } else if updated.labelIsUserAssigned == nil {
             
             
             
             
             
            updated.labelIsUserAssigned = ProfileLabelPolicy.isUserAssigned(profile)
        }
        updated.autoUpdate = autoUpdate
        updated.updateIntervalHours = updateIntervalHours

        guard case let .url(previousURL) = profile.source else { return updated }
        let trimmedURL = (subscriptionURL ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
         
         
         
         
         
         
         
        if trimmedURL == previousURL {
            return updated
        }
         
         
         
         
         
         
        guard let components = URLComponents(string: trimmedURL),
              components.scheme != nil,
              components.host?.isEmpty == false else {
            throw ValidationError.unusableSubscription
        }
        updated.source = .url(trimmedURL)
        return normalizingSourceChange(previous: profile, updated: updated)
    }

     
     
     
     
    static func normalizingSourceChange(
        previous: Profile,
        updated: Profile
    ) -> Profile {
        guard case let .url(previousURL) = previous.source,
              case let .url(newURL) = updated.source,
              previousURL != newURL else { return updated }
        var normalized = updated
        normalized.subscriptionETag = nil
        normalized.subscriptionLastModified = nil
        normalized.subscriptionInfo = nil
        normalized.lastUpdatedAt = nil
        normalized.usesLocalSourceOverride = false
        return normalized
    }

     
     
     
    static func shouldResyncAfterSourceChange(
        previous: Profile,
        updated: Profile
    ) -> Bool {
        guard case let .url(previousURL) = previous.source,
              case let .url(newURL) = updated.source,
              previousURL != newURL else { return false }
        return updated.usesLocalSourceOverride != true
    }
}

 
 
 
 
 
 
 
 
 
 
 
enum ProxyNodeEditPolicy {
     
     
     
     
     
     
     
     
     
     
     
    static func isEditable(hasStoredSource: Bool) -> Bool {
        hasStoredSource
    }

    static let unavailableReason =
        "Prepare this profile once before editing individual nodes."
}

enum DirectProfileTemplate {
     
     
     
     
     
     
     
     
     
     
    static let yaml = """
    mode: rule
    dns:
      enable: true
      ipv6: false
      enhanced-mode: fake-ip
      # Setting this key replaces the kernel's list rather than adding to it
      # (config/config.go:526-530), so its three entries are carried along.
      # The rest are names that must resolve to the address that really
      # answers them: iOS decides whether to show the Wi-Fi sign-in sheet by
      # resolving captive.apple.com, and a synthetic address there means a
      # hotel or airport login that silently never appears. Wildcard spelling
      # per Meta-Docs config/dns/index.md:19-20.
      fake-ip-filter:
        - "*.lan"
        - "*.local"
        - captive.apple.com
        - dns.msftnsci.com
        - www.msftnsci.com
        - www.msftconnecttest.com
      nameserver:
        - 223.5.5.5
        - 1.1.1.1
    proxies: []
    proxy-groups:
      - name: Default Route
        type: select
        proxies:
          - DIRECT
          - REJECT
    rules:
      # Changes nothing while everything is direct, and earns its place the
      # moment a proxy is added: a NAS, a printer or a router page must not be
      # carried through the tunnel. `lan`, not `private` -- only `lan` is the
      # pseudo-rule the kernel answers from the address itself, without a
      # database (rules/common/geoip.go:154-159, :213), while `private` would
      # look for a category our bundled geoip.metadb does not carry and the
      # config would be refused. `no-resolve` because under fake-ip a domain
      # request already carries a synthetic address.
      - GEOIP,lan,DIRECT,no-resolve
      - MATCH,Default Route
    """
}
