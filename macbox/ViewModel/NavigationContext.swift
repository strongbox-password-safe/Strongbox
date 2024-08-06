//
//  NavigationContext.swift
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
        case totpItems
        case itemsWithAttachments
        case expiredEntries
        case nearlyExpiredEntries
        case keeAgentSshKeyEntries
        case passkeys
        case allFavourites
    }

    enum AuditNavigationCategory: Equatable {
        case noPasswords
        case duplicated
        case common
        case similar
        case tooShort
        case pwned
        case lowEntropy
        case twoFactorAvailable
        case allEntries
        case excludedItems
    }

    case none 
    case favourites(_ node: NodeIdentifier)
    case regularHierarchy(_ group: NodeIdentifier)
    case tags(_ tag: String)
    case auditIssues(_ category: AuditNavigationCategory)
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
    case .auditIssues:
        return OGNavigationContextAuditIssues
    case .special:
        return OGNavigationContextSpecial
    }
}

func convertSpecialToOGSpecial(_ special: NavigationContext.SpecialNavigationItem) -> OGNavigationSpecial {
    switch special {
    case .allEntries:
        return OGNavigationSpecialAllItems
    case .expiredEntries:
        return OGNavigationSpecialExpired
    case .nearlyExpiredEntries:
        return OGNavigationSpecialNearlyExpired
    case .totpItems:
        return OGNavigationSpecialTotpItems
    case .itemsWithAttachments:
        return OGNavigationSpecialAttachmentItems
    case .keeAgentSshKeyEntries:
        return OGNavigationSpecialKeeAgentSshKeyItems
    case .passkeys:
        return OGNavigationSpecialPasskeys
    case .allFavourites:
        return OGNavigationSpecialAllFavourites
    }
}

func convertAuditCategoryToOGCategory(_ category: NavigationContext.AuditNavigationCategory) -> OGNavigationAuditCategory {
    switch category {
    case .noPasswords:
        return OGNavigationAuditCategoryNoPasswords
    case .duplicated:
        return OGNavigationAuditCategoryDuplicated
    case .common:
        return OGNavigationAuditCategoryCommon
    case .similar:
        return OGNavigationAuditCategorySimilar
    case .tooShort:
        return OGNavigationAuditCategoryTooShort
    case .pwned:
        return OGNavigationAuditCategoryPwned
    case .lowEntropy:
        return OGNavigationAuditCategoryLowEntropy
    case .twoFactorAvailable:
        return OGNavigationAuditCategoryTwoFactorAvailable
    case .allEntries:
        return OGNavigationAuditCategoryAllEntries
    case .excludedItems:
        return OGNavigationAuditCategoryExcludedItems
    }
}

func setModelNavigationContextWithViewNode(_ database: ViewModel, _ context: NavigationContext) {


    switch context {
    case .none:
        database.setNextGenNavigationNone()
    case let .regularHierarchy(groupId):
        database.setNextGenNavigation(convertToOgNavigationContext(context), selectedGroup: groupId)
    case let .favourites(nodeId):
        database.setNextGenNavigationFavourite(nodeId)
    case let .tags(tag):
        database.setNextGenNavigation(convertToOgNavigationContext(context), tag: tag)
    case let .special(special):
        database.setNextGenNavigation(convertToOgNavigationContext(context), special: convertSpecialToOGSpecial(special))
    case let .auditIssues(category):
        database.setNextGenNavigationToAuditIssues(convertAuditCategoryToOGCategory(category))
    }
}

func getNavContextFromModel(_ database: ViewModel) -> NavigationContext { 
    var navContext: NavigationContext = .none

    switch database.nextGenNavigationContext {
    case OGNavigationContextNone:
        navContext = .none
    case OGNavigationContextFavourites:
        navContext = .favourites(database.nextGenNavigationSelectedFavouriteId)
    case OGNavigationContextRegularHierarchy:
        navContext = .regularHierarchy(database.nextGenNavigationContextSideBarSelectedGroup)
    case OGNavigationContextTags:
        navContext = .tags(database.nextGenNavigationContextSelectedTag)
    case OGNavigationContextAuditIssues:
        switch database.nextGenNavigationContextAuditCategory {
        case OGNavigationAuditCategoryNoPasswords:
            navContext = .auditIssues(.noPasswords)
        case OGNavigationAuditCategoryDuplicated:
            navContext = .auditIssues(.duplicated)
        case OGNavigationAuditCategoryCommon:
            navContext = .auditIssues(.common)
        case OGNavigationAuditCategorySimilar:
            navContext = .auditIssues(.similar)
        case OGNavigationAuditCategoryTooShort:
            navContext = .auditIssues(.tooShort)
        case OGNavigationAuditCategoryPwned:
            navContext = .auditIssues(.pwned)
        case OGNavigationAuditCategoryLowEntropy:
            navContext = .auditIssues(.lowEntropy)
        case OGNavigationAuditCategoryTwoFactorAvailable:
            navContext = .auditIssues(.twoFactorAvailable)
        case OGNavigationAuditCategoryAllEntries:
            navContext = .auditIssues(.allEntries)
        case OGNavigationAuditCategoryExcludedItems:
            navContext = .auditIssues(.excludedItems)
        default:
            swlog("🔴 Unknown OG Nav Context")
        }
    case OGNavigationContextSpecial:
        switch database.nextGenNavigationContextSpecial {
        case OGNavigationSpecialAllItems:
            navContext = .special(.allEntries)
        case OGNavigationSpecialExpired:
            navContext = .special(.expiredEntries)
        case OGNavigationSpecialNearlyExpired:
            navContext = .special(.nearlyExpiredEntries)
        case OGNavigationSpecialTotpItems:
            navContext = .special(.totpItems)
        case OGNavigationSpecialAttachmentItems:
            navContext = .special(.itemsWithAttachments)
        case OGNavigationSpecialKeeAgentSshKeyItems:
            navContext = .special(.keeAgentSshKeyEntries)
        case OGNavigationSpecialPasskeys:
            navContext = .special(.passkeys)
        case OGNavigationSpecialAllFavourites:
            navContext = .special(.allFavourites)
        default:
            swlog("🔴 Unknown OG Nav Context")
        }
    default:
        swlog("🔴 Unknown OG Nav Context")
    }

    return navContext
}
