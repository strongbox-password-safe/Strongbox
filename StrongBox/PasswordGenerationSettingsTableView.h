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
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAlgorithm;
@property (weak, nonatomic) IBOutlet UIStepper *stepperXkcdWordCount;
@property (weak, nonatomic) IBOutlet UILabel *labelXkcdWordCount;

// Static labels - outlets added just for enabling/disabling
@property (weak, nonatomic) IBOutlet UILabel *labelLower;
@property (weak, nonatomic) IBOutlet UILabel *labelUpper;
@property (weak, nonatomic) IBOutlet UILabel *labelDigits;
@property (weak, nonatomic) IBOutlet UILabel *labelSymbols;
@property (weak, nonatomic) IBOutlet UILabel *labelEasyRead;
@property (weak, nonatomic) IBOutlet UILabel *labelMinLen;
@property (weak, nonatomic) IBOutlet UILabel *labelMaxLen;
@property (weak, nonatomic) IBOutlet UILabel *labelXkcdWc;
@property (weak, nonatomic) IBOutlet UITextField *wordSeparatorTextField;
- (IBAction)onWordSeparatorChanged:(id)sender;

- (IBAction)onChangeSettings:(id)sender;
- (IBAction)onGenerate:(id)sender;

@end
