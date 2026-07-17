import Foundation
import ObjectiveC.runtime
import CryptoKit

private enum AuditConstants {
    static let hibpMaxConcurrentRequests = 6
    static let hibpRequestTimeout: TimeInterval = 5.0
    static let comparisonsPerYield = 50
    static let hibpWeight: Double = 0.8
    static let breachedAccountsCacheKey = "SecretStoreBreachedAccountsCacheKey"
    static let pwnedCacheKey = "SecretStoreHibpPwnedSetCacheKey"
}

private enum HibpError: Error {
    case invalidResponse
    case http(Int)
    
    static func hibpErrorDescription(_ error: Error) -> String {
        if let hibpError = error as? HibpError {
            switch hibpError {
            case .invalidResponse:
                return "Invalid response"
            case .http(let code):
                return "HTTP \(code)"
            }
        }
        
        if let urlError = error as? URLError {
            return "Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        }
        
        return error.localizedDescription
    }
}

private struct HibpAccountResponse: Decodable {
    let domain: String?

    private enum CodingKeys: String, CodingKey {
        case domain = "Domain"
    }
}

private struct HibpResult {
    let email: String
    let nodes: [Node]
    let breaches: [String]
    let hadError: Bool
    let error: String?
}

private struct PwnedPasswordItem {
    let password: String
    let sha1: String
    let nodes: [Node]
}

private actor HibpCache {
    private var breachedAccounts: [String: [String]]

    init(existing: [String: [String]]) {
        breachedAccounts = existing
    }

    func cachedBreaches(for email: String) -> [String]? {
        breachedAccounts[email]
    }

    func updateBreaches(_ breaches: [String], for email: String) {
        breachedAccounts[email] = breaches
    }

    func snapshot() -> [String: [String]] {
        breachedAccounts
    }
}

extension DatabaseAuditor {
    private static var currentTaskKey: UInt8 = 0

    private var networkFeaturesDisabled: Bool {
        #if os(macOS)
        return Settings.sharedInstance().disableNetworkBasedFeatures ?? false
        #else
        return AppPreferences.sharedInstance().disableNetworkBasedFeatures
        #endif
    }

    private var currentAuditTask: Task<Void, Never>? {
        get {
            objc_getAssociatedObject(self, &Self.currentTaskKey) as? Task<Void, Never>
        }
        set {
            objc_setAssociatedObject(self, &Self.currentTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc func startSwiftAuditTask(
        auditableNodes: [Node],
        nodesChanged: @escaping @Sendable () -> Void,
        progressCallback: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (_ cancelled: Bool) -> Void
    ) {
        cancelSwiftAuditTask()
        stopRequested = false

        currentAuditTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            let cancelled: Bool
            do {
                try await self.performAuditsAsync(
                    auditableNodes: auditableNodes,
                    nodesChanged: nodesChanged,
                    progressCallback: progressCallback
                )
                cancelled = false
            } catch is CancellationError {
                cancelled = true
            } catch {
                cancelled = false
            }

            await MainActor.run { [weak self] in
                self?.currentAuditTask = nil
                completion(cancelled)
            }
        }
    }

    @objc func cancelSwiftAuditTask() {
        currentAuditTask?.cancel()
        currentAuditTask = nil
    }

    @objc func performAuditsAsync(
        auditableNodes: [Node],
        nodesChanged: @escaping @Sendable () -> Void,
        progressCallback: @escaping @Sendable (Double) -> Void
    ) async throws {
        try Task.checkCancellation()

        await resetAuditState()
        await updateProgress(hibp: 0, similar: 0, callback: progressCallback)

        try await performLocalChecks(nodes: auditableNodes)
        await MainActor.run {
            nodesChanged()
        }

        if isPro && (config.checkHibp || config.checkHibpBreaches) && !networkFeaturesDisabled {
            try Task.checkCancellation()
            try await performHIBPChecks(
                nodes: auditableNodes,
                nodesChanged: nodesChanged,
                progress: progressCallback
            )
        } else {
            await updateProgress(hibp: 1.0, callback: progressCallback)
        }

        if isPro && config.checkForSimilarPasswords {
            try Task.checkCancellation()
            try await performSimilarityCheck(
                nodes: auditableNodes,
                nodesChanged: nodesChanged,
                progress: progressCallback
            )
        } else {
            await updateProgress(similar: 0, callback: progressCallback)
        }

        if config.checkForTwoFactorAvailable {
            await performTwoFactorCheck(nodes: auditableNodes)
            await MainActor.run {
                nodesChanged()
            }
        }
    }

    private func resetAuditState() async {
        await MainActor.run {
            hibpErrorCount = 0
            hibpCompletedCount = 0
            hibpTotalCount = 0
            hibpProgress = 0
            similarProgress = 0
            mutablePwnedNodes = ConcurrentMutableSet<NSUUID>.init()
            mutableBreachedAccountNodes = ConcurrentMutableSet<NSUUID>.init()
            matchedBreachedDomainsByNode = NSMutableDictionary()
            hibpErrorReasons = NSMutableArray()
        }
    }
    
    private func recordHibpError(reason: String) async {
        await MainActor.run {
            hibpErrorCount += 1
            hibpErrorReasons.add(reason)
        }
    }
    
    private func updateProgress(
        hibp: Double? = nil,
        similar: Double? = nil,
        callback: @escaping @Sendable (Double) -> Void
    ) async {
        await MainActor.run {
            if let hibp {
                hibpProgress = CGFloat(hibp)
            }

            if let similar {
                similarProgress = CGFloat(similar)
            }

            callback(Double(calculatedProgress))
        }
    }

    private func performLocalChecks(nodes: [Node]) async throws {
        if config.checkForNoPasswords {
            try Task.checkCancellation()
                    
            let results = database.allActiveEntries
                .filter { $0.fields.password.isEmpty && !(isExcluded?($0) ?? false) }
                .map(\.uuid)

            await MainActor.run {
                noPasswords = makeUUIDSet(from: results)
            }
        } else {
            await MainActor.run {
                noPasswords = []
            }
        }

        if config.checkForDuplicatedPasswords {
            try Task.checkCancellation()
            let duplicates = duplicatedPasswords(nodes: nodes)
            let nodeSet = Set(duplicates.values.flatMap { $0 })

            await MainActor.run {
                duplicatedPasswords = duplicates
                duplicatedPasswordsNodeSet = makeUUIDSet(from: nodeSet)
            }
        } else {
            await MainActor.run {
                duplicatedPasswords = [:]
                duplicatedPasswordsNodeSet = []
            }
        }

        if config.checkForCommonPasswords {
            try Task.checkCancellation()
            let common = nodes
                .filter { !shouldSkipNumericPIN($0.fields.password) }
                .filter { PasswordMaker.sharedInstance().isCommonPassword($0.fields.password) }
                .map(\.uuid)

            await MainActor.run {
                commonPasswords = makeUUIDSet(from: common)
            }
        } else {
            await MainActor.run {
                commonPasswords = []
            }
        }

        if config.checkForLowEntropy {
            try Task.checkCancellation()
            let strengthConfig = strengthConfig ?? PasswordStrengthConfig.defaults()
            let lowEntropyNodes = nodes.filter { node in
                if shouldSkipNumericPIN(node.fields.password) {
                    return false
                }

                let strength = PasswordStrengthTester.getStrength(node.fields.password, config: strengthConfig)
                return strength.entropy < Double(config.lowEntropyThreshold)
            }.map(\.uuid)

            await MainActor.run {
                lowEntropy = makeUUIDSet(from: lowEntropyNodes)
            }
        } else {
            await MainActor.run {
                lowEntropy = []
            }
        }

        if config.checkForMinimumLength {
            try Task.checkCancellation()
            let tooShortSet = nodes
                .filter { node in
                    let password = node.fields.password
                    guard password.count < config.minimumLength else { return false }
                    return !shouldSkipNumericPIN(password)
                }
                .map(\.uuid)

            await MainActor.run {
                tooShort = makeUUIDSet(from: tooShortSet)
            }
        } else {
            await MainActor.run {
                tooShort = []
            }
        }
    }

    private func duplicatedPasswords(nodes: [Node]) -> [String: Set<UUID>] {
        var possible = [String: Set<UUID>]()

        for entry in nodes {
            var password = entry.fields.password

            if shouldSkipNumericPIN(password) {
                continue
            }

            if config.caseInsensitiveMatchForDuplicates {
                password = password.lowercased()
            }

            possible[password, default: Set<UUID>()].insert(entry.uuid)
        }

        return possible.filter { $0.value.count > 1 }
    }

    private func performHIBPChecks(
        nodes: [Node],
        nodesChanged: @escaping @Sendable () -> Void,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let runPasswordChecks = config.checkHibp
        let runAccountBreaches = config.checkHibpBreaches

        guard runPasswordChecks || runAccountBreaches else {
            await updateProgress(hibp: 1.0, callback: progress)
            return
        }

        try Task.checkCancellation()

        let filteredNodes = nodes.filter { !shouldSkipNumericPIN($0.fields.password) }
        let passwordGroups = runPasswordChecks ? Dictionary(grouping: filteredNodes) { $0.fields.password } : [:]
        let nodesByEmail: [String: [Node]]
        if runAccountBreaches {
            let nodesWithValidUsername = filteredNodes.filter {
                !$0.fields.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            nodesByEmail = Dictionary(grouping: nodesWithValidUsername) { $0.fields.username }
        } else {
            nodesByEmail = [:]
        }
        let total = passwordGroups.count + nodesByEmail.count

        await MainActor.run {
            hibpTotalCount = UInt(total)
            hibpCompletedCount = 0
            hibpErrorCount = 0
            hibpProgress = 0
        }

        guard total > 0 else {
            await updateProgress(hibp: 1.0, callback: progress)
            return
        }

        var completed = 0

        let updateProgressBlock: @Sendable () async -> Void = { [weak self] in
            guard let self else { return }
            let hibpProgressValue = Double(completed) / Double(max(total, 1))
            await MainActor.run {
                self.hibpCompletedCount = UInt(completed)
                self.hibpProgress = CGFloat(hibpProgressValue)
                progress(Double(self.calculatedProgress))
            }
        }

        if runPasswordChecks {
            let (pwnedHits, updatedCache) = try await performPwnedPasswordChecks(
                passwordGroups: passwordGroups,
                progressUpdate: {
                    completed += 1
                    await updateProgressBlock()
                }
            )

            persistPwnedSet(updatedCache)

            if !pwnedHits.isEmpty {
                await MainActor.run {
                    mutablePwnedNodes.addObjects(from: pwnedHits.map { $0 as NSUUID })
                    nodesChanged()
                }
            }
        }

        if runAccountBreaches {
            let shouldRefresh = shouldRefreshBreaches()
            let cacheActor = HibpCache(existing: loadCachedBreaches())
            let (breachedNodes, matchedDomains) = try await performAccountBreaches(
                nodesByEmail: nodesByEmail,
                forceRefresh: shouldRefresh,
                cacheActor: cacheActor,
                progressUpdate: {
                    completed += 1
                    await updateProgressBlock()
                },
                nodesChanged: nodesChanged
            )

            let cacheSnapshot = await cacheActor.snapshot()
            persistBreaches(cacheSnapshot)

            await MainActor.run {
                matchedBreachedDomainsByNode = NSMutableDictionary()
            }

            if !breachedNodes.isEmpty {
                await MainActor.run {
                    mutableBreachedAccountNodes.addObjects(from: breachedNodes.map { $0 as NSUUID })
                    matchedDomains.forEach { key, value in
                        matchedBreachedDomainsByNode[key as NSUUID] = value
                    }
                    nodesChanged()
                }
            }
        }

        await updateProgress(hibp: 1.0, callback: progress)
    }

    private func fetchHIBPResult(
        email: String,
        nodes: [Node],
        forceRefresh: Bool,
        cache: HibpCache
    ) async throws -> HibpResult {
        if !forceRefresh, let cached = await cache.cachedBreaches(for: email) {
            return HibpResult(email: email, nodes: nodes, breaches: cached, hadError: false, error: nil)
        }

        do {
            let breaches = try await requestBreaches(for: email)
            await cache.updateBreaches(breaches, for: email)
            return HibpResult(email: email, nodes: nodes, breaches: breaches, hadError: false, error: nil)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return HibpResult(email: email, nodes: nodes, breaches: [], hadError: true, error: HibpError.hibpErrorDescription(error))
        }
    }

    private func requestBreaches(for email: String) async throws -> [String] {
        guard let url = buildHibpAccountUrl() else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = AuditConstants.hibpRequestTimeout
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var payload: [String: Any] = [
            "account": email,
            "device_token": deviceCheckToken,
            "bundle_id": Bundle.main.bundleIdentifier ?? ""
        ]

        #if DEBUG
        payload["dev"] = true
        #else
        payload["dev"] = false
        #endif

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HibpError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let breaches = try JSONDecoder().decode([HibpAccountResponse].self, from: data)
            return breaches.compactMap { $0.domain }
        case 404:
            return []
        default:
            throw HibpError.http(httpResponse.statusCode)
        }
    }

    private func mapBreaches(result: HibpResult) -> (matchedNodes: Set<UUID>, matchedDomains: [UUID: [String]]) {
        var matchedNodes = Set<UUID>()
        var matchedDomains = [UUID: [String]]()

        for node in result.nodes {
            let domain = BrowserAutoFillManager.extractPSLDomainFromUrl(url: node.fields.url)
            guard !domain.isEmpty else { continue }

            let matches = result.breaches.filter { looseDomainMatch(domain, with: $0) }
            if !matches.isEmpty {
                matchedNodes.insert(node.uuid)
                matchedDomains[node.uuid] = matches
            }
        }

        return (matchedNodes, matchedDomains)
    }

    private func shouldRefreshBreaches() -> Bool {
        guard config.checkHibpBreaches else { return false }

        if let lastChecked = config.lastHibpOnlineCheck,
           config.hibpCheckForNewBreachesIntervalSeconds > 0 {
            let dueDate = Calendar.current.date(
                byAdding: .second,
                value: Int(config.hibpCheckForNewBreachesIntervalSeconds),
                to: lastChecked
            ) ?? .distantPast

            if dueDate.timeIntervalSinceNow > 0 {
                return false
            }
        }

        config.lastHibpOnlineCheck = Date()
        saveConfig?(config)
        return true
    }

    private func loadCachedBreaches() -> [String: [String]] {
        guard let cached = SecretStore.sharedInstance().getSecureObject(AuditConstants.breachedAccountsCacheKey) as? [String: Any] else {
            return [:]
        }

        var results: [String: [String]] = [:]
        for (email, value) in cached {
            if let breachInfo = value as? [String: Any],
               let breaches = breachInfo["allBreaches"] as? [String] {
                results[email] = breaches
            }
        }

        return results
    }

    private func persistBreaches(_ cache: [String: [String]]) {
        let dict = cache.mapValues { ["allBreaches": $0] }
        SecretStore.sharedInstance().setSecureObject(dict, forIdentifier: AuditConstants.breachedAccountsCacheKey)
    }

    private func loadCachedPwnedSet() -> Set<String> {
        if let set = SecretStore.sharedInstance().getSecureObject(AuditConstants.pwnedCacheKey) as? Set<String> {
            return set
        }

        if let nsset = SecretStore.sharedInstance().getSecureObject(AuditConstants.pwnedCacheKey) as? NSSet,
           let strings = nsset.allObjects as? [String] {
            return Set(strings)
        }

        return []
    }

    private func persistPwnedSet(_ cache: Set<String>) {
        SecretStore.sharedInstance().setSecureObject(cache, forIdentifier: AuditConstants.pwnedCacheKey)
    }

    private func performPwnedPasswordChecks(
        passwordGroups: [String: [Node]],
        progressUpdate: @escaping @Sendable () async -> Void
    ) async throws -> (Set<UUID>, Set<String>) {
        let cached = loadCachedPwnedSet()
        var updatedCache = cached
        var hits = Set<UUID>()

        let items = passwordGroups.map { entry in
            PwnedPasswordItem(password: entry.key, sha1: sha1Hex(entry.key), nodes: entry.value)
        }

        let cachedItems = items.filter { cached.contains($0.sha1) }
        let networkItems = items.filter { !cached.contains($0.sha1) }

        for item in cachedItems {
            hits.formUnion(item.nodes.map(\.uuid))
            await progressUpdate()
        }

        var iterator = networkItems.makeIterator()

        try await withThrowingTaskGroup(of: (PwnedPasswordItem, Bool)?.self) { group in
            for _ in 0..<min(AuditConstants.hibpMaxConcurrentRequests, networkItems.count) {
                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try Task.checkCancellation()
                        let pwned: Bool
                        do {
                            pwned = try await self.isPasswordPwned(item: next)
                        } catch {
                            await self.recordHibpError(reason: "Password prefix \(next.sha1.prefix(5)) check failed: \(HibpError.hibpErrorDescription(error))")
                            return (next, false)
                        }
                        return (next, pwned)
                    }
                }
            }

            while let result = try await group.next() {
                try Task.checkCancellation()

                if let (item, pwned) = result {
                    if pwned {
                        hits.formUnion(item.nodes.map(\.uuid))
                        updatedCache.insert(item.sha1)
                    }
                    await progressUpdate()
                }

                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try Task.checkCancellation()
                        let pwned: Bool
                        do {
                            pwned = try await self.isPasswordPwned(item: next)
                        } catch {
                            await self.recordHibpError(reason: "Password prefix \(next.sha1.prefix(5)) check failed: \(HibpError.hibpErrorDescription(error))")
                            return (next, false)
                        }
                        return (next, pwned)
                    }
                }
            }
        }

        return (hits, updatedCache)
    }

    private func isPasswordPwned(item: PwnedPasswordItem) async throws -> Bool {
        let prefix = String(item.sha1.prefix(5))
        let suffix = String(item.sha1.dropFirst(5))

        guard let url = buildPwnedPasswordUrl(prefix: prefix) else { return false }
        
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: AuditConstants.hibpRequestTimeout
        )
        request.httpMethod = "GET"
        request.setValue("true", forHTTPHeaderField: "Add-Padding")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HibpError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw HibpError.http(httpResponse.statusCode)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            return false
        }

        for line in body.split(separator: "\n") {
            let components = line.split(separator: ":")
            if components.count == 2 {
                let foundSuffix = components[0]
                let count = components[1]

                if foundSuffix.caseInsensitiveCompare(suffix) == .orderedSame && count != "0" {
                    return true
                }
            }
        }

        return false
    }

    private func performAccountBreaches(
        nodesByEmail: [String: [Node]],
        forceRefresh: Bool,
        cacheActor: HibpCache,
        progressUpdate: @escaping @Sendable () async -> Void,
        nodesChanged: @escaping @Sendable () -> Void
    ) async throws -> (Set<UUID>, [UUID: [String]]) {
        var iterator = nodesByEmail.makeIterator()
        var matchedDomains: [UUID: [String]] = [:]
        var breachedNodes = Set<UUID>()

        try await withThrowingTaskGroup(of: HibpResult?.self) { group in
            for _ in 0..<min(AuditConstants.hibpMaxConcurrentRequests, nodesByEmail.count) {
                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try Task.checkCancellation()
                        return try await self.fetchHIBPResult(
                            email: next.key,
                            nodes: next.value,
                            forceRefresh: forceRefresh,
                            cache: cacheActor
                        )
                    }
                }
            }

            var processed = 0

            while let result = try await group.next() {
                try Task.checkCancellation()
                processed += 1
                await progressUpdate()

                if let result {
                    if result.hadError {
                        let reason = result.error ?? "Unknown error"
                        await recordHibpError(reason: "Account check for \(result.email) failed: \(reason)")
                    } else if !result.breaches.isEmpty {
                        let domainMatches = mapBreaches(result: result)
                        breachedNodes.formUnion(domainMatches.matchedNodes)
                        domainMatches.matchedDomains.forEach { matchedDomains[$0.key] = $0.value }
                    }
                }

                if processed % 10 == 0 {
                    await MainActor.run {
                        nodesChanged()
                    }
                }

                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try Task.checkCancellation()
                        return try await self.fetchHIBPResult(
                            email: next.key,
                            nodes: next.value,
                            forceRefresh: forceRefresh,
                            cache: cacheActor
                        )
                    }
                }
            }
        }

        return (breachedNodes, matchedDomains)
    }

    private func performSimilarityCheck(
        nodes: [Node],
        nodesChanged: @escaping @Sendable () -> Void,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard nodes.count > 1 else {
            await MainActor.run {
                similar = [:]
                similarPasswordsNodeSet = []
            }
            return
        }

        var groups: [UUID: Set<UUID>] = [:]
        let totalComparisons = nodes.count * (nodes.count - 1) / 2
        var comparisonCount = 0

        for (index, entry) in nodes.enumerated() {
            let password = entry.fields.password
            if shouldSkipNumericPIN(password) {
                continue
            }

            for other in nodes[(index + 1)...] {
                if comparisonCount % AuditConstants.comparisonsPerYield == 0 {
                    try Task.checkCancellation()
                    let similarityProgress = Double(comparisonCount) / Double(max(totalComparisons, 1))
                    await updateProgress(similar: similarityProgress, callback: progress)
                    await Task.yield()
                }
                comparisonCount += 1

                let otherPassword = other.fields.password
                guard password != otherPassword else { continue }

                let similarity = password.levenshteinSimilarityRatio(otherPassword)
                guard similarity >= config.levenshteinSimilarityThreshold else { continue }

                if let existingKey = groups.first(where: { $0.value.contains(entry.uuid) || $0.value.contains(other.uuid) })?.key {
                    var group = groups[existingKey] ?? Set<UUID>()
                    group.insert(entry.uuid)
                    group.insert(other.uuid)
                    groups[existingKey] = group
                } else {
                    groups[entry.uuid] = Set([entry.uuid, other.uuid])
                }
            }
        }

        let similarSets = groups.mapValues { makeUUIDSet(from: $0) }
        let similarNodeSet = makeUUIDSet(from: groups.values.flatMap { $0 })

        await MainActor.run {
            similar = similarSets
            similarPasswordsNodeSet = similarNodeSet
            similarProgress = 1.0
            if !groups.isEmpty {
                nodesChanged()
            }
            progress(Double(calculatedProgress))
        }
    }

    private func performTwoFactorCheck(nodes: [Node]) async {
        let results = nodes.compactMap { node -> UUID? in
            guard node.fields.otpToken == nil else { return nil }
            let domain = BrowserAutoFillManager.extractPSLDomainFromUrl(url: node.fields.url)
            guard !domain.isEmpty, Self.twoFactorDomains.contains(domain) else { return nil }
            return node.uuid
        }

        await MainActor.run {
            twoFactorAvailable = makeUUIDSet(from: results)
        }
    }

    private func shouldSkipNumericPIN(_ password: String) -> Bool {
        config.excludeShortNumericPINCodes && isShortNumericPINCode(password)
    }

    private func isShortNumericPINCode(_ password: String) -> Bool {
        password.count <= 8 && password.allSatisfy(\.isNumber)
    }

    private func sha1Hex(_ password: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined().uppercased()
    }

    private func normalizeDomain(_ domain: String) -> String {
        var lowercased = domain.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://"),
           let url = URL(string: lowercased),
           let host = url.host {
            lowercased = host
        }

        if lowercased.hasPrefix("www.") {
            lowercased.removeFirst(4)
        }

        return lowercased
    }

    private func looseDomainMatch(_ domain: String?, with other: String) -> Bool {
        guard let domain else { return false }
        return normalizeDomain(domain) == normalizeDomain(other)
    }

    private func makeUUIDSet(from uuids: some Sequence<UUID>) -> Set<UUID> {
        Set(uuids)
    }

    private func buildPwnedPasswordUrl(prefix: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.pwnedpasswords.com"
        components.path = "/range/\(prefix)"
        return components.url
    }

    private func buildHibpAccountUrl() -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "faas-nyc1-2ef2e6cc.doserverless.co"
        components.path = "/api/v1/web/fn-8a419571-d5b5-47d2-852f-a153c3e81553/strongbox-mirror-one/pwned"
        
        return components.url
    }

    private static let twoFactorDomains: Set<String> = {
        guard let url = Bundle.main.url(forResource: "twofactorauth", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let domains = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }

        return Set(domains)
    }()
}
