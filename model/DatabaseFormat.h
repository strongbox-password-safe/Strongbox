//
//  DatabaseFormat.h
//  Strongbox
//
//  Created by Strongbox on 05/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#ifndef DatabaseFormat_h
#define DatabaseFormat_h

typedef NS_ENUM (NSInteger, DatabaseFormat) {
    kPasswordSafe,
    kKeePass,
    kKeePass4,
    kKeePass1,
    kFormatUnknown,
};

#endif /* DatabaseFormat_h */
