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

import XCTest
@testable import FavIcon

#if os(iOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif

// swiftlint:disable function_body_length
// swiftlint:disable line_length

class FavIconTests: XCTestCase {
    func testScan() {
        var actualIcons: [DetectedIcon] = []

        performWebRequest(name: "scan") { requestCompleted in
            do {
                try FavIcon.scan("https://apple.com") { icons, meta in
                    actualIcons = icons
                    requestCompleted()
                }
            } catch let error {
                XCTFail("failed to detect icons: \(error)")
            }
        }

        XCTAssertEqual(1, actualIcons.count)
        XCTAssertEqual(URL(string: "https://www.apple.com/favicon.ico")!, actualIcons[0].url)
    }

    func testDownloading() {
        var actualResults: [IconDownloadResult] = []

        performWebRequest(name: "download") { requestCompleted in
            do {
                try FavIcon.downloadAll("https://apple.com") { results in
                    actualResults = results
                    requestCompleted()
                }
            } catch let error {
                XCTFail("failed to download icons: \(error)")
            }
        }

        XCTAssertEqual(1, actualResults.count)

        switch actualResults[0] {
        case .success(let image):
            XCTAssertEqual(32, image.size.width)
            XCTAssertEqual(32, image.size.height)
            break
        case .failure(let error):
            XCTFail("unexpected error returned for download: \(error)")
            break
        }
    }

    func testChooseIcon() {
        let mixedIcons = [
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .shortcut, width: 32, height: 32),
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .classic, width: 64, height: 64),
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .appleIOSWebClip, width: 64, height: 64),
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .appleOSXSafariTab, width: 144, height: 144),
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .classic)
        ]
        let noSizeIcons = [
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .classic),
            DetectedIcon(url: URL(string: "https://google.com/favicon.ico")!, type: .shortcut)
        ]

        var icon = FavIcon.chooseIcon(mixedIcons, width: 50, height: 50)

        XCTAssertNotNil(icon)
        XCTAssertEqual(64, icon!.width)
        XCTAssertEqual(64, icon!.height)

        icon = FavIcon.chooseIcon(mixedIcons, width: 28, height: 28)

        XCTAssertNotNil(icon)
        XCTAssertEqual(32, icon!.width)
        XCTAssertEqual(32, icon!.height)

        icon = FavIcon.chooseIcon(mixedIcons)

        XCTAssertNotNil(icon)
        XCTAssertEqual(144, icon!.width)
        XCTAssertEqual(144, icon!.height)

        icon = FavIcon.chooseIcon(noSizeIcons)

        XCTAssertNotNil(icon)
        XCTAssertEqual(DetectedIconType.shortcut.rawValue, icon!.type.rawValue)

        icon = FavIcon.chooseIcon([])

        XCTAssertNil(icon)
    }

    func testHTMLHeadIconExtraction() {
        let html = stringForContentsOfFile(filePath: pathForTestBundleResource(fileName: "SampleHTMLFile.html")) ?? ""
        let document = HTMLDocument(string: html)
        let icons = extractHTMLHeadIcons(document, baseURL: URL(string: "https://localhost")!)

        XCTAssertEqual(19, icons.count)

        XCTAssertEqual("https://localhost/shortcut.ico", icons[0].url.absoluteString)
        XCTAssertEqual(DetectedIconType.shortcut.rawValue, icons[0].type.rawValue)
        XCTAssertNil(icons[0].width)
        XCTAssertNil(icons[0].height)

        XCTAssertEqual("https://localhost/content/images/favicon-96x96.png", icons[1].url.absoluteString)
        XCTAssertEqual(DetectedIconType.googleTV.rawValue, icons[1].type.rawValue)
        XCTAssertEqual(96, icons[1].width!)
        XCTAssertEqual(96, icons[1].height!)

        XCTAssertEqual("https://localhost/content/images/favicon-16x16.png", icons[2].url.absoluteString)
        XCTAssertEqual(DetectedIconType.classic.rawValue, icons[2].type.rawValue)
        XCTAssertEqual(16, icons[2].width!)
        XCTAssertEqual(16, icons[2].height!)

        XCTAssertEqual("https://localhost/content/images/favicon-32x32.png", icons[3].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleOSXSafariTab.rawValue, icons[3].type.rawValue)
        XCTAssertEqual(32, icons[3].width!)
        XCTAssertEqual(32, icons[3].height!)

        XCTAssertEqual("https://localhost/content/icons/favicon-192x192.png", icons[4].url.absoluteString)
        XCTAssertEqual(DetectedIconType.googleAndroidChrome.rawValue, icons[4].type.rawValue)
        XCTAssertEqual(192, icons[4].width!)
        XCTAssertEqual(192, icons[4].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-57x57.png", icons[5].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[5].type.rawValue)
        XCTAssertEqual(57, icons[5].width!)
        XCTAssertEqual(57, icons[5].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-114x114.png", icons[6].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[6].type.rawValue)
        XCTAssertEqual(114, icons[6].width!)
        XCTAssertEqual(114, icons[6].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-72x72.png", icons[7].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[7].type.rawValue)
        XCTAssertEqual(72, icons[7].width!)
        XCTAssertEqual(72, icons[7].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-144x144.png", icons[8].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[8].type.rawValue)
        XCTAssertEqual(144, icons[8].width!)
        XCTAssertEqual(144, icons[8].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-60x60.png", icons[9].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[9].type.rawValue)
        XCTAssertEqual(60, icons[9].width!)
        XCTAssertEqual(60, icons[9].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-120x120.png", icons[10].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[10].type.rawValue)
        XCTAssertEqual(120, icons[10].width!)
        XCTAssertEqual(120, icons[10].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-76x76.png", icons[11].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[11].type.rawValue)
        XCTAssertEqual(76, icons[11].width!)
        XCTAssertEqual(76, icons[11].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-152x152.png", icons[12].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[12].type.rawValue)
        XCTAssertEqual(152, icons[12].width!)
        XCTAssertEqual(152, icons[12].height!)

        XCTAssertEqual("https://localhost/content/images/apple-touch-icon-180x180.png", icons[13].url.absoluteString)
        XCTAssertEqual(DetectedIconType.appleIOSWebClip.rawValue, icons[13].type.rawValue)
        XCTAssertEqual(180, icons[13].width!)
        XCTAssertEqual(180, icons[13].height!)

        XCTAssertEqual("https://localhost/content/images/mstile-144x144.png", icons[14].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[14].type.rawValue)
        XCTAssertEqual(144, icons[14].width!)
        XCTAssertEqual(144, icons[14].height!)

        XCTAssertEqual("https://localhost/tile-tiny.png", icons[15].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[15].type.rawValue)
        XCTAssertEqual(70, icons[15].width!)
        XCTAssertEqual(70, icons[15].height!)

        XCTAssertEqual("https://localhost/tile-square.png", icons[16].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[16].type.rawValue)
        XCTAssertEqual(150, icons[16].width!)
        XCTAssertEqual(150, icons[16].height!)

        XCTAssertEqual("https://localhost/tile-wide.png", icons[17].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[17].type.rawValue)
        XCTAssertEqual(310, icons[17].width!)
        XCTAssertEqual(150, icons[17].height!)

        XCTAssertEqual("https://localhost/tile-large.png", icons[18].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[18].type.rawValue)
        XCTAssertEqual(310, icons[18].width!)
        XCTAssertEqual(310, icons[18].height!)
    }

    func testManifestJSONIconExtraction() {
        let json = stringForContentsOfFile(filePath: pathForTestBundleResource(fileName: "SampleManifest.json")) ?? ""
        let icons = extractManifestJSONIcons(json, baseURL: URL(string: "https://localhost")!)

        XCTAssertEqual(6, icons.count)

        XCTAssertEqual("https://localhost/launcher-icon-0-75x.png", icons[0].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[0].type.rawValue)
        XCTAssertEqual(36, icons[0].width!)
        XCTAssertEqual(36, icons[0].height!)

        XCTAssertEqual("https://localhost/launcher-icon-1x.png", icons[1].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[1].type.rawValue)
        XCTAssertEqual(48, icons[1].width!)
        XCTAssertEqual(48, icons[1].height!)

        XCTAssertEqual("https://localhost/launcher-icon-1-5x.png", icons[2].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[2].type.rawValue)
        XCTAssertEqual(72, icons[2].width!)
        XCTAssertEqual(72, icons[2].height!)

        XCTAssertEqual("https://localhost/launcher-icon-2x.png", icons[3].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[3].type.rawValue)
        XCTAssertEqual(96, icons[3].width!)
        XCTAssertEqual(96, icons[3].height!)

        XCTAssertEqual("https://localhost/launcher-icon-3x.png", icons[4].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[4].type.rawValue)
        XCTAssertEqual(144, icons[4].width!)
        XCTAssertEqual(144, icons[4].height!)

        XCTAssertEqual("https://localhost/launcher-icon-4x.png", icons[5].url.absoluteString)
        XCTAssertEqual(DetectedIconType.webAppManifest.rawValue, icons[5].type.rawValue)
        XCTAssertEqual(192, icons[5].width!)
        XCTAssertEqual(192, icons[5].height!)
    }

    func testBrowserConfigXMLIconExtraction() {
        let xml = stringForContentsOfFile(filePath: pathForTestBundleResource(fileName: "SampleBrowserConfig.xml")) ?? ""
        let document = LBXMLDocument(string: xml)
        let icons = extractBrowserConfigXMLIcons(document, baseURL: URL(string: "https://localhost")!)

        XCTAssertEqual(5, icons.count)

        XCTAssertEqual("https://localhost/small.png", icons[0].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[0].type.rawValue)
        XCTAssertEqual(70, icons[0].width!)
        XCTAssertEqual(70, icons[0].height!)

        XCTAssertEqual("https://localhost/medium.png", icons[1].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[1].type.rawValue)
        XCTAssertEqual(150, icons[1].width!)
        XCTAssertEqual(150, icons[1].height!)

        XCTAssertEqual("https://localhost/wide.png", icons[2].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[2].type.rawValue)
        XCTAssertEqual(310, icons[2].width!)
        XCTAssertEqual(150, icons[2].height!)

        XCTAssertEqual("https://localhost/large.png", icons[3].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[3].type.rawValue)
        XCTAssertEqual(310, icons[3].width!)
        XCTAssertEqual(310, icons[3].height!)

        XCTAssertEqual("https://localhost/tile.png", icons[4].url.absoluteString)
        XCTAssertEqual(DetectedIconType.microsoftPinnedSite.rawValue, icons[4].type.rawValue)
        XCTAssertEqual(144, icons[4].width!)
        XCTAssertEqual(144, icons[4].height!)
    }

    func testIssue6_ContentTypeWithEmptyComponent() {
        let result = "text/html;;charset=UTF-8".parseAsHTTPContentTypeHeader()

        XCTAssertEqual("text/html", result.mimeType)
        XCTAssertEqual(String.Encoding.utf8, result.encoding)
    }

    private func pathForTestBundleResource(fileName: String) -> String {
        let testBundle = Bundle(for: FavIconTests.self)
        return testBundle.path(forResource: fileName, ofType: "")!
    }

    private func stringForContentsOfFile(filePath: String, encoding: String.Encoding = String.Encoding.utf8) -> String? {
        return try? String(contentsOfFile: filePath, encoding: encoding) as String
    }
}

private extension XCTestCase {
    func performWebRequest(name: String, timeout: TimeInterval = 50000.0, callback: (@escaping () -> Void) -> Void) {
        FavIcon.urlSessionProvider = { URLSession.shared }
        let expectation = self.expectation(description: "web request - \(name)")
        callback(expectation.fulfill)
        waitForExpectations(timeout: timeout, handler: nil)
    }
}

// swiftlint:enable function_body_length
// swiftlint:enable line_length
