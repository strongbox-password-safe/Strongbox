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
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import FavIcon.XMLDocument

/// Represents an icon size.
struct IconSize : Hashable, Equatable {
  var hashValue: Int {
    return width.hashValue ^ height.hashValue
  }
  
  static func ==(lhs: IconSize, rhs: IconSize) -> Bool {
    return lhs.width == rhs.width && lhs.height == rhs.height
  }
  
  /// The width of the icon.
  let width: Int
  /// The height of the icon.
  let height: Int
}

private let kRelIconTypeMap: [IconSize: DetectedIconType] = [
  IconSize(width: 16, height: 16): .classic,
  IconSize(width: 32, height: 32): .appleOSXSafariTab,
  IconSize(width: 96, height: 96): .googleTV,
  IconSize(width: 192, height: 192): .googleAndroidChrome,
  IconSize(width: 196, height: 196): .googleAndroidChrome
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
  "twitter:image": IconSize(width: 1024, height: 512)
]

/// Extracts a list of icons from the `<head>` section of an HTML document.
///
/// - parameter document: An HTML document to process.
/// - parameter baseURL: A base URL to combine with any relative image paths.
/// - parameter returns: An array of `DetectedIcon` structures.
// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity
func examineHTMLMeta(_ document: HTMLDocument, baseURL: URL) -> [String:String] {
  var resp: [String:String] = [:]
  for meta in document.query("/html/head/meta") {
    if let property = meta.attributes["property"]?.lowercased(),
      let content = meta.attributes["content"]{
      switch property {
      case "og:url":
        resp["og:url"] = content;
        break
      case "og:description":
        resp["description"] = content;
        break
      case "og:image":
        resp["image"] = content;
        break
      case "og:title":
        resp["title"] = content;
        break
      case "og:site_name":
        resp["site_name"] = content;
        break
      default:
        break
      }
    }
    if let name = meta.attributes["name"]?.lowercased(),
      let content = meta.attributes["content"],
      name == "description" {
      resp["description"] = resp["description"] ?? content;
    }
  }
  
  for title in document.query("/html/head/title") {
    if let titleString = title.contents {
      resp["title"] = resp["title"] ?? titleString;
    }
  }
  
  for link in document.query("/html/head/link") {
    if let rel = link.attributes["rel"],
      let href = link.attributes["href"],
      let url = URL(string: href, relativeTo: baseURL)
    {
      switch rel.lowercased() {
      case "canonical":
        resp["canonical"] = url.absoluteString;
        break
      case "amphtml":
        resp["amphtml"] = url.absoluteString;
        break
      case "search":
        resp["search"] = url.absoluteString;
        break
      case "fluid-icon":
        resp["fluid-icon"] = url.absoluteString;
        break
      case "alternate":
        let application = link.attributes["application"]
        if application == "application/atom+xml" {
          resp["atom"] = url.absoluteString;
        }
        break
      default:
        break
      }
    }
  }
  
  return resp;
}

func extractHTMLHeadIcons(_ document: HTMLDocument, baseURL: URL) -> [DetectedIcon] {
  var icons: [DetectedIcon] = []
  
  for link in document.query("/html/head/link") {
    if let rel = link.attributes["rel"],
      let href = link.attributes["href"],
      let url = URL(string: href, relativeTo: baseURL) {
      switch rel.lowercased() {
      case "shortcut icon":
        icons.append(DetectedIcon(url: url.absoluteURL, type:.shortcut))
        break
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
      let size = kMicrosoftSizeMap[name] {
      icons.append(DetectedIcon(url: url,
                                type: .microsoftPinnedSite,
                                width: size.width,
                                height: size.height))
    } else if
      let property = meta.attributes["property"]?.lowercased(),
      let content = meta.attributes["content"],
      let url = URL(string: content, relativeTo: baseURL),
      let size = siteImage[property] {
      icons.append(DetectedIcon(url: url,
                                type: .FBImage,
                                width: size.width,
                                height: size.height))
    }
  }
  
  return icons
}
// swiftlint:enable cyclomatic_complexity
// swiftlint:enable function_body_length

/// Extracts a list of icons from a Web Application Manifest file
///
/// - parameter jsonString: A JSON string containing the contents of the manifest file.
/// - parameter baseURL: A base URL to combine with any relative image paths.
/// - returns: An array of `DetectedIcon` structures.
func extractManifestJSONIcons(_ jsonString: String, baseURL: URL) -> [DetectedIcon] {
  var icons: [DetectedIcon] = []
  
  if let data = jsonString.data(using: String.Encoding.utf8),
    let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()),
    let manifest = object as? NSDictionary,
    let manifestIcons = manifest["icons"] as? [NSDictionary] {
    for icon in manifestIcons {
      if let type = icon["type"] as? String, type.lowercased() == "image/png",
        let src = icon["src"] as? String,
        let url = URL(string: src, relativeTo: baseURL)?.absoluteURL {
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

/// Extracts a list of icons from a Microsoft browser configuration XML document.
///
/// - parameter document: An `XMLDocument` for the Microsoft browser configuration file.
/// - parameter baseURL: A base URL to combine with any relative image paths.
/// - returns: An array of `DetectedIcon` structures.
func extractBrowserConfigXMLIcons(_ document: LBXMLDocument, baseURL: URL) -> [DetectedIcon] {
  var icons: [DetectedIcon] = []
  
  for tile in document.query("/browserconfig/msapplication/tile/*") {
    if let src = tile.attributes["src"],
      let url = URL(string: src, relativeTo: baseURL)?.absoluteURL {
      switch tile.name.lowercased() {
      case "tileimage":
        icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 144, height: 144))
        break
      case "square70x70logo":
        icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 70, height: 70))
        break
      case "square150x150logo":
        icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 150, height: 150))
        break
      case "wide310x150logo":
        icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 310, height: 150))
        break
      case "square310x310logo":
        icons.append(DetectedIcon(url: url, type: .microsoftPinnedSite, width: 310, height: 310))
        break
      default:
        break
      }
    }
  }
  
  return icons
}

/// Extracts the Web App Manifest URLs from an HTML document, if any.
///
/// - parameter document: The HTML document to scan for Web App Manifest URLs
/// - parameter baseURL: The base URL that any 'href' attributes are relative to.
/// - returns: An array of Web App Manifest `URL`s.
func extractWebAppManifestURLs(_ document: HTMLDocument, baseURL: URL) -> [URL] {
  var urls: [URL] = []
  for link in document.query("/html/head/link") {
    if let rel = link.attributes["rel"]?.lowercased(), rel == "manifest",
      let href = link.attributes["href"], let manifestURL = URL(string: href, relativeTo: baseURL) {
      urls.append(manifestURL)
    }
  }
  return urls
}

/// Extracts the first browser config XML file URL from an HTML document, if any.
///
/// - parameter document: The HTML document to scan for browser config XML file URLs.
/// - parameter baseURL: The base URL that any 'href' attributes are relative to.
/// - returns: A named tuple describing the file URL or a flag indicating that the server
///            explicitly requested that the file not be downloaded.
func extractBrowserConfigURL(_ document: HTMLDocument, baseURL: URL) -> (url: URL?, disabled: Bool) {
  for meta in document.query("/html/head/meta") {
    if let name = meta.attributes["name"]?.lowercased(), name == "msapplication-config",
      let content = meta.attributes["content"] {
      if content.lowercased() == "none" {
        // Explicitly asked us not to download the file.
        return (url: nil, disabled: true)
      } else {
        return (url: URL(string: content, relativeTo: baseURL)?.absoluteURL, disabled: false)
      }
    }
  }
  return (url: nil, disabled: false)
}

/// Helper function for parsing a W3 `sizes` attribute value.
///
/// - parameter string: If not `nil`, the value of the attribute to parse (e.g. `50x50 144x144`).
/// - returns: An array of `IconSize` structs for each size found.
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

