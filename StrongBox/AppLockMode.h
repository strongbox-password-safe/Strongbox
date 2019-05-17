//
//  AppLockMode.h
//  Strongbox
//
//  Created by Mark on 16/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#ifndef AppLockMode_h
#define AppLockMode_h

typedef NS_ENUM (NSUInteger, AppLockMode) {
    kNoLock,
    kPinCode,
    kBiometric,
    kBoth
};

#endif /* AppLockMode_h */
