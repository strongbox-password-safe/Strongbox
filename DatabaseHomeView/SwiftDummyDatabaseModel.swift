//
//  SwiftDummyDatabaseModel.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class SwiftDummyDatabaseModel: SwiftDatabaseModelInterface {
    var showIcons = true

    var format: DatabaseFormat = .keePass4
    var ckfs: CompositeKeyFactors = .init(password: "a")

    #if os(iOS)
        var visibleHomeSections: Set<HomeViewSection> = Set([.favourites, .navigation, .otherViews, .quickTags])

        func isHomeViewSectionVisible(section: HomeViewSection) -> Bool {
            visibleHomeSections.contains(section)
        }

        func setHomeViewSectionVisible(section: HomeViewSection, visible: Bool) {
            if visible {
                visibleHomeSections.insert(section)
            } else {
                visibleHomeSections.remove(section)
            }
        }
    #endif

    var nickName: String = "Mark's Database"
    var entries: [any SwiftEntryModelInterface] = []

    var id: String { uuid }
    let uuid: String = UUID().uuidString

    var isReadOnly: Bool = false
    var isKeePass2Format: Bool = true
    var isItemsCanBeExported: Bool = true

    var isInOfflineMode: Bool = false
    var disableExport: Bool = false
    var disablePrinting: Bool = false
    var startWithSearch: Bool = false
    var tagCount: Int = 5
    var recycleBinCount: Int = 21
    var passkeyEntryCount: Int = 2
    var sshKeyEntryCount: Int = 3
    var attachmentsEntryCount = 34
    var expiredEntryCount = 2
    var expiringEntryCount = 3
    var entryCount: Int { entries.count }
    var groupCount: Int { 123 }

    var totpCodeEntries: [any SwiftEntryModelInterface] {
        entries
            .filter { $0.totp != nil }
    }

    var favourites: [any SwiftEntryModelInterface] {
        entries
            .filter(\.isFavourite)
    }

    var tags: [String] {
        let allTags = entries
            .filter { $0.tags.count > 0 }
            .flatMap(\.tags)

        let set = Set(allTags)

        return set.sorted()
    }

    var popularTags: [String] {
        Array(tags.prefix(2))
    }

    var auditIssueEntryCount: Int {
        auditModel.totalIssueCount
    }

    var auditModel: AuditViewModel = .init()

    func search(searchText: String, searchScope _: SearchScope) -> [any SwiftEntryModelInterface] {
        Self.TestEntries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    func canRecycle(item _: any SwiftItemModelInterface) -> Bool {
        true
    }

    var recycleBinNodeUuid: UUID? = nil

    var recycleBinGroup: (any SwiftGroupModelInterface)? {
        nil
    }
}
