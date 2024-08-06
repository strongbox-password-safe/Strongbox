//
//  CloudKitHostedDatabase.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import Foundation

extension CloudKitHostedDatabase {
    enum RecordKeys {
        static let nickname = "nickname"
        static let filename = "filename"
        static let dataBlob = "dataBlob"
        static let modDate = "modDate"
    }
}

struct CloudKitHostedDatabase: Identifiable {
    let id: CloudKitDatabaseIdentifier

    let nickname: String
    let filename: String
    let modDate: Date
    let dataBlob: Data? 
    let associatedCkRecord: CKRecord
    let sharedWithMe: Bool

    init?(record: CKRecord, sharedWithMe: Bool) {
        self.sharedWithMe = sharedWithMe

        if sharedWithMe {
            guard let ownerName = record.share?.recordID.zoneID.ownerName else {
                swlog("🔴 Database CKRecord marked as sharedWithMe but share is nil or ownerName on CKShare is nil")
                return nil
            }

            id = CloudKitDatabaseIdentifier(recordName: record.recordID.recordName, sharedWithMeOwnerName: ownerName)
        } else {
            id = CloudKitDatabaseIdentifier(recordName: record.recordID.recordName, sharedWithMeOwnerName: nil)
        }

        guard let nickname = record.encryptedValues[RecordKeys.nickname] as? String else {
            swlog("🔴 Could not read required field [\(RecordKeys.nickname)] from CKRecord - Invalid Database. \(id)")
            return nil
        }
        guard let filename = record.encryptedValues[RecordKeys.filename] as? String else {
            swlog("🔴 Could not read required field [\(RecordKeys.filename)] from CKRecord - Invalid Database. \(nickname) \(id)")
            return nil
        }
        guard let modDate = record.encryptedValues[RecordKeys.modDate] as? Date else {
            swlog("🔴 Could not read required field [\(RecordKeys.modDate)] from CKRecord - Invalid Database.  \(nickname) \(id)")
            return nil
        }

        self.nickname = nickname
        self.filename = filename
        self.modDate = modDate

        if let asset = record[RecordKeys.dataBlob] as? CKAsset {
            

            
            
            

            if let url = asset.fileURL {
                do {
                    dataBlob = try Data(contentsOf: url)
                } catch {
                    swlog("🔴 Could not read contents of URL for datablob asset [\(error)] id = \(id)")
                    return nil
                }
            } else {
                swlog("🔴 Could not read asset or fileUrl. url = \(String(describing: asset))")
                return nil
            }
        } else {
            dataBlob = nil
        }

        associatedCkRecord = record
    }
}
