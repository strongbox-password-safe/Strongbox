//
//  RecordView.h
//  StrongBox
//
//  Created by Mark on 31/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Record.h"
#import "Model.h"

@interface RecordView : UITableViewController <UITextViewDelegate>

@property (nonatomic, strong) Record *record;
@property (nonatomic, strong) Group *currentGroup;
@property (nonatomic, strong) Model *viewModel;

@property (weak, nonatomic) IBOutlet UITextView *textViewNotes;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUrl;

@property (weak, nonatomic) IBOutlet UIButton *buttonHidePassword;

@property (weak, nonatomic) IBOutlet UIButton *buttonGeneratePassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyUsername;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyUrl;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyAndLaunchUrl;

@property (weak, nonatomic) IBOutlet UILabel *labelHidePassword;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSettings;

- (IBAction)onGeneratePassword:(id)sender;
- (IBAction)onCopyUsername:(id)sender;
- (IBAction)onCopyUrl:(id)sender;
- (IBAction)onHide:(id)sender;
- (IBAction)onCopyAndLaunchUrl:(id)sender;

@end
