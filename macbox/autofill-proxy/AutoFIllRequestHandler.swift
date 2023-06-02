//
//  AutoFIllRequestHandler.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc class AutoFillRequestHandler: NSObject {
    var keyPair: BoxKeyPair = CryptoBoxHelper.createKeyPair()
  
    @objc static let shared = AutoFillRequestHandler()
    
    override private init() {
        super.init()
    }
    
    
    
    @objc func handleJsonRequest(json: String) -> AutoFillEncryptedResponse {
        guard let request = AutoFillEncryptedRequest.from(json: json) else {
            return AutoFillEncryptedResponse.error(message: "Could not convert request to JSON")
        }
        
        switch request.messageType {
        case .status:
            return handleGetStatusRequest(request)
        case .search:
            return handleSearchRequest(request)
        case .getCredentialsForUrl:
            return handleGetCredentialsForUrlRequest(request)
        case .copyField:
            return handleCopyFieldRequest(request)
        case .lock:
            return handleLockDatabaseRequest(request)
        case .unlock:
            return handleUnlockDatabaseRequest(request)
        case .createEntry:
            return handleCreateEntryRequest(request)
        case .getGroups:
            return handleGetGroupsRequest(request)
        case .getNewEntryDefaults:
            return handleGetNewEntryDefaultsRequest(request)
        case .generatePassword:
            return handleGeneratePasswordRequest(request)
        }
    }
    
    func handleCopyFieldRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let copyRequest = try? decoder.decode(CopyFieldRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode CopyFieldRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CopyFieldRequest from message JSON")
        }
                
        guard let theDatabase = MacDatabasePreferences.allDatabases.first ( where: { database in
            database.uuid == copyRequest.databaseId
        }) else {
            NSLog("🔴 Could not find this database")
            return AutoFillEncryptedResponse.error(message: "Could not find this database!")
        }
        
        guard theDatabase.autoFillEnabled else {
            NSLog("🔴 This database is not AutoFill enabled")
            return AutoFillEncryptedResponse.error(message: "This database is not AutoFill enabled")
        }
        
        guard let model = DatabasesCollection.shared .getUnlocked(uuid: theDatabase.uuid) else {
            NSLog("🔴 This database is not unlocked.")
            return AutoFillEncryptedResponse.error(message: "This database is not unlocked or error getting document")
        }
        
        switch ( copyRequest.field ) {
        case .totp:
            copyTotp(model: model, itemId: copyRequest.nodeId, explicitRequest: copyRequest.explicitTotp)
        case .username:
            copyUsername(model: model, itemId: copyRequest.nodeId)
        case .password:
            copyPassword(model: model, itemId: copyRequest.nodeId)
        }

        let response = CopyFieldResponse(success: true)
                
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleGetStatusRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let response = GetStatusResponse()
        
        response.serverSettings = ServerSettings()
        
        response.serverSettings?.supportsCreateNew = true
        
        response.serverVersionInfo = Utils.getAppVersion()
        response.databases = MacDatabasePreferences.allDatabases.map { obj in
            DatabaseSummary(uuid: obj.uuid, nickName: obj.nickName, autoFillEnabled: obj.autoFillEnabled, locked: !DatabasesCollection.shared.isUnlocked(uuid: obj.uuid))
        }
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleSearchRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let searchRequest = try? decoder.decode(SearchRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode SearchRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode SearchRequest from message JSON")
        }
        
        NSLog("Got Search Request - Query = [%@]", searchRequest.query)
                 
        let response = SearchResponse(results: [])
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleLockDatabaseRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(LockDatabaseRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode LockDatabaseRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode LockDatabaseRequest from message JSON")
        }
        
        NSLog("Got LockDatabaseRequest - Database ID = [%@]", request.databaseId)
        
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled else {
            NSLog("🔴 Can't find AutoFillEnabled database to Lock")
            return AutoFillEncryptedResponse.error(message: "🔴 Can't find AutoFillEnabled database to Lock")
        }
        
        if DatabasesCollection.shared.isUnlocked(uuid: request.databaseId) {
            DatabasesCollection.shared.initiateLockRequest(uuid: request.databaseId)
        }
        else {
            
        }
        
        let response = LockDatabaseResponse(success: true)
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleUnlockDatabaseRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(UnlockDatabaseRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode UnlockDatabaseRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode UnlockDatabaseRequest from message JSON")
        }
        
        NSLog("Got UnlockDatabaseRequest - Database ID = [%@]", request.databaseId)

        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled else {
            NSLog("🔴 Can't find AutoFillEnabled database to Unlock")
            return AutoFillEncryptedResponse.error(message: "Can't find AutoFillEnabled database to Unlock")
        }

        var go = false
        if !DatabasesCollection.shared.isUnlocked(uuid: request.databaseId) {
            let g = DispatchGroup()
            g.enter()
            
            DatabasesCollection.shared.initiateDatabaseUnlock(uuid: request.databaseId) { success in
                go = success
                g.leave()
            }
            
            if g.wait(timeout: .now() + 5) == .timedOut {
                NSLog("⚠️ Waiting for Database Unlock, timed out.")
            }
            else {
                NSLog("Waiting for Database Unlock done, result = [%@]", localizedOnOrOffFromBool(go))
            }
        }
        else {
            
            go = true
        }
                
        let response = UnlockDatabaseResponse(success: go)
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetCredentialsForUrlRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let searchRequest = try? decoder.decode(CredentialsForUrlRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode CredentialsForUrlRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CredentialsForUrlRequest from message JSON")
        }
        

                 
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            database.autoFillEnabled && DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }
        

        
        var credentials: [AutoFillCredential] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }
            
            let nodes = model.getAutoFillMatchingNodes(forUrl: searchRequest.url)
            

            
            let urlCredentialMatches = nodes.map { node in
                convertNodeToAutoFillCredential(database, model, node)
            }
            
            credentials += urlCredentialMatches
        }
         
        
        
        credentials = Array( credentials.prefix(15) )
        
        let response = CredentialsForUrlResponse(results: credentials,unlockedDatabaseCount: unlockedDatabases.count)
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }

    func handleCreateEntryRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(CreateEntryRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode CreateEntryRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CreateEntryRequest from message JSON")
        }
        
        NSLog("✅ Got CreateEntryRequest [databaseId = %@]", request.databaseId)
        
        let response = createEntry( request: request);
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGetGroupsRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetGroupsRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode CreateEntryRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CreateEntryRequest from message JSON")
        }
        
        NSLog("✅ Got CreateEntryRequest [databaseId = %@]", request.databaseId)
        
        let response = getGroups( request: request);
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }

    func handleGeneratePasswordRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GeneratePasswordRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode handleGeneratePasswordRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode handleGeneratePasswordRequest from message JSON")
        }
        
        NSLog("✅ Got handleGeneratePasswordRequest")
        
        let response = generatePassword( request: request);
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }
    
    func handleGetNewEntryDefaultsRequest(_ encryptedRequest: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = encryptedRequest.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let request = try? decoder.decode(GetNewEntryDefaultsRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode GetNewEntryDefaultsRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode GetNewEntryDefaultsRequest from message JSON")
        }
        
        NSLog("✅ Got GetNewEntryDefaultsRequest [databaseId = %@]", request.databaseId)
        
        let response = getNewEntryDefaults( request: request);
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: encryptedRequest.clientPublicKey, keyPair: keyPair)
    }
    
    
    
    func convertNodeToAutoFillCredential(_ database : MacDatabasePreferences, _ model : Model, _ node: Node) -> AutoFillCredential {
        var iconBase64Encoded = ""
        
        if let b64 = getNodeIconPngData(node) {
            iconBase64Encoded = String(format: "data:image/png;base64,%@", b64)
        }
        

        
        let credential = AutoFillCredential(uuid: node.uuid,
                                            databaseId: database.uuid,
                                            title: model.dereference(node.title, node: node),
                                            username: model.dereference(node.fields.username, node: node),
                                            password: model.dereference(node.fields.password, node: node),
                                            url: model.dereference(node.fields.url, node: node),
                                            totp: node.fields.otpToken?.url(true).absoluteString ?? "",
                                            icon: iconBase64Encoded,
                                            customFields: [:], 
                                            databaseName: database.nickName,
                                            tags: [],
                                            favourite: model.isFavourite(node.uuid))
        
        return credential
    }
    
    func getNodeIconPngData(_ node: Node) -> String? {
        
        
        let image = NodeIconHelper.getIconFor(node, predefinedIconSet: .sfSymbols, format: .keePass4) 
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSLog("🔴 Could not get cgimage for node icon")
            return nil
        }
        
        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = image.size 
        
        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            NSLog("🔴 Could not newRep.representation for new icon")
            return nil
        }
        
        return pngData.base64EncodedString()
    }
    
    func copyUsername ( model : Model, itemId : UUID ) {
        guard let item = model.getItemBy(itemId) else {
            NSLog("🔴 Could not find item to copy!")
            return
        }
        
        dereferenceAndCopy(model: model, text: item.fields.username , item: item)
    }
    
    func copyPassword ( model : Model, itemId : UUID ) {
        guard let item = model.getItemBy(itemId) else {
            NSLog("🔴 Could not find item to copy!")
            return
        }
        
        dereferenceAndCopy(model: model, text: item.fields.password , item: item)
    }
    
    func copyTotp ( model : Model, itemId : UUID, explicitRequest : Bool ) {
        guard explicitRequest || model.metadata.autoFillCopyTotp else {
            NSLog("🔴 Not copying TOTP as not configured or not an explicit request")
            return
        }

        guard let item = model.getItemBy(itemId), let token = item.fields.otpToken else {
            NSLog("🔴 Could not find item to copy!")
            return
        }
        
        ClipboardManager.sharedInstance().copyConcealedString(token.password)
        scheduleClipboardClearingTask()
    }
    
    func dereferenceAndCopy ( model : Model, text : String, item : Node ) {
        let deref = model.dereference(text, node: item)
        ClipboardManager.sharedInstance().copyConcealedString(deref)
        scheduleClipboardClearingTask()
    }
    
    func scheduleClipboardClearingTask() {
        if ( Settings.sharedInstance().clearClipboardEnabled ) {
            DispatchQueue.main.async {
                let delegate = NSApplication.shared.delegate as! AppDelegate
                delegate.onStrongboxDidChangeClipboard()
            }
        }
    }
    
    
    
    func createEntry ( request : CreateEntryRequest ) -> CreateEntryResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid)
        else {
            let response = CreateEntryResponse()
            response.error = "Can't find AutoFillEnabled database to Unlock"
            return response
        }

        let parent : Node
        if let groupId = request.groupId, let uuid = UUID(uuidString: groupId),
           let parentGroup = model.getItemBy(uuid) {
            parent = parentGroup
        }
        else {
            parent = model.database.effectiveRootGroup
        }

        let autoFill = Settings.sharedInstance().autoFillNewRecordSettings
    
        let mostPopularEmail = model.database.mostPopularEmail ?? "";
        let actualEmail = autoFill.emailAutoFillMode == .none ? "" : autoFill.emailAutoFillMode == .mostUsed ? mostPopularEmail : autoFill.emailCustomAutoFill;
        let actualNotes = autoFill.notesAutoFillMode == .none ? "" : autoFill.notesAutoFillMode == .clipboard ? getClipboardText() : autoFill.notesCustomAutoFill
        
        let fields = NodeFields(username: request.username ?? "", url: request.url ?? "", password: request.password ?? "", notes: actualNotes, email: actualEmail)
        
        let newNode = Node(asRecord: request.title ?? "", parent: parent, fields: fields, uuid: nil)
        
        if let iconB64 = request.icon,
           let data = Data(base64Encoded: iconB64) {
            let icon = NodeIcon.withCustom(data)
            newNode.icon = icon
        }
        else {
            let useParentGroupIcon = Settings.sharedInstance().useParentGroupIconOnCreate
            
            if ( useParentGroupIcon && !parent.isUsingKeePassDefaultIcon ) {
                newNode.icon = parent.icon;
            }
        }
        
        if !model.addChildren([newNode], destination: parent) {
            let response = CreateEntryResponse()
            response.error =  "Could not create new entry here."
            return response
        }
        
        if !DatabasesCollection.shared.updateAndQueueSync(uuid: prefs.uuid) {
            let response = CreateEntryResponse()
            response.error =  "Could not create new entry here."
            return response
        }
        
        notifyViewsRefresh(uuid: prefs.uuid)
        
        let response = CreateEntryResponse()
        response.uuid = newNode.uuid.uuidString
        
        if let foundNode = model.getItemBy(newNode.uuid) {
            response.credential = convertNodeToAutoFillCredential(prefs, model, foundNode)
        }
        
        return response
    }

    func getGroups ( request : GetGroupsRequest ) -> GetGroupsResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid) else {
            let response = GetGroupsResponse()
            response.error =  "Can't find AutoFillEnabled database to Unlock"
            return response
        }
        
        let summaries = model.database.allActiveGroups.map { grp in
            return GroupSummary( title: getGroupPathDisplayString(model, grp), uuid: grp.uuid.uuidString);
        }

        var sorted = summaries.sorted { n1, n2 in
            return finderStringCompare(n1.title, n2.title ) == .orderedAscending
        }
        
        if model.database.effectiveRootGroup.childRecordsAllowed {
            let title = getGroupPathDisplayString(model, model.database.effectiveRootGroup, rootGroupNameInsteadOfSlash: true)
            let root = GroupSummary( title: title, uuid: model.database.effectiveRootGroup.uuid.uuidString);
            sorted.insert(root, at: 0)
        }
        
        let response = GetGroupsResponse()
            
        response.groups = sorted;
        
        return response
    }

    func generatePassword ( request : GeneratePasswordRequest ) -> GeneratePasswordResponse {
        let pw = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)

        let pw1 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw2 = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        let pw3 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw4 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)
        let pw5 = PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig)

        let alternatives = [pw1, pw2, pw3, pw4, pw5]
        
        return GeneratePasswordResponse(password: pw, alternatives: alternatives)
    }
    
    func getNewEntryDefaults ( request : GetNewEntryDefaultsRequest ) -> GetNewEntryDefaultsResponse {
        guard let prefs = MacDatabasePreferences.getById(request.databaseId), prefs.autoFillEnabled,
              let model = DatabasesCollection.shared.getUnlocked(uuid: prefs.uuid) else {
            let response = GetNewEntryDefaultsResponse( error: "Can't find AutoFillEnabled database to Unlock")
            return response
        }
        
        let defaultConfig = Settings.sharedInstance().autoFillNewRecordSettings;
        
        let mostPopularUsername = model.database.mostPopularUsername ?? "";
        let username = defaultConfig.usernameAutoFillMode == .none ? "" : defaultConfig.usernameAutoFillMode == .mostUsed ? mostPopularUsername : defaultConfig.usernameCustomAutoFill;
        
        let generated = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        
        let password = defaultConfig.passwordAutoFillMode == .none ? "" : defaultConfig.passwordAutoFillMode == .generated ? generated : defaultConfig.passwordCustomAutoFill;
        
        let response = GetNewEntryDefaultsResponse(username: username, password: password, mostPopularUsernames: model.database.mostPopularUsernames)
        
        return response
    }
    
    func getClipboardText() -> String {
        return NSPasteboard.general.string(forType: .string) ?? ""
    }
    
    
    
    func getGroupPathDisplayString( _ model : Model, _ node : Node, rootGroupNameInsteadOfSlash: Bool = false) -> String {
        return model.database.getPathDisplayString(node, includeRootGroup: true, rootGroupNameInsteadOfSlash: rootGroupNameInsteadOfSlash, includeFolderEmoji: false, joinedBy: "/")
    }
    
    func notifyViewsRefresh( uuid : String ) {
        DatabasesCollection.shared.notifyViewsToRefresh(uuid: uuid);
    }
}
