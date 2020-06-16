//
//  BrowseTapAction.h
//  Strongbox
//
//  Created by Mark on 22/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#ifndef BrowseTapAction_h
#define BrowseTapAction_h

typedef NS_ENUM (NSUInteger, BrowseTapAction) {
    kBrowseTapActionNone,
    kBrowseTapActionOpenDetails,
    kBrowseTapActionCopyTitle,
    kBrowseTapActionCopyUsername,
    kBrowseTapActionCopyPassword,
    kBrowseTapActionCopyUrl,
    kBrowseTapActionCopyEmail,
    kBrowseTapActionCopyNotes,
    kBrowseTapActionCopyTotp,
    kBrowseTapActionEdit,
};

#endif /* BrowseTapAction_h */
