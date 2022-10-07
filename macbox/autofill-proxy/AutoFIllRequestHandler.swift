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
    
    func handleCopyFieldRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        let decoder = JSONDecoder()
        
        guard let jsonRequest = request.decryptMessage(keyPair: keyPair),
              let data = jsonRequest.data(using: .utf8),
              let copyRequest = try? decoder.decode(CopyFieldRequest.self, from: data) else
        {
            NSLog("🔴 Can't decode CopyFieldRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CopyFieldRequest from message JSON")
        }
        
        guard let dc = NSDocumentController.shared as? DocumentController else {
            NSLog("🔴 Can't get Document Controller")
            return AutoFillEncryptedResponse.error(message: "Can't get Document Controller")
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
        
        guard dc.databaseIsUnlocked(inDocumentWindow: theDatabase),
              let document = dc.document(forDatabase: theDatabase) else {
            NSLog("🔴 This database is not unlocked or error getting document")
            return AutoFillEncryptedResponse.error(message: "This database is not unlocked or error getting document")
        }
        
        switch ( copyRequest.field ) {
        case .totp:
            document.viewModel.copyTotp(copyRequest.nodeId)
        case .username:
            document.viewModel.copyUsername(copyRequest.nodeId)
        case .password:
            document.viewModel.copyPassword(copyRequest.nodeId)
        }
                
        let response = CopyFieldResponse(success: true)
                
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
    }
    
    func handleGetStatusRequest(_ request: AutoFillEncryptedRequest) -> AutoFillEncryptedResponse {
        guard let dc = NSDocumentController.shared as? DocumentController else {
            NSLog("🔴 Can't get Document Controller")
            return AutoFillEncryptedResponse.error(message: "Can't get Document Controller")
        }

        let response = GetStatusResponse()
        
        response.serverVersionInfo = Utils.getAppVersion()
        response.databases = MacDatabasePreferences.allDatabases.map { obj in
            DatabaseSummary(databaseId: obj.uuid, nickName: obj.nickName, autoFillEnabled: obj.autoFillEnabled, locked: !dc.databaseIsUnlocked(inDocumentWindow: obj))
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
                 
        let result = AutoFillCredential(uuid: UUID(), databaseId: UUID().uuidString, title: "Test Entry", username: "mark", password: "abc123", url: "https:
        
        let response = SearchResponse(results: [result])
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
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
        

                 
        guard let dc = NSDocumentController.shared as? DocumentController else {
            NSLog("🔴 Can't decode CredentialsForUrlRequest from message JSON")
            return AutoFillEncryptedResponse.error(message: "Can't decode CredentialsForUrlRequest from message JSON")
        }

        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            database.autoFillEnabled && dc.databaseIsUnlocked(inDocumentWindow: database)
        }
        

        
        var credentials: [AutoFillCredential] = []
        for database in unlockedDatabases {
            guard let document = dc.document(forDatabase: database) else {
                continue
            }
            
            let nodes = document.autoFillUrlCredentialMatches(forUrl: searchRequest.url)
            

            
            let urlCredentialMatches = nodes.map { node in
                convertNodeToAutoFillCredential(database, node)
            }
            
            credentials += urlCredentialMatches
        }
                            
        let response = CredentialsForUrlResponse(results: credentials,unlockedDatabaseCount: unlockedDatabases.count)
        
        let json = AutoFillJsonHelper.toJson(object: response)
        
        return AutoFillEncryptedResponse.successWithResult(resultJson: json, clientPublicKey: request.clientPublicKey, keyPair: keyPair)
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
        }
    }
    
    func convertNodeToAutoFillCredential(_ database : MacDatabasePreferences, _ node: Node) -> AutoFillCredential {
        
        
        
        var iconBase64Encoded = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4
        
        if let b64 = getNodeIconPngData(node) {
            iconBase64Encoded = String(format: "data:image/png;base64,%@", b64)
        }
        

        
        let credential = AutoFillCredential(uuid: node.uuid,
                                            databaseId: database.uuid,
                                            title: node.title,
                                            username: node.fields.username,
                                            password: node.fields.password,
                                            url: node.fields.url,
                                            totp: node.fields.otpToken?.url(true).absoluteString ?? "",
                                            icon: iconBase64Encoded,
                                            customFields: [:])
        
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
}
