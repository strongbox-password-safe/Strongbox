//
//  BackupsViewController.h
//  MacBox
//
//  Created by Strongbox on 07/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface BackupsViewController : NSViewController

@property NSString* databaseUuid;

@end

NS_ASSUME_NONNULL_END
