//
//  GenericOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GenericOnboardingModule.h"
#import "GenericOnboardingViewController.h"

@interface GenericOnboardingModule ()

@property Model* model;

@end

@implementation GenericOnboardingModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {
        self.model = model;
    }
    return self;
}

- (BOOL)shouldDisplay {
    if ( self.onShouldDisplay ) {
        return self.onShouldDisplay(self.model);
    }
    
    return NO;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"GenericOnboardSlide" bundle:nil];
    GenericOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.onDone = onDone;

    vc.button1 = self.button1;
    vc.button2 = self.button2;
    vc.button3 = self.button3;
    
    vc.button1Color = self.button1Color;
    vc.button2Color = self.button2Color;
    vc.button3Color = self.button3Color;
    vc.buttonWidth = self.buttonWidth;
    
    vc.header = self.header;
    vc.message = self.message;
    
    vc.image = self.image;
    if (@available(iOS 17.0, *)) {
        vc.symbolEffect = self.symbolEffect;
    }
    
    vc.onButtonClicked = self.onButtonClicked;
    vc.hideDismiss = self.hideDismiss;
    vc.imageSize = self.imageSize;
    
    return vc;
}

@end
