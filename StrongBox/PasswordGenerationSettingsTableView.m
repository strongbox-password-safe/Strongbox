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
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    
    [self bindUiToSettings];
    
    [self onGenerate:nil];
}

- (IBAction)onChangeSettings:(id)sender {
    NSLog(@"Change");

    PasswordGenerationParameters *params = [[PasswordGenerationParameters alloc] init];
    
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

    if(!params.useLower && !params.useUpper && !params.useDigits && !params.useSymbols) {
        params.useLower = YES;
        [Alerts info:self title:@"Invalid Settings" message:@"You must use at least one of the character pools."];
    }
    
    [[Settings sharedInstance] setPasswordGenerationParameters:params];
    
    [self bindUiToSettings];
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
}

- (IBAction)onGenerate:(id)sender {
    NSString* generated = [PasswordGenerator generatePassword:[[Settings sharedInstance] passwordGenerationParameters]];

    self.textFieldPassword.text = generated;
}

@end
