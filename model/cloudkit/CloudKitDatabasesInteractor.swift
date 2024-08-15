//
//  CloudKitDatabasesInteractor.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import UserNotifications

actor SerialTasks<Success> {
    private var previousTask: Task<Success, Error>?

    func add(block: @Sendable @escaping () async throws -> Success) async throws -> Success {
        let task = Task { [previousTask] in
            let _ = await previousTask?.result
            return try await block()
        }
        previousTask = task
        return try await task.value
    }
}

extension Notification.Name {
    static let cloudKitDatabaseUpdateAvailable = Notification.Name("cloudKitDatabaseUpdateAvailable")
}

@objc public extension NSNotification {
    static let cloudKitDatabaseUpdateAvailable = Notification.Name.cloudKitDatabaseUpdateAvailable
}

@objc
class CloudKitDatabasesInteractor: NSObject {
    enum CloudKitDatabasesInteractorError: Error {
        case cloudKitDatabaseNotFound
        case couldNotGenerateMacOSURL
        case couldNotParseCloudKitId
        case invalidParameter
    }

    @objc
    var isInitialized = false
    var subscribedToDatabaseChanges = false
    var hasCheckedAccountStatus = false
    @objc var cachedAccountStatus: CKAccountStatus = .couldNotDetermine
    @objc var cachedAccountStatusError: Error? = nil
    var registeredForNotifications: Bool = false
    var registeredForNotificationError: Error? = nil

    @objc
    var fastIsAvailable: Bool {
        if hasCheckedAccountStatus {
            return cachedAccountStatus == .available
        } else {
            return true 
        }
    }

    let taskSerializer = SerialTasks<Void>()

    @objc static let shared = CloudKitDatabasesInteractor()

    override private init() {}

    private func doRegularCloudKitRefreshOfZonesAndSubs() async throws {
        let lastCloudKitRefresh = CrossPlatformDependencies.defaults().applicationPreferences.lastCloudKitRefresh
        if (lastCloudKitRefresh as NSDate?)?.isMoreThanXDaysAgo(7) ?? true {
            CrossPlatformDependencies.defaults().applicationPreferences.lastCloudKitRefresh = Date.now
            CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated = false
            CrossPlatformDependencies.defaults().applicationPreferences.changeNotificationsSubscriptionCreated = false

            try await CloudKitManager.shared.createZoneIfNeeded()
        }
    }

    @objc
    func initialize() async throws {
        swlog("CloudKitDatabasesInteractor::initialize...")

        isInitialized = false

        observeAppActivate()

        observeCloudKitAccountChanges()

        guard await isCloudKitAccountAvailable() else {
            
            
            return
        }

        try await CloudKitManager.shared.initialize()

        isInitialized = true

        swlog("CloudKitDatabasesInteractor::initialized... Refreshing databases and subscription...")

        

        try await refreshAndMerge()

        try await subscribeForChangeNotifications()

        await registerForRemoteNotifications()
    }

    func observeAppActivate() {
        #if os(macOS)
            let notification = NSApplication.didBecomeActiveNotification
        #else
            let notification = UIApplication.didBecomeActiveNotification
        #endif

        NotificationCenter.default.removeObserver(self, name: notification, object: nil)

        NotificationCenter.default.addObserver(forName: notification, object: nil, queue: nil) { _ in
            Task { [weak self] in
                try await self?.refreshAndMerge()
            }
        }
    }

    var gotRecentAccountChangeNotification = false

    func observeCloudKitAccountChanges() {
        NotificationCenter.default.removeObserver(self, name: .CKAccountChanged, object: nil)

        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            swlog("🐞 Got CloudKit Account Change Notification...")

            guard !gotRecentAccountChangeNotification else {
                return
            }
            gotRecentAccountChangeNotification = true

            Task { [weak self] in
                try await self?.onCloudKitAccountChanged()
            }
        }
    }

    func onCloudKitAccountChanged() async throws {
        swlog("🐞 onCloudKitAccountChanged...")

        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

        gotRecentAccountChangeNotification = false

        CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated = false 
        CrossPlatformDependencies.defaults().applicationPreferences.changeNotificationsSubscriptionCreated = false 

        try await initialize()
    }

    func isCloudKitAccountAvailable() async -> Bool {
        do {
            return try await getCloudKitAccountStatus() == .available
        } catch {
            swlog("🔴 isCloudKitAccountAvailable \(error)")
            return false
        }
    }

    @objc
    func getCloudKitAccountStatus() async throws -> CKAccountStatus {
        defer {
            hasCheckedAccountStatus = true
        }

        do {
            let start = CFAbsoluteTimeGetCurrent()

            let ret = try await CloudKitManager.shared.getCloudKitStatus()

            let diff = CFAbsoluteTimeGetCurrent() - start

            cachedAccountStatus = ret
            cachedAccountStatusError = nil

            swlog("⏲ got CloudKit status = [\(ret)] in \(diff) seconds")

            return ret
        } catch {
            swlog("🔴 getCloudKitAccountStatus \(error)")

            cachedAccountStatus = .couldNotDetermine
            cachedAccountStatusError = error

            throw error
        }
    }

    @objc
    static func getAccountStatusString(status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return NSLocalizedString("generic_noun_state_available", comment: "Available")
        case .couldNotDetermine:
            return NSLocalizedString("cloudkit_status_could_not_determine", comment: "Could Not Determine")
        case .restricted:
            return NSLocalizedString("cloudkit_status_restricted", comment: "Restricted due to Parental Controls / Device Management.")
        case .noAccount:
            return NSLocalizedString("cloudkit_status_unavailable", comment: "Unavailable. Check Apple account in System Settings.")
        case .temporarilyUnavailable:
            return NSLocalizedString("cloudkit_status_temporarily_unavailable", comment: "Temporarily Unavailable. Check Apple account in System Settings.")
        @unknown default:
            return NSLocalizedString("generic_unknown", comment: "Unknown")
        }
    }

    @MainActor
    func isRegisterForRemoteNotifications() -> Bool {
        #if os(macOS)
            NSApplication.shared.isRegisteredForRemoteNotifications
        #else
            UIApplication.shared.isRegisteredForRemoteNotifications
        #endif
    }

    @objc
    @MainActor
    func registerForRemoteNotifications() {
        guard !CrossPlatformDependencies.defaults().applicationPreferences.disableNetworkBasedFeatures else {
            return
        }

        guard !isRegisterForRemoteNotifications() else {
            registeredForNotifications = true
            registeredForNotificationError = nil

            return
        }

        swlog("🐞 CloudKitDatabasesInteractor::\(#function) Registering for CloudKit Updates...")

        #if os(macOS)
            NSApplication.shared.registerForRemoteNotifications()
        #else
            UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    @objc
    func onRegisteredForRemoteNotifications(_ success: Bool, error: Error?) {
        swlog("🐞 CloudKitDatabasesInteractor::onRegisteredForRemoteNotifications - \(success) - \(String(describing: error))")

        registeredForNotifications = success
        registeredForNotificationError = error
    }

    @objc
    @MainActor
    func requestUserNotificationPermissions() async throws -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        guard settings.authorizationStatus == .notDetermined else {
            return false
        }

        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

        swlog("🐞 requestAuthorizationWithOptions completion with granted = [%hhd]", granted)

        registerForRemoteNotifications()

        return granted
    }

    func subscribeForChangeNotifications() async throws { 
        subscribedToDatabaseChanges = false

        try await CloudKitManager.shared.subscribeToChangeNotifications()

        subscribedToDatabaseChanges = true
    }

    @objc
    func onCloudKitDatabaseChangeNotification() {
        swlog("🟢 didReceiveRemoteNotification / onChangeNotification")

        Task {
            try await refreshAndMerge() 
        }
    }

    

    func databaseIsUnlocked(databaseId: String) -> Bool {
        #if os(iOS)
            AppModel.shared.isUnlocked(databaseId)
        #else
            DatabasesCollection.shared.isUnlocked(uuid: databaseId)
        #endif
    }

    func databaseHasEditsOrIsBeingEdited(databaseId: String) -> Bool {
        #if os(iOS)
            AppModel.shared.isEditing(databaseId)
        #else
            var ret = false

            DispatchQueue.main.sync {
                ret = DatabasesCollection.shared.databaseHasEditsOrIsBeingEdited(uuid: databaseId)
            }

            return ret
        #endif
    }

    

    @objc
    func refreshAndMerge() async throws {
        try await taskSerializer.add { [weak self] in
            try await self?.refreshAndMergeInternal()
        }
    }

    func refreshAndMergeInternal() async throws {





        guard isInitialized else {
            swlog("🐞 refreshAndMerge - CloudKit is not initialized. NOP")
            return
        }

        do {
            try await doRegularCloudKitRefreshOfZonesAndSubs()

            let ckDbs = try await CloudKitManager.shared.getDatabases()

            try await mergeOrUpdateDatabases(ckDbs)

        } catch {
            swlog("🔴 Error caught in \(#function) - [\(error)]")
        }
    }

    func mergeOrUpdateDatabases(_ ckDbs: [CloudKitHostedDatabase]) async throws {
        removeNoneExistentDatabases(ckDbs)

        

        for db in ckDbs {
            try await mergeCloudKitDatabaseIn(db)
        }
    }

    func updateExisting(_ existing: METADATA_PTR, _ database: CloudKitHostedDatabase) {
        if existing.nickName != database.nickname {
            swlog("🟢 Updating CloudKit Database. Database nickname has changed.")

            
            
            
            

            #if os(iOS)
                var set = Set(DatabasePreferences.allDatabases)
            #else
                var set = Set(MacDatabasePreferences.allDatabases)
            #endif

            set.remove(existing)
            let usedNicknames = Set(set.map(\.nickName))
            let nameInUseByOtherDatabase = usedNicknames.contains(database.nickname)

            if !nameInUseByOtherDatabase {
                #if os(iOS)
                    let nick = DatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
                #else
                    let nick = MacDatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
                #endif
                existing.nickName = nick
            } else {
                swlog("🔴 Can't rename cloudkit database to desiredname as it is already used by another database")
            }
        }

        #if os(iOS)
            if existing.fileName != database.filename {
                swlog("🟢 Updating CloudKit Database. Database filename has changed.")
                existing.fileName = database.filename
            }
        #else
            if let newUrl = CloudKitStorageProvider.getCloudKitPKUrl(filename: database.filename, uuid: existing.uuid) {
                if newUrl != existing.fileUrl {
                    swlog("🟢 Updating CloudKit Database. Database filename has changed.")
                    existing.fileUrl = newUrl
                }
            }
        #endif

        let shared = database.sharedWithMe || database.associatedCkRecord.share != nil 
        let ownedByMe = !database.sharedWithMe

        if existing.isSharedInCloudKit != shared {
            swlog("🟢 Updating CloudKit Database. Shared has changed.")
            existing.isSharedInCloudKit = shared
        }

        if existing.isOwnedByMeCloudKit != ownedByMe {
            swlog("🟢 Updating CloudKit Database. ownedByMe has changed.")
            existing.isOwnedByMeCloudKit = ownedByMe
        }

        checkIfContentUpdateAvailable(existing, database)
    }

    func mergeCloudKitDatabaseIn(_ database: CloudKitHostedDatabase) async throws {
        

        if let existing = findStrongboxDatabaseForCloudKitDatabase(cloudKitDatabase: database) {
            updateExisting(existing, database)
        } else {


            try await addNewlyAddedDatabase(database)
        }
    }

    func removeNoneExistentDatabases(_ ckDbs: [CloudKitHostedDatabase]) {
        

        let allIds = Set(ckDbs.map(\.id))

        let toRemove = existingCloudKitDatabases.filter { db in
            guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(db) else {
                swlog("🔴 ERROR: Could not read fileId! \(#function)!!")
                return true 
            }

            return !allIds.contains(cloudKitDatabaseId)
        }

        for removeMe in toRemove {
            guard !databaseIsUnlocked(databaseId: removeMe.uuid), !databaseHasEditsOrIsBeingEdited(databaseId: removeMe.uuid) else {
                swlog("⚠️ \(removeMe.uuid) scheduled for removal but is unlocked or is being edited, will not remove at this point.")
                continue
            }

            swlog("⚠️ Removing no longer present on CloudKit database: \(removeMe.nickName) from databases list")

            DatabaseNuker.nuke(removeMe, deleteUnderlyingIfSupported: false) { error in
                if let error {
                    swlog("🔴 DatabaseNuker.nuke - Error removing CloudKit Database. \(error)")
                }
            }
        }
    }

    func addNewlyAddedDatabase(_ database: CloudKitHostedDatabase) async throws {


        let newDatabasePrefs = try CloudKitStorageProvider.generateNewDatabaseMetadata(database: database)

        #if os(iOS)
            try newDatabasePrefs.add(withDuplicateCheck: nil, initialCacheModDate: nil) 

            

        #else
            newDatabasePrefs.add()


        #endif
    }

    func checkIfContentUpdateAvailable(_ existing: METADATA_PTR, _ database: CloudKitHostedDatabase) {
        let wcmod = WorkingCopyManager.sharedInstance().getModDate(existing.uuid)

        let updateAvailable = wcmod == nil ? true : !(wcmod!).isEqualToDateWithinEpsilon(database.modDate)

        if updateAvailable {
            swlog("🐞 Update is available for database [\(existing.uuid)]... working = [\(String(describing: wcmod))] =?= \(database.modDate)")

            if databaseIsUnlocked(databaseId: existing.uuid) {
                swlog("🐞 Database [\(existing.uuid)] is unlocked notifying App to request a sync if appropriate... ")
                notifyDatabaseUpdateAvailable(existing.uuid)
            } else {
                swlog("🐞 Database [\(existing.uuid)] is not unlocked performing a background sync... ")

                Task.detached {
                    #if os(iOS)
                        try await SyncManager.sharedInstance().backgroundSyncDatabase(existing, join: true, key: nil)
                    #else
                        try await MacSyncManager.sharedInstance().backgroundSyncDatabase(existing, key: nil)
                    #endif
                }
            }
        } else {
            
        }
    }

    func notifyDatabaseUpdateAvailable(_ uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cloudKitDatabaseUpdateAvailable, object: uuid)
        }
    }

    

    func createDatabase(nickname: String, filename: String, modDate: Date, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        let ret = try await CloudKitManager.shared.createDatabase(nickname: nickname, filename: filename, modDate: modDate, dataBlob: dataBlob)

        





        return ret
    }

    func getDatabase(id: CloudKitDatabaseIdentifier, includeDataBlob: Bool) async throws -> CloudKitHostedDatabase {
        try await CloudKitManager.shared.getDatabase(id: id, includeDataBlob: includeDataBlob)
    }

    func updateDatabase(_ id: CloudKitDatabaseIdentifier, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        try await CloudKitManager.shared.updateDatabase(id, dataBlob: dataBlob)
    }

    @objc
    func delete(database: METADATA_PTR) async throws {
        guard database.storageProvider == .kCloudKit else {
            swlog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            throw CloudKitDatabasesInteractorError.invalidParameter
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            swlog("🔴 ERROR: Could not read fileId! \(#function)!!")
            throw CloudKitDatabasesInteractorError.couldNotParseCloudKitId
        }

        try await CloudKitManager.shared.delete(id: cloudKitDatabaseId)

        try await refreshAndMerge()
    }

    @objc
    func rename(database: METADATA_PTR, nickName: String, fileName: String?) async throws {
        guard database.storageProvider == .kCloudKit else {
            swlog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            throw CloudKitDatabasesInteractorError.invalidParameter
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            swlog("🔴 ERROR: Could not read fileId! \(#function)!!")
            throw CloudKitDatabasesInteractorError.couldNotParseCloudKitId
        }

        _ = try await CloudKitManager.shared.rename(id: cloudKitDatabaseId, nickName: nickName, fileName: fileName)

        try await refreshAndMerge()
    }

    func beginSharing(for database: METADATA_PTR) async throws -> (share: CKShare, container: CKContainer) {
        let ckDb = try await findCloudKitDatabaseForStrongboxDatabase(database: database)

        let ret = try await CloudKitManager.shared.createShare(database: ckDb)

        try await refreshAndMerge()

        return ret
    }

    func getCurrentCKShare(for database: METADATA_PTR) async throws -> (CKShare?, CKContainer) {
        let ckDb = try await findCloudKitDatabaseForStrongboxDatabase(database: database)

        return try await CloudKitManager.shared.getShareRecord(database: ckDb)
    }

    @objc
    func acceptShare(metadata: CKShare.Metadata) async throws {
        CrossPlatformDependencies.defaults().spinnerUi.show(NSLocalizedString("accepting_share_status_spinner", comment: "Accepting Share..."),
                                                            viewController: nil)

        defer {
            CrossPlatformDependencies.defaults().spinnerUi.dismiss()
        }

        try await CloudKitManager.shared.acceptShare(metadata: metadata)

        

        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

        try await refreshAndMerge()
    }

    

    func findStrongboxDatabaseForCloudKitDatabase(cloudKitDatabase: CloudKitHostedDatabase) -> METADATA_PTR? {
        findStrongboxDatabaseForCloudKitDatabase(cloudKitIdentifier: cloudKitDatabase.id)
    }

    func findStrongboxDatabaseForCloudKitDatabase(cloudKitIdentifier: CloudKitDatabaseIdentifier) -> METADATA_PTR? {
        existingCloudKitDatabases.first(where: { existingDb in
            guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(existingDb) else {
                swlog("🔴 Could not read file identifier for cloudkit database")
                return false
            }

            return cloudKitDatabaseId == cloudKitIdentifier
        })
    }

    func findCloudKitDatabaseForStrongboxDatabase(database: METADATA_PTR) async throws -> CloudKitHostedDatabase {
        guard database.storageProvider == .kCloudKit else {
            swlog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            throw CloudKitDatabasesInteractorError.invalidParameter
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            swlog("🔴 ERROR: Could not read fileId! \(#function)!!")
            throw CloudKitDatabasesInteractorError.couldNotParseCloudKitId
        }

        return try await getDatabase(id: cloudKitDatabaseId, includeDataBlob: false)
    }

    var existingCloudKitDatabases: [METADATA_PTR] {
        #if os(iOS)
            return DatabasePreferences.forAllDatabases(of: .kCloudKit)
        #else
            return MacDatabasePreferences.forAllDatabases(of: .kCloudKit)
        #endif
    }

    func cloudKitIdentifierFromStrongboxDatabase(_ db: METADATA_PTR) -> CloudKitDatabaseIdentifier? {
        #if os(iOS)
            return CloudKitDatabaseIdentifier.fromJson(db.fileIdentifier)
        #else
            return CloudKitDatabaseIdentifier.fromJson(db.storageInfo)
        #endif
    }

    @objc
    class Instrumentation: NSObject {
        @objc let isInitialized: Bool
        @objc let subscribedToDatabaseChanges: Bool
        @objc let cloudKitAccountStatus: CKAccountStatus
        @objc let cloudKitAccountStatusError: Error?
        @objc let registeredForNotifications: Bool
        @objc let registeredForNotificationError: Error?
        @objc let userNotificationAuthStatus: UNAuthorizationStatus
        @objc let cloudKitInstruments: CloudKitManagerInstrumentation

        init(isInitialized: Bool,
             subscribedToDatabaseChanges: Bool,
             cloudKitAccountStatus: CKAccountStatus,
             cloudKitAccountStatusError: Error?,
             registeredForNotifications: Bool,
             registeredForNotificationError: Error?,
             userNotificationAuthStatus: UNAuthorizationStatus,
             cloudKitInstruments: CloudKitManagerInstrumentation)
        {
            self.isInitialized = isInitialized
            self.subscribedToDatabaseChanges = subscribedToDatabaseChanges
            self.cloudKitAccountStatus = cloudKitAccountStatus
            self.cloudKitAccountStatusError = cloudKitAccountStatusError
            self.registeredForNotifications = registeredForNotifications
            self.registeredForNotificationError = registeredForNotificationError
            self.userNotificationAuthStatus = userNotificationAuthStatus
            self.cloudKitInstruments = cloudKitInstruments
        }
    }

    @objc
    func getInstruments() async -> Instrumentation {
        let cloudKitInstruments = CloudKitManager.shared.instrumentation

        let settings = await UNUserNotificationCenter.current().notificationSettings()

        return Instrumentation(isInitialized: isInitialized,
                               subscribedToDatabaseChanges: subscribedToDatabaseChanges,
                               cloudKitAccountStatus: cachedAccountStatus,
                               cloudKitAccountStatusError: cachedAccountStatusError,
                               registeredForNotifications: registeredForNotifications,
                               registeredForNotificationError: registeredForNotificationError,
                               userNotificationAuthStatus: settings.authorizationStatus,
                               cloudKitInstruments: cloudKitInstruments)
    }
}
