//
//  SwiftDummyEntryModel.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import OrderedCollections

class SwiftDummyEntryModel: SwiftEntryModelInterface {
    var customFields: OrderedDictionary<String, StringValue> {
        .init()
    }

    var launchableUrl: URL? {
        guard !url.isEmpty else { return nil }

        return url.urlExtendedParseAddingDefaultScheme
    }

    var isFlaggedByAudit: Bool { false }

    static func == (lhs: SwiftDummyEntryModel, rhs: SwiftDummyEntryModel) -> Bool {
        lhs.uuid == rhs.uuid
    }

    static func < (lhs: SwiftDummyEntryModel, rhs: SwiftDummyEntryModel) -> Bool {
        lhs.title < rhs.title
    }

    var tags: [String] = []

    var favourite = false

    func toggleFavourite() -> Bool {
        favourite.toggle()
        return false
    }

    var isFavourite: Bool { favourite }

    var isGroup: Bool { false }

    var searchFoundInPath: String { "in Database/Finance/Another Folder" }

    var id: UUID { uuid }
    let uuid: UUID = .init()

    var title: String = ""
    var username: String = ""
    var password: String = ""
    var email: String = ""
    var notes: String = ""
    var url: String = ""

    var image: IMAGE_TYPE_PTR
    var totp: OTPToken?

    

    init(title: String = "Dummy", username: String = "Username", password: String = "pw1234", imageSystemName: String = "doc", favourite: Bool = false, tags: [String] = [], totpUrl: String? = nil) {
        #if os(iOS)
            let i = UIImage(systemName: imageSystemName)!
            let tinted = i.withTintColor(.blue, renderingMode: .alwaysTemplate)
        #else
            let i = NSImage(systemSymbolName: imageSystemName, accessibilityDescription: nil)!

            let tinted = i
        #endif

        var totp: OTPToken? = nil
        if let totpUrl {
            totp = OTPToken(url: URL(string: totpUrl))
        }

        self.title = title
        self.username = username
        self.password = password
        image = tinted
        self.totp = totp
        self.favourite = favourite
        self.tags = tags
    }
}
