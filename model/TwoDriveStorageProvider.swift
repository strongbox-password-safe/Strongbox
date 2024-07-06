//
//  TwoDriveStorageProvider.swift
//  Strongbox
//
//  Created by Strongbox on 03/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import MSAL
import MSGraphClientSDK // TODO: Remove dependency soon

class TwoDriveStorageProvider: NSObject, SafeStorageProvider {
    typealias AuthenticateCompletionHandler = (_ client: MSHTTPClient?, _ msalResult: MSALResult?, _ userInteractionRequired: Bool, _ userCancelled: Bool, _ error: Error?) -> Void


    static let SmallUploadFileSize = 10 * 320 * 1024 


    @objc
    static let sharedInstance = TwoDriveStorageProvider()

    static let scopes: [String] = ["Files.ReadWrite.All"]
    static let clientID = "1ac62c81-8569-4a96-9874-6e2941a00d17"

    var application: MSALPublicClientApplication?

    private let nextGenURLSession: URLSession

    static let NextGenRequestTimeout = 20.0 
    static let NextGenResourceTimeout = 10 * 60.0 

    override private init() {
        let sessionConfig = URLSessionConfiguration.ephemeral

        sessionConfig.allowsCellularAccess = true
        sessionConfig.waitsForConnectivity = false
        sessionConfig.timeoutIntervalForRequest = TwoDriveStorageProvider.NextGenRequestTimeout
        sessionConfig.timeoutIntervalForResource = TwoDriveStorageProvider.NextGenResourceTimeout
        #if os(iOS)
            sessionConfig.multipathServiceType = .none
        #endif

        nextGenURLSession = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: TwoDriveStorageProvider.NextGenOperationQueue)

        super.init()

        let config = MSALPublicClientApplicationConfig(clientId: TwoDriveStorageProvider.clientID, redirectUri: "strongbox-twodrive:

        do {
            application = try MSALPublicClientApplication(configuration: config) 
        } catch {
            NSLog("🔴 Could not load application OneDrive: [%@]", String(describing: error))
        }
    }

    var storageId: StorageProvider {
        .kTwoDrive
    }

    var providesIcons: Bool {
        false
    }

    var browsableNew: Bool {
        true
    }

    var browsableExisting: Bool {
        true
    }

    var rootFolderOnly: Bool {
        false
    }

    var supportsConcurrentRequests: Bool {
        false
    }

    var defaultForImmediatelyOfferOfflineCache: Bool {
        false
    }

    var privacyOptInRequired: Bool {
        true
    }

    var spinnerUI: SpinnerUI {
        CrossPlatformDependencies.defaults().spinnerUi
    }

    var appPreferences: ApplicationPreferences {
        CrossPlatformDependencies.defaults().applicationPreferences
    }

    func delete(_: METADATA_PTR, completion _: @escaping (Error?) -> Void) {
        
    }

    func loadIcon(_: NSObject, viewController _: VIEW_CONTROLLER_PTR, completion _: @escaping (IMAGE_TYPE_PTR) -> Void) {
        
    }

    func getDatabasePreferences(_ nickName: String, providerData: NSObject) -> METADATA_PTR? {
        guard let dItem = providerData as? DriveItem,
              let json = getJsonFileIdentifier(driveItem: dItem)
        else {
            NSLog("🔴 Not a proper provider data for OneDrive.")
            return nil
        }

        #if os(iOS)
            let ret = DatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileName: dItem.name!, fileIdentifier: json)

            return ret
        #else

            guard let filename = dItem.name else {
                NSLog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            var components = URLComponents()
            components.scheme = kStrongboxGoogleDriveUrlScheme
            components.path = String(format: "/host/%@", filename) 

            guard let url = components.url else {
                NSLog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            let metadata = MacDatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileUrl: url, storageInfo: json)

            components.queryItems = [URLQueryItem(name: "uuid", value: metadata.uuid)]

            guard let url2 = components.url else {
                NSLog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            metadata.fileUrl = url2

            return metadata
        #endif
    }

    func getJsonFileIdentifier(driveItem: DriveItem) -> String? {
        guard let driveId = driveItem.driveId, let parentItemId = driveItem.parentItemId else {
            NSLog("🔴 Missing required driveId or parentItemId in getJsonFileIdentifier")
            return nil
        }

        var dp = ["driveId": driveId,
                  "parentFolderId": parentItemId]

        if let accountIdentifier = driveItem.accountIdentifier {
            dp["accountIdentifier"] = accountIdentifier
        }

        if let username = driveItem.username {
            dp["username"] = username
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dp, options: []),
              let json = String(data: data, encoding: .utf8)
        else {
            NSLog("🔴 Could not encode file identifier for OneDrive.")
            return nil
        }

        return json
    }

    func create(_ nickName: String, fileName: String, data: Data, parentFolder: NSObject?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (METADATA_PTR?, Error?) -> Void) {
        let driveItem = parentFolder as? DriveItem

        

        authenticate(accountIdentifier: driveItem?.accountIdentifier, viewController: viewController) { [weak self] _, msalResult, _, userCancelled, error in
            guard let self else {
                return
            }

            if userCancelled { 
                completion(nil, nil)
                return
            }

            if let error {
                NSLog("🔴 Could not authenticate: [%@]", String(describing: error))
                completion(nil, error)
                return
            }

            guard let msalResult else {
                completion(nil, Utils.createNSError("nil MSHTTPClient returned", errorCode: 346))
                return
            }

            self.createWithMSALResult(driveItem, nickName, fileName, msalResult: msalResult, data, viewController, completion: completion)
        }
    }

    func createWithMSALResult(_ parentDriveItem: DriveItem?, _ nickName: String, _ fileName: String, msalResult: MSALResult, _ data: Data, _ viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (METADATA_PTR?, Error?) -> Void) {
        if let viewController {
            spinnerUI.show(NSLocalizedString("storage_provider_status_authenticating_creating", comment: "Creating..."), viewController: viewController)
        }

        Task {
            defer {
                if viewController != nil {
                    self.spinnerUI.dismiss()
                }
            }

            do {
                let driveItem = try await uploadNewFile(parentDriveItem: parentDriveItem, filename: fileName, data: data, msalResult: msalResult)

                let metadata = self.getDatabasePreferences(nickName, providerData: driveItem)

                completion(metadata, nil)
            } catch {
                NSLog("🔴 OneDrive create error: [%@]", String(describing: error))
                completion(nil, error)
                return
            }
        }
    }

    func pullDatabase(_ safeMetaData: METADATA_PTR, interactiveVC viewController: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        if viewController != nil {
            spinnerUI.show(NSLocalizedString("generic_status_sp_locating_ellipsis", comment: "Locating..."), viewController: viewController)
        }

        findDriveItemFromMetadata(metadata: safeMetaData, viewController: viewController) { [weak self] driveItem, userInteractionRequired, error in
            guard let self else {
                return
            }

            if viewController != nil {
                self.spinnerUI.dismiss()
            }

            if let error {
                completion(.readResultError, nil, nil, error)
            } else if userInteractionRequired {
                completion(.readResultBackgroundReadButUserInteractionRequired, nil, nil, nil)
            } else if driveItem == nil {
                completion(.readResultError, nil, nil, Utils.createNSError("🔴 Drive Item is nil!", errorCode: 453))
            } else {
                self.read(withProviderData: driveItem, viewController: viewController, options: options, completion: completion)
            }
        }
    }

    func read(withProviderData providerData: NSObject?, viewController: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion completionHandler: @escaping StorageProviderReadCompletionBlock) {
        guard let driveItem = providerData as? DriveItem,
              let driveId = driveItem.driveId,
              let parentFolderId = driveItem.itemId
        else {
            NSLog("🔴 Could not convert provider data to Listing State")
            completionHandler(.readResultError, nil, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

        authenticate(accountIdentifier: driveItem.accountIdentifier, viewController: viewController) { [weak self] client, _, userInteractionRequired, userCancelled, error in
            guard let self else {
                return
            }

            if let error {
                completionHandler(.readResultError, nil, nil, error)
                return
            }

            if userCancelled {
                completionHandler(.readResultError, nil, nil, nil)
                return
            }

            if userInteractionRequired {
                completionHandler(.readResultBackgroundReadButUserInteractionRequired, nil, nil, nil)
                return
            }

            if let dtMod2 = options.onlyIfModifiedDifferentFrom,
               let dtMod = driveItem.lastModifiedDateTime as NSDate?
            {
                if dtMod.isEqualToDate(withinEpsilon: dtMod2) {
                    completionHandler(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                    return
                }
            }

            if let viewController {
                self.spinnerUI.show(NSLocalizedString("storage_provider_status_reading", comment: "A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading..."), viewController: viewController)
            }

            let request = String(format: "/drives/%@/items/%@/content", driveId, parentFolderId)
            let url = URL(string: "\(MSGraphBaseURL)\(request)")!

            let dataTask = MSURLSessionDownloadTask(request: NSMutableURLRequest(url: url), client: client) { [weak self] url, _, graphError in
                guard let self else {
                    return
                }

                if viewController != nil {
                    self.spinnerUI.dismiss()
                }

                if let graphError {
                    NSLog("🔴 Read Error: [%@]", String(describing: graphError))
                    completionHandler(.readResultError, nil, nil, graphError)
                    return
                }

                guard let url else {
                    NSLog("🔴 Read Error")
                    completionHandler(.readResultError, nil, nil, nil)
                    return
                }

                let data = FileManager.default.contents(atPath: url.path)

                completionHandler(.readResultSuccess, data, driveItem.lastModifiedDateTime, nil)
            }

            dataTask?.execute()
        }
    }

    func pushDatabase(_ safeMetaData: METADATA_PTR, interactiveVC viewController: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        if viewController != nil {
            spinnerUI.show(NSLocalizedString("generic_status_sp_locating_ellipsis", comment: "Locating..."), viewController: viewController)
        }

        findDriveItemFromMetadata(metadata: safeMetaData, viewController: viewController) { [weak self] driveItem, userInteractionRequired, error in
            guard let self else {
                return
            }

            if viewController != nil {
                self.spinnerUI.dismiss()
            }

            if let error {
                completion(.updateResultError, nil, error)
            } else if userInteractionRequired {
                completion(.updateResultUserInteractionRequired, nil, nil)
            } else if driveItem == nil {
                completion(.updateResultError, nil, Utils.createNSError("🔴 Drive Item is nil!", errorCode: 453))
            } else {
                self.write(withProviderData: driveItem, viewController: viewController, data: data, completion: completion)
            }
        }
    }

    func write(withProviderData providerData: NSObject?, viewController: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        guard let driveItem = providerData as? DriveItem else {
            NSLog("🔴 Could not convert provider data to Listing State")
            completion(.updateResultError, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

        authenticate(accountIdentifier: driveItem.accountIdentifier, viewController: viewController) { [weak self] client, msalResult, userInteractionRequired, userCancelled, error in
            guard let self else {
                return
            }

            if let error {
                completion(.updateResultError, nil, error)
                return
            }

            if userCancelled {
                completion(.updateResultError, nil, nil)
                return
            }

            if userInteractionRequired {
                completion(.updateResultUserInteractionRequired, nil, nil)
                return
            }

            guard let msalResult else {
                completion(.updateResultError, nil, nil)
                return
            }

            writeWithMSALResult(client: client, msalResult: msalResult, driveItem: driveItem, data: data, viewController: viewController, completion: completion)
        }
    }

    func writeWithMSALResult(client: MSHTTPClient?, msalResult: MSALResult, driveItem: DriveItem, data: Data, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping StorageProviderUpdateCompletionBlock) {
        if !appPreferences.useNextGenOneDriveAPI {
            guard let client else {
                completion(.updateResultError, nil, nil)
                return
            }

            upload(driveItem: driveItem, msalResult: msalResult, data: data, client: client, viewController: viewController, completion: completion)
        } else {
            uploadNewOrder(driveItem: driveItem, msalResult: msalResult, data: data, viewController: viewController, completion: completion)
        }
    }

    func uploadNewOrder(driveItem: DriveItem, msalResult: MSALResult, data: Data, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping StorageProviderUpdateCompletionBlock) {
        
        

        if let viewController {
            spinnerUI.show(NSLocalizedString("storage_provider_status_syncing", comment: "Syncing..."), viewController: viewController)
        }

        Task {
            defer {
                if viewController != nil {
                    self.spinnerUI.dismiss()
                }
            }

            do {
                let driveItem = try await self.uploadToExistingFile(driveItem: driveItem, data: data, msalResult: msalResult)

                completion(.updateResultSuccess, driveItem.lastModifiedDateTime, nil)
            } catch {
                NSLog("🔴 OneDrive upload error: [%@]", String(describing: error))
                completion(.updateResultError, nil, error)
                return
            }
        }
    }

    func upload(driveItem: DriveItem, msalResult: MSALResult, data: Data, client: MSHTTPClient, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping StorageProviderUpdateCompletionBlock) {
        if data.count <= TwoDriveStorageProvider.SmallUploadFileSize {
            uploadSmall(driveItem: driveItem, data: data, client: client, viewController: viewController, completion: completion) 
        } else {



            uploadNewOrder(driveItem: driveItem, msalResult: msalResult, data: data, viewController: viewController, completion: completion)
        }
    }

    func uploadSmall(driveItem: DriveItem, data: Data, client: MSHTTPClient, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping StorageProviderUpdateCompletionBlock) {
        if let viewController {
            spinnerUI.show(NSLocalizedString("storage_provider_status_syncing", comment: "Syncing..."), viewController: viewController)
        }

        guard let driveId = driveItem.driveId,
              let itemId = driveItem.itemId
        else {
            NSLog("🔴 Could not convert provider data to Listing State")
            completion(.updateResultError, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

        let accountIdentifier = driveItem.accountIdentifier
        let username = driveItem.username
        let request = String(format: "/drives/%@/items/%@/content", driveId, itemId)
        let url = URL(string: "\(MSGraphBaseURL)\(request)")!

        let mutableRequest = NSMutableURLRequest(url: url)
        mutableRequest.httpMethod = "PUT" 

        let task = MSURLSessionUploadTask(request: mutableRequest, data: data, client: client) { [weak self] data, _, error in
            if viewController != nil {
                self?.spinnerUI.dismiss()
            }

            self?.handleUploadResponse(accountIdentifier, username, data, error, completion)
        }

        task?.execute()
    }

    func handleUploadResponse(_ accountIdentifier: String?, _ username: String?, _ data: Data?, _ error: Error?, _ completion: @escaping StorageProviderUpdateCompletionBlock) {
        if let error {
            NSLog("🔴 Error uploading [%@]", String(describing: error))
            completion(.updateResultError, nil, error)
            return
        }

        guard let data,
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject,
              let item = TwoDriveStorageProvider.convertOdataDriveItemToBrowserItem(accountIdentifier, username, dictionary),
              let driveItem = item.providerData as? DriveItem
        else {
            NSLog("🔴 Error uploading - Could not read Upload response")
            completion(.updateResultError, nil, Utils.createNSError("", errorCode: 346))
            return
        }

        completion(.updateResultSuccess, driveItem.lastModifiedDateTime, nil)
    }

    func getModDate(_ safeMetaData: METADATA_PTR, completion: @escaping StorageProviderGetModDateCompletionBlock) {
        findDriveItemFromMetadata(metadata: safeMetaData, viewController: nil) { driveItem, userInteractionRequired, error in
            NSLog("driveItem = %@, error = %@", String(describing: driveItem?.lastModifiedDateTime), String(describing: error))

            if userInteractionRequired {
                completion(true, nil, Utils.createNSError("User Interaction Required from getModDate", errorCode: 346))
            } else {
                completion(true, driveItem?.lastModifiedDateTime, error)
            }
        }
    }

    func list(_ parentFolder: NSObject?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        let driveItem = parentFolder as? DriveItem

        authenticate(accountIdentifier: driveItem?.accountIdentifier, viewController: viewController) { [weak self] client, msalResult, userInteractionRequired, userCancelled, error in
            guard let self else {
                return
            }

            if userCancelled || userInteractionRequired {
                completion(true, [], nil)
                return
            }

            if let error {
                NSLog("🔴 List error: [%@]", String(describing: error))
                completion(false, [], error)
                return
            }

            guard let client, let msalResult else {
                NSLog("🔴 List error: [%@]", String(describing: error))
                completion(false, [], Utils.createNSError("Nil MSHTTPClient", errorCode: 346))
                return
            }

            let authenticatedDriveItem: DriveItem
            if let driveItem {
                authenticatedDriveItem = driveItem
            } else {
                authenticatedDriveItem = DriveItem(accountIdentifier: msalResult.account.identifier, username: msalResult.account.username, name: nil, itemId: nil, parentItemId: nil, driveId: nil, lastModifiedDateTime: nil, path: nil)
            }

            let url = self.getListingRequestUrlFromDriveItem(driveItem: authenticatedDriveItem)

            self.listItemsRecursive(url: url, client: client, driveItem: authenticatedDriveItem, itemsSoFar: [], completion: completion)
        }
    }

    func listItemsRecursive(url: URL, client: MSHTTPClient, driveItem: DriveItem, itemsSoFar: [StorageBrowserItem], completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        let task = MSURLSessionDataTask(request: NSMutableURLRequest(url: url), client: client) { [weak self] (data: Data?, _: URLResponse?, graphError: Error?) in
            guard let self else {
                return
            }

            if let graphError {
                NSLog("🔴 error listing: [%@]", String(describing: graphError))
                completion(false, [], graphError)
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                  let items = json["value"] as? [AnyObject]
            else {
                NSLog("🔴 error listing - could not read response...")
                completion(false, [], Utils.createNSError("🔴 error listing - could not read response...", errorCode: 346))
                return
            }

            let nextLink = json["@odata.nextLink"] as? String

            self.processListingItems(items: items, nextLink: nextLink, client: client, driveItem: driveItem, itemsSoFar: itemsSoFar, completion: completion)
        }

        task?.execute()
    }

    func processListingItems(items: [AnyObject], nextLink: String?, client: MSHTTPClient, driveItem: DriveItem, itemsSoFar: [StorageBrowserItem], completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        let browserItems = items.compactMap { TwoDriveStorageProvider.convertOdataDriveItemToBrowserItem(driveItem.accountIdentifier, driveItem.username, $0) }

        var accumulated = itemsSoFar
        accumulated.append(contentsOf: browserItems)

        if let nextLink {

            listItemsRecursive(url: URL(string: nextLink)!, client: client, driveItem: driveItem, itemsSoFar: accumulated, completion: completion)
        } else {
            completion(false, accumulated, nil)
        }
    }

    class func convertOdataDriveItemToBrowserItem(_ accountIdentifier: String?, _ username: String?, _ item: AnyObject) -> StorageBrowserItem? {
        guard let item = item as? [String: AnyObject],
              let name = item["name"] as? String,
              let lastModifiedDateTimeString = item["lastModifiedDateTime"] as? String,
              let lastModifiedDateTime = NSDate.microsoftGraphDate(from: lastModifiedDateTimeString),
              let parentReference = item["parentReference"] as? [String: AnyObject],
              let parentId = parentReference["id"] as? String,
              let path = parentReference["path"] as? String
        else {
            NSLog("🔴 Could not get required fields...")
            return nil
        }

        let isFolder: Bool
        let fooDriveId: String
        let fooId: String

        if let remoteItem = item["remoteItem"] as? [String: AnyObject] {
            guard let pr = remoteItem["parentReference"] as? [String: AnyObject],
                  let driveId = pr["driveId"] as? String,
                  let id = remoteItem["id"] as? String
            else {
                NSLog("🔴 Could not get required fields...")
                return nil
            }

            isFolder = remoteItem["folder"] != nil
            fooDriveId = driveId
            fooId = id
        } else {
            guard let id = item["id"] as? String,
                  let driveId = parentReference["driveId"] as? String
            else {
                NSLog("🔴 Could not get required fields...")
                return nil
            }

            isFolder = item["folder"] != nil
            fooDriveId = driveId
            fooId = id
        }

        let parentFolder = DriveItem(accountIdentifier: accountIdentifier,
                                     username: username,
                                     name: name,
                                     itemId: fooId,
                                     parentItemId: parentId,
                                     driveId: fooDriveId,
                                     lastModifiedDateTime: lastModifiedDateTime as Date,
                                     path: path)

        return StorageBrowserItem(name: name, identifier: fooId, folder: isFolder, providerData: parentFolder)
    }

    

    func authenticate(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping AuthenticateCompletionHandler) {
        guard let application else {
            NSLog("🔴 Could not load or find Application!")
            completion(nil, nil, false, false, Utils.createNSError("🔴 Could not load or find Application!", errorCode: 346))
            return
        }

        
        






















        if let accountIdentifier,
           let account = try? application.account(forIdentifier: accountIdentifier)
        {
            application.acquireTokenSilent(with: MSALSilentTokenParameters(scopes: TwoDriveStorageProvider.scopes, account: account)) { [weak self] result, error in
                guard let self else {
                    return
                }

                if let error {
                    let nsError = error as NSError
                    if nsError.domain == MSALErrorDomain, nsError.code == MSALError.interactionRequired.rawValue {
                        self.interactiveAuthenticate(accountIdentifier: accountIdentifier, viewController: viewController, completion: completion)
                    } else {
                        completion(nil, nil, false, false, error)
                    }

                    return
                }

                guard let result,
                      let client = MSClientFactory.createHTTPClient(with: SimpleAccessTokenAuthProvider(accessToken: result.accessToken))
                else {
                    NSLog("🔴 Error in Interactive Logon - OneDrive")
                    completion(nil, nil, false, false, Utils.createNSError("🔴 Error in Logon", errorCode: 346))
                    return
                }

                completion(client, result, false, false, nil)
            }
        } else {
            interactiveAuthenticate(accountIdentifier: accountIdentifier, viewController: viewController, completion: completion)
        }
    }

    func interactiveAuthenticate(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping AuthenticateCompletionHandler) {
        guard let application else {
            NSLog("🔴 Could not load or find Application!")
            completion(nil, nil, false, false, Utils.createNSError("🔴 Could not load or find Application!", errorCode: 346))
            return
        }

        guard let viewController else {
            NSLog("⚠️ Interactive Logon required but Background Call...")
            completion(nil, nil, true, false, nil)
            return
        }

        #if os(iOS)
            let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        #else
            let webviewParameters = MSALWebviewParameters()
        #endif

        let interactiveParameters = MSALInteractiveTokenParameters(scopes: TwoDriveStorageProvider.scopes, webviewParameters: webviewParameters)

        if let accountIdentifier {
            interactiveParameters.account = try? application.account(forIdentifier: accountIdentifier)
            
        }

        if interactiveParameters.account == nil {
            interactiveParameters.promptType = .selectAccount
        }

        #if os(iOS)
            let delay = Utils.isAppInForeground ? 0.1 : 1 
        #else
            let delay = 0.0
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            application.acquireToken(with: interactiveParameters, completionBlock: { result, error in
                if let error, (error as NSError).code == MSALError.userCanceled.rawValue {
                    completion(nil, nil, false, true, nil)
                    return
                }

                guard error == nil,
                      let result,
                      let client = MSClientFactory.createHTTPClient(with: SimpleAccessTokenAuthProvider(accessToken: result.accessToken))
                else {
                    let err = error == nil ? Utils.createNSError("🔴 Error in Interactive Logon", errorCode: 346) : error
                    NSLog("🔴 Error in Interactive Logon - OneDrive [%@]", String(describing: err))
                    completion(nil, nil, false, false, err)
                    return
                }

                completion(client, result, false, false, nil)
            })
        }
    }

    @objc
    func signOutAll() {
        guard let application else {
            NSLog("🔴 Could not load or find Application!")
            return
        }

        application.accountsFromDevice(for: MSALAccountEnumerationParameters()) { accounts, error in
            guard let accounts else {
                return
            }

            for account in accounts {


                application.signout(with: account, signoutParameters: MSALSignoutParameters()) { _, error in
                    if let error {
                        NSLog("🔴 Error Signing out [%@]", String(describing: error))
                    }
                }
            }
        }
    }

    func getListingRequestUrlFromDriveItem(driveItem: DriveItem) -> URL {
        getListingRequestUrlFromDriveItem(driveId: driveItem.driveId, folderId: driveItem.itemId)
    }

    func getListingRequestUrlFromDriveItem(driveId: String?, folderId: String?) -> URL {
        let request: String

        if let driveId, let parentFolderId = folderId {
            request = String(format: "/drives/%@/items/%@/children", driveId, parentFolderId)
        } else if let parentFolderId = folderId {
            request = String(format: "/me/drive/items/%@/children", parentFolderId)
        } else {
            request = "/me/drive/root/children"
        }



        return URL(string: "\(MSGraphBaseURL)\(request)")!
    }

    func findDriveItemFromMetadata(metadata: METADATA_PTR, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (_ driveItem: DriveItem?, _ userInteractionRequired: Bool, _ error: Error?) -> Void) {
        #if os(iOS)
            let json = metadata.fileIdentifier
        #else
            let json = metadata.storageInfo ?? "{}"
        #endif

        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
              let driveId = obj["driveId"] as? String,
              let parentFolderId = obj["parentFolderId"] as? String
        else {
            NSLog("🔴 Could not decode the fileIdentifier")
            completion(nil, false, Utils.createNSError("🔴 Could not decode the fileIdentifier", errorCode: 123_456))
            return
        }

        let accountIdentifier = obj["accountIdentifier"] as? String
        let url = getListingRequestUrlFromDriveItem(driveId: driveId, folderId: parentFolderId)

        authenticate(accountIdentifier: accountIdentifier, viewController: viewController, completion: { [weak self] client, msalResult, userInteractionRequired, userCancelled, error in
            if let error {
                NSLog("🔴 Could not authenticate [%@]", String(describing: error))
                completion(nil, userInteractionRequired, error)
                return
            }

            if userCancelled {
                completion(nil, false, nil)
                return
            }

            if userInteractionRequired {
                completion(nil, userInteractionRequired, error)
                return
            }

            guard let client, let msalResult else {
                completion(nil, false, Utils.createNSError("nil MSHTTPClient returned", errorCode: 346))
                return
            }

            self?.findDriveItemFromMetadata2(metadata: metadata,
                                             viewController: viewController,
                                             accountIdentifier: accountIdentifier,
                                             username: msalResult.account.username,
                                             url: url,
                                             client: client,
                                             completion: completion)
        })
    }

    func findDriveItemFromMetadata2(metadata: METADATA_PTR,
                                    viewController: VIEW_CONTROLLER_PTR?,
                                    accountIdentifier: String?,
                                    username: String?,
                                    url: URL,
                                    client: MSHTTPClient,
                                    completion: @escaping (_ driveItem: DriveItem?, _ userInteractionRequired: Bool, _ error: Error?) -> Void)
    {
        let task = MSURLSessionDataTask(request: NSMutableURLRequest(url: url), client: client) { [weak self] data, _, graphError in
            if let graphError {
                NSLog("🔴 Error making graph request: [%@]", String(describing: graphError))
                completion(nil, false, graphError)
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                  let items = json["value"] as? [AnyObject]
            else {




                NSLog("🔴 Could not decode json, or get expected value object, from response in findDriveItem.")
                completion(nil, false, Utils.createNSError("🔴 Could not decode json, or get expected value object, from response in findDriveItem.", errorCode: 321_334))
                return
            }

            let browserItems = items.compactMap { TwoDriveStorageProvider.convertOdataDriveItemToBrowserItem(accountIdentifier, username, $0) }

            #if os(iOS)
                let filename = metadata.fileName
            #else
                let filename = metadata.fileUrl.lastPathComponent
            #endif

            if let found = browserItems.first(where: { $0.name.compare(filename) == .orderedSame }) {
                guard let driveItem = found.providerData as? DriveItem else {
                    NSLog("🔴 Could not get DriveItem from provider data.")
                    completion(nil, false, Utils.createNSError("🔴 Could not get DriveItem from provider data.", errorCode: 321_334))
                    return
                }

                completion(driveItem, false, nil)
            } else if let nextLink = json["@odata.nextLink"] as? String,
                      let nextLinkUrl = URL(string: nextLink)
            {
                self?.findDriveItemFromMetadata2(metadata: metadata,
                                                 viewController: viewController,
                                                 accountIdentifier: accountIdentifier,
                                                 username: username,
                                                 url: nextLinkUrl,
                                                 client: client,
                                                 completion: completion)
            } else {
                NSLog("Could not locate the database file. Has it been renamed or moved")
                completion(nil, false, Utils.createNSError("Could not locate the database file. Has it been renamed or moved?", errorCode: 45))
            }
        }

        task?.execute()
    }

    class DriveItem: NSObject {
        var accountIdentifier: String?
        var username: String?
        let parentItemId: String?
        let itemId: String?
        let driveId: String?
        let name: String?
        let lastModifiedDateTime: Date?
        let path: String?

        init(accountIdentifier: String?, username: String?, name: String?, itemId: String?, parentItemId: String?, driveId: String?, lastModifiedDateTime: Date?, path: String?) {
            self.accountIdentifier = accountIdentifier
            self.username = username
            self.name = name
            self.itemId = itemId
            self.parentItemId = parentItemId
            self.driveId = driveId
            self.lastModifiedDateTime = lastModifiedDateTime
            self.path = path
        }
    }

    class SimpleAccessTokenAuthProvider: NSObject, MSAuthenticationProvider {
        private var currentAccessToken: String

        init(accessToken: String) {
            currentAccessToken = accessToken
        }

        func getAccessToken(for _: MSAuthenticationProviderOptions!, andCompletion completion: ((String?, Error?) -> Void)!) {
            completion(currentAccessToken, nil)
        }
    }

    enum StrongboxGraphOneDriveLargeFileUploadTask {
        static func create(driveId: String, itemId: String, fileData: Data, httpClient: MSHTTPClient, completionHandler: @escaping OneDriveLargeFileUploadTaskInitCompletionHandler) {
            let createSessionRequest = createUploadSessionRequest(driveId: driveId, itemId: itemId)

            MSGraphOneDriveLargeFileUploadTask.createUploadSession(from: createSessionRequest, andHTTPClient: httpClient) { data, response, error in
                if let error {
                    completionHandler(nil, nil, response, error)
                } else if let data = data as? Data, let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] {
                    let task = MSGraphOneDriveLargeFileUploadTask(client: httpClient,
                                                                  fileData: fileData,
                                                                  uploadSessionDictionary: dictionary,
                                                                  andChunkSize: fileData.count) 

                    completionHandler(task, data, response, error)
                } else {
                    completionHandler(nil, nil, response, error)
                }
            }
        }

        static func createUploadSessionRequest(driveId: String, itemId: String) -> NSMutableURLRequest {
            let oneDriveUrlString = String(format: "%@/drives/%@/items/%@/createUploadSession", MSGraphBaseURL, driveId, itemId)

            let urlRequest = NSMutableURLRequest(url: URL(string: oneDriveUrlString)!)
            urlRequest.httpMethod = "POST"

            return urlRequest
        }
    }
}

extension TwoDriveStorageProvider {
    private static let NextGenOperationQueue: OperationQueue = {
        let queue = OperationQueue()

        queue.name = "com.markmcguill.strongbox.OneDriveStorageProvider"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4

        return queue
    }()

    enum TwoDriveStorageProviderError: Error {
        case invalidUploadUrl(detail: String)
        case unexpectedResponse(detail: String)
        case unexpectedResponseCode(code: Int, detail: String)
        case couldNotGetDriveItemUrl
        case couldNotBuildEscapedFilename
        case couldNotConvertOdataDriveItem
        case couldNotGetModDateAfterUpload
        case couldNotReadDriveOrParentItemId
    }

    enum OneDriveAPIHTTPParams {
        static let authorization = "Authorization"
        static let contentLength = "Content-Length"
        static let contentRange = "Content-Range"
        static let contentType = "Content-Type"
    }

    private struct CreateUploadSessionResponse: Codable {
        let uploadUrl: String
    }

    static let GraphBaseURL = "https:

    func getFileUploadRequestUrl(driveItem: DriveItem) -> URL? {
        
        
        
        
        

        guard let driveId = driveItem.driveId,
              let itemId = driveItem.itemId
        else {
            NSLog("🔴 Could not convert provider data to Listing State")
            return nil
        }

        let oneDriveUrlString = String(format: "%@/drives/%@/items/%@/content", TwoDriveStorageProvider.GraphBaseURL, driveId, itemId)

        return URL(string: oneDriveUrlString)
    }

    func getNewFileUploadRequestUrl(parentDriveItem: DriveItem?, escapedFileName: String) -> URL? {
        
        
        
        
        

        let path: String

        if let parentDriveItem {
            guard let driveId = parentDriveItem.driveId,
                  let parentItemId = parentDriveItem.itemId
            else {
                NSLog("🔴 Could not get driveId or parentItemId")
                return nil
            }

            path = String(format: "/drives/%@/items/%@:/%@:/content", driveId, parentItemId, escapedFileName)
        } else {
            path = String(format: "/me/drive/items/root:/%@:/content", escapedFileName)
        }

        let oneDriveUrlString = String(format: "%@/%@", TwoDriveStorageProvider.GraphBaseURL, path)

        return URL(string: oneDriveUrlString)
    }

    func uploadToExistingFile(driveItem: DriveItem, data: Data, msalResult: MSALResult) async throws -> DriveItem {
        guard let requestUrl = getFileUploadRequestUrl(driveItem: driveItem) else {
            NSLog("🔴 updateExistingFile - Could not get request URL")
            throw TwoDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let urlRequest = getAuthenticatedUrlRequest(msalResult: msalResult, url: requestUrl, method: "PUT", contentType: "text/plain")

        return try await uploadWithRequest(accountIdentifier: driveItem.accountIdentifier, username: driveItem.username, urlRequest: urlRequest, data: data)
    }

    func uploadNewFile(parentDriveItem: DriveItem?, filename: String, data: Data, msalResult: MSALResult) async throws -> DriveItem {
        guard let escapedFileName = (filename as NSString).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            NSLog("🔴 Could not build/escape filename")
            throw TwoDriveStorageProviderError.couldNotBuildEscapedFilename
        }

        guard let requestUrl = getNewFileUploadRequestUrl(parentDriveItem: parentDriveItem, escapedFileName: escapedFileName) else {
            NSLog("🔴 uploadNewFile - Could not get request URL")
            throw TwoDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let urlRequest = getAuthenticatedUrlRequest(msalResult: msalResult, url: requestUrl, method: "PUT", contentType: "text/plain")

        return try await uploadWithRequest(msalResult: msalResult, urlRequest: urlRequest, data: data)
    }

    func uploadWithRequest(msalResult: MSALResult, urlRequest: URLRequest, data: Data) async throws -> DriveItem {
        try await uploadWithRequest(accountIdentifier: msalResult.account.identifier, username: msalResult.account.username, urlRequest: urlRequest, data: data)
    }

    func uploadWithRequest(accountIdentifier: String?, username: String?, urlRequest: URLRequest, data: Data) async throws -> DriveItem {
        var mutableRequest = urlRequest

        mutableRequest.httpBody = data

        let (jsonData, response) = try await nextGenURLSession.data(for: mutableRequest)

        let driveItem = try validateResponseAndDeserializeDriveItem(accountIdentifier, username, data: jsonData, response: response)

        #if DEBUG
            NSLog("🐞 Upload Content DONE: \(driveItem)")
        #endif

        return driveItem
    }

    func validateResponse(data: Data, response: URLResponse) throws {
        #if DEBUG
            if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
               let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            {
                NSLog("🐞 verifyHttpResponse (HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode))): \(String(decoding: jsonData, as: UTF8.self))")
            } else {
                NSLog("🐞 verifyHttpResponse (HTTP \(String(describing: (response as? HTTPURLResponse)?.statusCode))): BODY NOT JSON!")
            }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwoDriveStorageProviderError.unexpectedResponse(detail: String(describing: response))
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            NSLog("🔴 verifyHttpResponse - Unexpected Response Code \(httpResponse.statusCode) ")
            throw TwoDriveStorageProviderError.unexpectedResponseCode(code: httpResponse.statusCode, detail: String(describing: response))
        }
    }

    func validateResponseAndDeserializeDriveItem(_ accountIdentifier: String?, _ username: String?, data: Data, response: URLResponse) throws -> DriveItem {
        try validateResponse(data: data, response: response)

        guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject,
              let item = TwoDriveStorageProvider.convertOdataDriveItemToBrowserItem(accountIdentifier, username, dictionary),
              let driveItem = item.providerData as? DriveItem
        else {
            throw TwoDriveStorageProviderError.couldNotConvertOdataDriveItem
        }

        return driveItem
    }

    func getAuthenticatedUrlRequest(msalResult: MSALResult, url: URL, method: String, contentType: String) -> URLRequest {
        var urlRequest = URLRequest(url: url)

        urlRequest.timeoutInterval = TwoDriveStorageProvider.NextGenRequestTimeout

        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(msalResult.accessToken)", forHTTPHeaderField: OneDriveAPIHTTPParams.authorization)
        urlRequest.setValue(contentType, forHTTPHeaderField: OneDriveAPIHTTPParams.contentType)

        return urlRequest
    }
}



































































































































































