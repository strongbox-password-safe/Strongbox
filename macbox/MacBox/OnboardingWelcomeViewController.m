//
//  OnboardingWelcomeViewController.m
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OnboardingWelcomeViewController.h"

@interface OnboardingWelcomeViewController ()

@property (weak) IBOutlet NSButton *checkboxTouchId;
@property (weak) IBOutlet NSButton *checkboxAutoFill;

@end

@implementation OnboardingWelcomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setInitialState:self.showTouchID showAutoFill:self.showAutoFill enableAutoFill:self.enableAutoFill];
}

- (void)setInitialState:(BOOL)showTouchID
           showAutoFill:(BOOL)showAutoFill
         enableAutoFill:(BOOL)enableAutoFill
{
    self.checkboxTouchId.hidden = !showTouchID;
    
#ifndef DEBUG
    self.checkboxTouchId.state = NSControlStateValueOn;
#else
    self.checkboxTouchId.state = NSControlStateValueOff;
#endif
    
    self.checkboxAutoFill.hidden = !showAutoFill;
    self.checkboxAutoFill.state = enableAutoFill ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onDismiss:(id)sender {
    self.onNext(NO, NO, NO);
}

- (IBAction)onNext:(id)sender {
    BOOL enableTouchID = self.checkboxTouchId.state == NSControlStateValueOn;
    BOOL enableAutoFill = self.checkboxAutoFill.state == NSControlStateValueOn;
    
    self.onNext(NO, enableTouchID, enableAutoFill);
}

@end
