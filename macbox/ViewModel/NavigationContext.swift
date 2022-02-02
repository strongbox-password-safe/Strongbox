//
//  NextGenNavigationContext.swift
//  MacBox
//
//  Created by Strongbox on 15/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

typealias NodeIdentifier = UUID

enum NavigationContext: Equatable {
    enum SpecialNavigationItem: Equatable {
        case allEntries

        



        
    }

    case none 
    case favourites(_ node: NodeIdentifier)
    case regularHierarchy(_ group: NodeIdentifier)
    case tags(_ tag: String)
    case totps(_ node: NodeIdentifier)
    case special(_ item: SpecialNavigationItem)
}

func convertToOgNavigationContext(_ context: NavigationContext) -> OGNavigationContext {
    switch context {
    case .none:
        return OGNavigationContextNone
    case .regularHierarchy:
        return OGNavigationContextRegularHierarchy
    case .favourites:
        return OGNavigationContextFavourites
    case .tags:
        return OGNavigationContextTags
    case .totps:
        return OGNavigationContextTotps
    case .special:
        return OGNavigationContextSpecial
    }
}

func convertSpecialToOGSpecial(_ special: NavigationContext.SpecialNavigationItem) -> OGNavigationSpecial {
    switch special {
    case .allEntries:
        return OGNavigationSpecialAllItems
    }
}

func setModelNavigationContextWithViewNode(_ database: ViewModel, _ context: NavigationContext) {


    switch context {
    case .none:
        database.setNextGenNavigationNone()
    case let .regularHierarchy(groupId):
        database.setNextGenNavigation(convertToOgNavigationContext(context), selectedGroup: groupId)
    case .favourites:
        NSLog("✅ setModelNavigationContextWithViewNode: favourites") 
    case let .tags(tag):
        database.setNextGenNavigation(convertToOgNavigationContext(context), tag: tag)
    case .totps:
        NSLog("✅ setModelNavigationContextWithViewNode: totps") 
    case let .special(special):
        database.setNextGenNavigation(convertToOgNavigationContext(context), special: convertSpecialToOGSpecial(special))
    }
}

func getNavContextFromModel(_ database: ViewModel) -> NavigationContext { 
    var navContext: NavigationContext = .none

    switch database.nextGenNavigationContext {
    case OGNavigationContextNone:
        navContext = .none
    case OGNavigationContextFavourites:
        
        break
    case OGNavigationContextRegularHierarchy:
        navContext = .regularHierarchy(database.nextGenNavigationContextSideBarSelectedGroup)
    case OGNavigationContextTags:
        navContext = .tags(database.nextGenNavigationContextSelectedTag)
    case OGNavigationContextTotps:
        
        break
    case OGNavigationContextSpecial:
        switch database.nextGenNavigationContextSpecial {
        case OGNavigationSpecialAllItems:
            navContext = .special(.allEntries)
        default:
            NSLog("🔴 Unknown OG Nav Context")
        }
    default:
        NSLog("🔴 Unknown OG Nav Context")
    }

    return navContext
}

































