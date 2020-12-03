//
//  SelectAutoFillDatabaseViewController.h
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectAutoFillDatabaseViewController : NSViewController

@property (nonatomic, copy) void (^onDone)(BOOL userCancelled, DatabaseMetadata*_Nullable database);

@end

NS_ASSUME_NONNULL_END
