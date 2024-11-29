//
//  Zip+Extensions.swift
//  Strongbox
//
//  Created by Strongbox on 21/11/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import Zip

extension Zip {
    class func unzipDataToUniqueDirectory(data: Data) throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
        let uniqFile = temp.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: uniqFile)
        }

        try data.write(to: uniqFile)

        return try unzipUrlToUniqueDirectory(url: uniqFile)
    }

    class func unzipUrlToUniqueDirectory(url: URL) throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
        let uniqDir = temp.appendingPathComponent(UUID().uuidString)

        StrongboxFilesManager.sharedInstance().createIfNecessary(uniqDir)

        Zip.addCustomFileExtension(url.pathExtension) 

        try Zip.unzipFile(url, destination: uniqDir, overwrite: true, password: nil)

        return uniqDir
    }
}
