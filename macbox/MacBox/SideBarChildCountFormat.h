//
//  SideBarChildCountFormat.h
//  MacBox
//
//  Created by Strongbox on 05/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#ifndef SideBarChildCountFormat_h
#define SideBarChildCountFormat_h

typedef NS_ENUM (NSInteger, SideBarChildCountFormat) {
    kSideBarChildCountFormatEntries,
    kSideBarChildCountFormatEntriesRecursive,
    kSideBarChildCountFormatGroupsAndEntries,
    kSideBarChildCountFormatGroupsAndEntriesRecursive,
    kSideBarChildCountFormatGroupsAndEntriesCombined,
    kSideBarChildCountFormatGroupsAndEntriesCombinedRecursive,
};

#endif /* SideBarChildCountFormat_h */
