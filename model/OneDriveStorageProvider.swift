//
//  OneDriveStorageProvider.swift
//  Strongbox
//
//  Created by Strongbox on 03/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import MSAL

@objc
enum OneDriveNavigationContextMode: Int {
    case initial
    case sharedWithMe
    case myDrives
    case sharepointSharedLibraries
    case driveRoot
    case regularDriveNavigation
}

@objc
class OneDriveNavigationContext: NSObject {
    let mode: OneDriveNavigationContextMode
    let msalResult: MSALResult?
    let driveItem: OneDriveDriveItem?

    @objc
    init(mode: OneDriveNavigationContextMode, msalResult: MSALResult? = nil, driveItem: OneDriveDriveItem? = nil) {
        self.mode = mode
        self.msalResult = msalResult
        self.driveItem = driveItem
    }
}

class OneDriveDriveItem: NSObject {
    let parentItemId: String? 
    let driveId: String? 
    let name: String? 
    let itemId: String?
    let lastModifiedDateTime: Date?
    let driveType: String?
    let siteId: String?
    let sharedWithMe: Bool

    init(parentItemId: String?,
         driveId: String?,
         name: String?,
         itemId: String?,
         lastModifiedDateTime: Date?,
         driveType: String?,
         siteId: String?,
         sharedWithMe: Bool)
    {
        self.parentItemId = parentItemId
        self.driveId = driveId
        self.name = name
        self.itemId = itemId
        self.lastModifiedDateTime = lastModifiedDateTime
        self.driveType = driveType
        self.siteId = siteId
        self.sharedWithMe = sharedWithMe
    }
}

class OneDriveStorageProvider: NSObject, SafeStorageProvider {
    @objc
    static let sharedInstance = OneDriveStorageProvider()

    static let RegularScopes: [String] = ["Files.ReadWrite.All"]

    static let ExtendedScopes: [String] = ["Files.ReadWrite.All",
                                           "Sites.Read.All"]

    static let clientID = "1ac62c81-8569-4a96-9874-6e2941a00d17"

    private static let NextGenOperationQueue: OperationQueue = {
        let queue = OperationQueue()

        queue.name = "com.markmcguill.strongbox.OneDriveStorageProvider"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4

        return queue
    }()

    enum OneDriveStorageProviderError: Error {
        case invalidUploadUrl(detail: String)
        case unexpectedResponse(detail: String)
        case unexpectedResponseCode(code: Int, detail: String)
        case couldNotGetDriveItemUrl
        case couldNotReadNextUrlForListing
        case couldNotBuildEscapedFilename
        case couldNotConvertOdataDriveItem
        case couldNotGetModDateAfterUpload
        case couldNotReadDriveOrParentItemId
        case couldNotDeserializeExpectedJson
        case couldNotAuthenticate(innerError: (any Error)?)
        case couldNotFindApplication
        case interactiveSessionRequired
        case userCancelledAuthentication
        case couldNotGetDriveFields
    }

    enum OneDriveAPIHTTPParams {
        static let authorization = "Authorization"
        static let contentLength = "Content-Length"
        static let contentRange = "Content-Range"
        static let contentType = "Content-Type"
    }

    static let NextGenRequestTimeout = 30.0 
    static let NextGenResourceTimeout = 10 * 60.0 

    var storageId: StorageProvider { .kOneDrive }
    var providesIcons: Bool { false }
    var browsableNew: Bool { true }
    var browsableExisting: Bool { true }
    var rootFolderOnly: Bool { false }
    var supportsConcurrentRequests: Bool { false }
    var defaultForImmediatelyOfferOfflineCache: Bool { false }
    var privacyOptInRequired: Bool { true }
    var spinnerUI: SpinnerUI { CrossPlatformDependencies.defaults().spinnerUi }
    var appPreferences: ApplicationPreferences { CrossPlatformDependencies.defaults().applicationPreferences }

    private var defaultApplication: MSALPublicClientApplication?

    private let nextGenURLSession: URLSession

    override private init() {
        let sessionConfig = URLSessionConfiguration.ephemeral

        sessionConfig.allowsCellularAccess = true
        sessionConfig.waitsForConnectivity = false
        sessionConfig.timeoutIntervalForRequest = OneDriveStorageProvider.NextGenRequestTimeout
        sessionConfig.timeoutIntervalForResource = OneDriveStorageProvider.NextGenResourceTimeout

        #if os(iOS)
            sessionConfig.multipathServiceType = .none
        #endif

        nextGenURLSession = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: OneDriveStorageProvider.NextGenOperationQueue)

        super.init()

        let config = MSALPublicClientApplicationConfig(clientId: OneDriveStorageProvider.clientID, redirectUri: "strongbox-twodrive:

        do {
            defaultApplication = try MSALPublicClientApplication(configuration: config) 
        } catch {
            swlog("🔴 Could not load application OneDrive: [%@]", String(describing: error))
        }

        #if DEBUG
            
            
            
            
        #endif
    }

    func getDatabasePreferences(_ nickName: String, providerData: NSObject) -> METADATA_PTR? {
        guard let navContext = providerData as? OneDriveNavigationContext,
              let msalResult = navContext.msalResult,
              let dItem = navContext.driveItem,
              let json = getJsonFileIdentifier(msalResult: msalResult, driveItem: dItem)
        else {
            swlog("🔴 Not a proper provider data for OneDrive.")
            return nil
        }

        #if os(iOS)
            let ret = DatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileName: dItem.name!, fileIdentifier: json)

            return ret
        #else

            guard let filename = dItem.name else {
                swlog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            var components = URLComponents()
            components.scheme = kStrongboxGoogleDriveUrlScheme
            components.path = String(format: "/host/%@", filename) 

            guard let url = components.url else {
                swlog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            let metadata = MacDatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileUrl: url, storageInfo: json)

            components.queryItems = [URLQueryItem(name: "uuid", value: metadata.uuid)]

            guard let url2 = components.url else {
                swlog("🔴 Not a proper URL for OneDrive.")
                return nil
            }

            metadata.fileUrl = url2

            return metadata
        #endif
    }

    func getJsonFileIdentifier(msalResult: MSALResult, driveItem: OneDriveDriveItem) -> String? {
        guard let driveId = driveItem.driveId else {
            swlog("🔴 Missing required driveId or parentItemId in getJsonFileIdentifier")
            return nil
        }

        var dp: [String: Any] = ["driveId": driveId]

        if let parentItemId = driveItem.parentItemId {
            dp["parentFolderId"] = parentItemId
        }

        if let accountIdentifier = msalResult.account.identifier {
            dp["accountIdentifier"] = accountIdentifier
        }

        if let username = msalResult.account.username {
            dp["username"] = username
        }

        if let driveType = driveItem.driveType {
            dp["driveType"] = driveType
        }

        if let siteId = driveItem.siteId {
            dp["siteId"] = siteId
        }

        if let itemId = driveItem.itemId {
            dp["itemId"] = itemId
        }

        if driveItem.sharedWithMe {
            dp["sharedWithMe"] = driveItem.sharedWithMe
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dp, options: []),
              let json = String(data: data, encoding: .utf8)
        else {
            swlog("🔴 Could not encode file identifier for OneDrive.")
            return nil
        }

        return json
    }

    

    class func convertOdataDriveItemToBrowserItem(msalResult: MSALResult, item: AnyObject, sharedWithMe: Bool) -> StorageBrowserItem? {
        guard let item = item as? [String: AnyObject],
              let name = item["name"] as? String,
              let lastModifiedDateTimeString = item["lastModifiedDateTime"] as? String,
              let lastModifiedDateTime = NSDate.microsoftGraphDate(from: lastModifiedDateTimeString)
        else {
            swlog("🔴 Could not get required fields...") 
            return nil
        }

        let isFolder: Bool
        let driveId: String
        let itemId: String
        let driveType: String?
        let siteId: String?
        let parentId: String?

        if let remoteItem = item["remoteItem"] as? [String: AnyObject] {
            guard let pr = remoteItem["parentReference"] as? [String: AnyObject],
                  let dId = pr["driveId"] as? String,
                  let id = remoteItem["id"] as? String
            else {
                swlog("🔴 Could not get required fields...") 
                return nil
            }

            driveType = pr["driveType"] as? String
            siteId = pr["siteId"] as? String
            isFolder = remoteItem["folder"] != nil
            driveId = dId
            itemId = id
            parentId = pr["id"] as? String 
        } else {
            guard let parentReference = item["parentReference"] as? [String: AnyObject],
                  let id = item["id"] as? String,
                  let dId = parentReference["driveId"] as? String
            else {
                swlog("🔴 Could not get required fields...") 
                return nil
            }

            driveType = parentReference["driveType"] as? String
            siteId = parentReference["siteId"] as? String
            isFolder = item["folder"] != nil
            driveId = dId
            itemId = id
            parentId = parentReference["id"] as? String 
        }

        let theDriveItem = OneDriveDriveItem(parentItemId: parentId, driveId: driveId, name: name, itemId: itemId, lastModifiedDateTime: lastModifiedDateTime as Date, driveType: driveType, siteId: siteId, sharedWithMe: sharedWithMe)

        let navContext = OneDriveNavigationContext(mode: .regularDriveNavigation, msalResult: msalResult, driveItem: theDriveItem)

        return StorageBrowserItem(name: name, identifier: itemId, folder: isFolder, providerData: navContext)
    }

    

    func create(_ nickName: String, fileName: String, data: Data, parentFolder: NSObject?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (METADATA_PTR?, Error?) -> Void) {
        guard let navContext = parentFolder as? OneDriveNavigationContext,
              let msalResult = navContext.msalResult,
              let parentDriveItem = navContext.driveItem
        else {
            swlog("🔴 Could not get parentItem!")
            completion(nil, nil)
            return
        }

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
                let driveItem = try await uploadNewFile(accountIdentifier: msalResult.account.identifier,
                                                        viewController: viewController,
                                                        parentDriveItem: parentDriveItem,
                                                        filename: fileName,
                                                        data: data)

                let navContext = OneDriveNavigationContext(mode: .regularDriveNavigation, msalResult: msalResult, driveItem: driveItem)

                let metadata = self.getDatabasePreferences(nickName, providerData: navContext)

                completion(metadata, nil)
            } catch OneDriveStorageProviderError.userCancelledAuthentication {
                completion(nil, nil)
            } catch {
                swlog("🔴 OneDrive create error: [%@]", String(describing: error))
                completion(nil, error)
                return
            }
        }
    }

    func pullDatabase(_ safeMetaData: METADATA_PTR, interactiveVC viewController: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        if viewController != nil {
            spinnerUI.show(NSLocalizedString("generic_status_sp_locating_ellipsis", comment: "Locating..."), viewController: viewController)
        }

        findDriveItemFromMetadata(metadata: safeMetaData, viewController: viewController) { [weak self] navContext, userInteractionRequired, error in
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
            } else if navContext?.driveItem == nil {
                completion(.readResultError, nil, nil, Utils.createNSError("🔴 Drive Item is nil!", errorCode: 453))
            } else {
                self.read(withProviderData: navContext, viewController: viewController, options: options, completion: completion)
            }
        }
    }

    func read(withProviderData providerData: NSObject?, viewController: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        guard let navContext = providerData as? OneDriveNavigationContext,
              let msalResult = navContext.msalResult,
              let driveItem = navContext.driveItem
        else {
            swlog("🔴 Could not convert provider data to Listing State")
            completion(.readResultError, nil, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

        if let dtMod2 = options.onlyIfModifiedDifferentFrom,
           let dtMod = driveItem.lastModifiedDateTime as NSDate?
        {
            if dtMod.isEqualToDate(withinEpsilon: dtMod2) {
                completion(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                return
            }
        }

        guard let driveId = driveItem.driveId,
              let itemId = driveItem.itemId
        else {
            swlog("🔴 Could not convert provider data to Listing State")
            completion(.readResultError, nil, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

        if let viewController {
            spinnerUI.show(NSLocalizedString("storage_provider_status_reading", comment: "Reading..."), viewController: viewController)
        }

        Task {
            defer {
                if viewController != nil {
                    self.spinnerUI.dismiss()
                }
            }

            do {
                let data = try await readFile(accountIdentifier: msalResult.account.identifier, viewController: viewController, driveId: driveId, itemId: itemId)
                completion(.readResultSuccess, data, driveItem.lastModifiedDateTime, nil)
            } catch OneDriveStorageProviderError.userCancelledAuthentication {
                completion(.readResultError, nil, nil, nil)
            } catch OneDriveStorageProviderError.interactiveSessionRequired {
                completion(.readResultBackgroundReadButUserInteractionRequired, nil, nil, nil)
            } catch {
                swlog("🔴 OneDrive upload error: [%@]", String(describing: error))
                completion(.readResultError, nil, nil, error)
                return
            }
        }
    }

    func pushDatabase(_ safeMetaData: METADATA_PTR, interactiveVC viewController: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        if viewController != nil {
            spinnerUI.show(NSLocalizedString("generic_status_sp_locating_ellipsis", comment: "Locating..."), viewController: viewController)
        }

        findDriveItemFromMetadata(metadata: safeMetaData, viewController: viewController) { [weak self] navContext, userInteractionRequired, error in
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
            } else if navContext?.driveItem == nil {
                completion(.updateResultError, nil, Utils.createNSError("🔴 Drive Item is nil!", errorCode: 453))
            } else {
                self.write(withProviderData: navContext, viewController: viewController, data: data, completion: completion)
            }
        }
    }

    func write(withProviderData providerData: NSObject?, viewController: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        guard let navContext = providerData as? OneDriveNavigationContext,
              let msalResult = navContext.msalResult,
              let driveItem = navContext.driveItem
        else {
            swlog("🔴 Could not convert provider data to Listing State")
            completion(.updateResultError, nil, Utils.createNSError("🔴 Could not convert provider data to Listing State", errorCode: -23456))
            return
        }

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
                let driveItem = try await self.uploadToExistingFile(accountIdentifier: msalResult.account.identifier, viewController: viewController, driveItem: driveItem, data: data)

                completion(.updateResultSuccess, driveItem.lastModifiedDateTime, nil)
            } catch OneDriveStorageProviderError.userCancelledAuthentication {
                completion(.updateResultError, nil, nil)
            } catch OneDriveStorageProviderError.interactiveSessionRequired {
                completion(.updateResultUserInteractionRequired, nil, nil)
            } catch {
                swlog("🔴 OneDrive upload error: [%@]", String(describing: error))
                completion(.updateResultError, nil, error)
                return
            }
        }
    }

    func getModDate(_ safeMetaData: METADATA_PTR, completion: @escaping StorageProviderGetModDateCompletionBlock) {
        findDriveItemFromMetadata(metadata: safeMetaData, viewController: nil) { navContext, userInteractionRequired, error in
            

            if userInteractionRequired {
                completion(true, nil, Utils.createNSError("User Interaction Required from getModDate", errorCode: 346))
            } else {
                completion(true, navContext?.driveItem?.lastModifiedDateTime, error)
            }
        }
    }

    

    func list(_ parentFolder: NSObject?, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        guard let navContext = parentFolder as? OneDriveNavigationContext else {
            swlog("🔴 nil passed to list!")
            completion(false, [], nil)
            return
        }

        let accountIdentifier = navContext.msalResult?.account.identifier

        if let viewController {
            spinnerUI.show(NSLocalizedString("storage_provider_status_authenticating_listing", comment: "Listing..."), viewController: viewController)
        }

        Task {
            defer {
                if viewController != nil {
                    self.spinnerUI.dismiss()
                }
            }

            let driveItem = navContext.driveItem

            do {
                switch navContext.mode {
                case .sharedWithMe:
                    let items = try await self.getSharedWithMeFiles(viewController: viewController)
                    completion(false, items, nil)
                case .myDrives:
                    let items = try await self.getMyDrives(viewController: viewController)
                    completion(false, items, nil)
                case .sharepointSharedLibraries:
                    let items = try await self.getSharedLibraryDrives(accountIdentifier: accountIdentifier, viewController: viewController)
                    completion(false, items, nil)
                case .driveRoot, .regularDriveNavigation:
                    let items = try await self.listFolder(accountIdentifier: accountIdentifier, viewController: viewController, driveId: driveItem?.driveId, folderId: driveItem?.itemId)
                    completion(false, items, nil)
                case .initial:
                    completion(false, [], nil)
                }
            } catch OneDriveStorageProviderError.userCancelledAuthentication {
                completion(true, [], nil)
            } catch {
                swlog("🔴 error listing: [%@]", String(describing: error))
                completion(false, [], error)
            }
        }
    }

    @objc
    func isBusinessDrive(metadata: METADATA_PTR) -> Bool {
        #if os(iOS)
            let json = metadata.fileIdentifier
        #else
            let json = metadata.storageInfo ?? "{}"
        #endif

        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
              let driveType = obj["driveType"] as? String
        else {
            swlog("🔴 Could not decode the fileIdentifier")
            return false
        }

        return driveType == "business" || driveType == "documentLibrary"
    }

    func findDriveItemFromMetadata(metadata: METADATA_PTR, viewController: VIEW_CONTROLLER_PTR?, completion: @escaping (_ driveItem: OneDriveNavigationContext?, _ userInteractionRequired: Bool, _ error: Error?) -> Void) {
        #if os(iOS)
            let json = metadata.fileIdentifier
        #else
            let json = metadata.storageInfo ?? "{}"
        #endif

        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
              let driveId = obj["driveId"] as? String
        else {
            swlog("🔴 Could not decode the fileIdentifier")
            completion(nil, false, Utils.createNSError("🔴 Could not decode the fileIdentifier", errorCode: 123_456))
            return
        }

        let parentFolderId = obj["parentFolderId"] as? String 
        let itemId = obj["itemId"] as? String 

        #if os(iOS)
            let filename = metadata.fileName
        #else
            let filename = metadata.fileUrl.lastPathComponent
        #endif

        let accountIdentifier = obj["accountIdentifier"] as? String

        Task {
            do {
                if parentFolderId == nil, let itemId {
                    let maybeFound = try await getFileById(accountIdentifier: accountIdentifier, driveId: driveId, itemId: itemId, viewController: viewController)

                    if let found = maybeFound {
                        let navContext = found.providerData as? OneDriveNavigationContext

                        completion(navContext, false, nil)
                    } else {
                        completion(nil, false, Utils.createNSError("Could not locate the database file. Has it been renamed or moved?", errorCode: 45))
                    }
                } else {
                    let maybeFound = try await getFileByFilename(accountIdentifier: accountIdentifier, driveId: driveId, parentFolderId: parentFolderId, fileName: filename, viewController: viewController)

                    if let found = maybeFound {
                        let navContext = found.providerData as? OneDriveNavigationContext

                        completion(navContext, false, nil)
                    } else {
                        
                        
                        
                        

                        let listing = try await listFolder(accountIdentifier: accountIdentifier, viewController: viewController, driveId: driveId, folderId: parentFolderId)

                        if let found = listing.first(where: { $0.name.compare(filename) == .orderedSame }) {
                            let navContext = found.providerData as? OneDriveNavigationContext

                            completion(navContext, false, nil)
                        } else {
                            completion(nil, false, Utils.createNSError("Could not locate the database file. Has it been renamed or moved?", errorCode: 45))
                        }
                    }
                }
            } catch OneDriveStorageProviderError.userCancelledAuthentication {
                completion(nil, false, nil)
            } catch OneDriveStorageProviderError.interactiveSessionRequired {
                completion(nil, true, nil)
            } catch {
                swlog("🔴 Error in findDriveItemFromMetadata: [%@]", String(describing: error))
                completion(nil, false, error)
            }
        }
    }

    

    static let GraphBaseURL = "https:

    func getSharedWithMeFilesUrl() -> URL? {
        

        let request = "/me/drive/sharedWithMe?allowExternal=true"

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getFileByFilenameUrl(driveId: String, parentFolderId: String?, fileName: String) -> URL? {
        let escapedFilename = fileName.replacingOccurrences(of: "'", with: "''")

        let ret: URL?




        
        


        
        

        

        var components = URLComponents(string: OneDriveStorageProvider.GraphBaseURL)

        let path: String
        if let parentFolderId {
            path = String(format: "/v1.0/drives/%@/items/%@/children", driveId, parentFolderId)
        } else {
            path = String(format: "/v1.0/drives/%@/items/root/children", driveId)
        }
        let queryVal = String(format: "name eq '%@'", escapedFilename)
        let queryItems: [URLQueryItem] = [.init(name: "$filter", value: queryVal)]

        components?.path = path
        components?.queryItems = queryItems

        ret = components?.url








        return ret
    }

    func getMyDrivesUrl() -> URL? {
        let request = "/me/drives"

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getPrimaryDriveUrl() -> URL? {
        let request = "/me/drive"

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getSharedLibrariesUrl() -> URL? {
        let request = "/sites?search=*&$select=id,displayName"

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getDrivesForSiteUrl(siteId: String) -> URL? {
        let request = "/sites/\(siteId)/drives?$select=id,name,driveType"

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getListingRequestUrlFromDriveItem(driveId: String?, folderId: String?) -> URL? {
        
        
        
        
        
        
        

        let request: String

        if let driveId {
            if let folderId {
                request = String(format: "/drives/%@/items/%@/children", driveId, folderId)
            } else {
                request = String(format: "/drives/%@/root/children", driveId)
            }
        } else {
            request = "/me/drive/root/children"
        }

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getFileByIdUrl(driveId: String, itemId: String) -> URL? {
        
        
        
        
        
        
        
        
        
        
        
        

        let request = String(format: "/drives/%@/items/%@", driveId, itemId)

        return URL(string: "\(OneDriveStorageProvider.GraphBaseURL)\(request)")
    }

    func getFileUploadRequestUrl(driveItem: OneDriveDriveItem) -> URL? {
        
        
        
        
        

        guard let driveId = driveItem.driveId,
              let itemId = driveItem.itemId
        else {
            swlog("🔴 Could not convert provider data to Listing State")
            return nil
        }

        let oneDriveUrlString = String(format: "%@/drives/%@/items/%@/content", OneDriveStorageProvider.GraphBaseURL, driveId, itemId)

        return URL(string: oneDriveUrlString)
    }

    func getFileContentRequestUrl(driveId: String, itemId: String) -> URL? {
        
        
        
        
        
        

        let oneDriveUrlString = String(format: "%@/drives/%@/items/%@/content", OneDriveStorageProvider.GraphBaseURL, driveId, itemId)

        return URL(string: oneDriveUrlString)
    }

    func getNewFileUploadRequestUrl(parentDriveItem: OneDriveDriveItem, fileName: String) -> URL? {
        
        
        
        
        

        guard let driveId = parentDriveItem.driveId else {
            swlog("🔴 Could not get driveId")
            return nil
        }

        let path: String

        if let parentItemId = parentDriveItem.itemId {
            path = String(format: "/drives/%@/items/%@:/%@:/content", driveId, parentItemId, fileName)
        } else {
            path = String(format: "/drives/%@/items/root:/%@:/content", driveId, fileName)
        }

        let oneDriveUrlString = String(format: "%@/%@", OneDriveStorageProvider.GraphBaseURL, path)

        

        let ret = URL(string: oneDriveUrlString)

        

        return ret
    }

    

    

    func getFileById(accountIdentifier: String?, driveId: String, itemId: String, viewController: VIEW_CONTROLLER_PTR?) async throws -> StorageBrowserItem? {
        guard let url = getFileByIdUrl(driveId: driveId, itemId: itemId) else {
            swlog("🔴 getFileById - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as AnyObject else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }
        return OneDriveStorageProvider.convertOdataDriveItemToBrowserItem(msalResult: msalResult, item: json, sharedWithMe: false)
    }

    func getFileByFilename(accountIdentifier: String?, driveId: String, parentFolderId: String?, fileName: String, viewController: VIEW_CONTROLLER_PTR?) async throws -> StorageBrowserItem? {
        guard let url = getFileByFilenameUrl(driveId: driveId, parentFolderId: parentFolderId, fileName: fileName) else {
            swlog("🔴 getFileByFilename - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        guard let match = items.first else {
            return nil
        }

        return OneDriveStorageProvider.convertOdataDriveItemToBrowserItem(msalResult: msalResult, item: match, sharedWithMe: false)
    }

    

    func getSharedWithMeFiles(viewController: VIEW_CONTROLLER_PTR?) async throws -> [StorageBrowserItem] {
        guard let url = getSharedWithMeFilesUrl() else {
            swlog("🔴 getAllDrives - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: nil, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        return items.compactMap { OneDriveStorageProvider.convertOdataDriveItemToBrowserItem(msalResult: msalResult, item: $0, sharedWithMe: true) }
    }

    func getPrimaryDrive(viewController: VIEW_CONTROLLER_PTR?) async throws -> (StorageBrowserItem, MSALResult) {
        guard let url = getPrimaryDriveUrl() else {
            swlog("🔴 getAllDrives - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: nil, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject] else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        guard let id = json["id"] as? String,
              let driveType = json["driveType"] as? String
        else {
            swlog("🔴 Could not get required fields...")
            throw OneDriveStorageProviderError.couldNotGetDriveFields
        }

        let name = json["name"] as? String ?? "OneDrive"

        let driveItem = OneDriveDriveItem(parentItemId: nil, driveId: id, name: name, itemId: nil, lastModifiedDateTime: nil, driveType: driveType, siteId: nil, sharedWithMe: false)

        let navContext = OneDriveNavigationContext(mode: .driveRoot, msalResult: msalResult, driveItem: driveItem)

        return (StorageBrowserItem(name: name, identifier: id, folder: true, canNotCreateDatabaseInThisFolder: false, providerData: navContext), msalResult)
    }

    func getMyDrives(viewController: VIEW_CONTROLLER_PTR?) async throws -> [StorageBrowserItem] {
        let (primary, msalResultPrimary) = try await getPrimaryDrive(viewController: viewController)

        guard let url = getMyDrivesUrl() else {
            swlog("🔴 getAllDrives - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResultAllDrives) = try await getAuthenticatedUrlRequest(accountIdentifier: msalResultPrimary.account.identifier, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        let extraDrives = try items.compactMap { item in
            guard let item = item as? [String: AnyObject],
                  let id = item["id"] as? String,
                  let driveType = item["driveType"] as? String
            else {
                swlog("🔴 Could not get required fields...")
                throw OneDriveStorageProviderError.couldNotGetDriveFields
            }

            let name = item["name"] as? String ?? "OneDrive"

            let driveItem = OneDriveDriveItem(parentItemId: nil, driveId: id, name: name, itemId: nil, lastModifiedDateTime: nil, driveType: driveType, siteId: nil, sharedWithMe: false)

            let navContext = OneDriveNavigationContext(mode: .driveRoot, msalResult: msalResultAllDrives, driveItem: driveItem)

            let displayName = String(format: "%@ (%@)", name, driveType)

            return StorageBrowserItem(name: displayName, identifier: id, folder: true, canNotCreateDatabaseInThisFolder: false, providerData: navContext)
        }

        var drives = extraDrives.filter { theDrive in
            theDrive.identifier != primary.identifier
        }

        if drives.isEmpty {
            return [primary]
        } else {
            primary.name = String(format: NSLocalizedString("adjective_primary_in_parenthesis_fmt", comment: "%@ (Primary)"), primary.name)
            drives.insert(primary, at: 0)

            

            var i = 1
            for drive in drives {
                drive.name = String(format: "%d. %@", i, drive.name)
                i += 1
            }

            return drives
        }
    }

    func getSharedLibraryDrives(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?) async throws -> [StorageBrowserItem] {
        guard let url = getSharedLibrariesUrl() else {
            swlog("🔴 getAllDrives - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url, extendedScope: true)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        let sites = try items.reduce(into: [String: String]()) { result, key in
            guard let siteId = key["id"] as? String,
                  let displayName = key["displayName"] as? String
            else {
                swlog("🔴 required fields id, displayName are not present")
                throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
            }

            result[siteId] = displayName
        }

        var combined: [StorageBrowserItem] = []

        try await withThrowingTaskGroup(of: [StorageBrowserItem]?.self) { taskGroup in
            for site in sites {
                taskGroup.addTask { [weak self] in
                    let siteId = site.key
                    let siteName = site.value
                    return try await self?.getAllDrivesForSite(accountIdentifier: msalResult.account.identifier, viewController: viewController, siteId: siteId, siteName: siteName)
                }
            }

            for try await result in taskGroup {
                if let result {
                    combined.append(contentsOf: result)
                }
            }
        }

        return combined
    }

    func getAllDrivesForSite(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, siteId: String, siteName: String) async throws -> [StorageBrowserItem] {
        guard let url = getDrivesForSiteUrl(siteId: siteId) else {
            swlog("🔴 getAllDrivesForGroup - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url, extendedScope: true)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        return mapDriveItemsResponseToSBI(msalResult: msalResult, siteName: siteName, items: items)
    }

    func mapDriveItemsResponseToSBI(msalResult: MSALResult, siteName: String, items: [AnyObject]) -> [StorageBrowserItem] {
        let moreThanOne = items.count > 1

        let converted = items.map { item in
            let name = item["name"] as? String
            let id = item["id"] as? String
            let driveType = item["driveType"] as? String

            let displayName = moreThanOne ? String(format: "%@/%@", siteName, name ?? NSLocalizedString("generic_unknown", comment: "Unknown")) : siteName

            let driveItem = OneDriveDriveItem(parentItemId: nil, driveId: id, name: displayName, itemId: nil, lastModifiedDateTime: nil, driveType: driveType, siteId: nil, sharedWithMe: false)

            let navContext = OneDriveNavigationContext(mode: .driveRoot, msalResult: msalResult, driveItem: driveItem)

            return StorageBrowserItem(name: displayName, identifier: id, folder: true, canNotCreateDatabaseInThisFolder: true, providerData: navContext)
        }

        return converted
    }

    func listFolder(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, driveId: String?, folderId: String?, searchingForFilename: String? = nil) async throws -> [StorageBrowserItem] {
        
        

        guard let url = getListingRequestUrlFromDriveItem(driveId: driveId, folderId: folderId) else {
            swlog("🔴 updateExistingFile - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        return try await internalListRecursive(url: url, accountIdentifier: accountIdentifier, viewController: viewController, searchingForFilename: searchingForFilename)
    }

    func internalListRecursive(url: URL, accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, itemsSoFar: [StorageBrowserItem] = [], searchingForFilename: String?) async throws -> [StorageBrowserItem] {
        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url)

        let (jsonData, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: jsonData, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject],
              let items = json["value"] as? [AnyObject]
        else {
            swlog("🔴 error listing - could not read response...")
            throw OneDriveStorageProviderError.couldNotDeserializeExpectedJson
        }

        let browserItems = items.compactMap { OneDriveStorageProvider.convertOdataDriveItemToBrowserItem(msalResult: msalResult, item: $0, sharedWithMe: false) }

        

        var accumulated = itemsSoFar

        if let searchingForFilename {
            if let found = browserItems.first(where: { $0.name.compare(searchingForFilename) == .orderedSame }) {
                return [found]
            }
        } else {
            accumulated.append(contentsOf: browserItems)
        }

        if let nextLink = json["@odata.nextLink"] as? String {
            guard let nextUrl = URL(string: nextLink) else {
                swlog("🔴 Next URL is invalid!")
                throw OneDriveStorageProviderError.couldNotReadNextUrlForListing
            }

            return try await internalListRecursive(url: nextUrl, accountIdentifier: accountIdentifier, viewController: viewController, itemsSoFar: accumulated, searchingForFilename: searchingForFilename)
        } else {
            return accumulated
        }
    }

    

    func uploadToExistingFile(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, driveItem: OneDriveDriveItem, data: Data) async throws -> OneDriveDriveItem {
        guard let requestUrl = getFileUploadRequestUrl(driveItem: driveItem) else {
            swlog("🔴 updateExistingFile - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: requestUrl, method: "PUT", contentType: "text/plain")

        return try await uploadWithRequest(msalResult: msalResult, urlRequest: urlRequest, data: data)
    }

    func uploadNewFile(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, parentDriveItem: OneDriveDriveItem, filename: String, data: Data) async throws -> OneDriveDriveItem {
        guard let requestUrl = getNewFileUploadRequestUrl(parentDriveItem: parentDriveItem, fileName: filename) else {
            swlog("🔴 uploadNewFile - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, msalResult) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: requestUrl, method: "PUT", contentType: "text/plain")

        return try await uploadWithRequest(msalResult: msalResult, urlRequest: urlRequest, data: data)
    }

    func uploadWithRequest(msalResult: MSALResult, urlRequest: URLRequest, data: Data) async throws -> OneDriveDriveItem {
        var mutableRequest = urlRequest

        mutableRequest.httpBody = data

        let (jsonData, response) = try await nextGenURLSession.data(for: mutableRequest)

        let driveItem = try validateResponseAndDeserializeDriveItem(msalResult: msalResult, data: jsonData, response: response)

        #if DEBUG
            swlog("🐞 Upload Content DONE: \(driveItem)")
        #endif

        return driveItem
    }

    

    func readFile(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, driveId: String, itemId: String) async throws -> Data {
        guard let url = getFileContentRequestUrl(driveId: driveId, itemId: itemId) else {
            swlog("🔴 readFile - Could not get request URL")
            throw OneDriveStorageProviderError.couldNotGetDriveItemUrl
        }

        let (urlRequest, _) = try await getAuthenticatedUrlRequest(accountIdentifier: accountIdentifier, viewController: viewController, url: url)

        let (data, response) = try await nextGenURLSession.data(for: urlRequest)

        try validateResponse(data: data, response: response)

        return data
    }

    

    func validateResponse(data _: Data, response: URLResponse) throws {
        #if DEBUG








        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OneDriveStorageProviderError.unexpectedResponse(detail: String(describing: response))
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            swlog("🔴 verifyHttpResponse - Unexpected Response Code \(httpResponse.statusCode) ")
            throw OneDriveStorageProviderError.unexpectedResponseCode(code: httpResponse.statusCode, detail: String(describing: response))
        }
    }

    func validateResponseAndDeserializeDriveItem(msalResult: MSALResult, data: Data, response: URLResponse) throws -> OneDriveDriveItem {
        try validateResponse(data: data, response: response)

        guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject,
              let item = OneDriveStorageProvider.convertOdataDriveItemToBrowserItem(msalResult: msalResult, item: dictionary, sharedWithMe: false),
              let navContext = item.providerData as? OneDriveNavigationContext,
              let driveItem = navContext.driveItem
        else {
            throw OneDriveStorageProviderError.couldNotConvertOdataDriveItem
        }

        return driveItem
    }

    

    func getAuthenticatedUrlRequest(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, url: URL, method: String = "GET", extendedScope: Bool = false, contentType: String? = nil) async throws -> (URLRequest, MSALResult) {
        let msalResult = try await authenticate(accountIdentifier: accountIdentifier, viewController: viewController, extendedScope: extendedScope)

        var urlRequest = URLRequest(url: url)

        urlRequest.timeoutInterval = OneDriveStorageProvider.NextGenRequestTimeout

        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(msalResult.accessToken)", forHTTPHeaderField: OneDriveAPIHTTPParams.authorization)
        urlRequest.setValue(contentType, forHTTPHeaderField: OneDriveAPIHTTPParams.contentType)

        return (urlRequest, msalResult)
    }

    func authenticate(accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, extendedScope: Bool) async throws -> MSALResult {
        let application: MSALPublicClientApplication

        if appPreferences.useOneDriveUSGovCloudInstance {
            

            let authority = try? MSALAADAuthority(cloudInstance: .usGovernmentCloudInstance, audienceType: .azureADMultipleOrgsAudience, rawTenant: nil)

            let config = MSALPublicClientApplicationConfig(clientId: OneDriveStorageProvider.clientID, redirectUri: "strongbox-twodrive:

            do {
                application = try MSALPublicClientApplication(configuration: config) 
            } catch {
                swlog("🔴 Could not load application OneDrive: [%@]", String(describing: error))
                throw OneDriveStorageProviderError.couldNotFindApplication
            }
        } else {
            guard let defaultApplication else {
                throw OneDriveStorageProviderError.couldNotFindApplication
            }

            application = defaultApplication
        }

        let scopes = extendedScope ? OneDriveStorageProvider.ExtendedScopes : OneDriveStorageProvider.RegularScopes

        if let accountIdentifier, let account = try? application.account(forIdentifier: accountIdentifier) {
            do {
                return try await application.acquireTokenSilent(with: MSALSilentTokenParameters(scopes: scopes, account: account))
            } catch {
                if (error as NSError).code == MSALError.interactionRequired.rawValue {
                    return try await attemptInteractiveAuth(application: application, accountIdentifier: accountIdentifier, viewController: viewController, scopes: scopes)
                } else {
                    throw error
                }
            }
        } else {
            return try await attemptInteractiveAuth(application: application, accountIdentifier: accountIdentifier, viewController: viewController, scopes: scopes)
        }
    }

    private func attemptInteractiveAuth(application: MSALPublicClientApplication, accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR?, scopes: [String]) async throws -> MSALResult {
        guard let viewController else {
            swlog("Interactive Logon required but Background Call...")
            throw OneDriveStorageProviderError.interactiveSessionRequired
        }

        return try await interactiveAuthenticate(application: application, accountIdentifier: accountIdentifier, viewController: viewController, scopes: scopes)
    }

    @MainActor
    private func interactiveAuthenticate(application: MSALPublicClientApplication, accountIdentifier: String?, viewController: VIEW_CONTROLLER_PTR, scopes: [String]) async throws -> MSALResult {
        #if os(iOS)
            let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        #else
            let webviewParameters = MSALWebviewParameters()
        #endif

        let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webviewParameters)

        if let accountIdentifier {
            interactiveParameters.account = try? application.account(forIdentifier: accountIdentifier)
            
        }

        if interactiveParameters.account == nil {
            interactiveParameters.promptType = .selectAccount
        }

        #if os(iOS)
            if !Utils.isAppInForeground {
                try? await Task.sleep(nanoseconds: 1_000_000_000) 
            }
        #endif

        do {
            return try await application.acquireToken(with: interactiveParameters)
        } catch {
            if (error as NSError).code == MSALError.userCanceled.rawValue {
                throw OneDriveStorageProviderError.userCancelledAuthentication
            } else {
                throw error
            }
        }
    }

    @objc
    func signOutAll() {
        guard let application = defaultApplication else { 
            swlog("🔴 Could not load or find Application!")
            return
        }

        application.accountsFromDevice(for: MSALAccountEnumerationParameters()) { accounts, error in
            guard let accounts else {
                return
            }

            for account in accounts {
                application.signout(with: account, signoutParameters: MSALSignoutParameters()) { _, error in
                    if let error {
                        swlog("🔴 Error Signing out [%@]", String(describing: error))
                    }
                }
            }
        }
    }

    

    func delete(_: METADATA_PTR, completion _: @escaping (Error?) -> Void) {
        
    }

    func loadIcon(_: NSObject, viewController _: VIEW_CONTROLLER_PTR, completion _: @escaping (IMAGE_TYPE_PTR) -> Void) {
        
    }
}
