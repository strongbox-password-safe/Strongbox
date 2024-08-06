//
//  NativeMessagingManifestInstallHelper.swift
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

struct FirefoxNativeMessagingManifest: Encodable {
    let name: String = "com.markmcguill.strongbox"
    let description: String = "Strongbox Browser AutoFill Extension"
    var path: String
    let type: String = "stdio"
    let allowed_extensions: [String] = ["strongbox@phoebecode.com"]
}

struct ChromeNativeMessagingManifest: Encodable {
    let name: String = "com.markmcguill.strongbox"
    let description: String = "Strongbox Browser AutoFill Extension"
    var path: String
    let type: String = "stdio"

    


    

    let allowed_origins: [String] = ["chrome-extension:

    
}

class NativeMessagingManifestInstallHelper: NSObject {
    @objc
    class func installNativeMessagingHostsFiles() {
        installFirefoxLikeManifestAt("Library/Application Support/Mozilla/NativeMessagingHosts")
        installFirefoxLikeManifestAt("Library/Application Support/librewolf/NativeMessagingHosts")
        installFirefoxLikeManifestAt("Library/Application Support/TorBrowser-Data/Browser/Mozilla/NativeMessagingHosts")

        installForChromiumBasedBrowser("Library/Application Support/Google/Chrome/NativeMessagingHosts")
        installForChromiumBasedBrowser("Library/Application Support/Google/Chrome Beta/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Google/Chrome Dev/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Google/Chrome Canary/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Chromium/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Microsoft Edge/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Microsoft Edge Beta/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Microsoft Edge Dev/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Microsoft Edge Canary/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Vivaldi/NativeMessagingHosts/")
        installForChromiumBasedBrowser("Library/Application Support/Arc/User Data/NativeMessagingHosts")
        installForChromiumBasedBrowser("Library/Application Support/Sidekick/NativeMessagingHosts")
        installForChromiumBasedBrowser("Library/Application Support/Thorium/NativeMessagingHosts")
        installForChromiumBasedBrowser("Library/Application Support/Orion/NativeMessagingHosts") 
        installForChromiumBasedBrowser("Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts")

        
    }

    @objc
    class func removeNativeMessagingHostsFiles() {
        removeManifest("Library/Application Support/Mozilla/NativeMessagingHosts")
        removeManifest("Library/Application Support/librewolf/NativeMessagingHosts")

        removeManifest("Library/Application Support/Google/Chrome/NativeMessagingHosts")
        removeManifest("Library/Application Support/Google/Chrome Beta/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Google/Chrome Dev/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Google/Chrome Canary/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Chromium/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Microsoft Edge/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Microsoft Edge Beta/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Microsoft Edge Dev/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Microsoft Edge Canary/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Vivaldi/NativeMessagingHosts/")
        removeManifest("Library/Application Support/Arc/User Data/NativeMessagingHosts")
        removeManifest("Library/Application Support/Sidekick/NativeMessagingHosts")
        removeManifest("Library/Application Support/Thorium/NativeMessagingHosts")
        removeManifest("Library/Application Support/Orion/NativeMessagingHosts")

        removeManifest("Library/Application Support/Orion/NativeMessagingHosts")
        removeManifest("Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts")
        removeManifest("Library/Application Support/TorBrowser-Data/Browser/Mozilla/NativeMessagingHosts")
    }

    class func removeManifest(_ path: String) {
        let filename = "com.markmcguill.strongbox.json"
        let browserPathUrl = Utils.userHomeDirectoryEvenInSandbox().appendingPathComponent(path)
        let fullPath = browserPathUrl.appendingPathComponent(filename)

        do {
            try FileManager.default.removeItem(at: fullPath)

            swlog("✅ Removed Native Manifest... [%@]", path)
        } catch {
            if (error as NSError).code == NSFileNoSuchFileError {
                return
            } else {
                swlog("🔴 Couldn't delete Native Manifest... [%@]", String(describing: error))
            }
        }
    }

    class func installFirefoxLikeManifestAt(_ browserHomePath: String) {
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/afproxy").path
        let manifest = FirefoxNativeMessagingManifest(path: path)

        writeNativeManifest(manifest, browserHomePath: browserHomePath)
    }

    class func installForChromiumBasedBrowser(_ browserHomePath: String) {
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/afproxy").path
        let manifest = ChromeNativeMessagingManifest(path: path)

        writeNativeManifest(manifest, browserHomePath: browserHomePath)
    }

    class func writeNativeManifest(_ manifest: Encodable, browserHomePath: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let encodedData = try? encoder.encode(manifest),
              let jsonString = String(data: encodedData, encoding: .utf8)
        else {
            swlog("🔴 Could not encode to JSON")
            return
        }

        let filename = "com.markmcguill.strongbox.json"
        let browserPathUrl = Utils.userHomeDirectoryEvenInSandbox().appendingPathComponent(browserHomePath)
        let fullPath = browserPathUrl.appendingPathComponent(filename)

        let dir = fullPath.deletingLastPathComponent().path
        let parentDir = fullPath.deletingLastPathComponent().deletingLastPathComponent().path

        if FileManager.default.fileExists(atPath: parentDir) { 
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try jsonString.write(toFile: fullPath.path, atomically: true, encoding: .utf8)

            } catch {
                swlog("🔴 Couldn't write Native Manifest... [%@]", String(describing: error))
            }
        }
    }
}
