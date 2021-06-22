//
//  DatabaseOnboardingTabViewController.h
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"
#import "CompositeKeyFactors.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseOnboardingTabViewController : NSTabViewController

@property BOOL convenienceUnlock;
@property BOOL autoFill;

@property NSString* databaseUuid;
@property CompositeKeyFactors *ckfs;
@property DatabaseModel* model;

@end

NS_ASSUME_NONNULL_END
