//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software






import Foundation

#if os(iOS)
    import UIKit
    
    public typealias ImageType = UIImage
#elseif os(OSX)
    import Cocoa
    
    public typealias ImageType = NSImage
#endif


public enum IconDownloadResult {
    
    
    
    case success(image: ImageType)

    
    
    
    case failure(error: Error)
}




class AuthSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {









        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            swlog("%@", challenge)
            completionHandler(.rejectProtectionSpace, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}


@objc public final class FavIcon: NSObject {
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    @objc public static func scan(_ url: URL,
                                  on queue: OperationQueue? = nil,
                                  favIcon: Bool = true,
                                  scanHtml: Bool = true,
                                  duckDuckGo: Bool = true,
                                  google: Bool = true,
                                  allowInvalidSSLCerts: Bool = false,
                                  completion: @escaping ([DetectedIcon], [String: String]) -> Void) throws
    {
        let syncQueue = DispatchQueue(label: "org.bitserf.FavIcon", attributes: [])
        var icons: [DetectedIcon] = []
        var additionalDownloads: [URLRequestWithCallback] = []
        let urlSession = allowInvalidSSLCerts ? insecureUrlSessionProvider() : urlSessionProvider()
        var meta: [String: String] = [:]

        var operations: [URLRequestWithCallback] = []

        if scanHtml {
            let downloadHTMLOperation = DownloadTextOperation(url: url, session: urlSession)
            let downloadHTML = urlRequestOperation(downloadHTMLOperation) { result in
                if case let .textDownloaded(actualURL, text, contentType) = result {
                    if contentType == "text/html" {
                        let document = HTMLDocument(string: text)

                        let htmlIcons = extractHTMLHeadIcons(document, baseURL: actualURL)
                        let htmlMeta = examineHTMLMeta(document, baseURL: actualURL)
                        syncQueue.sync {
                            icons.append(contentsOf: htmlIcons)
                            meta = htmlMeta
                        }

                        for manifestURL in extractWebAppManifestURLs(document, baseURL: url) {
                            let downloadOperation = DownloadTextOperation(url: manifestURL,
                                                                          session: urlSession)
                            let download = urlRequestOperation(downloadOperation) { result in
                                if case let .textDownloaded(_, manifestJSON, _) = result {
                                    let jsonIcons = extractManifestJSONIcons(
                                        manifestJSON,
                                        baseURL: actualURL
                                    )
                                    syncQueue.sync {
                                        icons.append(contentsOf: jsonIcons)
                                    }
                                }
                            }
                            additionalDownloads.append(download)
                        }

                        let browserConfigResult = extractBrowserConfigURL(document, baseURL: url)
                        if let browserConfigURL = browserConfigResult.url, !browserConfigResult.disabled {
                            let downloadOperation = DownloadTextOperation(url: browserConfigURL,
                                                                          session: urlSession)
                            let download = urlRequestOperation(downloadOperation) { result in
                                if case let .textDownloaded(_, browserConfigXML, _) = result {
                                    let document = LBXMLDocument(string: browserConfigXML)
                                    let xmlIcons = extractBrowserConfigXMLIcons(
                                        document,
                                        baseURL: actualURL
                                    )
                                    syncQueue.sync {
                                        icons.append(contentsOf: xmlIcons)
                                    }
                                }
                            }
                            additionalDownloads.append(download)
                        }
                    }
                }
            }

            operations.append(downloadHTML)
        }

        if favIcon {
            let commonFiles: [String] = ["favicon.ico",
                                         "apple-touch-icon.png",
                                         "apple-icon-57x57.png",
                                         "apple-icon-60x60.png",
                                         "apple-icon-72x72.png",
                                         "apple-icon-76x76.png",
                                         "apple-icon-114x114.png",
                                         "apple-icon-120x120.png",
                                         "apple-icon-144x144.png",
                                         "apple-icon-152x152.png",
                                         "apple-icon-180x180.png",
                                         "android-icon-192x192.png",
                                         "favicon-32x32.png",
                                         "favicon-96x96.png",
                                         "favicon-16x16.png",
                                         "ms-icon-144x144.png"]

            for commonFile in commonFiles {
                

                let favIconURL = URL(string: commonFile, relativeTo: url as URL)!.absoluteURL
                let checkFavIconOperation = CheckURLExistsOperation(url: favIconURL, session: urlSession)
                let checkFavIcon = urlRequestOperation(checkFavIconOperation) { result in
                    if case let .success(actualURL) = result {

                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic))
                        }
                    }
                }
                operations.append(checkFavIcon)
            }
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = "" 
        components?.query = nil 
        components?.user = nil 
        components?.password = nil 
        components?.fragment = nil 

        let domain = components?.host ?? url.absoluteString
        let blah = String(format: "https:

        if duckDuckGo {
            let ddgUrl = URL(string: blah)

            if ddgUrl != nil {
                let duckDuckGoURL = ddgUrl!.absoluteURL
                let checkDuckDuckGoURLOperation = CheckURLExistsOperation(url: duckDuckGoURL, session: urlSession)
                let checkDuckDuckGoURL = urlRequestOperation(checkDuckDuckGoURLOperation) { result in
                    if case let .success(actualURL) = result {
                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic))
                        }
                    }
                }

                operations.append(checkDuckDuckGoURL)
            }
        }

        

        if google {
            let blah2 = String(format: "https:
            let googleURL = URL(string: blah2)?.absoluteURL
            if googleURL != nil {
                let checkGoogleUrlOperation = CheckURLExistsOperation(url: googleURL!, session: urlSession)
                let checkGoogleUrl = urlRequestOperation(checkGoogleUrlOperation) { result in
                    if case let .success(actualURL) = result {
                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic))
                        }
                    }
                }

                operations.append(checkGoogleUrl)
            }
        }

        if operations.count == 0 {
            DispatchQueue.main.async {
                completion(icons, meta)
            }
        }

        executeURLOperations(operations, on: queue) {
            if additionalDownloads.count > 0 {
                executeURLOperations(additionalDownloads, on: queue) {
                    DispatchQueue.main.async {
                        completion(icons, meta)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(icons, meta)
                }
            }
        }
    }

    

    
    
    
    
    
    
    @objc public static func download(_ icons: [DetectedIcon], completion: @escaping ([ImageType]) -> Void) {
        let urlSession = urlSessionProvider()
        let operations: [DownloadImageOperation] =
            icons.map { DownloadImageOperation(url: $0.url, session: urlSession) }

        executeURLOperations(operations) { results in
            let downloadResults: [ImageType] = results.compactMap { result in
                switch result {
                case let .imageDownloaded(_, image):
                    return image
                case .failed:
                    return nil
                default:
                    return nil
                }
            }

            DispatchQueue.main.async {
                completion(downloadResults)
            }
        }
    }

    enum MyError: Error {
        case runtimeError(String)
    }

    @objc public static func downloadAll(_ url: URL,
                                         favIcon: Bool,
                                         scanHtml: Bool,
                                         duckDuckGo: Bool,
                                         google: Bool,
                                         allowInvalidSSLCerts: Bool,
                                         completion: @escaping ([ImageType]?) -> Void) throws
    {
        do {
            try scan(url, favIcon: favIcon, scanHtml: scanHtml, duckDuckGo: duckDuckGo, google: google, allowInvalidSSLCerts: allowInvalidSSLCerts) { icons, _ in
                let iconMap = icons.reduce(into: [URL: DetectedIcon]()) { current, icon in
                    current[icon.url] = icon
                }

                let uniqueIcons = Array(iconMap.values)
                dl(uniqueIcons) { downloaded in
                    let blah = Array(downloaded.values)
                    DispatchQueue.main.async {
                        completion(blah)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }

    @objc public static func dl(_ icons: [DetectedIcon], on queue: OperationQueue? = nil, completion: @escaping ([URL: ImageType]) -> Void) {
        let urlSession = urlSessionProvider()
        let operations: [DownloadImageOperation] =
            icons.map { DownloadImageOperation(url: $0.url, session: urlSession) }

        var myDictionary = [URL: ImageType]()

        executeURLOperations(operations, on: queue) { results in
            for result in results {
                switch result {
                case let .imageDownloaded(url, image):
                    myDictionary[url] = image
                default:
                    continue
                }
            }

            DispatchQueue.main.async {
                completion(myDictionary)
            }
        }
    }

    typealias URLSessionProvider = () -> URLSession
    @objc static var urlSessionProvider: URLSessionProvider = FavIcon.createDefaultURLSession
    @objc static var insecureUrlSessionProvider: URLSessionProvider = FavIcon.createInsecureURLSession

    @objc static func createDefaultURLSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 5.0
        return URLSession(configuration: sessionConfig)
    }

    @objc static func createInsecureURLSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 5.0
        return URLSession(configuration: sessionConfig, delegate: AuthSessionDelegate(), delegateQueue: nil)
    }
}


enum IconError: Error {
    
    case invalidBaseURL
    
    case atLeastOneOneIconRequired
    
    case invalidDownloadResponse
    
    case noIconsDetected
}

extension DetectedIcon {
    
    var area: Int? {
        if let width = width, let height = height {
            return width * height
        }
        return nil
    }
}
