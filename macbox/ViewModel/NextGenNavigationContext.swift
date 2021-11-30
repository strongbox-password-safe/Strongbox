//
//  NextGenNavigationContext.swift
//  MacBox
//
//  Created by Strongbox on 15/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

typealias NodeIdentifier = UUID

enum NavigationContext : Equatable {
    enum SpecialNavigationItem : Equatable {
        case allEntries
        case expiredEntries
        case nearlyExpiredEntries
        case auditIssues
    }

    case favourites( _ node : NodeIdentifier )
    case regularHierarchy( _ group : NodeIdentifier? )
    case tags ( _ tag : String )
    case totps ( _ node : NodeIdentifier )
    case special ( _ item : SpecialNavigationItem )
    case search ( _ criteria : String )
}
