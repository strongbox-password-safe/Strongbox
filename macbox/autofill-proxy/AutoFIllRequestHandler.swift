//
//  AutoFillRequestHandler.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc class AutoFillRequestHandler: NSObject {
    var keyPair: BoxKeyPair = CryptoBoxHelper.createKeyPair()

    static let MaxFieldLength = 8192
    static let MaxIconBase64LengthMultipleItems = 100 * 1024
    static let MaxIconBase64LengthExplicitRequest = 500 * 1024

    @objc static let shared = AutoFillRequestHandler()

    override private init() {
        super.init()
    }

    @objc func handleJsonRequest(json: String) -> String {
        guard let request = AutoFillEncryptedRequest.from(json: json) else {
            return AutoFillEncryptedResponse.error(message: "Could not convert request to JSON").toJson()
        }

        let startTime = NSDate.timeIntervalSinceReferenceDate

        var ret: AutoFillEncryptedResponse

        switch request.messageType {
        case .status:
            ret = handleGetStatusRequest(request)
        case .search:
            ret = handleSearchRequest(request)
        case .getCredentialsForUrl:
            ret = handleGetCredentialsForUrlRequest(request)
        case .copyField:
            ret = handleCopyFieldRequest(request)
        case .lock:
            ret = handleLockDatabaseRequest(request)
        case .unlock:
            ret = handleUnlockDatabaseRequest(request)
        case .createEntry:
            ret = handleCreateEntryRequest(request)
        case .getGroups:
            ret = handleGetGroupsRequest(request)
        case .getNewEntryDefaults:
            ret = handleGetNewEntryDefaultsRequest(request)
        case .generatePassword:
            ret = handleGeneratePasswordRequest(request)
        case .getIcon:
            ret = handleGetIconRequest(request)
        case .generatePasswordV2:
            ret = handleGeneratePasswordV2Request(request)
        case .getPasswordStrength:
            ret = handleGetPasswordStrengthRequest(request)
        case .getNewEntryDefaultsV2:
            ret = handleGetNewEntryDefaultsV2Request(request)
        case .getFavourites:
            ret = handleGetFavouritesRequest(request)
        case .copyString:
            ret = handleCopyStringRequest(request)
        }

        let response = ret.toJson()

        let perf = NSDate.timeIntervalSinceReferenceDate - startTime
        let size = response.count

        if perf > 0.05 || size > (30 * 1024) {
            swlog("🐞 PERF: Processed AutoFill [%@] request in %f seconds (%d bytes)", request.messageType.description, perf, size)
        }

        return response
    }

    func handleGetFavouritesRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let favRequest = try? decoder.decode(GetFavouritesRequest.self, from: data)
        else {
            swlog("🔴 Can't decode GetFavouritesRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode GetFavouritesRequest from message JSON")
        }

        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            database.autoFillEnabled && DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        let takeRequested = (favRequest.take ?? GetFavouritesRequest.DefaultMaxResults)
        let take = takeRequested > GetFavouritesRequest.AbsoluteMaxResults ? GetFavouritesRequest.AbsoluteMaxResults : takeRequested
        if takeRequested > GetFavouritesRequest.AbsoluteMaxResults {
            swlog("⚠️ WARN: GetFavourites - Paging: Take (%d) greater than AbsoluteMaxResults (%d) - will truncate results", takeRequested, GetFavouritesRequest.AbsoluteMaxResults)
        }

        let skip = favRequest.skip ?? 0

        let credentials = getFavourites(unlockedDatabases: unlockedDatabases, skip: skip, take: take)

        let response = GetFavouritesResponse(results: credentials)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func getFavourites(unlockedDatabases: [MacDatabasePreferences], skip: Int, take: Int) -> [AutoFillCredential] {
        var collected: [(Model, Node)] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }

            let nodes = model.favourites

            let thisDbResults = nodes.map { node in
                (model, node)
            }

            collected += thisDbResults
        }

        #if DEBUG
            swlog("✅ getFavourites - skip %d, take %d, with Result Count %d", skip, take, collected.count)
        #endif

        let credentials = getResultsWindow(collected, skip, take)

        return credentials
    }

    func handleCopyFieldRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let copyRequest = try? decoder.decode(CopyFieldRequest.self, from: data)
        else {
            swlog("🔴 Can't decode CopyFieldRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CopyFieldRequest from message JSON")
        }

        guard let theDatabase = MacDatabasePreferences.allDatabases.first(where: { database in
            database.uuid == copyRequest.databaseId
        }) else {
            swlog("🔴 Could not find this database")
            return AutoFillEncryptedResponse.error(message: "Could not find this database!")
        }

        guard theDatabase.autoFillEnabled else {
            swlog("🔴 This database is not AutoFill enabled")
            return AutoFillEncryptedResponse.error(message: "This database is not AutoFill enabled")
        }

        guard let model = DatabasesCollection.shared.getUnlocked(uuid: theDatabase.uuid) else {
            swlog("🔴 This database is not unlocked.")
            return AutoFillEncryptedResponse.error(message: "This database is not unlocked or error getting document")
        }

        switch copyRequest.field {
        case .totp:
            copyTotp(model: model, itemId: copyRequest.nodeId, explicitRequest: copyRequest.explicitTotp)
        case .username:
            copyUsername(model: model, itemId: copyRequest.nodeId)
        case .password:
            copyPassword(model: model, itemId: copyRequest.nodeId)
        }

        let response = BooleanAutoFillResponse(success: true)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleCopyStringRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let copyRequest = try? decoder.decode(CopyStringRequest.self, from: data)
        else {
            swlog("🔴 Can't decode CopyFieldRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CopyFieldRequest from message JSON")
        }

        copyString(copyRequest.value)

        let response = BooleanAutoFillResponse(success: true)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleGetStatusRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let response = GetStatusResponse()

        let settings = ServerSettings()

        settings.supportsCreateNew = true
        settings.markdownNotes = Settings.sharedInstance().markdownNotes

        settings.colorizePasswords = Settings.sharedInstance().colorizePasswords
        settings.colorBlindPalette = Settings.sharedInstance().colorizeUseColorBlindPalette

        response.serverSettings = settings
        response.serverVersionInfo = Utils.getAppVersion()
        response.databases = MacDatabasePreferences.allDatabases.map { obj in
            DatabaseSummary(uuid: obj.uuid, nickName: obj.nickName, autoFillEnabled: obj.autoFillEnabled, includeFavIconForNewEntries: obj.expressDownloadFavIconOnNewOrUrlChanged, locked: !DatabasesCollection.shared.isUnlocked(uuid: obj.uuid))
        }

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleSearchRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let searchRequest = try? decoder.decode(SearchRequest.self, from: data)
        else {
            swlog("🔴 Can't decode SearchRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode SearchRequest from message JSON")
        }

        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            database.autoFillEnabled && DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }



        var collected: [(Model, Node)] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }

            let nodes = model.search(searchRequest.query,
                                     scope: .all,
                                     dereference: true,
                                     includeKeePass1Backup: false, includeRecycleBin: false, includeExpired: false, includeGroups: false, browseSortField: .title, descending: false, foldersSeparately: false)



            collected += nodes.map { node in
                (model, node)
            }
        }

        let takeRequested = (searchRequest.take ?? SearchRequest.DefaultMaxResults)
        let take = takeRequested > SearchRequest.AbsoluteMaxResults ? SearchRequest.AbsoluteMaxResults : takeRequested
        if takeRequested > SearchRequest.AbsoluteMaxResults {
            swlog("⚠️ WARN: Search - Paging: Take (%d) greater than AbsoluteMaxResults (%d) - will truncate results", takeRequested, SearchRequest.AbsoluteMaxResults)
        }

        let skip = searchRequest.skip ?? 0

        #if DEBUG
            swlog("✅ Got Search Request - Query = [%@] - skip %d, take %d, with Result Count %d", searchRequest.query, skip, take, collected.count)
        #endif

        let results = getResultsWindow(collected, skip, take)

        let response = SearchResponse(results: results)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func getResultsWindow(_ collected: [(Model, Node)], _ skipIn: Int, _ takeIn: Int) -> [AutoFillCredential] {
        var skip = skipIn
        var take = takeIn

        if skip > collected.count {
            swlog("⚠️ WARN: getResultsWindow - Paging: Skip (%d) greater than result count (%d) - zeroing skip and take", skip, collected.count)
            skip = 0
            take = 0
        }

        let window = collected.suffix(from: skip).prefix(take)

        let results: [AutoFillCredential] = window.enumerated().map { idx, item in
            let (model, node) = item
            let includeNIcons = 2 
            return convertNodeToAutoFillCredential(model, node, includeIcon: idx < includeNIcons)
        }

        return results
    }

    func handleLockDatabaseRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(LockDatabaseRequest.self, from: data)
        else {
            swlog("🔴 Can't decode LockDatabaseRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode LockDatabaseRequest from message JSON")
        }

        swlog("Got LockDatabaseRequest - Database ID = [%@]", request.databaseId)

        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled else {
            swlog("🔴 Can't find AutoFillEnabled database to Lock")
            return AutoFillEncryptedResponse.error(message: "🔴 Can't find AutoFillEnabled database to Lock")
        }

        if DatabasesCollection.shared.isUnlocked(uuid: request.databaseId) {
            DatabasesCollection.shared.initiateLockRequest(uuid: request.databaseId)
        } else {
            
        }

        let response = LockDatabaseResponse(success: true)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleUnlockDatabaseRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(UnlockDatabaseRequest.self, from: data)
        else {
            swlog("🔴 Can't decode UnlockDatabaseRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode UnlockDatabaseRequest from message JSON")
        }

        swlog("Got UnlockDatabaseRequest - Database ID = [%@]", request.databaseId)

        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled else {
            swlog("🔴 Can't find AutoFillEnabled database to Unlock")
            return AutoFillEncryptedResponse.error(message: "Can't find AutoFillEnabled database to Unlock")
        }

        let go = DatabasesCollection.shared.initiateUnlockWithSynchronousTimeout(request.databaseId, timeoutSeconds: 10)

        let response = UnlockDatabaseResponse(success: go)

        let json = AutoFillJsonHelper.toJson(object: response)

        

        if go {
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }
        }

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetCredentialsForUrlRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let gcfuRequest = try? decoder.decode(CredentialsForUrlRequest.self, from: data)
        else {
            swlog("🔴 Can't decode CredentialsForUrlRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CredentialsForUrlRequest from message JSON")
        }


        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            database.autoFillEnabled && DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        

        let takeRequested = (gcfuRequest.take ?? CredentialsForUrlRequest.DefaultMaxResults)
        let take = takeRequested > CredentialsForUrlRequest.AbsoluteMaxResults ? CredentialsForUrlRequest.AbsoluteMaxResults : takeRequested
        if takeRequested > CredentialsForUrlRequest.AbsoluteMaxResults {
            swlog("⚠️ WARN: Get Credentials for URL - Paging: Take (%d) greater than AbsoluteMaxResults (%d) - will truncate results", takeRequested, CredentialsForUrlRequest.AbsoluteMaxResults)
        }

        let skip = gcfuRequest.skip ?? 0

        let credentials = getCredentialsForUrl(unlockedDatabases: unlockedDatabases, url: gcfuRequest.url, skip: skip, take: take)

        let response = CredentialsForUrlResponse(results: credentials, unlockedDatabaseCount: unlockedDatabases.count)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func getCredentialsForUrl(unlockedDatabases: [MacDatabasePreferences], url: String, skip: Int, take: Int) -> [AutoFillCredential] {
        var collected: [(Model, Node)] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }

            let nodes = model.getAutoFillMatchingNodes(forUrl: url)

            

            let thisDbResults = nodes.map { node in
                (model, node)
            }

            collected += thisDbResults
        }

        #if DEBUG

        #endif

        let credentials = getResultsWindow(collected, skip, take)

        return credentials
    }

    func handleCreateEntryRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(CreateEntryRequest.self, from: data)
        else {
            swlog("🔴 Can't decode CreateEntryRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CreateEntryRequest from message JSON")
        }

        swlog("✅ Got CreateEntryRequest [databaseId = %@]", request.databaseId)

        let response = createEntry(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetGroupsRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetGroupsRequest.self, from: data)
        else {
            swlog("🔴 Can't decode CreateEntryRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CreateEntryRequest from message JSON")
        }

        swlog("✅ Got CreateEntryRequest [databaseId = %@]", request.databaseId)

        let response = getGroups(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGeneratePasswordRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GeneratePasswordRequest.self, from: data)
        else {
            swlog("🔴 Can't decode handleGeneratePasswordRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode handleGeneratePasswordRequest from message JSON")
        }

        swlog("✅ Got handleGeneratePasswordRequest")

        let response = generatePassword(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGeneratePasswordV2Request(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GeneratePasswordRequest.self, from: data)
        else {
            swlog("🔴 Can't decode handleGeneratePasswordV2Request from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode handleGeneratePasswordV2Request from message JSON")
        }

        swlog("✅ Got handleGeneratePasswordV2Request")

        let response = generatePasswordV2(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetPasswordStrengthRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetPasswordStrengthRequest.self, from: data)
        else {
            swlog("🔴 Can't decode handleGetPasswordStrengthRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode handleGetPasswordStrengthRequest from message JSON")
        }

        swlog("✅ Got handleGetPasswordStrengthRequest")

        let response = getPasswordStrength(request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetNewEntryDefaultsRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetNewEntryDefaultsRequest.self, from: data)
        else {
            swlog("🔴 Can't decode GetNewEntryDefaultsRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode GetNewEntryDefaultsRequest from message JSON")
        }

        swlog("✅ Got GetNewEntryDefaultsRequest [databaseId = %@]", request.databaseId)

        let response = getNewEntryDefaults(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetNewEntryDefaultsV2Request(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetNewEntryDefaultsRequest.self, from: data)
        else {
            swlog("🔴 Can't decode GetNewEntryDefaultsRequestV2 from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode GetNewEntryDefaultsRequestV2 from message JSON")
        }

        swlog("✅ Got GetNewEntryDefaultsRequestV2 [databaseId = %@]", request.databaseId)

        let response = getNewEntryDefaultsV2(request: request)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetIconRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()

        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetIconRequest.self, from: data)
        else {
            swlog("🔴 Can't decode GetIconRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode GetIconRequest from message JSON")
        }

        

        guard let prefs = MacDatabasePreferences.getById(request.databaseId),
              prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: request.databaseId),
              let node = model.getItemBy(request.nodeId),
              let b64 = getNodeIconPngBase64String(model, node, maxLength: AutoFillRequestHandler.MaxIconBase64LengthExplicitRequest)
        else {
            swlog("🔴 Can't find AutoFillEnabled database to get Icon for, or this database is not unlocked or could not find node")
            return AutoFillEncryptedResponse.error(message: "This database is not unlocked or error getting document")
        }

        let iconBase64Encoded = String(format: "data:image/png;base64,%@", b64)

        let response = GetIconResponse(icon: iconBase64Encoded)

        let json = AutoFillJsonHelper.toJson(object: response)

        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    

    func convertNodeToAutoFillCredential(_ model: Model, _ node: Node, includeIcon: Bool = true) -> AutoFillCredential {
        var iconBase64Encoded = ""

        if includeIcon, let b64 = getNodeIconPngBase64String(model, node, maxLength: AutoFillRequestHandler.MaxIconBase64LengthMultipleItems) {
            iconBase64Encoded = String(format: "data:image/png;base64,%@", b64)
        }



        let vm = EntryViewModel.fromNode(node, model: model)

        let cfs = vm.customFieldsFiltered.map { cfvm in
            AutoFillCredentialCustomField(key: cfvm.key,
                                          value: String(cfvm.value.prefix(AutoFillRequestHandler.MaxFieldLength)),
                                          concealable: cfvm.protected)
        }

        let atts = vm.filteredAttachments.allKeys().map { $0 as String }

        let credential = AutoFillCredential(uuid: node.uuid,
                                            databaseId: model.metadata.uuid,
                                            title: model.dereference(vm.title, node: node),
                                            username: model.dereference(vm.username, node: node),
                                            password: model.dereference(vm.password, node: node),
                                            url: model.dereference(vm.url, node: node),
                                            totp: vm.totp?.url(true).absoluteString ?? "",
                                            icon: iconBase64Encoded,
                                            customFields: cfs,
                                            attachmentFileNames: atts,
                                            databaseName: model.metadata.nickName,
                                            tags: vm.tags,
                                            favourite: vm.favourite,
                                            notes: String(vm.notes.prefix(AutoFillRequestHandler.MaxFieldLength)),
                                            modified: (node.fields.modified as? NSDate)?.friendlyDateTimeString ?? "")

        return credential
    }

    let iconCache = ConcurrentMutableDictionary<NSString, NSString>()

    func getNodeIconPngBase64String(_ model: Model, _ node: Node, maxLength: Int = AutoFillRequestHandler.MaxIconBase64LengthMultipleItems) -> String? {
        let key = String(format: "%@-%@-%ld", model.databaseUuid, node.uuid.uuidString, node.fields.modified?.timeIntervalSinceReferenceDate ?? 0)

        

        

        if let cached = iconCache.object(forKey: key as NSString) {
            
            return cached as String
        }

        var image = NodeIconHelper.getIconFor(node, predefinedIconSet: model.metadata.keePassIconSet, format: model.originalFormat)

        if node.icon == nil || !(node.icon?.isCustom ?? false) {
            if model.metadata.keePassIconSet == .sfSymbols {
                image = Utils.imageTinted(withColor: image, tint: .systemBlue) 
            }
        }

        return getPngBase64StringForImage(model: model, image: image, cacheKey: key, maxLength: maxLength)
    }

    func getPngBase64StringForImage(model _: Model, image: NSImage, cacheKey: String, maxLength: Int) -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            swlog("🔴 Could not get cgimage for node icon")
            return nil
        }

        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = image.size 

        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            swlog("🔴 Could not newRep.representation for new icon")
            return nil
        }

        var ret = pngData.base64EncodedString()

        if ret.count > maxLength {
            swlog("⚠️ Icon is too large to return. Size=\(ret.count)bytes.")

            

            let smallFallbackVisible = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX

            ret = smallFallbackVisible
        }

        iconCache.setObject(ret as NSString, forKey: cacheKey as NSString)



        return ret
    }

    func copyUsername(model: Model, itemId: UUID) {
        guard let item = model.getItemBy(itemId) else {
            swlog("🔴 Could not find item to copy!")
            return
        }

        dereferenceAndCopy(model: model, text: item.fields.username, item: item)
    }

    func copyPassword(model: Model, itemId: UUID) {
        guard let item = model.getItemBy(itemId) else {
            swlog("🔴 Could not find item to copy!")
            return
        }

        dereferenceAndCopy(model: model, text: item.fields.password, item: item)
    }

    func copyTotp(model: Model, itemId: UUID, explicitRequest: Bool) {
        guard explicitRequest || model.metadata.autoFillCopyTotp else {
            swlog("🔴 Not copying TOTP as not configured or not an explicit request")
            return
        }

        guard let item = model.getItemBy(itemId), let token = item.fields.otpToken else {
            swlog("🔴 Could not find item to copy!")
            return
        }

        copyString(token.password)
    }

    func dereferenceAndCopy(model: Model, text: String, item: Node) {
        let deref = model.dereference(text, node: item)
        copyString(deref)
    }

    func copyString(_ string: String) {
        ClipboardManager.sharedInstance().copyConcealedString(string)
        scheduleClipboardClearingTask()
    }

    func scheduleClipboardClearingTask() {
        if Settings.sharedInstance().clearClipboardEnabled {
            DispatchQueue.main.async {
                let delegate = NSApplication.shared.delegate as! AppDelegate
                delegate.onStrongboxDidChangeClipboard()
            }
        }
    }

    

    func createEntry(request: CreateEntryRequest) -> CreateEntryResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid)
        else {
            let response = CreateEntryResponse()
            response.error = "Can't find AutoFillEnabled database to Unlock"
            return response
        }

        let parent: Node
        if let groupId = request.groupId, let uuid = UUID(uuidString: groupId),
           let parentGroup = model.getItemBy(uuid)
        {
            parent = parentGroup
        } else {
            parent = model.database.effectiveRootGroup
        }

        let autoFill = Settings.sharedInstance().autoFillNewRecordSettings

        let mostPopularEmail = model.database.mostPopularEmail ?? ""
        let actualEmail = autoFill.emailAutoFillMode == .none ? "" : autoFill.emailAutoFillMode == .mostUsed ? mostPopularEmail : autoFill.emailCustomAutoFill
        let actualNotes = autoFill.notesAutoFillMode == .none ? "" : autoFill.notesAutoFillMode == .clipboard ? getClipboardText() : autoFill.notesCustomAutoFill

        let fields = NodeFields(username: request.username ?? "", url: request.url ?? "", password: request.password ?? "", notes: actualNotes, email: actualEmail)

        let newNode = Node(asRecord: request.title ?? "", parent: parent, fields: fields, uuid: nil)

        if let iconB64 = request.icon,
           let data = Data(base64Encoded: iconB64)
        {
            let icon = NodeIcon.withCustom(data)
            newNode.icon = icon
        } else {
            let useParentGroupIcon = Settings.sharedInstance().useParentGroupIconOnCreate

            if useParentGroupIcon, !parent.isUsingKeePassDefaultIcon {
                newNode.icon = parent.icon
            }
        }

        if !model.addChildren([newNode], destination: parent) {
            let response = CreateEntryResponse()
            response.error = "Could not create new entry here."
            return response
        }

        if !DatabasesCollection.shared.updateAndQueueSync(uuid: prefs.uuid) {
            let response = CreateEntryResponse()
            response.error = "Could not create new entry here."
            return response
        }

        notifyViewsRefresh(uuid: prefs.uuid)

        let response = CreateEntryResponse()
        response.uuid = newNode.uuid.uuidString

        if let foundNode = model.getItemBy(newNode.uuid) {
            response.credential = convertNodeToAutoFillCredential(model, foundNode)
        }

        return response
    }

    func getGroups(request: GetGroupsRequest) -> GetGroupsResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid)
        else {
            let response = GetGroupsResponse()
            response.error = "Can't find AutoFillEnabled database to Unlock"
            return response
        }

        let summaries = model.database.allActiveGroups.map { grp in
            GroupSummary(title: getGroupPathDisplayString(model, grp), uuid: grp.uuid.uuidString)
        }

        var sorted = summaries.sorted { n1, n2 in
            finderStringCompare(n1.title, n2.title) == .orderedAscending
        }

        if model.database.effectiveRootGroup.childRecordsAllowed {
            let title = getGroupPathDisplayString(model, model.database.effectiveRootGroup, rootGroupNameInsteadOfSlash: true)
            let root = GroupSummary(title: title, uuid: model.database.effectiveRootGroup.uuid.uuidString)
            sorted.insert(root, at: 0)
        }

        let response = GetGroupsResponse()

        response.groups = sorted

        return response
    }

    func generatePassword(request _: GeneratePasswordRequest) -> GeneratePasswordResponse {
        let pw = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)

        let pw1 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw2 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw3 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw4 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw5 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)

        let alternatives = [pw1, pw2, pw3, pw4, pw5]

        return GeneratePasswordResponse(password: pw, alternatives: alternatives)
    }

    func generatePasswordV2(request _: GeneratePasswordRequest) -> GeneratePasswordV2Response {
        let pw = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw1 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw2 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw3 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw4 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw5 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)

        let alternatives = [getPasswordAndStrength(pw1),
                            getPasswordAndStrength(pw2),
                            getPasswordAndStrength(pw3),
                            getPasswordAndStrength(pw4),
                            getPasswordAndStrength(pw5)]

        return GeneratePasswordV2Response(password: getPasswordAndStrength(pw), alternatives: alternatives)
    }

    func getPasswordStrength(_ request: GetPasswordStrengthRequest) -> GetPasswordStrengthResponse {
        let strength = PasswordStrengthTester.getStrength(request.password, config: Settings.sharedInstance().passwordStrengthConfig)
        let pwsd = PasswordStrengthData(entropy: strength.entropy, category: strength.category, summaryString: strength.summaryString)

        return GetPasswordStrengthResponse(strength: pwsd)
    }

    func getPasswordAndStrength(_ pw: String) -> PasswordAndStrength {
        let strength = PasswordStrengthTester.getStrength(pw, config: Settings.sharedInstance().passwordStrengthConfig)
        let pwsd = PasswordStrengthData(entropy: strength.entropy, category: strength.category, summaryString: strength.summaryString)
        return PasswordAndStrength(password: pw, strength: pwsd)
    }

    func getNewEntryDefaults(request: GetNewEntryDefaultsRequest) -> GetNewEntryDefaultsResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid)
        else {
            let response = GetNewEntryDefaultsResponse(error: "Can't find AutoFillEnabled database to Unlock")
            return response
        }

        let defaultConfig = Settings.sharedInstance().autoFillNewRecordSettings

        let mostPopularUsername = model.database.mostPopularUsername ?? ""
        let username = defaultConfig.usernameAutoFillMode == .none ? "" : defaultConfig.usernameAutoFillMode == .mostUsed ? mostPopularUsername : defaultConfig.usernameCustomAutoFill

        let generated = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)

        let password = defaultConfig.passwordAutoFillMode == .none ? "" : defaultConfig.passwordAutoFillMode == .generated ? generated : defaultConfig.passwordCustomAutoFill

        let response = GetNewEntryDefaultsResponse(username: username, password: password, mostPopularUsernames: model.database.mostPopularUsernames)

        return response
    }

    func getNewEntryDefaultsV2(request: GetNewEntryDefaultsRequest) -> GetNewEntryDefaultsV2Response {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid)
        else {
            let response = GetNewEntryDefaultsV2Response(error: "Can't find AutoFillEnabled database to Unlock")
            return response
        }

        let defaultConfig = Settings.sharedInstance().autoFillNewRecordSettings

        let mostPopularUsername = model.database.mostPopularUsername ?? ""
        let username = defaultConfig.usernameAutoFillMode == .none ? "" : defaultConfig.usernameAutoFillMode == .mostUsed ? mostPopularUsername : defaultConfig.usernameCustomAutoFill

        let generated = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)

        let password = defaultConfig.passwordAutoFillMode == .none ? "" : defaultConfig.passwordAutoFillMode == .generated ? generated : defaultConfig.passwordCustomAutoFill
        let passwordAndStrength = getPasswordAndStrength(password)

        let response = GetNewEntryDefaultsV2Response(username: username, password: passwordAndStrength, mostPopularUsernames: model.database.mostPopularUsernames)

        return response
    }

    func getClipboardText() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    

    func getGroupPathDisplayString(_ model: Model, _ node: Node, rootGroupNameInsteadOfSlash: Bool = false) -> String {
        model.database.getPathDisplayString(node, includeRootGroup: true, rootGroupNameInsteadOfSlash: rootGroupNameInsteadOfSlash, includeFolderEmoji: false, joinedBy: "/")
    }

    func notifyViewsRefresh(uuid: String) {
        DatabasesCollection.shared.notifyViewsToRefresh(uuid: uuid)
    }
}
