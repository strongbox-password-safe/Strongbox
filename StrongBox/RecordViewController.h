//
//  FieldsViewTableViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 12/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "core-model/Record.h"
#import "Model.h"
#import "BSKeyboardControls.h"
//#import "HTAutocompleteTextField.h"

@interface RecordViewController : UIViewController <UITextViewDelegate, BSKeyboardControlsDelegate, UITableViewDataSource, UITableViewDelegate>

@property Record* record;        // Exiting record to display edit or nil to create and edit a new record
@property Group* currentGroup;   // Used when record is nil, i.e. we are creating a new record
@property (nonatomic, strong) Model* viewModel;

@property (weak, nonatomic) IBOutlet UITextView *textViewNotes;
@property (weak, nonatomic) IBOutlet UITextView *textViewTitle;
@property (weak, nonatomic) IBOutlet UITextView *textViewUsername;
@property (weak, nonatomic) IBOutlet UITextView *textViewPassword;
@property (weak, nonatomic) IBOutlet UITextView *textViewUrl;

@property (weak, nonatomic) IBOutlet UIButton *buttonGeneratePassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyUsername;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyUrl;
@property (weak, nonatomic) IBOutlet UIButton *buttonCopyNotes;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAdvanced;
@property (weak, nonatomic) IBOutlet UILabel *labelCreated;
@property (weak, nonatomic) IBOutlet UILabel *labelAccessed;
@property (weak, nonatomic) IBOutlet UILabel *labelModified;
@property (weak, nonatomic) IBOutlet UILabel *labelPasswordModified;
@property (weak, nonatomic) IBOutlet UIView *viewInternal;

- (IBAction)onDeleteRecord:(id)sender;
- (IBAction)onGeneratePassword:(id)sender;
- (IBAction)onCopyUsername:(id)sender;
- (IBAction)onCopyNotes:(id)sender;
- (IBAction)onCopyUrl:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *toolbarButtonDelete;
@property (nonatomic, strong) BSKeyboardControls *keyboardControls;

@end
