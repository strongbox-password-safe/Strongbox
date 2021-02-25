//
//  CustomBackgroundTableView.h
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomBackgroundTableView : NSTableView

@property NSString* emptyString;
@property BOOL rightClickSelectsItem; // Useful for allowing a Right-Click select of item (context menus)

@end

NS_ASSUME_NONNULL_END
