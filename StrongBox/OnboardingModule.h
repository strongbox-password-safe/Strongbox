//
//  OnboardingModule.h
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

typedef UIViewController* VIEW_CONTROLLER_PTR;

#else

#import <Cocoa/Cocoa.h>

typedef NSViewController* VIEW_CONTROLLER_PTR;

#endif

NS_ASSUME_NONNULL_BEGIN

typedef void (^OnboardingModuleDoneBlock)(BOOL databaseModified, BOOL stopOnboarding);

@protocol OnboardingModule <NSObject>



- (instancetype)initWithModel:(Model*_Nullable)model;



- (BOOL)shouldDisplay;



- (VIEW_CONTROLLER_PTR _Nullable)instantiateViewController:(OnboardingModuleDoneBlock)onDone;

@end

NS_ASSUME_NONNULL_END
