//
//  DatabaseUnzipper.swift
//  Strongbox
//
//  Created by Strongbox on 21/11/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Zip

@objc
class DatabaseUnzipper: NSObject {
    enum DatabaseUnzipperError: Error, LocalizedError {
        case noDatabaseFound

        var errorDescription: String? {
            switch self {
            case .noDatabaseFound:
                return NSLocalizedString("import_file_zip_no_database_found_msg", comment: "No database found in zip file")
            }
        }
    }

    @objc
    class func isZipFile(data: Data) -> Bool {
        data.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }

    @objc
    class func unzipSingleDatabase(data: Data) throws -> [Any] {
        let unzippedDir = try Zip.unzipDataToUniqueDirectory(data: data)

        defer {
            try? FileManager.default.removeItem(at: unzippedDir)
        }

        var files = [URL]()
        if let enumerator = FileManager.default.enumerator(at: unzippedDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if fileAttributes.isRegularFile! {
                        files.append(fileURL)
                    }
                } catch {
                    NSLog("\(error), \(fileURL)")
                }
            }
        }

        let first1: URL? = files.first { url in
            Serializator.isValidDatabaseSwiftCompat(url)
        }

        guard let first1 else {
            throw DatabaseUnzipperError.noDatabaseFound
        }

        let data = try Data(contentsOf: first1)

        return [data, first1]
    }
}
