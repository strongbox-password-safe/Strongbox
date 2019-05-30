//
//  PasswordGenerationSettingsTableView.m
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationSettingsTableView.h"
#import "Settings.h"
#import "PasswordGenerator.h"
#import "Alerts.h"

@implementation PasswordGenerationSettingsTableView

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    [self bindUiToSettings];
    
    [self onGenerate:nil];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (IBAction)onWordSeparatorChanged:(id)sender {
    [self onChangeSettings:sender];
}

- (IBAction)onChangeSettings:(id)sender {
    PasswordGenerationParameters *params = [[PasswordGenerationParameters alloc] init];
    
    params.algorithm = self.segmentAlgorithm.selectedSegmentIndex == 0 ? kBasic : kXkcd;
    params.xkcdWordCount = self.stepperXkcdWordCount.value;
    
    if(params.xkcdWordCount <= 0) {
        params.xkcdWordCount = 1;
    }
    
    params.useDigits = self.switchUseDigits.on;
    params.useSymbols = self.switchUseSymbols.on;
    params.useLower = self.switchUseLowercase.on;
    params.useUpper = self.switchUseUppercase.on;
    params.easyReadOnly = self.switchMakeEasyRead.on;
    params.minimumLength = self.stepperMinimumLength.value;
    params.maximumLength = self.stepperMaximumLength.value;

    if(params.minimumLength > params.maximumLength) {
        params.minimumLength = params.maximumLength;
    }
    
    if(params.minimumLength <= 0) {
        params.minimumLength = 1;
    }
    
    if(params.maximumLength > 512){
        params.maximumLength = 512;
    }

    if(params.maximumLength < params.minimumLength) {
        params.maximumLength = params.minimumLength;
    }

    if(params.xkcdWordCount < 2){
        params.xkcdWordCount = 2;
    }
    
    if(params.xkcdWordCount > 50){
        params.xkcdWordCount = 50;
    }
    
    params.wordSeparator = self.wordSeparatorTextField.text;
    
    if(!params.useLower && !params.useUpper && !params.useDigits && !params.useSymbols) {
        params.useLower = YES;
        [Alerts info:self title:@"Invalid Settings" message:@"You must use at least one of the character pools."];
    }
    
    [[Settings sharedInstance] setPasswordGenerationParameters:params];
    
    [self bindUiToSettings];
    
    [self onGenerate:nil];
}

-(void)bindUiToSettings {
    PasswordGenerationParameters *params = [[Settings sharedInstance] passwordGenerationParameters];

    self.switchUseDigits.on = params.useDigits;
    self.switchUseSymbols.on = params.useSymbols;
    self.switchUseLowercase.on = params.useLower;
    self.switchUseUppercase.on = params.useUpper;
    self.switchMakeEasyRead.on = params.easyReadOnly;
    self.labelMinimumLength.text = [NSString stringWithFormat:@"%d", params.minimumLength];
    self.labelMaximumLength.text = [NSString stringWithFormat:@"%d", params.maximumLength];
    self.stepperMinimumLength.value = params.minimumLength;
    self.stepperMaximumLength.value = params.maximumLength;
    
    self.segmentAlgorithm.selectedSegmentIndex = params.algorithm == kBasic ? 0 : 1;
    self.stepperXkcdWordCount.value = params.xkcdWordCount;
    self.labelXkcdWordCount.text = [NSString stringWithFormat:@"%d", params.xkcdWordCount];

    
    self.switchUseDigits.enabled = params.algorithm == kBasic;
    self.switchUseSymbols.enabled = params.algorithm == kBasic;
    self.switchUseLowercase.enabled = params.algorithm == kBasic;
    self.switchUseUppercase.enabled = params.algorithm == kBasic;
    self.switchMakeEasyRead.enabled = params.algorithm == kBasic;
    self.labelMinimumLength.enabled = params.algorithm == kBasic;
    self.labelMaximumLength.enabled = params.algorithm == kBasic;
    self.stepperMinimumLength.enabled = params.algorithm == kBasic;
    self.stepperMaximumLength.enabled = params.algorithm == kBasic;
    
    self.stepperXkcdWordCount.enabled = params.algorithm == kXkcd;
    self.labelXkcdWordCount.enabled = params.algorithm == kXkcd;
    
    self.labelLower.enabled = params.algorithm == kBasic;
    self.labelUpper.enabled = params.algorithm == kBasic;
    self.labelDigits.enabled = params.algorithm == kBasic;
    self.labelSymbols.enabled = params.algorithm == kBasic;
    self.labelEasyRead.enabled = params.algorithm == kBasic;
    self.labelMinLen.enabled = params.algorithm == kBasic;
    self.labelMaxLen.enabled = params.algorithm == kBasic;
    
    self.labelXkcdWc.enabled = params.algorithm == kXkcd;
    self.wordSeparatorTextField.text = params.wordSeparator ? params.wordSeparator : @"";
}

- (IBAction)onGenerate:(id)sender {
    NSString* generated = [PasswordGenerator generatePassword:[[Settings sharedInstance] passwordGenerationParameters]];

    self.textFieldPassword.text = generated;
}

- (IBAction)onDone:(id)sender {
    NSLog(@"onDone: %@", self.presentingViewController);
    if([self isModal]) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (BOOL)isModal { // TODO: Remove need for this by always presenting Modal...
    if([self presentingViewController])
        return YES;
    if([[[self navigationController] presentingViewController] presentedViewController] == [self navigationController])
        return YES;
    if([[[self tabBarController] presentingViewController] isKindOfClass:[UITabBarController class]])
        return YES;
    
    return NO;
}

@end
