//
//  QuickTypeAutoFillDisplayFormat.h
//  Strongbox
//
//  Created by Strongbox on 02/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef QuickTypeAutoFillDisplayFormat_h
#define QuickTypeAutoFillDisplayFormat_h

typedef NS_ENUM (NSInteger, QuickTypeAutoFillDisplayFormat) {
    kQuickTypeFormatTitleThenUsername,
    kQuickTypeFormatUsernameOnly,
    kQuickTypeFormatTitleOnly,
    kQuickTypeFormatDatabaseThenTitleThenUsername,
    kQuickTypeFormatDatabaseThenTitle,
    kQuickTypeFormatDatabaseThenUsername,
};

NSString* quickTypeFormatString(QuickTypeAutoFillDisplayFormat format);

#endif /* QuickTypeAutoFillDisplayFormat_h */
