//
//  SyncLogViewController.h
//  MacBox
//
//  Created by Strongbox on 16/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncLogViewController : NSViewController

+ (instancetype)showForDatabase:(MacDatabasePreferences*)database;

@end

NS_ASSUME_NONNULL_END
