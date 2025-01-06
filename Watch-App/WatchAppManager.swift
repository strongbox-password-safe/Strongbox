//
//  WatchAppManager.swift
//  Strongbox
//
//  Created by Strongbox on 07/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import WatchConnectivity

@objc
class WatchStatus: NSObject {
    @objc var isPaired: Bool
    @objc var isSupportedOnThisDevice: Bool
    @objc var isInstalled: Bool
    @objc var isReachable: Bool
    @objc var lastError: Error?
    @objc var lastSuccessfulComms: Date?
    @objc var activationState: WCSessionActivationState
    @objc var outstandingUpdateCount: Int

    init(isPaired: Bool,
         isSupportedOnThisDevice: Bool,
         isInstalled: Bool,
         isReachable: Bool,
         lastError: Error? = nil,
         lastSuccessfulComms: Date? = nil,
         activationState: WCSessionActivationState,
         outstandingUpdateCount: Int)
    {
        self.isPaired = isPaired
        self.isSupportedOnThisDevice = isSupportedOnThisDevice
        self.isInstalled = isInstalled
        self.isReachable = isReachable
        self.lastError = lastError
        self.lastSuccessfulComms = lastSuccessfulComms
        self.activationState = activationState
        self.outstandingUpdateCount = outstandingUpdateCount
    }
}

@objc
class WatchAppManager: NSObject, WCSessionDelegate {
    static let MaxBatchSize = 62 * 1024 
    static let MaxEntriesPerDatabase = 100 

    enum WatchAppManagerError: Error {
        case couldNotEncodeEntry
        case couldNotBatchEntries
    }

    @objc
    static let shared = WatchAppManager()

    @objc
    var status: WatchStatus {
        WatchStatus(isPaired: wcSession.isPaired,
                    isSupportedOnThisDevice: WCSession.isSupported(),
                    isInstalled: wcSession.isWatchAppInstalled,
                    isReachable: wcSession.isReachable,
                    lastError: lastError,
                    lastSuccessfulComms: lastSuccessfulComms,
                    activationState: wcSession.activationState,
                    outstandingUpdateCount: outstandingUpdateCount)
    }

    var wcSession: WCSession! = nil
    var lastError: Error? = nil
    var lastSuccessfulComms: Date?

    let taskSerializer = SerialTasks<Bool>()

    override init() {
        super.init()

        wcSession = WCSession.default
        wcSession.delegate = self
    }

    

    private var activateContinuation: CheckedContinuation<WCSessionActivationState, Error>?

    @objc
    var watchIsPairedAndInstalled: Bool {
        wcSession.isPaired && wcSession.isWatchAppInstalled
    }

    @objc func quickActivate() {
        Task {
            let _ = try await activateWatchSession()
        }
    }

    @objc func activate() async throws -> Bool {
        try await activateWatchSession()
    }

    private func activateWatchSession() async throws -> Bool {
        swlog("🐞 activateWatchSession")

        guard AppPreferences.sharedInstance().appleWatchIntegration, WCSession.isSupported() else {
            swlog("🔴 Watch Session is not supported on this device.")
            return false
        }

        guard wcSession.activationState != .activated else {
            swlog("🐞 Watch Session already activated, no need to do it again.")
            return true
        }

        do {
            let astate = try await withCheckedThrowingContinuation { con in
                activateContinuation = con
                wcSession.activate()
            }

            guard astate == .activated else {
                swlog("🔴 Could not activate Watch Session...")
                return false
            }

            swlog("🟢 Watch Session activated. isPaired = \(wcSession.isPaired) && isWatchAppInstalled = \(wcSession.isWatchAppInstalled). Clearing outstanding updates...")

            cancelOutstandingUpdates(databaseId: nil)

            return wcSession.isPaired && wcSession.isWatchAppInstalled
        } catch {
            lastError = error
            throw error
        }
    }

    private var outstandingUpdateCount: Int {
        guard wcSession.activationState == .activated else {
            swlog("🔴 Cannot get outstandingUpdateCount, session is not activated.")
            return 0
        }

        return wcSession.outstandingFileTransfers.count
    }

    private func cancelOutstandingUpdates(databaseId: String?) {
        guard wcSession.activationState == .activated else {
            swlog("🔴 Cannot cancelOutstandingUpdates, session is not activated.")
            return
        }

        let outstanding = wcSession.outstandingUserInfoTransfers

        for foo in outstanding {
            if let databaseId {
                if let thisDbId = foo.userInfo[WatchAppMessage.databaseId] as? String, thisDbId == databaseId {
                    swlog("🐞 Cancelling DB Specific Outstanding Update...")
                    foo.cancel()
                }
            } else {
                swlog("🐞 Cancelling Outstanding Update...")
                foo.cancel()
            }
        }
    }

    

    @objc
    func clearAllEntriesForDatabase(databaseUuid: String) async throws -> Bool {
        try await taskSerializer.add { [weak self] in
            guard let self else { return false }

            return await clearAllEntriesForDatabaseInternal(databaseUuid: databaseUuid)
        }
    }

    @objc
    func expressUpdateEntries(model: Model) {
        Task {
            try await updateEntries(model: model)
        }
    }

    @objc
    func updateEntries(model: Model) async throws -> Bool {
        try await taskSerializer.add { [weak self] in
            guard let self else { return false }

            return try await updateEntriesInternal(model: model)
        }
    }

    @objc
    func syncDatabasesAndSettings() async throws -> Bool {
        try await taskSerializer.add { [weak self] in
            guard let self else { return false }

            return await syncDatabasesAndSettingsInternal()
        }
    }

    

    private func syncDatabasesAndSettingsInternal() async -> Bool {
        guard AppPreferences.sharedInstance().appleWatchIntegration, wcSession.activationState == .activated else {
            swlog("🔴 Cannot syncDatabasesAndSettings, session is not activated, or integration disabled")
            return false
        }

        do {
            try await sendEntrySetToWatch("🐞 Set-Settings-Empty-Dummy-Database 🐞", entries: []) 

            swlog("🟢 Databases/settings successfully sent to watch...")
            lastSuccessfulComms = Date.now
        } catch {
            swlog("🔴 Error sending entry set to watch: \(error)")
            lastError = error
            return false
        }

        return true
    }

    private func clearAllEntriesForDatabaseInternal(databaseUuid: String) async -> Bool {
        swlog("🚀 clearAllEntriesForDatabase")

        guard AppPreferences.sharedInstance().appleWatchIntegration, wcSession.activationState == .activated else {
            swlog("🔴 Cannot clear watch entries, session is not activated or integration disabled")
            return false
        }

        do {
            try await sendRemoveAllEntriesForDatabase(databaseUuid, isStartOfBatchUpdate: false)
            swlog("🟢 clearAllEntriesForDatabase sent to watch...")
            lastSuccessfulComms = Date.now
        } catch {
            swlog("🔴 Error clearAllEntriesForDatabase on Apple Watch: \(error)")
            lastError = error
            return false
        }

        return true
    }

    private func updateEntriesInternal(model: Model) async throws -> Bool {
        swlog("🚀 updateEntriesForDatabase")

        guard AppPreferences.sharedInstance().appleWatchIntegration,
              wcSession.activationState == .activated,
              model.metadata.appleWatchEnabled
        else {
            swlog("🔴 Cannot updateEntriesForDatabase, session is not activated or integration disabled at global or db level")
            return false
        }

        let sorted = model.appleWatchEntries.sorted(by: Node.sortTitleLikeFinder) 

        let mapped = sorted.compactMap { entry in
            convertToWatchEntry(model, entry)
        }

        let limited = Array(mapped.prefix(Self.MaxEntriesPerDatabase)) 

        do {
            cancelOutstandingUpdates(databaseId: model.databaseUuid) 

            try await sendRemoveAllEntriesForDatabase(model.databaseUuid, isStartOfBatchUpdate: true)

            try await sendEntrySetToWatch(model.databaseUuid, entries: limited)

            swlog("🟢 updateEntriesForDatabase sent to watch...")
            lastSuccessfulComms = Date.now
        } catch {
            swlog("🔴 Error sending entry set to watch: \(error)")
            lastError = error
            throw error
        }

        return true
    }

    

    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        swlog("⌚︎ activationDidCompleteWith \(activationState) and \(error?.localizedDescription ?? "")")

        if let error {
            activateContinuation?.resume(throwing: error)
        } else {
            activateContinuation?.resume(returning: activationState)
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {
        swlog("⌚︎ sessionDidBecomeInactive")
    }

    func sessionDidDeactivate(_: WCSession) {
        swlog("⌚︎ sessionDidDeactivate")
    }

    func session(_: WCSession, didFinish _: WCSessionUserInfoTransfer, error: (any Error)?) {
        swlog("🐞 WC: didFinishUserInfoTransfer: \(String(describing: error))")
    }

    

    private func sendEntrySetToWatch(_ databaseUuid: String, entries: [WatchEntry]) async throws {
        swlog("🐞 sendEntrySetToWatch...")

        let batched: [[WatchEntry]] = try batchEntries(databaseUuid, entries)

        for (index, batch) in batched.enumerated() {
            swlog("🐞 Sending Batch No. \(index + 1)/\(batched.count) of \(batch.count) entries (out of \(entries.count) total)...")

            do {
                try await sendAppendBatchOfEntriesDataToWatch(databaseUuid, batch: batch)
            } catch {
                swlog("🔴 ERROR - sendAppendBatchOfEntriesDataToWatch \(error)")
                lastError = error
                throw error
            }
        }
    }

    private func sendAppendBatchOfEntriesDataToWatch(_ databaseUuid: String, batch: [WatchEntry]) async throws { 
        let encoded = try encodeEntries(databaseUuid, batch)
        let watchDatabases = getWatchDatabases()
        let watchSettings = getSettings()

        let jsonEncoder = JSONEncoder()
        let watchDatabasesEncoded = try jsonEncoder.encode(watchDatabases)
        let watchSettingsEncoded = try jsonEncoder.encode(watchSettings)

        let message: [String: Any] = [
            WatchAppMessage.databaseId: databaseUuid,
            WatchAppMessage.settings: watchSettingsEncoded,
            WatchAppMessage.databases: watchDatabasesEncoded,
            WatchAppMessage.appendEntries: encoded,
        ]

        #if targetEnvironment(simulator)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                wcSession.sendMessage(message, replyHandler: { reply in
                    swlog("🟢 Message Sent to Watch!... \(reply)")
                    continuation.resume()
                }) { error in
                    swlog("🔴 wcSession.sendMessage - \(error)")
                    continuation.resume(throwing: error)
                }
            }
        #else

            wcSession.transferUserInfo(message)
            
        #endif
    }

    private func sendRemoveAllEntriesForDatabase(_ databaseUuid: String, isStartOfBatchUpdate: Bool) async throws {
        let jsonEncoder = JSONEncoder()

        let resetMessage = ResetMessage(databaseUuid: databaseUuid, isStartOfBatchUpdate: isStartOfBatchUpdate)
        let messageJson = try jsonEncoder.encode(resetMessage)
        let message = [WatchAppMessage.resetEntries: messageJson]

        #if targetEnvironment(simulator)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                wcSession.sendMessage(message, replyHandler: { reply in
                    swlog("🟢 Message Sent to Watch!... \(reply)")
                    continuation.resume()
                }) { error in
                    swlog("🔴 \(error)")
                    continuation.resume(throwing: error)
                }
            }
        #else

            wcSession.transferUserInfo(message)

        #endif
    }

    

    private func batchEntries(_ databaseUuid: String, _ entries: [WatchEntry]) throws -> [[WatchEntry]] {
        let initialChunks: [[WatchEntry]] = [[]]

        let batches = try entries.reduce(into: initialChunks) { partialResult, entry in
            let currentChunk = partialResult.last!

            var candidateChunk = currentChunk
            candidateChunk.append(entry)

            let data = try encodeEntries(databaseUuid, candidateChunk)

            if data.count < WatchAppManager.MaxBatchSize {
                partialResult.removeLast()
                partialResult.append(candidateChunk)
            } else {
                partialResult.append([entry]) 
            }
        }

        return batches
    }

    private func encodeEntries(_ databaseUuid: String, _ entries: [WatchEntry]) throws -> Data {
        let encoder = JSONEncoder()

        return try encoder.encode([databaseUuid: entries])
    }

    private func convertToWatchEntry(_ model: Model, _ entry: Node) -> WatchEntry? {
        let evm = EntryViewModel.fromNode(entry, model: model)

        

        let alternativeUrls = entry.fields.alternativeUrls.map { alt in
            model.dereference(alt, node: entry)
        }

        

        let customFields = evm.customFieldsFilteredAndExcludeAlternativeUrls.map { customField in
            [customField.key: WatchCustomField(key: customField.key, value: customField.value, concealable: customField.protected)]
        }

        

        let twoFactor = entry.fields.otpToken?.url(true).absoluteString

        var icon: WatchEntryIcon = .Default
        if let entryIcon = entry.icon {
            if entryIcon.isCustom {
                icon = .custom(iconDataB64: entryIcon.custom.base64EncodedString())
            } else {
                icon = .preset(icon: entryIcon.preset)
            }
        }

        let entry = WatchEntry(id: entry.uuid,
                               title: model.dereference(evm.title, node: entry),
                               icon: icon,
                               username: model.dereference(evm.username, node: entry),
                               password: model.dereference(evm.password, node: entry),
                               email: model.dereference(evm.email, node: entry),
                               url: model.dereference(evm.url, node: entry),
                               alternativeUrls: alternativeUrls,
                               twoFaOtpAuthUrl: twoFactor,
                               customFields: customFields,
                               notes: model.dereference(evm.notes, node: entry))

        return stripEntryIfTooLarge(entry)
    }

    func stripEntryIfTooLarge(_ entry: WatchEntry) -> WatchEntry? {
        guard let data = try? encodeEntries(UUID().uuidString, [entry]) else {
            return nil
        }

        if data.count < Self.MaxBatchSize {
            return entry
        }

        swlog("🐞 stripEntryIfTooLarge [\(entry.title)] - encoded size = \(data.count)...")

        var trimmed = entry

        if case .custom = entry.icon {
            swlog("🐞 Entry [\(entry.title)] too large, trimming Custom Icon...")
            trimmed.icon = .preset(icon: 0)
            return stripEntryIfTooLarge(trimmed)
        } else if !entry.alternativeUrls.isEmpty {
            swlog("🐞 Entry [\(entry.title)] too large, trimming Alternative URLs...")
            trimmed.alternativeUrls = []
            return stripEntryIfTooLarge(trimmed)
        } else if !entry.customFields.isEmpty {
            swlog("🐞 Entry [\(entry.title)] too large, trimming Custom Fields...")
            trimmed.customFields = []
            return stripEntryIfTooLarge(trimmed)
        } else if !entry.notes.isEmpty {
            swlog("🐞 Entry [\(entry.title)] too large, trimming Notes...")
            trimmed.notes = ""
            return stripEntryIfTooLarge(trimmed)
        } else if trimmed.twoFaOtpAuthUrl != nil {
            swlog("🐞 Entry [\(entry.title)] too large, trimming 2FA...")
            trimmed.twoFaOtpAuthUrl = nil
            return stripEntryIfTooLarge(trimmed)
        } else {
            swlog("⚠️ Entry [\(entry.title)] is too large to encode, will skip...")
            return nil 
        }
    }

    private func getWatchDatabases() -> [WatchDatabaseModel] {
        guard AppPreferences.sharedInstance().appleWatchIntegration else {
            return []
        }

        return DatabasePreferences.allDatabases
            .filter { database in
                database.appleWatchEnabled
            }
            .map { db in
                WatchDatabaseModel(nickName: db.nickName, uuid: db.uuid, iconSet: db.keePassIconSet.rawValue)
            }
    }

    private func getSettings() -> WatchSettingsModel {
        var ret = WatchSettingsModel()

        ret.pro = AppPreferences.sharedInstance().isPro
        ret.markdownNotes = AppPreferences.sharedInstance().markdownNotes
        ret.twoFactorEasyReadSeparator = AppPreferences.sharedInstance().twoFactorEasyReadSeparator
        ret.colorBlind = AppPreferences.sharedInstance().colorizeUseColorBlindPalette
        ret.twoFactorHideCountdownDigits = AppPreferences.sharedInstance().twoFactorHideCountdownDigits

        return ret
    }
}
