//
//  GenericOnboardingModule.h
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OnboardingModule.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^OnButtonClicked)(NSInteger buttonIdCancelIsZero, UIViewController* viewController, OnboardingModuleDoneBlock onDone);
typedef BOOL (^ShouldDisplayBlock)(Model* model);

@interface GenericOnboardingModule : NSObject<OnboardingModule>

@property NSString* header;
@property NSString* message;

@property NSString* button1;
@property (nullable) NSString* button2;
@property (nullable) NSString* button3;

@property (nullable) UIColor* button1Color;
@property (nullable) UIColor* button2Color;
@property (nullable) UIColor* button3Color;

@property (nullable) NSNumber* buttonWidth;

@property UIImage* image;
@property NSSymbolEffect* symbolEffect API_AVAILABLE(ios(17.0));

@property OnButtonClicked onButtonClicked;
@property ShouldDisplayBlock onShouldDisplay;
@property BOOL hideDismiss;
@property NSUInteger imageSize;

@end

NS_ASSUME_NONNULL_END
