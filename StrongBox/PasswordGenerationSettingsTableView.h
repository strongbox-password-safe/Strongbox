//
//  PasswordGenerationSettingsTableView.h
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PasswordGenerationSettingsTableView : UITableViewController

@property (weak, nonatomic) IBOutlet UISwitch *switchUseLowercase;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseUppercase;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseDigits;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseSymbols;
@property (weak, nonatomic) IBOutlet UISwitch *switchMakeEasyRead;
@property (weak, nonatomic) IBOutlet UIStepper *stepperMinimumLength;
@property (weak, nonatomic) IBOutlet UIStepper *stepperMaximumLength;
@property (weak, nonatomic) IBOutlet UILabel *labelMinimumLength;
@property (weak, nonatomic) IBOutlet UILabel *labelMaximumLength;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;

- (IBAction)onChangeSettings:(id)sender;
- (IBAction)onGenerate:(id)sender;

@end
