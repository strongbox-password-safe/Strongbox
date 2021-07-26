//
//  OnboardingModule.h
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^OnboardingModuleDoneBlock)(BOOL databaseModified, BOOL stopOnboarding);

@protocol OnboardingModule <NSObject>



- (instancetype)initWithModel:(Model*_Nullable)model;



- (BOOL)shouldDisplay;



- (UIViewController*)instantiateViewController:(OnboardingModuleDoneBlock)onDone;

@end

NS_ASSUME_NONNULL_END
