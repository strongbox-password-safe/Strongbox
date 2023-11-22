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



struct IconSize: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(width.hashValue ^ height.hashValue)
    }

    static func == (lhs: IconSize, rhs: IconSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }

    
    let width: Int
    
    let height: Int
}

private let kRelIconTypeMap: [IconSize: DetectedIconType] = [
    IconSize(width: 16, height: 16): .classic,
    IconSize(width: 32, height: 32): .appleOSXSafariTab,
    IconSize(width: 96, height: 96): .googleTV,
    IconSize(width: 192, height: 192): .googleAndroidChrome,
    IconSize(width: 196, height: 196): .googleAndroidChrome,
]

private let kMicrosoftSizeMap: [String: IconSize] = [
    "msapplication-tileimage": IconSize(width: 144, height: 144),
    "msapplication-square70x70logo": IconSize(width: 70, height: 70),
    "msapplication-square150x150logo": IconSize(width: 150, height: 150),
    "msapplication-wide310x150logo": IconSize(width: 310, height: 150),
    "msapplication-square310x310logo": IconSize(width: 310, height: 310),
]

private let siteImage: [String: IconSize] = [
    "og:image": IconSize(width: 1024, height: 512),
    "twitter:image": IconSize(width: 1024, height: 512),
]








func examineHTMLMeta(_ document: HTMLDocument, baseURL: URL) -> [String: String] {
    var resp: [String: String] = [:]
    for meta in document.query("/html/head/meta") {
        if let property = meta.attributes["property"]?.lowercased(),
           let content = meta.attributes["content"]
        {
            switch property {
            case "og:url":
                resp["og:url"] = content
            case "og:description":
                resp["description"] = content
            case "og:image":
                resp["image"] = content
            case "og:title":
                resp["title"] = content
            case "og:site_name":
                resp["site_name"] = content
            default:
                break
            }
        }
        if let name = meta.attributes["name"]?.lowercased(),
           let content = meta.attributes["content"],
           name == "description"
        {
            resp["description"] = resp["description"] ?? content
        }
    }

    for title in document.query("/html/head/title") {
        if let titleString = title.contents {
            resp["title"] = resp["title"] ?? titleString
        }
    }

    for link in document.query("/html/head/link") {
        if let rel = link.attributes["rel"],
           let href = link.attributes["href"],
           let url = URL(string: href, relativeTo: baseURL)
        {
            switch rel.lowercased() {
            case "canonical":
                resp["canonical"] = url.absoluteString
            case "amphtml":
                resp["amphtml"] = url.absoluteString
            case "search":
                resp["search"] = url.absoluteString
            case "fluid-icon":
                resp["fluid-icon"] = url.absoluteString
            case "alternate":
                let application = link.attributes["application"]
                if application == "application/atom+xml" {
                    resp["atom"] = url.absoluteString
                }
            default:
                break
            }
        }
    }

    return resp
}

func extractHTMLHeadIcons(_ document: HTMLDocument, baseURL: URL) -> [DetectedIcon] {
    var icons: [DetectedIcon] = []

    for link in document.query("/html/head/link") {
        if let rel = link.attributes["rel"],
           let href = link.attributes["href"],
           let url = URL(string: href, relativeTo: baseURL)
        {
            switch rel.lowercased() {
            case "shortcut icon":
                icons.append(DetectedIcon(url: url.absoluteURL, type: .shortcut))
            case "icon":
                if let type = link.attributes["type"], type.lowercased() == "image/png" {
                    let sizes = parseHTMLIconSizes(link.attributes["sizes"])
                    if sizes.count > 0 {
                        for size in sizes {
                            if let type = kRelIconTypeMap[size] {
                                icons.append(DetectedIcon(url: url,
                                                          type: type,
                                                          width: size.width,
                                                          height: size.height))
                            }
                        }
                    } else {
                        icons.append(DetectedIcon(url: url.absoluteURL, type: .classic))
                    }
                } else {
                    icons.append(DetectedIcon(url: url.absoluteURL, type: .classic))
                }
            case "apple-touch-icon":
                let sizes = parseHTMLIconSizes(link.attributes["sizes"])
                if sizes.count > 0 {
                    for size in sizes {
                        icons.append(DetectedIcon(url: url.absoluteURL,
                                                  type: .appleIOSWebClip,
                                                  width: size.width,
                                                  height: size.height))
                    }
                } else {
                    icons.append(DetectedIcon(url: url.absoluteURL,
                                              type: .appleIOSWebClip,
                                              width: 60,
                                              height: 60))
                }
            default:
                break
            }
        }
    }

    for meta in document.query("/html/head/meta") {
        if let name = meta.attributes["name"]?.lowercased(),
           let content = meta.attributes["content"],
           let url = URL(string: content, relativeTo: baseURL),
           let size = kMicrosoftSizeMap[name]
        {
            icons.append(DetectedIcon(url: url,
                                      type: .microsoftPinnedSite,
                                      width: size.width,
                                      height: size.height))
        } else if
            let property = meta.attributes["property"]?.lowercased(),
            let content = meta.attributes["content"],
            let url = URL(string: content, relativeTo: baseURL),
            let size = siteImage[property]
        {
            icons.append(DetectedIcon(url: url,
                                      type: .FBImage,
                                      width: size.width,
                                      height: size.height))
        }
    }

    return icons
}









func extractManifestJSONIcons(_ jsonString: String, baseURL: URL) -> [DetectedIcon] {
    var icons: [DetectedIcon] = []

    if let data = jsonString.data(using: String.Encoding.utf8),
       let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()),
       let manifest = object as? NSDictionary,
       let manifestIcons = manifest["icons"] as? [NSDictionary]
    {
        for icon in manifestIcons {
            if let type = icon["type"] as? String, type.lowercased() == "image/png",
               let src = icon["src"] as? String,
               let url = URL(string: src, relativeTo: baseURL)?.absoluteURL
            {
                let sizes = parseHTMLIconSizes(icon["sizes"] as? String)
                if sizes.count > 0 {
                    for size in sizes {
                        icons.append(DetectedIcon(url: url,
                                                  type: .webAppManifest,
                                                  width: size.width,
                                                  height: size.height))
                    }
                } else {
                    icons.append(DetectedIcon(url: url, type: .webAppManifest))
                }
            }
        }
    }

    return icons
}






func extractBrowserConfigXMLIcons(_ document: LBXMLDocument, baseURL: URL) -> [DetectedIcon] {
    var icons: [DetectedIcon] = []

    for tile in document.query("/browserconfig/msapplication/tile/*") {
        if let src = tile.attributes["src"],
           let url = URL(string: src, relativeTo: baseURL)?.absoluteURL
        {
            switch tile.name.lowercased() {
            case "tileimage":
                icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 144, height: 144))
            case "square70x70logo":
                icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 70, height: 70))
            case "square150x150logo":
                icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 150, height: 150))
            case "wide310x150logo":
                icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 310, height: 150))
            case "square310x310logo":
                icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 310, height: 310))
            default:
                break
            }
        }
    }

    return icons
}






func extractWebAppManifestURLs(_ document: HTMLDocument, baseURL: URL) -> [URL] {
    var urls: [URL] = []
    for link in document.query("/html/head/link") {
        if let rel = link.attributes["rel"]?.lowercased(), rel == "manifest",
           let href = link.attributes["href"], let manifestURL = URL(string: href, relativeTo: baseURL)
        {
            urls.append(manifestURL)
        }
    }
    return urls
}







func extractBrowserConfigURL(_ document: HTMLDocument, baseURL: URL) -> (url: URL?, disabled: Bool) {
    for meta in document.query("/html/head/meta") {
        if let name = meta.attributes["name"]?.lowercased(), name == "msapplication-config",
           let content = meta.attributes["content"]
        {
            if content.lowercased() == "none" {
                
                return (url: nil, disabled: true)
            } else {
                return (url: URL(string: content, relativeTo: baseURL)?.absoluteURL, disabled: false)
            }
        }
    }
    return (url: nil, disabled: false)
}





func parseHTMLIconSizes(_ string: String?) -> [IconSize] {
    var sizes: [IconSize] = []
    if let string = string?.lowercased(), string != "any" {
        for size in string.components(separatedBy: .whitespaces) {
            let parts = size.components(separatedBy: "x")
            if parts.count != 2 { continue }
            if let width = Int(parts[0]), let height = Int(parts[1]) {
                sizes.append(IconSize(width: width, height: height))
            }
        }
    }
    return sizes
}
