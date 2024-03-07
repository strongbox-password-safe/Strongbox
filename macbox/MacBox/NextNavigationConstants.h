//
//  NextNavigationConstants.h
//  MacBox
//
//  Created by Strongbox on 31/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#ifndef NextNavigationConstants_h
#define NextNavigationConstants_h

typedef enum : NSUInteger {
    OGNavigationContextNone,
    OGNavigationContextFavourites,
    OGNavigationContextRegularHierarchy,
    OGNavigationContextTags,
    OGNavigationContextAuditIssues,
    OGNavigationContextSpecial,
} OGNavigationContext;

typedef enum : NSUInteger {
    OGNavigationSpecialAllItems,
    OGNavigationSpecialTotpItems,
    OGNavigationSpecialAttachmentItems,
    OGNavigationSpecialExpired,
    OGNavigationSpecialNearlyExpired,
    OGNavigationSpecialKeeAgentSshKeyItems,
    OGNavigationSpecialPasskeys,
    OGNavigationSpecialAllFavourites,
} OGNavigationSpecial;

typedef enum : NSUInteger {
    OGNavigationAuditCategoryNoPasswords,
    OGNavigationAuditCategoryDuplicated,
    OGNavigationAuditCategoryCommon,
    OGNavigationAuditCategorySimilar,
    OGNavigationAuditCategoryTooShort,
    OGNavigationAuditCategoryPwned,
    OGNavigationAuditCategoryLowEntropy,
    OGNavigationAuditCategoryTwoFactorAvailable,
    OGNavigationAuditCategoryAllEntries,
    OGNavigationAuditCategoryExcludedItems,
} OGNavigationAuditCategory;

#endif /* NextNavigationConstants_h */
