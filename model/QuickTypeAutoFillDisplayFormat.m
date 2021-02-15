//
//  QuickTypeAutoFillDisplayFormat.m
//  MacBox
//
//  Created by Strongbox on 02/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QuickTypeAutoFillDisplayFormat.h"

NSString* quickTypeFormatString(QuickTypeAutoFillDisplayFormat format) {
    switch (format) {
        case kQuickTypeFormatTitleThenUsername:
            return NSLocalizedString(@"quick_type_format_title_username", @"Title (Username)");
            break;
        case kQuickTypeFormatTitleOnly:
            return NSLocalizedString(@"quick_type_format_title", @"Title");
            break;
        default:
            return NSLocalizedString(@"quick_type_format_username", @"Username");
            break;
    }
}
