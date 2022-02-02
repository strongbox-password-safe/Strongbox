//
//  KeePassIconSet.m
//  
//
//  Created by Strongbox on 17/01/2022.
//

#import <Foundation/Foundation.h>
#import "KeePassIconSet.h"

NSString* getIconSetName(KeePassIconSet iconSet) {
    switch (iconSet) {
        case kKeePassIconSetKeePassXC:
            return NSLocalizedString(@"keepass_icon_set_keepassxc", @"KeePassXC");
            break;
        case kKeePassIconSetSfSymbols:
            return NSLocalizedString(@"keepass_icon_set_sf_symbols", @"SF Symbols");
            break;
        default:
            return NSLocalizedString(@"keepass_icon_set_classic", @"Classic");
            break;
    }
}
