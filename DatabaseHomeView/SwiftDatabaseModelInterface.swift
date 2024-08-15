//
//  SwiftDatabaseModelInterface.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

// Allows [any SwiftEntryModelInterface] to conform to Identifiable for easy use in ForEach's like:





extension ForEach where ID == UUID, Content: View, Data.Element == any SwiftEntryModelInterface {
    init(_ data: Data, @ViewBuilder content: @escaping (any SwiftEntryModelInterface) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

protocol SwiftDatabaseModelInterface {
    var format: DatabaseFormat { get }
    var ckfs: CompositeKeyFactors { get }

    var recycleBinGroup: (any SwiftGroupModelInterface)? { get }

    var uuid: String { get }
    var nickName: String { get }
    var tags: [String] { get }
    var popularTags: [String] { get }

    var favourites: [any SwiftEntryModelInterface] { get }
    var totpCodeEntries: [any SwiftEntryModelInterface] { get }

    var tagCount: Int { get }
    var recycleBinCount: Int { get }

    var passkeyEntryCount: Int { get }
    var sshKeyEntryCount: Int { get }
    var attachmentsEntryCount: Int { get }
    var expiredEntryCount: Int { get }
    var expiringEntryCount: Int { get }

    var entryCount: Int { get }
    var groupCount: Int { get }

    var isReadOnly: Bool { get }
    var isInOfflineMode: Bool { get }
    var isItemsCanBeExported: Bool { get }

    var isKeePass2Format: Bool { get }
    var recycleBinNodeUuid: UUID? { get }

    func canRecycle(item: any SwiftItemModelInterface) -> Bool
    func search(searchText: String, searchScope: SearchScope) -> [any SwiftEntryModelInterface]

    var auditIssueEntryCount: Int { get }
    var auditModel: AuditViewModel { get }

    var startWithSearch: Bool { get set }

    var disableExport: Bool { get }
    var disablePrinting: Bool { get }
    var showIcons: Bool { get }

    #if os(iOS)
        func isHomeViewSectionVisible(section: HomeViewSection) -> Bool
        func setHomeViewSectionVisible(section: HomeViewSection, visible: Bool)
    #endif
}
