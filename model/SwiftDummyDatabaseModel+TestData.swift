//
//  SwiftDummyDatabaseModel+TestData.swift
//  Strongbox
//
//  Created by Strongbox on 02/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

extension SwiftDummyDatabaseModel {
    static let TotpUrl = "otpauth://totp/Timely:Strongbox%20Schimke?secret=2Y&algorithm=SHA1&digits=6&period=30&issuer=Timely"

    static let TestEntries = [
        SwiftDummyEntryModel(title: "HSBC UK", favourite: true, tags: []),
        SwiftDummyEntryModel(title: "Lloyds", tags: ["Banking", "Finance"]),
        SwiftDummyEntryModel(title: "Bank of Ireland", favourite: true, tags: ["Chamonix", "Dublin", "London"]),
        SwiftDummyEntryModel(title: "Microsoft", favourite: true, tags: ["Personal", "London"], totpUrl: TotpUrl),
        SwiftDummyEntryModel(title: "Santander", tags: ["Cryptography"]),
        SwiftDummyEntryModel(title: "Google", tags: ["Dublin", "Cryptography"]),
        SwiftDummyEntryModel(title: "Starling", favourite: true, tags: ["Finance", "Dublin"]),
        SwiftDummyEntryModel(title: "Wise", tags: ["Chamonix", "Science & Technology"]),
    ]

    static var testModel: SwiftDatabaseModelInterface {
        let db = SwiftDummyDatabaseModel()

        db.nickName = "Mark's Database"
        db.entries = TestEntries
        db.auditModel = AuditViewModel(common: [TestEntries.first!])

        return db
    }
}
