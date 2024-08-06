//
//  SwiftEntryModelInterface.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import OrderedCollections

protocol SwiftItemModelInterface: Comparable, Identifiable where ID == UUID {
    var id: Self.ID { get }

    var uuid: UUID { get }
    var title: String { get }
    var image: IMAGE_TYPE_PTR { get }
    var isGroup: Bool { get }
}

protocol SwiftGroupModelInterface: SwiftItemModelInterface {}

protocol SwiftEntryModelInterface: SwiftItemModelInterface {
    var username: String { get }
    var password: String { get }
    var email: String { get }
    var url: String { get }
    var notes: String { get }
    var tags: [String] { get }
    var totp: OTPToken? { get }
    var searchFoundInPath: String { get }
    func toggleFavourite() -> Bool
    var isFavourite: Bool { get }
    var isFlaggedByAudit: Bool { get }
    var launchableUrl: URL? { get }

    var customFields: OrderedDictionary<String, StringValue> { get }
}
