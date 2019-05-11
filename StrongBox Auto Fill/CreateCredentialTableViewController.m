//
//  CreateCredentialTableViewController.m
//  Strongbox
//
//  Created by Mark on 11/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CreateCredentialTableViewController.h"
#import "Settings.h"
#import "Alerts.h"

static const int kMinNotesCellHeight = 160;

@interface CreateCredentialTableViewController () <UITextViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textFieldTitle;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UITextField *textFieldHiddenPassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonReveal;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldEmail;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUrl;
@property (weak, nonatomic) IBOutlet UITextView *textFieldNotes;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSave;

@property BOOL hidePassword;

@end

@implementation CreateCredentialTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.hidePassword = ![[Settings sharedInstance] isShowPasswordByDefaultOnEditScreen];

    [self initializeUi];
    
    // TODO: Allow selection of Folder/Group
    // TODO: Ability to create new even during a search
}

- (BOOL)canSave {
    return [self.rootViewController isLiveAutoFillProvider:self.viewModel.metadata.storageProvider];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if([self.textFieldTitle canBecomeFirstResponder]) {
        [self.textFieldTitle becomeFirstResponder];
    }
}

- (void)initializeUi {
    self.buttonSave.enabled = [self canSave];
    
    self.textFieldTitle.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldPassword.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldHiddenPassword.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldUsername.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldEmail.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldUrl.borderStyle = UITextBorderStyleRoundedRect;
    
    self.textFieldTitle.layer.borderWidth = 1.0f;
    self.textFieldNotes.layer.borderWidth = 1.0f;
    self.textFieldPassword.layer.borderWidth = 1.0f;
    self.textFieldHiddenPassword.layer.borderWidth = 1.0f;
    self.textFieldUrl.layer.borderWidth = 1.0f;
    self.textFieldUsername.layer.borderWidth = 1.0f;
    self.textFieldEmail.layer.borderWidth = 1.0f;
    
    self.textFieldNotes.layer.cornerRadius = 5;
    self.textFieldPassword.layer.cornerRadius = 5;
    self.textFieldHiddenPassword.layer.cornerRadius = 5;
    self.textFieldUrl.layer.cornerRadius = 5;
    self.textFieldUsername.layer.cornerRadius = 5;
    self.textFieldEmail.layer.cornerRadius = 5;
    self.textFieldTitle.layer.cornerRadius = 5;
    
    self.textFieldNotes.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldPassword.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldHiddenPassword.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldUrl.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldUsername.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldEmail.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.textFieldTitle.layer.borderColor = [UIColor darkGrayColor].CGColor;
    
    self.textFieldNotes.delegate = self;
    
    [self.textFieldTitle addTarget:self
                            action:@selector(textViewDidChange:)
                  forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldPassword addTarget:self
                               action:@selector(textViewDidChange:)
                     forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldUsername addTarget:self
                               action:@selector(textViewDidChange:)
                     forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldEmail addTarget:self
                            action:@selector(textViewDidChange:)
                  forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldUrl addTarget:self
                          action:@selector(textViewDidChange:)
                forControlEvents:UIControlEventEditingChanged];
    
    [self setTitleTextFieldUIValidationIndicator];
    
    // Show / Hide Password
    
    [self hideOrShowPassword:_hidePassword];

    [self initializeNewRecordTextFields];
}

static NSString * trim(NSString *string) {
    return [string stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
}

- (void)setTitleTextFieldUIValidationIndicator {
    BOOL titleValid = trim(self.textFieldTitle.text).length > 0;
    if(!titleValid) {
        self.textFieldTitle.layer.borderColor = [UIColor redColor].CGColor;
        self.textFieldTitle.placeholder = @"Title Is Required";
    }
    else {
        self.textFieldTitle.layer.borderColor = nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 3) {  // Hide Email Section for KeePass
        return self.viewModel.database.format == kPasswordSafe ? [super tableView:tableView heightForHeaderInSection:section] : 0;
    }
    
    return [super tableView:tableView heightForHeaderInSection:section];
}

-(int)getPasswordRowHeight {
    return 119;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.row == 0) {
        return [self getPasswordRowHeight];
    }
    else if (indexPath.section == 5 && indexPath.row == 0) { // Notes should fill whatever is left
        int title = [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        int username = [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:2]];
        int url = [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:4]];
        
        int email = self.viewModel.database.format == kPasswordSafe ?
        [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:3]] + self.tableView.sectionHeaderHeight : 0;
        
        //NSLog(@"Cells: %d-%d-%d-%d-%d", password, username, email, url, attachments);
        
        // Include Header Height (not from cells as they're set to UITableViewAutomaicDimension (-1) so ask for default
        // Tableview section header height then x 3 fixed header
        
        int otherCellsAndCellHeadersHeight = title + [self getPasswordRowHeight] + username + email + url + (4 * self.tableView.sectionHeaderHeight);
        
        int statusBarHeight = 70; // App Extension Guess...
        int toolBarHeight = self.navigationController.toolbar.frame.size.height * 2; // Bottom and Top
        int navBarHeight = self.navigationController.navigationBar.frame.size.height;
        
        //NSLog(@"Bars: %d-%d-%d", statusBarHeight, navBarHeight, toolBarHeight);
        
        //NSLog(@"Total Height: %f", self.tableView.bounds.size.height);
        int totalVisibleHeight = self.tableView.bounds.size.height - statusBarHeight - navBarHeight - toolBarHeight;
        
        //NSLog(@"Total Visible Height: %d", totalVisibleHeight);
        
        int availableHeight = totalVisibleHeight - otherCellsAndCellHeadersHeight;
        
        //NSLog(@"Total availableHeight: %d", availableHeight);
        
        availableHeight = (availableHeight > kMinNotesCellHeight) ? availableHeight : kMinNotesCellHeight;
        
        return availableHeight;
    }
    else if (indexPath.section == 3 && indexPath.row == 0) { // Hide Email Section for KeePass
        return self.viewModel.database.format == kPasswordSafe ? [super tableView:tableView heightForRowAtIndexPath:indexPath] : 0;
    }
    else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

- (void)initializeNewRecordTextFields {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    NSString *title = settings.titleAutoFillMode == kDefault ? @"Untitled" : settings.titleCustomAutoFill;
    NSString* username = settings.usernameAutoFillMode == kNone ? @"" :
    settings.usernameAutoFillMode == kMostUsed ? self.viewModel.database.mostPopularUsername : settings.usernameCustomAutoFill;
    
    NSString *password =
    settings.passwordAutoFillMode == kNone ? @"" :
    settings.passwordAutoFillMode == kGenerated ? [self.viewModel generatePassword] : settings.passwordCustomAutoFill;
    
    NSString* email =
    settings.emailAutoFillMode == kNone ? @"" :
    settings.emailAutoFillMode == kMostUsed ? self.viewModel.database.mostPopularEmail : settings.emailCustomAutoFill;
    
    NSString* url = settings.urlAutoFillMode == kNone ? @"" : settings.urlCustomAutoFill;
    NSString* notes = settings.notesAutoFillMode == kNone ? @"" : settings.notesCustomAutoFill;

    self.textFieldPassword.text = password;
    self.textFieldTitle.text = self.suggestedTitle.length ? self.suggestedTitle : title;
    self.textFieldUrl.text = self.suggestedUrl.length ? self.suggestedUrl : url;
    self.textFieldUsername.text = username;
    self.textFieldEmail.text = email;
    self.textFieldNotes.text = notes;
}

- (void)textViewDidChange:(UITextView *)textView {
    self.buttonSave.enabled = [self canSave] && [self recordCanBeSaved];
    [self setTitleTextFieldUIValidationIndicator];
}

- (BOOL)recordCanBeSaved {
    BOOL titleValid = trim(self.textFieldTitle.text).length > 0;
    return titleValid;
}

- (IBAction)onToggleRevealPassword:(id)sender {
    _hidePassword = !_hidePassword;
    [self hideOrShowPassword:_hidePassword];
}

- (void)hideOrShowPassword:(BOOL)hide {
    self.textFieldPassword.hidden = hide;
    self.textFieldHiddenPassword.hidden = !hide;
}

- (IBAction)onGeneratePassword:(id)sender {
    self.hidePassword = NO;
    self.textFieldPassword.text = [self.viewModel generatePassword];
    [self hideOrShowPassword:self.hidePassword];
}

- (IBAction)onSave:(id)sender {
    if(![self.rootViewController isLiveAutoFillProvider:self.viewModel.metadata.storageProvider]) {
        [Alerts info:self title:@"Unsupported Storage" message:@"This database is stored on a Storage Provider that does not support Live editing in App Extensions. Cannot Save"];
        return;
    }
    
    self.buttonSave.enabled = NO;
    
    Node* parentGroup = self.viewModel.database.rootGroup;
    Node* record = [[Node alloc] initAsRecord:trim(self.textFieldTitle.text) parent:parentGroup];
    [parentGroup addChild:record allowDuplicateGroupTitles:YES];
    
    record.fields.notes = self.textFieldNotes.text;
    record.fields.password = trim(self.textFieldPassword.text);
    record.fields.url = trim(self.textFieldUrl.text);
    record.fields.username = trim(self.textFieldUsername.text);
    record.fields.email = trim(self.textFieldEmail.text);
    
    record.fields.accessed = [[NSDate alloc] init];
    record.fields.modified = [[NSDate alloc] init];
    record.fields.created = [[NSDate alloc] init];
    
    [self.viewModel update:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            self.buttonSave.enabled = YES;
            
            if (error != nil) {
                [Alerts error:self title:@"Problem Saving" error:error completion:^{
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }];
                NSLog(@"%@", error);
            }
            else {
                [self.rootViewController onCredentialSelected:record.fields.username password:record.fields.password];
            }
        });
    }];
}

@end
