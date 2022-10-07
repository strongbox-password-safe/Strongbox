//
//  SearchScope.h
//  Strongbox
//
//  Created by Mark on 21/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef SearchScope_h
#define SearchScope_h

typedef NS_ENUM (NSInteger, SearchScope) {
    kSearchScopeTitle,
    kSearchScopeUsername,
    kSearchScopePassword,
    kSearchScopeUrl,
    kSearchScopeTags,
    kSearchScopeAll,
};

#endif /* SearchScope_h */
