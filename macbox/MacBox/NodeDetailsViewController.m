//
//  NodeDetailsViewController.m
//  Strongbox
//
//  Created by Mark on 27/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "NodeDetailsViewController.h"
#import "CustomField.h"
#import "SelectPredefinedIconController.h"
#import "MMcGACTextField.h"
#import "KSPasswordField.h"
#import "ClickableImageView.h"
#import "AttachmentCollectionView.h"
#import "MacAlerts.h"
#import "Utils.h"
#import "Settings.h"
#import "OTPToken+Generation.h"
#import "AppDelegate.h"
#import "NodeIconHelper.h"
#import "MBProgressHUD.h"
#import "Entry.h"
#import "ViewController.h"
#import "AttachmentItem.h"
#import "CustomFieldTableCellView.h"
#import "FavIconDownloader.h"
#import "PreferencesWindowController.h"
#import "ClipboardManager.h"
#import "QRCodePresenterPopover.h"
#import "OTPToken+Serialization.h"
#import "ColoredStringHelper.h"
#import "ClickableSecureTextField.h"
#import "NSString+Extensions.h"
#import "FileManager.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"
#import "NSDate+Extensions.h"
#import "EditCustomFieldController.h"
#import "EditTagsViewController.h"
#import "PasswordStrengthTester.h"

@interface NodeDetailsViewController () <   NSWindowDelegate,
                                            NSTableViewDataSource,
                                            NSTableViewDelegate,
                                            NSTextFieldDelegate,
                                            NSTextViewDelegate,
                                            NSCollectionViewDataSource,
                                            NSCollectionViewDelegate,
                                            QLPreviewPanelDataSource,
                                            QLPreviewPanelDelegate,
                                            NSComboBoxDataSource,
                                            NSComboBoxDelegate>

@property (weak) IBOutlet NSTableView *tableViewCustomFields;
@property (weak) IBOutlet NSButton *buttonAddCustomField;
@property (weak) IBOutlet NSButton *buttonRemoveCustomField;
@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet NSView *emailRow;
@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet MMcGACTextField *textFieldUsername;
@property (weak) IBOutlet MMcGACTextField *textFieldUrl;
@property (weak) IBOutlet MMcGACTextField *textFieldEmail;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet ClickableImageView *imageViewIcon;
@property (weak) IBOutlet ClickableImageView *imageViewShowHidePassword;
@property (weak) IBOutlet AttachmentCollectionView *attachmentsView;
@property (weak) IBOutlet NSView *totpRow;
@property (weak) IBOutlet NSTextField *labelTotp;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;
@property (weak) IBOutlet NSComboBox *comboGroup;
@property (weak) IBOutlet NSTextField *labelID;
@property (weak) IBOutlet NSTextField *labelCreated;
@property (weak) IBOutlet NSTextField *labelModified;
@property (weak) IBOutlet NSButton *buttonGenerate;
@property (weak) IBOutlet NSButton *buttonSettings;
@property (weak) IBOutlet NSButton *buttonAddAttachment;
@property (weak) IBOutlet NSButton *buttonRemoveAttachment;

@property NSView* currentlyEditingUIControl;
@property (nonnull, strong, nonatomic) NSArray<CustomField*> *customFields;
@property (strong, nonatomic) SelectPredefinedIconController* selectPredefinedIconController;
@property NSTimer* timerRefreshOtp;
@property (nonnull, strong, nonatomic) NSArray *sortedAttachmentFileNames;
@property NSArray<Node*>* groups;
@property NSMutableDictionary<NSString*, NSImage*> *attachmentsIconCache;



@property (strong) IBOutlet NSMenu *customFieldsContextMenu;
@property (strong) IBOutlet NSMenu *attachmentsContextMenu;

@property (weak) IBOutlet NSButton *checkboxExpires;
@property (weak) IBOutlet NSDatePicker *datePickerExpires;

@property BOOL hasLoaded;

@property dispatch_block_t onSaveCompletion;

@property (weak) IBOutlet NSTextField *revealedPasswordField;
@property (weak) IBOutlet ClickableSecureTextField *concealedPasswordField;
@property BOOL passwordIsRevealed;

@property (weak) IBOutlet NSView *tagsStack;
@property (weak) IBOutlet NSTokenField *tagsField;

@property (weak) IBOutlet NSProgressIndicator *progressStrength;
@property (weak) IBOutlet NSTextField *labelStrength;

@property (readonly) BOOL isEffectivelyReadOnly;

@end

@implementation NodeDetailsViewController

- (BOOL)isEffectivelyReadOnly {
    return self.historicalItem || self.model.isEffectivelyReadOnly;
}

static NSString* trimField(NSTextField* textField) {
    return [Utils trim:textField.stringValue];
}

- (void)cancel:(id)sender { 
    [self closeWithCompletion:nil];
}

- (void)closeWithCompletion:(void (^)(void))completion {
    if(self.newEntry) { 
        [self stopObservingModelChanges]; 
        [self setModelForEditField:self.currentlyEditingUIControl];
        [self.view.window close];
        [self onWindowClosed];
        if (completion) {
            completion();
        }
    }
    else if([self shouldPromptToSaveSimpleChanges]) {
        [self promptToSaveSimpleUIChangesBeforeClose:completion];
    }
    else {
        [self.view.window close];
        if (completion) {
            completion();
        }
    }
}

- (BOOL)shouldPromptToSaveSimpleChanges {
    BOOL changes = NO;
    
    if(self.tabView.selectedTabViewItem == self.tabView.tabViewItems[0]) { 
        if(self.currentlyEditingUIControl == self.textFieldTitle) {
            if(![self.node.title isEqualToString:trimField(self.textFieldTitle)]) {
                changes = YES;
            }
        }
        else if(self.currentlyEditingUIControl == self.textFieldUsername) {
            if(![self.node.fields.username isEqualToString:trimField(self.textFieldUsername)]) {
                changes = YES;
            }
        }
        else if(self.currentlyEditingUIControl == self.textFieldEmail){
            if(![self.node.fields.email isEqualToString:trimField(self.textFieldEmail)]) {
                changes = YES;
            }
        }
        else if(self.currentlyEditingUIControl == self.textFieldUrl){
            if(![self.node.fields.url isEqualToString:trimField(self.textFieldUrl)]) {
                changes = YES;
            }
        }
        else if(self.currentlyEditingUIControl == self.revealedPasswordField){
            if(![self.node.fields.password isEqualToString:trimField(self.revealedPasswordField)]) {
                changes = YES;
            }
        }
        else if(self.currentlyEditingUIControl == self.textViewNotes) {
            NSString *updated = [NSString stringWithString:self.textViewNotes.textStorage.string];
            if(![self.node.fields.notes isEqualToString:updated]) {
                changes = YES;
            }
        }
    }
    
    return changes;
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if([self shouldPromptToSaveSimpleChanges]) {
        [self promptToSaveSimpleUIChangesBeforeClose:nil];
        return NO;
    }
    else {
        return YES;
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [self onWindowClosed];
}

- (void)onWindowClosed {
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }

    [self stopObservingModelChanges];
    
    if(self.onClosed) {
        self.onClosed(); 
    }
}

- (void)promptToSaveSimpleUIChangesBeforeClose:(void (^)(void))completion {
    NSString* loc = NSLocalizedString(@"mac_node_details_save_changes", @"Save Changes?");
    NSString* loc2 = NSLocalizedString(@"mac_node_details_unsaved_changes_save", @"There are unsaved changes present. Would you like to save those before exiting?");

    NSString* message = loc;
    NSString* informative = loc2;

    [MacAlerts yesNo:message
  informativeText:informative
           window:self.view.window
 disableEscapeKey:YES
       completion:^(BOOL yesNo) {
        if(self.newEntry) {
            if(yesNo) {
                [self stopObservingModelChanges]; 
                [self setModelForEditField:self.currentlyEditingUIControl];
                [self.view.window close];
                [self onWindowClosed];

                if (completion) {
                    [self save:completion];
                }
            }
            else {
                
                
                [self stopObservingModelChanges]; 

                [self.view.window close];
                [self onWindowClosed];

                if (completion) {
                    completion();
                }
            }
        }
        else {
            if(yesNo) {
                [self stopObservingModelChanges]; 
                [self setModelForEditField:self.currentlyEditingUIControl];
                [self.view.window close];
                [self onWindowClosed];
                
                if (completion) {
                    [self save:completion];
                }
            }
            else {
                [self.view.window close];
                [self onWindowClosed];
                
                if (completion) {
                    completion();
                }
            }
        }
    }];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
   return self.model.document.undoManager;
}

- (void)doInitialSetup {
    [self setupUi];
    
    [self setupAutoCompletes];
    
    [self bindUiToNode];
    
    [self observeModelChanges];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
    
    [self.view.window makeFirstResponder:self.newEntry ? self.textFieldTitle : self.imageViewIcon]; 

    [self updateTitle];
    
    [self.view.window setFrameAutosaveName:self.node.uuid.UUIDString]; 
}

- (void)updateTitle {
    NSString* title = [self.model dereference:self.node.title node:self.node];

    NSString* loc = NSLocalizedString(@"mac_node_details_historical_item_suffix_fmt", @"%@ (Historical Item)");
    NSString* aTitle = [NSString stringWithFormat:self.historicalItem ? loc : @"%@", title];
    
    NSMutableArray* statusii = NSMutableArray.array;



    if ( self.model.isEffectivelyReadOnly ) {
        [statusii addObject:NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read-Only")];
    }
        
    NSString* statusSuffix = @"";
    if ( statusii.firstObject ) {
        NSString* statusiiStrings = [statusii componentsJoinedByString:@", "];
        statusSuffix = [NSString stringWithFormat:@" (%@)", statusiiStrings];
    }
    
    aTitle = [aTitle stringByAppendingString:statusSuffix];
    
    [self.view.window setTitle:aTitle];
}

- (void)newWindowForTab:(id)sender {
    
}

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (void)observeModelChanges {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationTitleChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationUsernameChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationExpiryChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationUrlChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationEmailChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationNotesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationPasswordChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationIconChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCustomFieldsChanged:) name:kModelUpdateNotificationCustomFieldsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onAttachmentsChanged:) name:kModelUpdateNotificationAttachmentsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onTotpChanged:) name:kModelUpdateNotificationTotpChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onTagsChanged:) name:kModelUpdateNotificationTagsChanged object:nil];
}

- (void)stopObservingModelChanges {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setModelForEditField:(NSView*)obj {
    if(obj == self.textFieldTitle) {
        if(![self.node.title isEqualToString:trimField(self.textFieldTitle)]) {
            if(![self.model setItemTitle:self.node title:trimField(self.textFieldTitle)]) {
                self.textFieldTitle.stringValue = self.node.title; 
            }
        }
    }
    else if(obj == self.textFieldUsername) {
        if(![self.node.fields.username isEqualToString:trimField(self.textFieldUsername)]) {
            [self.model setItemUsername:self.node username:trimField(self.textFieldUsername)];
        }
    }
    else if(obj == self.textFieldEmail){
        if(![self.node.fields.email isEqualToString:trimField(self.textFieldEmail)]) {
            [self.model setItemEmail:self.node email:trimField(self.textFieldEmail)];
        }
    }
    else if(obj == self.textFieldUrl){
        if(![self.node.fields.url isEqualToString:trimField(self.textFieldUrl)]) {
            [self.model setItemUrl:self.node url:trimField(self.textFieldUrl)];
        }
    }
    else if(obj == self.revealedPasswordField){
        if(![self.node.fields.password isEqualToString:trimField(self.revealedPasswordField)]) {
            [self.model setItemPassword:self.node password:trimField(self.revealedPasswordField)];
        }
        else {
            [self bindRevealedPassword]; 
        }
    }
    else if(obj == self.textViewNotes) {
        NSString *updated = [NSString stringWithString:self.textViewNotes.textStorage.string];
        if(![self.node.fields.notes isEqualToString:updated]) {
            [self.model setItemNotes:self.node notes:updated];
        }
    }
}

- (void)setupUi {
    NSUInteger doc = [NSDocumentController.sharedDocumentController.documents indexOfObject:self.model.document];

    
    if (@available(macOS 10.12, *)) {
        self.view.window.tabbingIdentifier = @(doc).stringValue;
    }
    
    self.view.window.delegate = self; 
    
    [self showHideForDatabaseFormat];
    [self setupSimpleUI];
    [self setupCustomFieldsUI];
    [self setupAttachmentsUI];
}

- (void)setupCustomFieldsUI {
    self.customFields = [NSArray array];

    self.tableViewCustomFields.dataSource = self;
    self.tableViewCustomFields.delegate = self;
    [self.tableViewCustomFields registerNib:[[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil] forIdentifier:@"CustomFieldValueCellIdentifier"];
    self.tableViewCustomFields.doubleAction = @selector(onEditField:);
}

- (void)showHideForDatabaseFormat {
    self.emailRow.hidden = self.model.format != kPasswordSafe;
    self.tagsStack.hidden = self.model.format == kPasswordSafe || self.model.format == kKeePass1;
    
    if(self.model.format == kPasswordSafe) {
        [self.tabView removeTabViewItem:self.tabView.tabViewItems[1]]; 
        [self.tabView removeTabViewItem:self.tabView.tabViewItems[1]]; 
    }
    else if (self.model.format == kKeePass1) {
        [self.tabView removeTabViewItem:self.tabView.tabViewItems[1]]; 
    }
}

- (void)setupAttachmentsUI {
    self.sortedAttachmentFileNames = @[];
    self.attachmentsView.dataSource = self;
    self.attachmentsView.delegate = self;
    self.attachmentsView.onSpaceBar = self.attachmentsView.onDoubleClick = ^{ 
        [self onPreviewAttachment:nil];
    };
}

- (void)setupSimpleUI {
    self.textFieldTitle.delegate = self;
    self.revealedPasswordField.delegate = self;
    self.textViewNotes.delegate = self;
    
    
    
    self.textFieldUsername.onBeginEditing = ^{
        self.currentlyEditingUIControl = self.textFieldUsername;
    };
    self.textFieldUsername.onEndEditing = ^{
        self.currentlyEditingUIControl = nil;
        [self setModelForEditField:self.textFieldUsername];
    };

    self.textFieldUrl.onBeginEditing = ^{
        self.currentlyEditingUIControl = self.textFieldUrl;
    };
    self.textFieldUrl.onEndEditing = ^{
        self.currentlyEditingUIControl = nil;
        [self setModelForEditField:self.textFieldUrl];
    };
    
    self.textFieldEmail.onBeginEditing = ^{
        self.currentlyEditingUIControl = self.textFieldEmail;
    };
    self.textFieldEmail.onEndEditing = ^{
        self.currentlyEditingUIControl = nil;
        [self setModelForEditField:self.textFieldEmail];
    };

    self.passwordIsRevealed = Settings.sharedInstance.revealPasswordsImmediately;
    
    self.concealedPasswordField.onClick = ^{
        [self revealPassword];
    };
    
    self.imageViewShowHidePassword.clickable = YES;
    self.imageViewShowHidePassword.image = [NSImage imageNamed:self.passwordIsRevealed ? @"hide" : @"show"];

    self.imageViewShowHidePassword.onClick = ^{
        if (self.passwordIsRevealed) {
            [self.revealedPasswordField resignFirstResponder];
        }
        [self toggleRevealConcealPassword];
        self.imageViewShowHidePassword.image = [NSImage imageNamed:self.passwordIsRevealed ? @"hide" : @"show"];
    };
    
    [self bindRevealedConcealedPassword];
    
    
    
    NSMutableArray* groups = [self.model.activeGroups mutableCopy];
    [groups addObject:self.model.rootGroup];
    
    self.groups = [groups sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        Node* n1 = (Node*)obj1;
        Node* n2 = (Node*)obj2;
        
        NSString *p1 = [self.model getGroupPathDisplayString:n1];
        NSString *p2 = [self.model getGroupPathDisplayString:n2];
        
        return finderStringCompare(p1, p2);
    }];
    
    self.comboGroup.usesDataSource = YES;
    self.comboGroup.dataSource = self;
    
    [self syncComboGroupWithNode];
    
    self.comboGroup.delegate = self; 
}

- (void)revealPassword {
    self.passwordIsRevealed = YES;
    [self bindRevealedConcealedPassword];
}

- (void)toggleRevealConcealPassword {
    self.passwordIsRevealed = !self.passwordIsRevealed;
    [self bindRevealedConcealedPassword];
}

- (void)bindRevealedConcealedPassword {
    self.revealedPasswordField.hidden = !self.passwordIsRevealed;
    self.concealedPasswordField.hidden = self.passwordIsRevealed;
}

- (void)bindUiToNode {
    [self bindUiToCustomFields];
    [self bindUiToSimpleFields];
    [self bindUiToAttachments];
}

- (void)bindUiToAttachments {
    self.attachmentsIconCache = nil;
    self.sortedAttachmentFileNames = [self.node.fields.attachments.allKeys sortedArrayUsingComparator:finderStringComparator];
    [self.attachmentsView reloadData];
    
    self.buttonAddAttachment.enabled = !self.isEffectivelyReadOnly && !(self.model.format == kKeePass1 && self.sortedAttachmentFileNames.count > 0);
    self.buttonRemoveAttachment.enabled = !self.isEffectivelyReadOnly;
}

- (void)bindUiToSimpleFields {
    [self updateTitle];
    
    self.textFieldTitle.stringValue = self.node.title;
    self.textFieldUsername.stringValue = self.node.fields.username;
    
    [self bindRevealedPassword];
    
    self.textFieldEmail.stringValue = self.node.fields.email;
    self.textFieldUrl.stringValue = self.node.fields.url;
    self.textViewNotes.string = self.node.fields.notes;

    NSArray<NSString*>* sortedTags = [self.node.fields.tags.allObjects sortedArrayUsingComparator:finderStringComparator];
    [self.tagsField setObjectValue:sortedTags];
    
    self.imageViewIcon.image = [self getIconForNode];
    self.imageViewIcon.onClick = ^{ [self onEditNodeIcon]; };
    self.imageViewIcon.showClickableBorder = YES;
    
    self.labelID.stringValue = self.model.format == kPasswordSafe ? self.node.uuid.UUIDString : keePassStringIdFromUuid(self.node.uuid);
    self.labelCreated.stringValue = self.node.fields.created ? self.node.fields.created.friendlyDateTimeString : @"";
    self.labelModified.stringValue = self.node.fields.modified ? self.node.fields.modified.friendlyDateTimeString : @"";
    
    self.imageViewIcon.clickable = self.model.format != kPasswordSafe && !self.isEffectivelyReadOnly;
    self.textFieldTitle.enabled = !self.isEffectivelyReadOnly;
    self.textFieldUsername.enabled = !self.isEffectivelyReadOnly;
    self.revealedPasswordField.enabled = !self.isEffectivelyReadOnly;
    self.textFieldEmail.enabled = !self.isEffectivelyReadOnly;
    
    self.tagsField.enabled = !self.isEffectivelyReadOnly;
    
    self.textFieldUrl.enabled = !self.isEffectivelyReadOnly;
    self.textViewNotes.editable = !self.isEffectivelyReadOnly;
    self.comboGroup.enabled = !self.isEffectivelyReadOnly;
    self.buttonGenerate.enabled = !self.isEffectivelyReadOnly;
    self.buttonSettings.enabled = !self.isEffectivelyReadOnly;
        
    self.checkboxExpires.state = self.node.fields.expires == nil ? NSOffState : NSOnState;
    self.datePickerExpires.dateValue = self.node.fields.expires;
    
    self.checkboxExpires.enabled = !self.isEffectivelyReadOnly;
    self.datePickerExpires.enabled = !self.isEffectivelyReadOnly && self.node.fields.expires != nil;
    
    [self validateTitleAndIndicateValidityInUI];
    
    [self initializeTotp];
    
    [self bindPasswordStrength];
}

- (void)bindPasswordStrength {
    NSString* pw = self.revealedPasswordField.stringValue;
    PasswordStrength* strength = [PasswordStrengthTester getStrength:pw config:PasswordStrengthConfig.defaults];
    
    self.labelStrength.stringValue = strength.summaryString;
    
    double relativeStrength = MIN(strength.entropy / 128.0f, 1.0f); 
        
    self.progressStrength.doubleValue = relativeStrength * 100.0f;
    
    CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
    [colorPoly setDefaults];
    
    double red = 1.0 - relativeStrength;
    double green = relativeStrength;

    CIVector *redVector = [CIVector vectorWithX:red Y:0 Z:0 W:0];
    CIVector *greenVector = [CIVector vectorWithX:green Y:0 Z:0 W:0];
    CIVector *blueVector = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    
    [colorPoly setValue:redVector forKey:@"inputRedCoefficients"];
    [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
    [colorPoly setValue:blueVector forKey:@"inputBlueCoefficients"];
    [self.progressStrength setContentFilters:@[colorPoly]];
}

- (void)bindRevealedPassword {
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    BOOL dark = ([osxMode isEqualToString:@"Dark"]);
    BOOL colorBlind = Settings.sharedInstance.colorizeUseColorBlindPalette;
    
    self.revealedPasswordField.attributedStringValue = [ColoredStringHelper getColorizedAttributedString:self.node.fields.password
                                                                                                colorize:Settings.sharedInstance.colorizePasswords
                                                                                                darkMode:dark
                                                                                              colorBlind:colorBlind
                                                                                                    font:self.revealedPasswordField.font];
}

- (void)initializeTotp {
    [self bindUiToTotp];
    
    if( self.model.showTotp && self.node.fields.otpToken ) {
        if(self.timerRefreshOtp == nil) {
            self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(refreshTotp:) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
        }
    }
    else {
        if(self.timerRefreshOtp) {
            [self.timerRefreshOtp invalidate];
            self.timerRefreshOtp = nil;
        }
    }

}

- (void)refreshTotp:(id)sender {
    [self bindUiToTotp];
}

- (void)bindUiToTotp {
    if( self.model.showTotp && self.node.fields.otpToken ) {
        self.totpRow.hidden = NO;
        
        uint64_t remainingSeconds = self.node.fields.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.node.fields.otpToken.period);
        
        self.labelTotp.stringValue = self.node.fields.otpToken.password;
        self.labelTotp.textColor = (remainingSeconds < 5) ? NSColor.redColor : (remainingSeconds < 9) ? NSColor.orangeColor : NSColor.controlTextColor;
        
        self.progressTotp.minValue = 0;
        self.progressTotp.maxValue = self.node.fields.otpToken.period;
        self.progressTotp.doubleValue = remainingSeconds;
    }
    else {
        self.totpRow.hidden = YES;
        self.labelTotp.stringValue = @"000000";
    }
}

- (void)setupAutoCompletes {
    [self setupUsernameAutoComplete];
    [self setupEmailAutoComplete];
    [self setupUrlAutoComplete];
}

- (void)setupEmailAutoComplete {
    self.textFieldEmail.completions = self.model.emailSet.allObjects;
    self.textFieldEmail.completionEnabled = self.model.showAutoCompleteSuggestions;
}

- (void)setupUrlAutoComplete {
    self.textFieldUrl.completions = self.model.urlSet.allObjects;
    self.textFieldUrl.completionEnabled = self.model.showAutoCompleteSuggestions;
}

- (void)setupUsernameAutoComplete {
    self.textFieldUsername.completions = self.model.usernameSet.allObjects;
    self.textFieldUsername.completionEnabled = self.model.showAutoCompleteSuggestions;
}

- (void)onPreferencesChanged:(NSNotification*)notification {
    NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];

        [self.tableViewCustomFields reloadData];
    });
}




- (void)onSimpleFieldsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];
    if(node == self.node) {
        [self bindUiToSimpleFields];

        self.newEntry = NO;
        
        if(notification.name == kModelUpdateNotificationTitleChanged) {
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_title", @"Title");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if(notification.name == kModelUpdateNotificationUsernameChanged){
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_username", @"Username");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if(notification.name == kModelUpdateNotificationUrlChanged){
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_url", @"URL");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if(notification.name == kModelUpdateNotificationEmailChanged){
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_email", @"Email");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if(notification.name == kModelUpdateNotificationNotesChanged){
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_notes", @"Notes");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if (notification.name == kModelUpdateNotificationExpiryChanged) {
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_expiry_date", @"Expiry Date");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
        else if(notification.name == kModelUpdateNotificationPasswordChanged){
            
            
            










        }
        else if(notification.name == kModelUpdateNotificationIconChanged){
            NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
            NSString* loc2 = NSLocalizedString(@"generic_fieldname_icon", @"Icon");
            NSString* foo = [NSString stringWithFormat:loc, loc2];
            [self showPopupToastNotification:foo];
        }
    }
}

- (void)onCustomFieldsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }

    [self bindUiToSimpleFields]; 
    [self bindUiToCustomFields];
    
    self.newEntry = NO;
    
    NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_custom_fields", @"Custom Fields");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (void)onAttachmentsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    [self bindUiToSimpleFields]; 
    [self bindUiToAttachments];
    
    self.newEntry = NO;
    
    NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_attachments", @"Attachments");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (void)onTotpChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    [self bindUiToSimpleFields]; 
    [self initializeTotp];
    
    self.newEntry = NO;
    
    
    NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_totp", @"TOTP");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (void)onTagsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    [self bindUiToSimpleFields]; 
    
    self.newEntry = NO;
        
    NSString* loc = NSLocalizedString(@"mac_field_changed_notification_fmt", @"%@ Changed");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_tags", @"Tags");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (void)showPopupToastNotification:(NSString*)message {
    [self showPopupToastNotification:message duration:0.75];
}

- (void)showPopupToastNotification:(NSString*)message duration:(CGFloat)duration {
    if ( !self.model.showChangeNotifications ) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
   
    hud.labelText = @"";
    hud.detailsLabelText = message;
    hud.color = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
    hud.mode = MBProgressHUDModeText;
    hud.margin = 2.f;
    hud.yOffset = -210.f;
    hud.removeFromSuperViewOnHide = YES;
    hud.dismissible = NO;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud hide:YES];
    });
}

- (IBAction)onEditField:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }

    CustomField* field = self.customFields[row];
    [self onEditCustomField:field];
}

- (void)onEditCustomField:(CustomField*)field {
    if(self.isEffectivelyReadOnly) {
        return;
    }

    [self performSegueWithIdentifier:@"segueToEditCustomField" sender:field];
}

- (IBAction)onAddCustomField:(id)sender {
    if(self.isEffectivelyReadOnly) {
        return;
    }
    
    
    [self performSegueWithIdentifier:@"segueToEditCustomField" sender:nil];
}

- (void)setCustomField:(NSString*)key value:(NSString*)value allowUpdate:(BOOL)allowUpdate protected:(BOOL)protected {
    NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
    
    if(!allowUpdate && [existingKeySet containsObject:key]) {
        NSString* loc = NSLocalizedString(@"mac_node_details_you_cannot_use_that_key_already_exists", @"You cannot use that Key here as it already exists in custom fields.");
        [MacAlerts info:loc window:self.view.window];
        return;
    }
    
    if([keePassReserved containsObject:key]) {
        NSString* loc = NSLocalizedString(@"mac_node_details_you_cannot_use_key_reserved", @"You cannot use that Key here as it is reserved for standard KeePass fields.");
        [MacAlerts info:loc window:self.view.window];
        return;
    }
    
    [self.model setCustomField:self.node key:key value:[StringValue valueWithString:value protected:protected]];
}

- (IBAction)onCopyCustomFieldKey:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    
    [ClipboardManager.sharedInstance copyConcealedString:field.key];
}

- (IBAction)onCopyCustomFieldValue:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    
    NSString* str = [self.model dereference:field.value node:self.node];
    
    [ClipboardManager.sharedInstance copyConcealedString:str];
}

- (IBAction)onDeleteCustomField:(id)sender {
    if(self.isEffectivelyReadOnly) {
        return;
    }
    
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    
    NSString* loc = NSLocalizedString(@"mac_node_details_are_you_sure_remove_custom_field_fmt", @"Are you sure you want to remove the custom field '%@'?");

    [MacAlerts yesNo:[NSString stringWithFormat:loc, field.key]
           window:self.view.window
       completion:^(BOOL yesNo) {
           if(yesNo) {
               [self.model removeCustomField:self.node key:field.key];
           }
       }];
}

- (IBAction)onRemoveCustomField:(id)sender {
    if(self.isEffectivelyReadOnly) {
        return;
    }
    
    if(self.tableViewCustomFields.selectedRow != -1) {
        CustomField *field = self.customFields[self.tableViewCustomFields.selectedRow];
            
        NSString* loc = NSLocalizedString(@"mac_node_details_are_you_sure_remove_custom_field_fmt", @"Are you sure you want to remove the custom field '%@'?");

        [MacAlerts yesNo:[NSString stringWithFormat:loc, field.key]
               window:self.view.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                [self.model removeCustomField:self.node key:field.key];
            }
        }];
    }
}

- (void)syncComboGroupWithNode {
    NSInteger origIdx = self.node.parent ? [self.groups indexOfObject:self.node.parent] : 0;
    
    if(origIdx != NSNotFound) {
        [self.comboGroup selectItemAtIndex:origIdx];
    }
}

- (void)bindUiToCustomFields {
    NSArray<NSString*> *sortedKeys = [self.node.fields.customFields.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableArray *fields = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        StringValue* value = self.node.fields.customFields[key];
        
        CustomField* field = [[CustomField alloc] init];
        
        field.key = key;
        field.value = value.value;
        field.protected = value.protected;
        
        [fields addObject:field];
    }
    
    self.customFields = [fields copy];
    [self.tableViewCustomFields reloadData];
    
    self.buttonRemoveCustomField.enabled = !self.isEffectivelyReadOnly;
    self.buttonAddCustomField.enabled = !self.isEffectivelyReadOnly;
}

- (NSImage * )getIconForNode {
    return [NodeIconHelper getIconForNode:self.node predefinedIconSet:kKeePassIconSetClassic format:self.model.format];
}

- (void)onEditNodeIcon {
    if(self.model.format == kPasswordSafe) {
        return;
    }
    
    [self setModelForEditField:self.currentlyEditingUIControl]; 
    
    __weak NodeDetailsViewController* weakSelf = self;
    self.selectPredefinedIconController = [[SelectPredefinedIconController alloc] initWithWindowNibName:@"SelectPredefinedIconController"];
    self.selectPredefinedIconController.customIcons = self.model.customIcons.allObjects;
    self.selectPredefinedIconController.hideSelectFile = self.model.format == kKeePass1;
    self.selectPredefinedIconController.hideFavIconButton = NO;
    
    self.selectPredefinedIconController.onSelectedItem = ^(NodeIcon * _Nullable icon, BOOL showFindFavIcons) {
        if(showFindFavIcons) {
            [weakSelf showFavIconDownloader];
        }
        else {
            [weakSelf.model setItemIcon:weakSelf.node icon:icon];
        }
    };
    
    [self.view.window beginSheet:self.selectPredefinedIconController.window  completionHandler:nil];
}

- (void)showFavIconDownloader {
    FavIconDownloader *vc = [FavIconDownloader newVC];
    vc.nodes = @[self.node];
    vc.viewModel = self.model;

    __weak NodeDetailsViewController* weakSelf = self;
    vc.onDone = ^(BOOL go, NSDictionary<NSUUID *,NSImage *> * _Nullable selectedFavIcons) {
        if(go) {
            [weakSelf.model batchSetIcons:selectedFavIcons];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}

- (void)validateTitleAndIndicateValidityInUI {
    if(trimField(self.textFieldTitle).length == 0) {
        self.textFieldTitle.layer.borderColor = NSColor.redColor.CGColor;
        self.textFieldTitle.layer.borderWidth = 2.0f;
    }
    else {
        self.textFieldTitle.layer.borderWidth = 0.0f;
    }
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.sortedAttachmentFileNames.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    AttachmentItem *item = [self.attachmentsView makeItemWithIdentifier:@"AttachmentItem" forIndexPath:indexPath];
    
    NSString* filename = self.sortedAttachmentFileNames[indexPath.item];
    DatabaseAttachment* dbAttachment = self.node.fields.attachments[filename];
    
    item.textField.stringValue = filename;
    item.labelFileSize.stringValue = [NSByteCountFormatter stringFromByteCount:dbAttachment.length countStyle:NSByteCountFormatterCountStyleFile];
    
    if(self.attachmentsIconCache == nil) {
        self.attachmentsIconCache = [NSMutableDictionary dictionary];
        [self buildAttachmentsIconCache];
    }
    
    NSImage* cachedIcon = self.attachmentsIconCache[dbAttachment.digestHash];
    if(cachedIcon) {
        item.imageView.image = cachedIcon;
    }
    else {
        NSImage* img = [[NSWorkspace sharedWorkspace] iconForFileType:filename.pathExtension];
        item.imageView.image = img;
    }
    
    return item;
}

- (void)buildAttachmentsIconCache {
    NSArray *workingCopy = self.model.database.attachmentPool;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0;i<workingCopy.count;i++) {
            DatabaseAttachment* dbAttachment = workingCopy[i];
            
            NSData* data = [NSData dataWithContentsOfStream:[dbAttachment getPlainTextInputStream]];
            NSImage* img = [[NSImage alloc] initWithData:data];
            
            if(img) {
                img = scaleImage(img, CGSizeMake(88, 88));
                if (img) {
                    [self.attachmentsIconCache setObject:img forKey:@(i)];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.attachmentsView reloadData];
            [self.view setNeedsDisplay:YES];
        });
    });
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}



- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return self.groups.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return [self.model getGroupPathDisplayString:self.groups[index]];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger idx = [self.comboGroup indexOfSelectedItem];
    Node* group = self.groups[idx];
    
    
    
    if(self.node.parent != group) {
        if(![self.model validateMove:@[self.node] destination:group]) { 
            NSString* loc = NSLocalizedString(@"mac_node_details_could_not_change_group", @"Could not change group! Validate failed...");
            [MacAlerts info:loc window:self.view.window];
            [self syncComboGroupWithNode];
        }
        else {
            [self.model move:@[self.node] destination:group];
            self.newEntry = NO;
        }
    }
    else {
        
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    BOOL isKeyColumn = [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"];
    NSString* cellId = isKeyColumn ? @"CustomFieldKeyCellIdentifier" : @"CustomFieldValueCellIdentifier";

    CustomField* field = [self.customFields objectAtIndex:row];

    if(isKeyColumn) {
        NSTableCellView* cell = [self.tableViewCustomFields makeViewWithIdentifier:cellId owner:nil];
        cell.textField.stringValue = field.key;
        return cell;
    }
    else {
        CustomFieldTableCellView* cell = [self.tableViewCustomFields makeViewWithIdentifier:cellId owner:nil];
        
        cell.value = field.value;
        cell.protected = field.protected && !(field.value.length == 0 && !self.model.concealEmptyProtectedFields);
        cell.valueHidden = field.protected && !(field.value.length == 0 && !self.model.concealEmptyProtectedFields); 
        
        return cell;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.customFields.count;
}



- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    self.currentlyEditingUIControl = obj.object;
}

- (void)textDidBeginEditing:(NSNotification *)notification {
    self.currentlyEditingUIControl = notification.object;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == self.textFieldTitle) {
        [self validateTitleAndIndicateValidityInUI];
    }
    else if ( obj.object == self.revealedPasswordField ) {
        [self bindPasswordStrength];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    self.currentlyEditingUIControl = nil;
    [self setModelForEditField:obj.object];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    self.currentlyEditingUIControl = nil;
    [self setModelForEditField:notification.object];
}



- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return 0;
    }
    
    return 1;
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    if(index != 0) {
        return nil;
    }
    
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return nil;
    }
    NSString* filename = self.sortedAttachmentFileNames[idx];
    DatabaseAttachment* dbAttachment = self.node.fields.attachments[filename];
    
    NSString* f = [FileManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];
    [StreamUtils pipeFromStream:[dbAttachment getPlainTextInputStream] to:[NSOutputStream outputStreamToFileAtPath:f append:NO]];
    
    NSURL* url = [NSURL fileURLWithPath:f];
    
    return url;
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    panel.dataSource = self;
    panel.delegate = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
    [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
}



- (void)copyToPasteboard:(NSString*)text {
    [[NSPasteboard generalPasteboard] clearContents];
    
    if(text.length) {
        NSString* str = [self.model dereference:text node:self.node];
        [ClipboardManager.sharedInstance copyConcealedString:str];
    }
}

- (IBAction)onCopyTitle:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.title];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_title", @"Title");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyUsername:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.fields.username];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_username", @"Username");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyEmail:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.fields.email];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_email", @"Email");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyUrl:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.fields.url];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_url", @"URL");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyNotes:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.fields.notes];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_notes", @"Notes");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyPassword:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    [self copyToPasteboard:self.node.fields.password];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_password", @"Password");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    [self.view.window makeFirstResponder:nil]; 
    
    [self copyToPasteboard:self.node.fields.password];

    [self.model launchUrl:self.node];
    
    NSString* loc = NSLocalizedString(@"mac_node_details_password_copied_url_launched", @"Password Copied and URL Launched");
    [self showPopupToastNotification:loc];
}

- (IBAction)onCopyTotp:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];

    if(self.node.fields.otpToken) {
        NSString *password = self.node.fields.otpToken.password;
        [ClipboardManager.sharedInstance copyConcealedString:password];
    }
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_no_item_title_fmt", @"%@ Copied");
    NSString* loc2 = NSLocalizedString(@"generic_fieldname_totp", @"TOTP");
    NSString* foo = [NSString stringWithFormat:loc, loc2];
    [self showPopupToastNotification:foo];
}

- (IBAction)onPasswordSettings:(id)sender {
    [PreferencesWindowController.sharedInstance showPasswordSettings];
}

- (IBAction)onGenerate:(id)sender {
    [self.view.window makeFirstResponder:self.imageViewIcon]; 
    
    [self.model setItemPassword:self.node password:[self.model generatePassword]];

    self.passwordIsRevealed = YES;
    [self bindRevealedConcealedPassword];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL theAction = [menuItem action];
    


    if(theAction == @selector(onAddCustomField:) ||
       theAction == @selector(onRemoveCustomField:) ||
       theAction == @selector(onEditCustomField:)) {
        return !self.isEffectivelyReadOnly;
    }
    
   if (theAction == @selector(onPreviewAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }
    else if (theAction == @selector(onSaveAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }
    else if (theAction == @selector(onRemoveAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }

    return YES;
}

- (IBAction)onPreviewAttachment:(id)sender {
    NSUInteger index = [self.attachmentsView.selectionIndexes firstIndex];
    if(index == NSNotFound) {
        return;
    }
    
    [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:self];
}

- (IBAction)onSaveAttachment:(id)sender {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NSString* filename = self.sortedAttachmentFileNames[idx];
    
    
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = filename;
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            DatabaseAttachment* dbAttachment = self.node.fields.attachments[filename];
            
            NSOutputStream* outStream = [NSOutputStream outputStreamToFileAtPath:savePanel.URL.path append:NO];
            [StreamUtils pipeFromStream:[dbAttachment getPlainTextInputStream] to:outStream];
            
            [savePanel orderOut:self];
        }
    }];
}

- (IBAction)onRemoveAttachment:(id)sender {
    if(self.isEffectivelyReadOnly) {
        return;
    }
    
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NSString* filename = self.sortedAttachmentFileNames[idx];
    
    NSString* loc = NSLocalizedString(@"mac_node_details_are_you_sure_remove_attachment_fmt", @"Are you sure you want to remove the attachment: %@?");
    NSString* prompt = [NSString stringWithFormat:loc, filename];
    [MacAlerts yesNo:prompt window:self.view.window completion:^(BOOL yesNo) {
        if(yesNo) {
            [self.model removeItemAttachment:self.node filename:filename];
        }
    }];
}

- (IBAction)onAddAttachment:(id)sender {
    if(self.isEffectivelyReadOnly || (self.model.format == kKeePass1 && self.sortedAttachmentFileNames.count > 0)) {
        return;
    }
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = YES;
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            for (NSURL* url in openPanel.URLs) {
                NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:url.path];
                DatabaseAttachment* dbA = [[DatabaseAttachment alloc] initWithStream:stream protectedInMemory:YES compressed:YES];
                NSString* filename = url.lastPathComponent;
                [self.model addItemAttachment:self.node filename:filename attachment:dbA];
            }
        }
    }];
}

#pragma mark - QR Code Generator

- (CIImage *)createQRForString:(NSString *)qrString {
    NSData *stringData = [qrString dataUsingEncoding:NSISOLatin1StringEncoding];

    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    
    
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    return qrFilter.outputImage;
}

- (NSImage*)generateTheQRCodeImageFromDataBaseInfo:(NSString*)string {
    CIImage *input = [self createQRForString:string];

    

    static NSUInteger kImageViewSize = 256;
    CGFloat scale = kImageViewSize / input.extent.size.width;

    

    
    
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);

    CIImage *qrCode = [input imageByApplyingTransform:transform];

    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:qrCode];
    NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
    
    [nsImage addRepresentation:rep];

    return nsImage;
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToQrCodePresentation"]) {
        QRCodePresenterPopover* qr = (QRCodePresenterPopover*)segue.destinationController;
        
        if(!self.node.fields.otpToken) {
            return;
        }
        
        NSURL *totpUrl = [self.node.fields.otpToken url:YES];
        

        
        NSImage* image = [self generateTheQRCodeImageFromDataBaseInfo:totpUrl.absoluteString];
        
        qr.qrCodeImage = image ? image : [NSImage imageNamed:@"error"];
    }
    else if ( [segue.identifier isEqualToString:@"segueToEditCustomField"] ) {
        EditCustomFieldController* vc = segue.destinationController;

        NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
            return obj.key;
        }];
        
        NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
        
        vc.field = sender;
        vc.existingKeySet = existingKeySet;
        
        vc.onSetField = ^(NSString * _Nonnull key, NSString * _Nonnull value, BOOL protected) {
            [self setCustomField:key value:value allowUpdate:(sender != nil) protected:protected];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToEditTags"] ) {
        EditTagsViewController* vc = segue.destinationController;
        vc.items = [self.node.fields.tags.allObjects sortedArrayUsingComparator:finderStringComparator];

        __weak NodeDetailsViewController* weakSelf = self;
        vc.onAdd = ^(NSString * _Nonnull tag) {
            [weakSelf addTag:tag];
        };
        vc.onRemove = ^(NSString * _Nonnull tag) {
            [weakSelf removeTag:tag];
        };
    }
}

- (void)addTag:(NSString*)tag {

    [self.model addItemTag:self.node tag:trim(tag)];
}

- (void)removeTag:(NSString*)tag {

    [self.model removeItemTag:self.node tag:tag];
}

- (IBAction)onExpiresCheckbox:(id)sender {
    if(self.checkboxExpires.state == NSOnState) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:30 toDate:[NSDate date] options:0];
        [self.model setItemExpires:self.node expiry:date];
    }
    else {
        [self.model setItemExpires:self.node expiry:nil];
    }
}

- (IBAction)onDatePickerChanged:(id)sender {
    
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setExpiryDate:) object:nil];
    [self performSelector:@selector(setExpiryDate:) withObject:nil afterDelay:0.5f];
}

- (void)setExpiryDate:(NSDate*)date {
    [self.model setItemExpires:self.node expiry:self.datePickerExpires.dateValue];
}

- (IBAction)saveDocument:(id)sender {
    
    [self setModelForEditField:self.currentlyEditingUIControl];
    [self save:nil];
}

- (void)save:(void (^)(void))completion {
    self.onSaveCompletion = completion;
    [self.model.document saveDocumentWithDelegate:self didSaveSelector:@selector(onSaveDone) contextInfo:nil];
}

- (void)onSaveDone {
    if (self.onSaveCompletion) {
        self.onSaveCompletion();
        self.onSaveCompletion = nil;
    }
}

@end
