//
//  AddOrCreateHelper.swift
//  MacBox
//
//  Created by Strongbox on 18/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

enum AddOrCreateHelper {
    static func getGroupPathDisplayString(_ node: Node, _ database: DatabaseModel, _ rootGroupNameInsteadOfSlash: Bool = false) -> String {
        database.getPathDisplayString(node, includeRootGroup: true, rootGroupNameInsteadOfSlash: rootGroupNameInsteadOfSlash, includeFolderEmoji: false, joinedBy: "/")
    }

    static func getSortedGroups(_ model: Model) -> [Node] {
        model.database.allActiveGroups.sorted { n1, n2 in
            let p1 = getGroupPathDisplayString(n1, model.database)
            let p2 = getGroupPathDisplayString(n2, model.database)
            return finderStringCompare(p1, p2) == .orderedAscending
        }
    }
}
