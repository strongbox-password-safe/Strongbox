//
//  RecordView.m
//  StrongBox
//
//  Created by Mark on 31/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "RecordView.h"
#import "Field.h"
#import "PasswordHistoryViewController.h"
#import "PasswordHistory.h"
#import "Alerts.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import "ISMessages/ISMessages.h"
#import "TextFieldAutoSuggest.h"
#import "Settings.h"
#import "FileAttachmentsViewControllerTableViewController.h"
#import "NSArray+Extensions.h"
#import "UiAttachment.h"
#import "CustomFieldsViewController.h"
#import "Node+OtpToken.h"
#import "OTPToken+Generation.h"
#import "QRCodeScannerViewController.h"

static const int kMinNotesCellHeight = 160;

@interface RecordView ()

@property (nonatomic, strong) TextFieldAutoSuggest *passwordAutoSuggest;
@property (nonatomic, strong) TextFieldAutoSuggest *usernameAutoSuggest;
@property (nonatomic, strong) TextFieldAutoSuggest *emailAutoSuggest;
@property (nonatomic, strong) UITextField *textFieldTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelAttachmentCount;
@property BOOL editingNewRecord;
@property UIBarButtonItem *navBack;
@property BOOL hidePassword;
@property BOOL showOtp;
@property NSTimer* timerRefreshOtp;

@end

@implementation RecordView

- (void)setupAutoComplete {
    self.passwordAutoSuggest = [[TextFieldAutoSuggest alloc]
                                initForTextField:self.textFieldPassword
                                viewController:self
                                suggestionsProvider:^NSArray<NSString *> *(NSString *text) {
                                    NSSet<NSString*> *allPasswords = self.viewModel.database.passwordSet;
                                    
                                    NSArray<NSString*> *filtered = [[allPasswords allObjects]
                                                                    filteredArrayUsingPredicate:[NSPredicate
                                                                                                 predicateWithFormat:@"SELF BEGINSWITH[c] %@", text]];
                                    
                                    return [filtered sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                                }];
    
    self.usernameAutoSuggest = [[TextFieldAutoSuggest alloc]
                                initForTextField:self.textFieldUsername
                                viewController:self
                                suggestionsProvider:^NSArray<NSString *> *(NSString *text) {
                                    NSSet<NSString*> *allUsernames = self.viewModel.database.usernameSet;
                                    
                                    NSArray* filtered = [[allUsernames allObjects]
                                                         filteredArrayUsingPredicate:[NSPredicate
                                                                                      predicateWithFormat:@"SELF BEGINSWITH[c] %@", text]];
                                    
                                    return [filtered sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                                }];
    
    self.emailAutoSuggest = [[TextFieldAutoSuggest alloc]
                             initForTextField:self.textFieldEmail
                             viewController:self
                             suggestionsProvider:^NSArray<NSString *> *(NSString *text) {
                                 NSSet<NSString*> *allEmails = self.viewModel.database.emailSet;
                                 
                                 NSArray* filtered = [[allEmails allObjects]
                                                      filteredArrayUsingPredicate:[NSPredicate
                                                                                   predicateWithFormat:@"SELF BEGINSWITH[c] %@", text]];
                                 
                                 return [filtered sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                             }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setInitialTextFieldBordersAndColors {
    self.textFieldPassword.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldHidden.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldUsername.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldEmail.borderStyle = UITextBorderStyleRoundedRect;
    self.textFieldUrl.borderStyle = UITextBorderStyleRoundedRect;
    
    self.textViewNotes.layer.borderWidth = 1.0f;
    self.textFieldPassword.layer.borderWidth = 1.0f;
    self.textFieldHidden.layer.borderWidth = 1.0f;
    self.textFieldUrl.layer.borderWidth = 1.0f;
    self.textFieldUsername.layer.borderWidth = 1.0f;
    self.textFieldEmail.layer.borderWidth = 1.0f;
    
    [self.buttonCopyAndLaunchUrl setTitle:@"" forState:UIControlStateNormal];
    
    self.textViewNotes.layer.cornerRadius = 5;
    self.textFieldPassword.layer.cornerRadius = 5;
    self.textFieldHidden.layer.cornerRadius = 5;
    self.textFieldUrl.layer.cornerRadius = 5;
    self.textFieldUsername.layer.cornerRadius = 5;
    self.textFieldEmail.layer.cornerRadius = 5;
    
    self.textViewNotes.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textFieldPassword.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textFieldHidden.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textFieldUrl.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textFieldUsername.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.textFieldEmail.layer.borderColor = [UIColor lightGrayColor].CGColor;
    
    self.textViewNotes.delegate = self;
    
    self.textFieldTitle = [[UITextField alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x, 7, self.view.bounds.size.width, 31)];
    
    self.textFieldTitle.backgroundColor = [UIColor clearColor];
    self.textFieldTitle.textAlignment = NSTextAlignmentCenter;
    self.textFieldTitle.borderStyle = UITextBorderStyleNone;
    self.textFieldTitle.font = [UIFont boldSystemFontOfSize:20];
    self.textFieldTitle.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textFieldTitle.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.textFieldTitle.layer.masksToBounds = NO;
    self.textFieldTitle.enabled = NO;
    self.textFieldTitle.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.textFieldTitle.layer.shadowOpacity = 0;
    self.textFieldTitle.layer.cornerRadius = 5;
    self.textFieldTitle.tag = 1;
    
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
    
    self.navigationItem.titleView = self.textFieldTitle;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = YES;
    self.navigationController.navigationBar.hidden = NO;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }

    [self showHideOtpCode];
    [self refreshOtpCode:nil];

    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
    self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(refreshOtpCode:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(self.editingNewRecord) {
        [self.textFieldTitle becomeFirstResponder];
        [self.textFieldTitle selectAll:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setInitialTextFieldBordersAndColors];
    [self setupAutoComplete];
    
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.hidePassword = ![[Settings sharedInstance] isShowPasswordByDefaultOnEditScreen];

    if(!self.record) {
        self.record = [self createNewRecord];
        self.editingNewRecord = YES;
    }
    
    [self bindUiToRecord];
    
    [self setEditing:self.editingNewRecord animated:YES];
}

- (void)bindUiToRecord {
    self.textFieldPassword.text = self.record.fields.password;
    self.textFieldTitle.text = self.record.title;
    self.textFieldUrl.text = self.record.fields.url;
    self.textFieldUsername.text = self.record.fields.username;
    self.textFieldEmail.text = self.record.fields.email;
    self.textViewNotes.text = self.record.fields.notes;
    
    int count = (int)self.record.fields.attachments.count;
    
    NSString* singleAttachment;
    if(count == 1) {
        singleAttachment = [NSString stringWithFormat:@"📎 %@", [self.record.fields.attachments objectAtIndex:0].filename];
    }
    self.labelAttachmentCount.text = count == 0 ? @"📎 None" : count == 1 ? singleAttachment : [NSString stringWithFormat:@"📎 %d Attachments", count];
    
    // Custom Fields
    
    int customFieldCount = (int)self.record.fields.customFields.count;

    self.labelCustomFieldsCount.text = customFieldCount == 0 ? @"None" : [NSString stringWithFormat:@"%d Field(s)", customFieldCount];

    // OTP?

    [self showHideOtpCode];
    [self refreshOtpCode:nil];
}

- (void)setEditing:(BOOL)flag animated:(BOOL)animated {
    [super setEditing:flag animated:animated];
    
    if (flag == YES) {
        self.navBack = self.navigationItem.leftBarButtonItem;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancelBarButton)];
        [self enableDisableUiForEditing];
        self.editButtonItem.enabled = [self recordCanBeSaved];
        [self.textFieldTitle becomeFirstResponder];
    }
    else {
        if ([self recordCanBeSaved]) { // Any other changes? Change the record and save the safe
            [self onDoneWithChanges];
        }
        else {
            self.navigationItem.leftBarButtonItem = self.navBack;
            self.editButtonItem.enabled = !(self.viewModel.isUsingOfflineCache || self.viewModel.isReadOnly);
            self.textFieldTitle.borderStyle = UITextBorderStyleLine;
            self.navBack = nil;
        
            [self enableDisableUiForEditing];
        }
    }
}

- (void)enableDisableUiForEditing {
    self.textFieldTitle.enabled = self.editing;
    self.textFieldTitle.layer.borderWidth = self.editing ? 1.0f : 0.0f;
    self.textFieldTitle.borderStyle = self.editing ? UITextBorderStyleRoundedRect : UITextBorderStyleNone;
    [self setTitleTextFieldUIValidationIndicator];
    
    self.textFieldPassword.enabled = self.editing;
    self.textFieldPassword.layer.borderColor = self.editing ? [UIColor darkGrayColor].CGColor : [UIColor lightGrayColor].CGColor;
    self.textFieldPassword.backgroundColor = [UIColor whiteColor];
    
    self.textFieldUsername.enabled = self.editing;
    self.textFieldUsername.textColor = self.editing ? [UIColor blackColor] : [UIColor darkGrayColor];
    self.textFieldUsername.layer.borderColor = self.editing ? [UIColor blackColor].CGColor : [UIColor lightGrayColor].CGColor;
    self.textFieldUsername.backgroundColor = [UIColor whiteColor];
    
    self.textFieldEmail.enabled = self.editing;
    self.textFieldEmail.textColor = self.editing ? [UIColor blackColor] : [UIColor darkGrayColor];
    self.textFieldEmail.layer.borderColor = self.editing ? [UIColor blackColor].CGColor : [UIColor lightGrayColor].CGColor;
    self.textFieldEmail.backgroundColor = [UIColor whiteColor];
    
    self.textFieldUrl.enabled = self.editing;
    self.textFieldUrl.textColor = self.editing ? [UIColor blackColor] : [UIColor blueColor];
    self.textFieldUrl.layer.borderColor = self.editing ? [UIColor darkGrayColor].CGColor : [UIColor lightGrayColor].CGColor;
    self.textFieldUrl.backgroundColor = [UIColor whiteColor];
    
    self.textViewNotes.editable = self.editing;
    self.textViewNotes.textColor = self.editing ? [UIColor blackColor] : [UIColor grayColor];
    self.textViewNotes.layer.borderColor = self.editing ? [UIColor darkGrayColor].CGColor : [UIColor lightGrayColor].CGColor;
    
    UIImage *btnImage = [UIImage imageNamed:self.isEditing ? @"arrow_circle_left_64" : @"copy_64"];
    
    [self.buttonGeneratePassword setImage:btnImage forState:UIControlStateNormal];
    (self.buttonGeneratePassword).enabled = self.editing || (!self.isEditing && (self.record != nil && (self.record.fields.password).length));
    
    (self.buttonCopyUsername).enabled = !self.isEditing && self.record.fields.username.length;
    (self.buttonCopyEmail).enabled = !self.isEditing && self.record.fields.email.length;
    (self.buttonCopyUrl).enabled = !self.isEditing && self.record.fields.url.length;
    (self.buttonCopyAndLaunchUrl).enabled = !self.isEditing;
    (self.buttonCopyTotp).enabled = !self.isEditing && self.labelOtp.text.length;

    // Attachments & Custom Fields screen not available in edit mode
    
    self.labelAttachmentCount.textColor = self.editing ? [UIColor grayColor] : [UIColor blueColor];
    self.tableCellAttachments.userInteractionEnabled = !self.editing;

    self.labelCustomFieldsCount.textColor = self.editing ? [UIColor grayColor] : [UIColor blueColor];
    self.tableCellCustomFields.userInteractionEnabled = !self.editing;

    // History only available on Password Safe and non new

    self.buttonHistory.enabled = !self.editing && self.viewModel.database.format == kPasswordSafe;

    // Show / Hide Password
    
    [self hideOrShowPassword:self.isEditing ? NO : _hidePassword];
    (self.buttonHidePassword).enabled = !self.isEditing;
    
    // Edit OTP
    
    self.buttonSetOtp.hidden = Settings.sharedInstance.hideTotp || self.isEditing;
    self.buttonSetOtp.enabled = !self.isEditing;
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

- (void)textViewDidChange:(UITextView *)textView {
    self.editButtonItem.enabled = [self recordCanBeSaved];

    [self setTitleTextFieldUIValidationIndicator];
}

- (BOOL)recordCanBeSaved {
    BOOL ret =  ([self uiEditsPresent] || self.editingNewRecord) && [self uiIsValid];

    //NSLog(@"validEditsPresent: %d", ret);
    
    return ret;
}

- (BOOL)uiIsValid {
    BOOL titleValid = trim(self.textFieldTitle.text).length > 0;
    
    return titleValid;
}

- (BOOL)uiEditsPresent {
    if(!self.record) {
        return YES;
    }
    
    BOOL notesClean = [self.textViewNotes.text isEqualToString:self.record.fields.notes];
    BOOL passwordClean = [trim(self.textFieldPassword.text) isEqualToString:self.record.fields.password];
    BOOL titleClean = [trim(self.textFieldTitle.text) isEqualToString:self.record.title];
    BOOL urlClean = [trim(self.textFieldUrl.text) isEqualToString:self.record.fields.url];
    BOOL emailClean = [trim(self.textFieldEmail.text) isEqualToString:self.record.fields.email];
    BOOL usernameClean = [trim(self.textFieldUsername.text) isEqualToString:self.record.fields.username];
    
    //NSLog(@"titleClean = %d, usernameClean = %d, passwordClean = %d, emailClean = %d, urlClean = %d, notesClean = %d",
    //      titleClean, usernameClean, passwordClean, emailClean, urlClean, notesClean);

    //NSLog(@"[%@] != [%@]", trim(self.textFieldPassword.text), self.record.fields.password);
    
    return !(notesClean && passwordClean && titleClean && urlClean && emailClean && usernameClean);
}

- (Node*)createNewRecord {
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
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:username url:url password:password notes:notes email:email];
    
    return [[Node alloc] initAsRecord:title parent:self.parentGroup fields:fields uuid:nil];
}

static NSString * trim(NSString *string) {
    return [string stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
}

- (void)copyToClipboard:(NSString *)value message:(NSString *)message {
    if (value.length == 0) {
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = value;
    
    [ISMessages showCardAlertWithTitle:message
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (IBAction)onGenerateOrCopyPassword:(id)sender {
    if (self.editing) {
        self.textFieldPassword.text = [self.viewModel generatePassword];
        self.editButtonItem.enabled = [self recordCanBeSaved];
    }
    else
    {
        [self copyToClipboard:self.record.fields.password message:@"Password Copied"];
    }
}

- (IBAction)onCopyUrl:(id)sender {
    [self copyToClipboard:self.record.fields.url message:@"URL Copied"];
}

- (IBAction)onCopyUsername:(id)sender {
    [self copyToClipboard:self.record.fields.username message:@"Username Copied"];
}

- (IBAction)onCopyTotp:(id)sender {
    [self copyToClipboard:self.labelOtp.text message:@"One Time Password Copied"];
}

- (IBAction)onCopyAndLaunchUrl:(id)sender {
    NSString *urlString = self.record.fields.url;

    if (!urlString.length) {
        return;
    }

    [self copyToClipboard:self.record.fields.password message:@"Password Copied. Launching URL..."];
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
    });
}

- (IBAction)onCopyEmail:(id)sender {
    [self copyToClipboard:self.record.fields.email message:@"Email Copied"];
}

- (IBAction)onHide:(id)sender {
    _hidePassword = !_hidePassword;
    [self hideOrShowPassword:_hidePassword];
}

- (void)hideOrShowPassword:(BOOL)hide {
    self.textFieldPassword.hidden = hide;
    self.textFieldHidden.hidden = !hide;
    [self.buttonHidePassword setTitle:hide ? @"Show" : @"Hide" forState:UIControlStateNormal];
}

- (void)onCancelBarButton {
    if (self.editingNewRecord) {
        // Back to safe view if we just cancelled out of a new record
        [self.navigationController popViewControllerAnimated:YES];
    }
    else {
        [self bindUiToRecord];
        [self setEditing:NO animated:YES];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqual:@"segueToPasswordHistory"] && (self.record != nil))
    {
        PasswordHistoryViewController *vc = segue.destinationViewController;
        vc.model = self.record.fields.passwordHistory;
        vc.readOnly = self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache;
        
        vc.saveFunction = ^(PasswordHistory *changed, void (^onDone)(NSError *)) {
            [self onPasswordHistoryChanged:changed onDone:onDone];
        };
    }
    else if ([segue.identifier isEqual:@"segueToFileAttachments"]) {
        UINavigationController *nav = segue.destinationViewController;
        
        FileAttachmentsViewControllerTableViewController* vc = (FileAttachmentsViewControllerTableViewController*)[nav topViewController];
        
        NSArray<UiAttachment*>* attachments = getUiAttachments(self.record, self.viewModel.database.attachments);
        vc.attachments = attachments;
        vc.format = self.viewModel.database.format;
        vc.readOnly = self.viewModel.isReadOnly;
        
        __weak FileAttachmentsViewControllerTableViewController* weakRef = vc;
        vc.onDoneWithChanges = ^{
            [self onAttachmentsChanged:self.record attachments:weakRef.attachments];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToCustomFields"]) {
        UINavigationController *nav = segue.destinationViewController;
        
        CustomFieldsViewController* vc = (CustomFieldsViewController*)[nav topViewController];
        vc.readOnly = self.viewModel.isReadOnly;
        
        NSArray<NSString*> *sortedKeys = [self.record.fields.customFields.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1 compare:obj2];
        }];
        
        NSMutableArray<CustomField*> *items = [NSMutableArray array];
        for (NSString* key in sortedKeys) {
            CustomField* customField = [[CustomField alloc] init];
            
            customField.key = key;
            customField.value = self.record.fields.customFields[key];
            
            [items addObject:customField];
        }
        
        vc.items = items;
        
        __weak CustomFieldsViewController* weakRef = vc;
        vc.onDoneWithChanges = ^{
            [self onCustomFieldsChanged:self.record items:weakRef.items];
        };
    }
}

static NSArray<UiAttachment*>* getUiAttachments(Node* record, NSArray<DatabaseAttachment*>* dbAttachments) {
    return [record.fields.attachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        DatabaseAttachment *dbAttachment = dbAttachments[obj.index];
        return [[UiAttachment alloc] initWithFilename:obj.filename data:dbAttachment.data];
    }];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Hide Delete Buttons and Indentation during editing and autosize last row to fill available space

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 4) { // Hide Attachments Section for PasswordSafe
        return self.viewModel.database.format == kPasswordSafe ? 0 : [super tableView:tableView heightForHeaderInSection:section];
    }
    else if (section == 5) { // Hide Custom Fields for password safe and keepass 1
        return self.viewModel.database.format == kPasswordSafe || self.viewModel.database.format == kKeePass1 ? 0 : [super tableView:tableView heightForHeaderInSection:section];
    }
    else if (section == 2) {  // Hide Email Section for KeePass
        return self.viewModel.database.format == kPasswordSafe ? [super tableView:tableView heightForHeaderInSection:section] : 0;
    }
    
    return [super tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        return self.showOtp ? 162 : 95; // [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    }
    else if (indexPath.section == 6 && indexPath.row == 0) { // Notes should fill whatever is left
        int password = self.showOtp ? 162 : 95; //[super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        int username = [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:1]];
        int url = [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:3]];
       
        int attachments = self.viewModel.database.format == kPasswordSafe ? 0 :
            [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:4]] + self.tableView.sectionHeaderHeight;
        
        int customFields = self.viewModel.database.format == kPasswordSafe || self.viewModel.database.format == kKeePass1 ? 0 :
        [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:5]] + self.tableView.sectionHeaderHeight;
        
        int email = self.viewModel.database.format == kPasswordSafe ?
            [super tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:2]] + self.tableView.sectionHeaderHeight : 0;

        //NSLog(@"Cells: %d-%d-%d-%d-%d", password, username, email, url, attachments);

        // Include Header Height (not from cells as they're set to UITableViewAutomaicDimension (-1) so ask for default
        // Tableview section header height then x 3 fixed header
        
        int otherCellsAndCellHeadersHeight = password + username + email + url + attachments + customFields + (3 * self.tableView.sectionHeaderHeight);
        
        int statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        int toolBarHeight = self.navigationController.toolbar.frame.size.height;
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
    else if (indexPath.section == 4 && indexPath.row == 0) { // Hide Attachments Section for Passwprd Safe
        return self.viewModel.database.format == kPasswordSafe ? 0 : [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    else if (indexPath.section == 5 && indexPath.row == 0) { // Hide Custom Fields Section for Password Safe & KeePass 1
        return self.viewModel.database.format == kPasswordSafe || self.viewModel.database.format == kKeePass1 ? 0 : [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    else if (indexPath.section == 2 && indexPath.row == 0) { // Hide Email Section for KeePass
        return self.viewModel.database.format == kPasswordSafe ? [super tableView:tableView heightForRowAtIndexPath:indexPath] : 0;
    }
    else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onPasswordHistoryChanged:(PasswordHistory*)changed onDone:(void (^)(NSError *))onDone {
    self.record.fields.passwordHistory = changed;
    self.record.fields.accessed = [[NSDate alloc] init];
    self.record.fields.modified = [[NSDate alloc] init];
    
    [self.viewModel update:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            onDone(error);
        });
    }];
}

- (void)onDoneWithChanges {
    [self saveChanges:^(NSError *error) {
        self.navigationItem.leftBarButtonItem = self.navBack;
        self.editButtonItem.enabled = YES;
        self.navBack = nil;
        
        if (error != nil) {
            [Alerts error:self title:@"Problem Saving" error:error completion:^{
                [self.navigationController popToRootViewControllerAnimated:YES];
            }];
            NSLog(@"%@", error);
        }
        else {
            [self bindUiToRecord];
            [self enableDisableUiForEditing];
        }
    }];
}

- (void)onAttachmentsChanged:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments {
    [self.viewModel.database setNodeAttachments:node attachments:attachments];
    
    [self saveChanges:^(NSError *error) {
        if (error != nil) {
            [Alerts error:self title:@"Problem Saving" error:error completion:^{
                [self.navigationController popToRootViewControllerAnimated:YES];
            }];
            NSLog(@"%@", error);
        }
        else {
            [self bindUiToRecord];
        }
    }];
}

- (void)onCustomFieldsChanged:(Node*)node items:(NSArray<CustomField*>*)items {
    [node.fields.customFields removeAllObjects];
    
    for (CustomField *field in items) {
        [node.fields.customFields setObject:field.value forKey:field.key];
    }
    
    [self saveChanges:^(NSError *error) {
        if (error != nil) {
            [Alerts error:self title:@"Problem Saving" error:error completion:^{
                [self.navigationController popToRootViewControllerAnimated:YES];
            }];
            NSLog(@"%@", error);
        }
        else {
            [self bindUiToRecord];
        }
    }];
}

- (void)saveChanges:(void (^)(NSError *))completion {
    self.record.fields.accessed = [[NSDate alloc] init];
    self.record.fields.modified = [[NSDate alloc] init];
    self.record.fields.notes = self.textViewNotes.text;
    self.record.fields.password = trim(self.textFieldPassword.text);
    self.record.title = trim(self.textFieldTitle.text);
    self.record.fields.url = trim(self.textFieldUrl.text);
    self.record.fields.username = trim(self.textFieldUsername.text);
    self.record.fields.email = trim(self.textFieldEmail.text);

    if (self.editingNewRecord) {
        self.record.fields.created = [[NSDate alloc] init];
        [self.parentGroup addChild:self.record];
    }

    [self.viewModel update:^(NSError *error) {
        if(!error) {
            self.editingNewRecord = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            completion(error);
        });
    }];
}

- (IBAction)refreshOtpCode:(id)sender
{
    if(self.showOtp && self.record.otpToken) {
        //NSLog(@"Token: [%@] - Password: %@", self.record.otpToken, self.record.otpToken.password);

        uint64_t remainingSeconds = self.record.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.record.otpToken.period);
        
        self.labelOtp.text = [NSString stringWithFormat:@"%@", self.record.otpToken.password];
        self.labelOtp.textColor = (remainingSeconds < 5) ? [UIColor redColor] : (remainingSeconds < 9) ? [UIColor orangeColor] : [UIColor blueColor];
        self.otpProgress.tintColor = self.labelOtp.textColor;
        
        // Flash...
        
        self.labelOtp.alpha = 1;
        
        if(remainingSeconds < 4) {
            [UIView animateWithDuration:0.9 delay:0.0 options:kNilOptions animations:^{
                self.labelOtp.alpha = 0.2;
            } completion:nil];
        }
        
        self.otpProgress.progress = remainingSeconds / self.record.otpToken.period;

        self.labelOtp.hidden = NO;
        self.otpProgress.hidden = NO;
        self.buttonCopyTotp.hidden = NO;
    }
    else {
        self.labelOtp.hidden = YES;
        self.otpProgress.hidden = YES;
        self.buttonCopyTotp.hidden = YES;
    }
}

- (IBAction)onSetTotp:(id)sender {
    [Alerts threeOptions:self title:@"How would you like to setup TOTP?" message:@"You can setup TOTP by using a QR Code, or manually by entering the secret or an OTPAuth URL" defaultButtonText:@"QR Code..." secondButtonText:@"Manually..." thirdButtonText:@"Cancel" action:^(int response) {
        if(response == 0){
            QRCodeScannerViewController* vc = [[QRCodeScannerViewController alloc] init];
            vc.onDone = ^(BOOL response, NSString * _Nonnull string) {
                [self dismissViewControllerAnimated:YES completion:nil];
                if(response) {
                    BOOL success = [self.record setTotpWithString:string appendUrlToNotes:self.viewModel.database.format == kPasswordSafe];
                    if(!success) {
                        [Alerts warn:self title:@"Failed to Set TOTP" message:@"Could not set TOTP using this QR Code."];
                    }
                    else {
                        [self saveAfterTotpSet];
                    }
                }
            };
            
            [self presentViewController:vc animated:YES completion:nil];
        }
        else if(response == 1) {
            [Alerts OkCancelWithTextField:self textFieldPlaceHolder:@"Secret or OTPAuth URL" title:@"Please enter the secret or an OTPAuth URL" message:@"" completion:^(NSString *text, BOOL response) {
                if(response) {
                    BOOL success = [self.record setTotpWithString:text appendUrlToNotes:self.viewModel.database.format == kPasswordSafe];
                    if(!success) {
                        [Alerts warn:self title:@"Failed to Set TOTP" message:@"Could not set TOTP using this string."];
                    }
                    else {
                        [self saveAfterTotpSet];
                    }
                }
            }];
        }
    }];
}

- (void)saveAfterTotpSet {
    [self.viewModel update:^(NSError *error) {
        if(error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts error:self title:@"Error While Saving" error:error];
            });
        }
        
        [self showHideOtpCode];
        [self bindUiToRecord];
    }];
}

- (void)showHideOtpCode {
    self.showOtp = !Settings.sharedInstance.hideTotp && self.record.otpToken != nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    });
}

@end
