//
//  BrowseViewType.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef BrowseViewType_h
#define BrowseViewType_h

typedef NS_ENUM (NSUInteger, BrowseViewType) {
    kBrowseViewTypeHierarchy,
    kBrowseViewTypeList,
    kBrowseViewTypeTotpList,
    kBrowseViewTypeFavourites,
    kBrowseViewTypeTags,
    kBrowseViewTypeHome,
    
    kBrowseViewTypePasskeys,
    kBrowseViewTypeSshKeys,
    kBrowseViewTypeAttachments,
    kBrowseViewTypeExpiredAndExpiring,
    kBrowseViewTypeAuditIssues,
};

#endif /* BrowseViewType_h */
