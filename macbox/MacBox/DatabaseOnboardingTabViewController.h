//
//  DatabaseOnboardingTabViewController.h
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacDatabasePreferences.h"
#import "CompositeKeyFactors.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseOnboardingTabViewController : NSTabViewController

+ (instancetype)fromStoryboard;
+ (BOOL)shouldShowOnboarding:(MacDatabasePreferences*)databaseMetadata;

@property NSString* databaseUuid;
@property CompositeKeyFactors *ckfs;
@property ViewModel* viewModel;

@end

NS_ASSUME_NONNULL_END
