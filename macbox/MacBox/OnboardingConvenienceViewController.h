//
//  OnboardingConvenienceViewController.h
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

@interface OnboardingConvenienceViewController : NSViewController

@property DatabaseMetadata* database;
@property (nonatomic, copy) void (^onNext)(void);
@property BOOL autoFillIsAvailable;
@property CompositeKeyFactors *ckfs;

@end

NS_ASSUME_NONNULL_END
