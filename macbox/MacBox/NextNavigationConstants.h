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
    OGNavigationContextTotps,
    OGNavigationContextSpecial,
} OGNavigationContext;

typedef enum : NSUInteger {
    OGNavigationSpecialAllItems,
} OGNavigationSpecial;

#endif /* NextNavigationConstants_h */
