//
//  GenericOnboardingViewController.h
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OnboardingModule.h"
#import "GenericOnboardingModule.h"
#import "RoundedBlueButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface GenericOnboardingViewController : UIViewController

@property (weak, nonatomic) IBOutlet RoundedBlueButton *labelButton1;

@property OnboardingModuleDoneBlock onDone;

@property NSString* header;
@property NSString* message;

@property NSString* button1;
@property NSString* button2;
@property NSString* button3;

@property (nullable) UIColor* button1Color;
@property (nullable) UIColor* button2Color;
@property (nullable) UIColor* button3Color;

@property UIImage* image;
@property (nullable) NSSymbolEffect* symbolEffect API_AVAILABLE(ios(17.0));

@property OnButtonClicked onButtonClicked;
@property BOOL hideDismiss;
@property NSUInteger imageSize;

@property (nullable) NSNumber* buttonWidth;

@end

NS_ASSUME_NONNULL_END
