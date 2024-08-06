//
//  CloudKitDatabaseIdentifier.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import Foundation

struct CloudKitDatabaseIdentifier: Codable, Equatable, Identifiable, Hashable {
    var id: String {
        if let sharedWithMeOwnerName {
            return recordName + sharedWithMeOwnerName
        } else {
            return recordName
        }
    }

    var sharedWithMe: Bool { sharedWithMeOwnerName != nil }

    var recordName: String
    var sharedWithMeOwnerName: String? 

    var json: String {
        let data = try! JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }

    static func fromJson(_ json: String?) -> Self? {
        guard let json, let data = json.data(using: .utf8) else {
            swlog("🔴 Could not decode CloudKitDatabaseFileIdentifier!")
            return nil
        }

        do {
            return try JSONDecoder().decode(CloudKitDatabaseIdentifier.self, from: data)
        } catch {
            swlog("🔴 Could not JSON decode CloudKitDatabaseFileIdentifier! \(error)")
            return nil
        }
    }

    var zoneID: CKRecordZone.ID {
        if let sharedWithMeOwnerName {
            return CKRecordZone.ID(zoneName: CloudKitManager.RecordZoneName, ownerName: sharedWithMeOwnerName)
        } else {
            return CKRecordZone.ID(zoneName: CloudKitManager.RecordZoneName, ownerName: CKCurrentUserDefaultName)
        }
    }
}
