//
//  NativeMessagingManifestInstallHelper.swift
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

struct FirefoxNativeMessagingManifest : Encodable {
    let name : String = "com.markmcguill.strongbox"
    let description : String = "Strongbox Browser AutoFill Extension"
    var path : String
    let type : String = "stdio"
    let allowed_extensions : [String] = ["strongbox@phoebecode.com"]
}

struct ChromeNativeMessagingManifest : Encodable {
    let name : String = "com.markmcguill.strongbox"
    let description : String = "Strongbox Browser AutoFill Extension"
    var path : String
    let type : String = "stdio"
    
#if DEBUG
    let allowed_origins : [String] = ["chrome-extension:
                                      "chrome-extension:
#else
    let allowed_origins : [String] = ["chrome-extension:
#endif
}

class NativeMessagingManifestInstallHelper: NSObject {
    @objc
    class func installNativeMessagingHostsFiles() {
        installForFirefox()
        
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
    }
    
    class func installForFirefox () {
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/afproxy").path
        let manifest = FirefoxNativeMessagingManifest(path: path)
        
        writeNativeManifest( manifest, browserHomePath: "Library/Application Support/Mozilla/NativeMessagingHosts" )
    }
    
    class func installForChromiumBasedBrowser ( _ browserHomePath : String ) {
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/afproxy").path
        let manifest = ChromeNativeMessagingManifest(path: path)
        
        writeNativeManifest(manifest, browserHomePath: browserHomePath)
    }
    
    class func writeNativeManifest ( _ manifest : Encodable, browserHomePath: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let encodedData = try? encoder.encode(manifest),
              let jsonString = String(data: encodedData, encoding: .utf8) else {
            NSLog("🔴 Could not encode to JSON");
            return
        }
        
        let filename = "com.markmcguill.strongbox.json"
        let browserPathUrl = Utils.userHomeDirectoryEvenInSandbox().appendingPathComponent(browserHomePath)
        let fullPath = browserPathUrl.appendingPathComponent(filename)
        
        let dir = fullPath.deletingLastPathComponent().path;
        let parentDir = fullPath.deletingLastPathComponent().deletingLastPathComponent().path
        
        if ( FileManager.default.fileExists(atPath: parentDir)) { 
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try jsonString.write(toFile: fullPath.path, atomically: true, encoding: .utf8)
                NSLog("✅ Wrote Native Messaging Manifest at [%@]", fullPath.path);
            }
            catch {
                NSLog("🔴 Couldn't write Native Manifest... [%@]", String.init(describing: error));
            }
        }
    }
}
