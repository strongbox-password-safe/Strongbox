//
//  KeePassIconSet.h
//  MacBox
//
//  Created by Strongbox on 23/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef KeePassIconSet_h
#define KeePassIconSet_h

typedef NS_ENUM (NSInteger, KeePassIconSet) {
    kKeePassIconSetClassic,
    kKeePassIconSetSfSymbols,
    kKeePassIconSetKeePassXC,
};

NSString* getIconSetName(KeePassIconSet iconSet);

#endif /* KeePassIconSet_h */
