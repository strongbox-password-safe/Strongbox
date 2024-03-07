//
//  Zipper.swift
//  Strongbox
//
//  Created by Strongbox on 25/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import UIKit
import Zip

@objc
public class Zipper: NSObject {
    @objc
    public class func zipFile(_ url: URL) throws -> URL {
        let outputPath = url.appendingPathExtension("zip")

        try Zip.zipFiles(paths: [url], zipFilePath: outputPath, password: nil, progress: nil)

        return outputPath
    }
}
