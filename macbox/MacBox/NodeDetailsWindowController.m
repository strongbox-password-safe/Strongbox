//
//  NodeDetailsWindowController.m
//  Strongbox
//
//  Created by Mark on 28/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "NodeDetailsWindowController.h"
#import "CustomField.h"
#import "Alerts.h"
#import "NSArray+Extensions.h"
#import "Entry.h"
#import "CustomFieldTableCellView.h"
#import "Settings.h"
#import "Utils.h"
#import "SprCompilation.h"
#import "MMcGACTextField.h"
#import "MacNodeIconHelper.h"
#import "PreferencesWindowController.h"
#import "MBProgressHUD.h"
#import "SelectPredefinedIconController.h"
#import "AttachmentItem.h"
#import "Node+OtpToken.h"
#import "OTPToken+Generation.h"

@interface NodeDetailsWindowController () < NSTableViewDataSource,
                                            NSTableViewDelegate,
                                            NSWindowDelegate,
                                            NSTextFieldDelegate,
                                            NSTextViewDelegate,
                                            NSCollectionViewDataSource,
                                            NSCollectionViewDelegate,
                                            QLPreviewPanelDataSource,
                                            QLPreviewPanelDelegate,
                                            NSComboBoxDataSource,
                                            NSComboBoxDelegate>

@property Node* node;
@property ViewModel* model;
@property BOOL readOnly;
@property ViewController* parentViewController;
@property (nonnull, strong, nonatomic) NSArray<CustomField*> *customFields;
@property (strong, nonatomic) SelectPredefinedIconController* selectPredefinedIconController;
@property NSView* currentlyEditingUIControl;

@property (weak) IBOutlet NSTableView *tableViewCustomFields;
@property (weak) IBOutlet NSButton *buttonAddCustomField;
@property (weak) IBOutlet NSButton *buttonRemoveCustomField;
@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet NSView *emailRow;
@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet MMcGACTextField *textFieldUsername;
@property (weak) IBOutlet MMcGACTextField *textFieldUrl;
@property (weak) IBOutlet MMcGACTextField *textFieldEmail;
@property (weak) IBOutlet KSPasswordField *textFieldPassword;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet ClickableImageView *imageViewIcon;
@property (weak) IBOutlet ClickableImageView *imageViewShowHidePassword;

@property (weak) IBOutlet AttachmentCollectionView *attachmentsView;
@property (nonnull, strong, nonatomic) NSArray *attachments;
@property NSMutableDictionary<NSNumber*, NSImage*> *attachmentsIconCache;

@property (weak) IBOutlet NSView *totpRow;
@property (weak) IBOutlet NSTextField *labelTotp;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;
@property NSTimer* timerRefreshOtp;
@property BOOL newEntry;

@property (weak) IBOutlet NSComboBox *comboGroup;
@property NSArray<Node*>* groups;
@property (weak) IBOutlet NSTextField *labelID;
@property (weak) IBOutlet NSTextField *labelCreated;
@property (weak) IBOutlet NSTextField *labelModified;

@end

static NSImage* kDefaultAttachmentIcon;

@implementation NodeDetailsWindowController

+ (void)initialize {
    if(self == [NodeDetailsWindowController class]) {
        kDefaultAttachmentIcon = [NSImage imageNamed:@"document_empty_64"];
    }
}

+ (instancetype)showNode:(Node*)node
                   model:(ViewModel*)model
                readOnly:(BOOL)readOnly
    parentViewController:(ViewController*)parentViewController
                newEntry:(BOOL)newEntry {
    NodeDetailsWindowController *window = [[NodeDetailsWindowController alloc] initWithWindowNibName:@"NodeDetailsWindowController"];
    
    window.node = node;
    window.model = model;
    window.readOnly = readOnly;
    window.newEntry = newEntry;
    window.parentViewController = parentViewController;
    
    [window showWindow:nil];
    
    return window;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.model.document.undoManager;
}

- (void)promptToSaveSimpleUIChangesBeforeClose {
    [Alerts yesNo:@"There are unsaved changes present. Would you like to save those before exiting?"
           window:self.window completion:^(BOOL yesNo) {
               if(yesNo) {
                   [self stopObservingModelChanges]; // Prevent any kind of race condition on close
                   [self setModelForEditField:self.currentlyEditingUIControl];
                   [self close];
               }
               else {
                   [self close];
               }
           }];
}

- (void)cancel:(id)sender { // Pick up escape key
    if([self changesInSimpleUICurrentEditor]) {
        [self promptToSaveSimpleUIChangesBeforeClose];
    }
    else {
        [self close];
    }
}

- (BOOL)changesInSimpleUICurrentEditor {
    BOOL changes = NO;
    
    if(self.tabView.selectedTabViewItem == self.tabView.tabViewItems[0]) { // Simple Tab
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
        else if(self.currentlyEditingUIControl == self.textFieldPassword){
            if(![self.node.fields.password isEqualToString:trimField(self.textFieldPassword)]) {
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

-(BOOL)windowShouldClose:(NSWindow *)sender {
    if([self changesInSimpleUICurrentEditor]) {
        [self promptToSaveSimpleUIChangesBeforeClose];
        return NO;
    }
    else {
        return YES;
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }

    [self stopObservingModelChanges];
    [self.parentViewController onDetailsWindowClosed:self.node.uuid]; // Allows parent VC to remove reference to this
}

- (void)observeModelChanges {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationTitleChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationUsernameChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationUrlChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationEmailChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationNotesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationPasswordChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onSimpleFieldsChanged:) name:kModelUpdateNotificationIconChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCustomFieldsChanged:) name:kModelUpdateNotificationCustomFieldsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onAttachmentsChanged:) name:kModelUpdateNotificationAttachmentsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onTotpChanged:) name:kModelUpdateNotificationTotpChanged object:nil];
}

- (void)stopObservingModelChanges {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)canEdit {
    return !self.readOnly;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSString* title =[self.model dereference:self.node.title node:self.node];
    
    self.window.title = self.readOnly ? [NSString stringWithFormat:@"%@ [Read-Only]", title] : title;
    
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    [self.window setLevel:Settings.sharedInstance.doNotFloatDetailsWindowOnTop ? NSNormalWindowLevel : NSFloatingWindowLevel];
    
    [self setupUi];
    
    [self setupAutoCompletes];
    
    [self enableDisableFieldsForEditing];
    
    [self bindUiToNode];
    
    [self observeModelChanges];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
    
    [self.window makeFirstResponder:self.newEntry ? self.textFieldTitle : self.imageViewIcon]; // Take focus off Title so that edits require some effort...
}

- (void)setupUi {
    [self showHideForPasswordSafe];
    [self setupSimpleUI];
    [self setupCustomFieldsUI];
    [self setupAttachmentsUI];
}

- (void)setupAttachmentsUI {
    self.attachments = [NSArray array];
    self.attachmentsView.dataSource = self;
    self.attachmentsView.delegate = self;
    self.attachmentsView.onSpaceBar = self.attachmentsView.onDoubleClick = ^{ // Funky
        [self onPreviewAttachment:nil];
    };
}

- (void)setupSimpleUI {
    self.textFieldTitle.delegate = self;
    self.textFieldPassword.delegate = self;
    self.textViewNotes.delegate = self;
    
    // MMcG: Cannot set delegate on these as it is used to do AutoComplete...
    
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

    self.textFieldPassword.showsText = Settings.sharedInstance.alwaysShowPassword;
    
    self.imageViewShowHidePassword.clickable = YES;
    self.imageViewShowHidePassword.image = [NSImage imageNamed:self.textFieldPassword.showsText ? @"hide" : @"show"];

    self.imageViewShowHidePassword.onClick = ^{
        [self.textFieldPassword toggleTextShown:nil];
        self.imageViewShowHidePassword.image = [NSImage imageNamed:self.textFieldPassword.showsText ? @"hide" : @"show"];
    };
    
    //
    
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
    
    self.comboGroup.delegate = self; // Do This after the select - so we don't see it as a user effected change!
}

- (void)bindUiToNode {
    [self bindUiToCustomFields];
    [self bindUiToSimpleFields];
    [self bindUiToAttachments];
}

- (void)bindUiToSimpleFields {
    self.window.title = self.node.title;
    self.textFieldTitle.stringValue = self.node.title;
    self.textFieldUsername.stringValue = self.node.fields.username;
    self.textFieldPassword.stringValue = self.node.fields.password;
    self.textFieldEmail.stringValue = self.node.fields.email;
    self.textFieldUrl.stringValue = self.node.fields.url;
    self.textViewNotes.string = self.node.fields.notes;
    
    self.imageViewIcon.image = [self getIconForNode];
    self.imageViewIcon.clickable = self.model.format != kPasswordSafe;
    self.imageViewIcon.onClick = ^{ [self onEditNodeIcon]; };
    self.imageViewIcon.showClickableBorder = YES;
    
    self.labelID.stringValue = self.model.format == kPasswordSafe ? self.node.uuid.UUIDString : keePassStringIdFromUuid(self.node.uuid);
    self.labelCreated.stringValue = friendlyDateString(self.node.fields.created);
    self.labelModified.stringValue = friendlyDateString(self.node.fields.modified);
    
    [self validateTitleAndIndicateValidityInUI];
    
    [self initializeTotp];
}

- (void)initializeTotp {
    [self bindUiToTotp];
    
    if(!Settings.sharedInstance.doNotShowTotp && self.node.otpToken) {
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
    if(!Settings.sharedInstance.doNotShowTotp && self.node.otpToken) {
        self.totpRow.hidden = NO;
        
        uint64_t remainingSeconds = self.node.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.node.otpToken.period);
        
        self.labelTotp.stringValue = self.node.otpToken.password;
        self.labelTotp.textColor = (remainingSeconds < 5) ? NSColor.redColor : (remainingSeconds < 9) ? NSColor.orangeColor : NSColor.controlTextColor;
        
        self.progressTotp.minValue = 0;
        self.progressTotp.maxValue = self.node.otpToken.period;
        self.progressTotp.doubleValue = remainingSeconds;
    }
    else {
        self.totpRow.hidden = YES;
        self.labelTotp.stringValue = @"000000";
    }
}

- (NSImage * )getIconForNode {
    return [MacNodeIconHelper getIconForNode:self.model vm:self.node large:NO];
}

- (void)showHideForPasswordSafe {
    self.emailRow.hidden = self.model.format != kPasswordSafe;
    
    if(self.model.format == kPasswordSafe) {
        [self.tabView removeTabViewItem:self.tabView.tabViewItems[1]]; // Remove Custom Fields
        [self.tabView removeTabViewItem:self.tabView.tabViewItems[1]]; // Remove Atachments
    }
}

- (void)setupAutoCompletes {
    [self setupUsernameAutoComplete];
    [self setupEmailAutoComplete];
    [self setupUrlAutoComplete];
}

- (void)setupEmailAutoComplete {
    self.textFieldEmail.completions = self.model.emailSet.allObjects;
    self.textFieldEmail.completionEnabled = !Settings.sharedInstance.doNotShowAutoCompleteSuggestions;
}

- (void)setupUrlAutoComplete {
    self.textFieldUrl.completions = self.model.urlSet.allObjects;
    self.textFieldUrl.completionEnabled = !Settings.sharedInstance.doNotShowAutoCompleteSuggestions;
}

- (void)setupUsernameAutoComplete {
    self.textFieldUsername.completions = self.model.usernameSet.allObjects;
    self.textFieldUsername.completionEnabled = !Settings.sharedInstance.doNotShowAutoCompleteSuggestions;
}

- (void)enableDisableFieldsForEditing {
    [self enableDisableSimpleForEditing];
    [self enableDisableCustomFieldsForEditing];
    [self enableDisableAttachmentsForEditing];
}

- (void)enableDisableAttachmentsForEditing {
    // TODO:
}

- (void)enableDisableSimpleForEditing {
    // TODO:
}

- (void)enableDisableCustomFieldsForEditing {
    self.buttonAddCustomField.enabled = [self canEdit];
    self.buttonRemoveCustomField.enabled = [self canEdit];
}

- (void)setupCustomFieldsUI {
    self.customFields = [NSArray array];

    self.tableViewCustomFields.dataSource = self;
    self.tableViewCustomFields.delegate = self;
    [self.tableViewCustomFields registerNib:[[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil] forIdentifier:@"CustomFieldValueCellIdentifier"];
    self.tableViewCustomFields.doubleAction = @selector(onEditField:);
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
        cell.protected = field.protected && !(field.value.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields);
        cell.valueHidden = field.protected && !(field.value.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields); // Initially Hide the Value if it is protected
        
        return cell;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.customFields.count;
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
    //NSLog(@"onEditCustomField: %@", field);
    
    if([self canEdit]) {
        Alerts* alert = [[Alerts alloc] init];
        
        [alert inputKeyValue:@"Edit Custom Field" initKey:field.key initValue:field.value initProtected:field.protected placeHolder:NO completion:^(BOOL yesNo, NSString *key, NSString *value, BOOL protected) {
            if(yesNo) {
                [self setCustomField:key value:value allowUpdate:YES protected:protected];
            }
        }];
    }
}

- (IBAction)onCopyCustomFieldKey:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:field.key forType:NSStringPboardType];
}

- (IBAction)onCopyCustomFieldValue:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:field.value forType:NSStringPboardType];
}

- (IBAction)onDeleteCustomField:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    
    [Alerts yesNo:[NSString stringWithFormat:@"Are you sure you want to remove the custom field '%@'?", field.key]
           window:self.window
       completion:^(BOOL yesNo) {
           if(yesNo) {
               [self.model removeCustomField:self.node key:field.key];
           }
       }];
}

- (IBAction)onRemoveCustomField:(id)sender {
    if(self.tableViewCustomFields.selectedRow != -1) {
        CustomField *field = self.customFields[self.tableViewCustomFields.selectedRow];
        
        [Alerts yesNo:[NSString stringWithFormat:@"Are you sure you want to remove the custom field '%@'?", field.key]
               window:self.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                [self.model removeCustomField:self.node key:field.key];
            }
        }];
    }
}

- (IBAction)onAddCustomField:(id)sender {
    Alerts* alert = [[Alerts alloc] init];
    
    [alert inputKeyValue:@"Add Custom Field" initKey:@"Key" initValue:@"Value" initProtected:NO placeHolder:YES completion:^(BOOL yesNo, NSString *key, NSString *value, BOOL protected) {
        if(yesNo) {
            [self setCustomField:key value:value allowUpdate:NO protected:protected];
        }
    }];
}

- (void)setCustomField:(NSString*)key value:(NSString*)value allowUpdate:(BOOL)allowUpdate protected:(BOOL)protected {
    NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
    
    if(!allowUpdate && [existingKeySet containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it already exists in custom fields." window:self.window];
        return;
    }
    
    if([keePassReserved containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it is reserved for standard KeePass fields." window:self.window];
        return;
    }
    
    [self.model setCustomField:self.node key:key value:[StringValue valueWithString:value protected:protected]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL theAction = [menuItem action];
    
    if (theAction == @selector(onDeleteCustomField:)) {
        return [self canEdit];
    }
    else if (theAction == @selector(onEditField:)) {
        return [self canEdit];
    }
    else if (theAction == @selector(onPreviewAttachment:)) {
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

- (IBAction)onPasswordSettings:(id)sender {
    [PreferencesWindowController.sharedInstance showOnTab:1];
}

- (IBAction)onGenerate:(id)sender {
    [self.window makeFirstResponder:self.imageViewIcon]; // text doesn't change unless we do this!
    
    [self.model setItemPassword:self.node password:[self.model generatePassword]];
    self.textFieldPassword.showsText = YES;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    self.currentlyEditingUIControl = nil;
    [self setModelForEditField:obj.object];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    self.currentlyEditingUIControl = nil;
    [self setModelForEditField:notification.object];
}

- (void)setModelForEditField:(NSView*)obj {
    // NSLog(@"setModelForEditField for [%@]", obj);
    
    if(obj == self.textFieldTitle) {
        if(![self.node.title isEqualToString:trimField(self.textFieldTitle)]) {
            if(![self.model setItemTitle:self.node title:trimField(self.textFieldTitle)]) {
                self.textFieldTitle.stringValue = self.node.title; // Title Rename Failed
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
    else if(obj == self.textFieldPassword){
        if(![self.node.fields.password isEqualToString:trimField(self.textFieldPassword)]) {
            [self.model setItemPassword:self.node password:trimField(self.textFieldPassword)];
        }
    }
    else if(obj == self.textViewNotes) {
        NSString *updated = [NSString stringWithString:self.textViewNotes.textStorage.string];
        if(![self.node.fields.notes isEqualToString:updated]) {
            [self.model setItemNotes:self.node notes:updated];
        }
    }
    else {
        // NSLog(@"NOP for setModelForEditField");
    }
}

NSString* trimField(NSTextField* textField) {
    return [Utils trim:textField.stringValue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onEditNodeIcon {
    if(self.model.format == kPasswordSafe) {
        return;
    }
    
    __weak NodeDetailsWindowController* weakSelf = self;
    self.selectPredefinedIconController = [[SelectPredefinedIconController alloc] initWithWindowNibName:@"SelectPredefinedIconController"];
    self.selectPredefinedIconController.customIcons = self.model.customIcons;
    self.selectPredefinedIconController.hideSelectFile = self.model.format == kKeePass1;
    self.selectPredefinedIconController.onSelectedItem = ^(NSNumber * _Nullable index, NSData * _Nullable data, NSUUID * _Nullable existingCustom) {
        onSelectedNewIcon(weakSelf.model, weakSelf.node, index, data, existingCustom, weakSelf.window);
    };
    
    [self.window beginSheet:self.selectPredefinedIconController.window  completionHandler:nil];
}

- (void)onSelectedNewIcon:(Node*)item index:(NSNumber*)index data:(NSData*)data existingCustom:(NSUUID*)existingCustom {
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Attachments

- (void)bindUiToAttachments {
    self.attachmentsIconCache = nil;
    self.attachments = [self.node.fields.attachments copy];
    [self.attachmentsView reloadData];
}

- (IBAction)onPreviewAttachment:(id)sender {
    NSUInteger index = [self.attachmentsView.selectionIndexes firstIndex];
    if(index == NSNotFound) {
        return;
    }
    
    [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:self];
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.attachments.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    AttachmentItem *item = [self.attachmentsView makeItemWithIdentifier:@"AttachmentItem" forIndexPath:indexPath];
    
    NodeFileAttachment* attachment = self.attachments[indexPath.item];
    DatabaseAttachment* dbAttachment = self.model.attachments[attachment.index];
    
    item.textField.stringValue = attachment.filename;
    item.imageView.image = kDefaultAttachmentIcon;
    item.labelFileSize.stringValue = [NSByteCountFormatter stringFromByteCount:dbAttachment.data.length countStyle:NSByteCountFormatterCountStyleFile];
    
    if(self.attachmentsIconCache == nil) {
        self.attachmentsIconCache = [NSMutableDictionary dictionary];
        [self buildAttachmentsIconCache];
    }
    
    NSImage* cachedIcon = self.attachmentsIconCache[@(attachment.index)];
    if(cachedIcon) {
        item.imageView.image = cachedIcon;
    }
    else {
        NSImage* img = [[NSWorkspace sharedWorkspace] iconForFileType:attachment.filename];
        
        if(img.size.width != 32 || img.size.height != 32) {
            img = scaleImage(img, CGSizeMake(32, 32));
        }
        
        item.imageView.image = img;
    }
    
    return item;
}

- (void)buildAttachmentsIconCache {
    NSArray *workingCopy = [self.model.attachments copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0;i<workingCopy.count;i++) {
            DatabaseAttachment* dbAttachment = workingCopy[i];
            
            NSImage* img = [[NSImage alloc] initWithData:dbAttachment.data];
            if(img) {
                img = scaleImage(img, CGSizeMake(88, 88));
                [self.attachmentsIconCache setObject:img forKey:@(i)];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.attachmentsView reloadData];
            [self.window.contentView setNeedsDisplay:YES];
        });
    });
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
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
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    
    if(nodeAttachment.index < 0 || nodeAttachment.index >= self.model.attachments.count) {
        NSLog(@"Node Attachment out of bounds of Database Attachments. [%d]", nodeAttachment.index);
        return nil;
    }
    
    DatabaseAttachment* dbAttachment = [self.model.attachments objectAtIndex:nodeAttachment.index];
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:nodeAttachment.filename];
    
    NSError* error;
    //BOOL success =
    [dbAttachment.data writeToFile:f options:kNilOptions error:&error];
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
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        NSString* path = [NSString pathWithComponents:@[NSTemporaryDirectory(), file]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (IBAction)onSaveAttachment:(id)sender {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    
    if(nodeAttachment.index < 0 || nodeAttachment.index >= self.model.attachments.count) {
        NSLog(@"Node Attachment out of bounds of Database Attachments. [%d]", nodeAttachment.index);
        return;
    }
    
    // Save As Dialog...
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = nodeAttachment.filename;
    
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            DatabaseAttachment* dbAttachment = [self.model.attachments objectAtIndex:nodeAttachment.index];
            [dbAttachment.data writeToFile:savePanel.URL.path atomically:YES];
            [savePanel orderOut:self];
        }
    }];
}

- (IBAction)onRemoveAttachment:(id)sender {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    NSString* prompt = [NSString stringWithFormat:@"Are you sure you want to remove the attachment: %@?", nodeAttachment.filename];
    [Alerts yesNo:prompt window:self.window completion:^(BOOL yesNo) {
        if(yesNo) {
            [self.model removeItemAttachment:self.node atIndex:idx];
        }
    }];
}

- (IBAction)onAddAttachment:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSError* error;
            NSData* data = [NSData dataWithContentsOfURL:openPanel.URL options:kNilOptions error:&error];
            
            if(!data) {
                NSLog(@"Could not read file at %@. Error: %@", openPanel.URL, error);
                return;
            }
            
            NSString* filename = openPanel.URL.lastPathComponent;
            
            [self.model addItemAttachment:self.node attachment:[[UiAttachment alloc] initWithFilename:filename data:data]];
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)copyToPasteboard:(NSString*)text {
    [[NSPasteboard generalPasteboard] clearContents];
    
    if(text.length) {
        [[NSPasteboard generalPasteboard] setString:[self.model dereference:text node:self.node] forType:NSStringPboardType];
    }
}

- (IBAction)onCopyTitle:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.title];
    [self showPopupToastNotification:@"Title Copied"];
}

- (IBAction)onCopyUsername:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.fields.username];
    [self showPopupToastNotification:@"Username Copied"];
}

- (IBAction)onCopyEmail:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.fields.email];
    [self showPopupToastNotification:@"Email Copied"];
}

- (IBAction)onCopyUrl:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.fields.url];
    [self showPopupToastNotification:@"URL Copied"];
}

- (IBAction)onCopyNotes:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.fields.notes];
    [self showPopupToastNotification:@"Notes Copied"];
}

- (IBAction)onCopyPassword:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    [self copyToPasteboard:self.node.fields.password];
    [self showPopupToastNotification:@"Password Copied"];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    [self.window makeFirstResponder:nil]; // Force end editing of fields and set to model... then copy
    
    [self copyToPasteboard:self.node.fields.password];

    NSString *urlString = [self.model dereference:self.node.fields.url node:self.node];
    if (!urlString.length) {
        return;
    }
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    [self showPopupToastNotification:@"Password Copied and URL Launched"];
}

- (IBAction)onCopyTotp:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];

    if(self.node.otpToken) {
        NSString *password = self.node.otpToken.password;
        [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];
    }
    
    [self showPopupToastNotification:@"TOTP Copied"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onSetTotp:(id)sender {
    NSString* response = [[Alerts alloc] input:@"Please enter the secret or an OTPAuth URL" defaultValue:@"" allowEmpty:NO];
    
    if(response) {
        [self.model setTotp:self.node otp:response];
    }
}

- (IBAction)onClearTotp:(id)sender {
    [self.model clearTotp:self.node];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Model Changes...

- (void)onSimpleFieldsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];
    if(node == self.node) {
        [self bindUiToSimpleFields];

        if(notification.name == kModelUpdateNotificationTitleChanged) {
            [self showPopupToastNotification:@"Title Changed"];
        }
        else if(notification.name == kModelUpdateNotificationUsernameChanged){
            [self showPopupToastNotification:@"Username Changed"];
        }
        else if(notification.name == kModelUpdateNotificationUrlChanged){
            [self showPopupToastNotification:@"URL Changed"];
        }
        else if(notification.name == kModelUpdateNotificationEmailChanged){
            [self showPopupToastNotification:@"Email Changed"];
        }
        else if(notification.name == kModelUpdateNotificationNotesChanged){
            [self showPopupToastNotification:@"Notes Changed"];
        }
        else if(notification.name == kModelUpdateNotificationPasswordChanged){
            [self showPopupToastNotification:@"Password Changed"];
        }
        else if(notification.name == kModelUpdateNotificationIconChanged){
            [self showPopupToastNotification:@"Icon Changed"];
        }
    }
}

- (void)onCustomFieldsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }

    [self bindUiToSimpleFields]; // Update Modified Date
    [self bindUiToCustomFields];
    
    [self showPopupToastNotification:@"Custom Fields Changed"];
}

- (void)onAttachmentsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    [self bindUiToSimpleFields]; // Update Modified Date
    [self bindUiToAttachments];
    
    [self showPopupToastNotification:@"Attachments Changed"];
}

- (void)onTotpChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }
    
    [self bindUiToSimpleFields]; // Update Modified Date
    [self initializeTotp];
    
    [self showPopupToastNotification:@"TOTP Changed"];
}

- (void)showPopupToastNotification:(NSString*)message {
    if(Settings.sharedInstance.doNotShowChangeNotifications) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.window.contentView animated:YES];
    hud.labelText = @"";
    hud.detailsLabelText = message;
    hud.color = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
    hud.mode = MBProgressHUDModeText;
    hud.margin = 2.f;
    hud.yOffset = -210.f;
    hud.removeFromSuperViewOnHide = YES;
    hud.dismissible = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud hide:YES];
    });
}

// Combo Group

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    return self.groups.count;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    return [self.model getGroupPathDisplayString:self.groups[index]];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger idx = [self.comboGroup indexOfSelectedItem];
    Node* group = self.groups[idx];
    
    //NSLog(@"Selected Group: [%@]", group.title);
    
    if(self.node.parent != group) {
        if(![self.model validateChangeParent:group node:self.node]) { // Should never happen - but safety in case we someday cover groups?
            [Alerts info:@"Could not change group! Validate failed..." window:self.window];
            [self syncComboGroupWithNode];
        }
        else {
            [self.model changeParent:group node:self.node];
        }
    }
    else {
        //NSLog(@"Ignoring Combo change to identical parent group");
    }
}

- (void)syncComboGroupWithNode {
    NSInteger origIdx = self.node.parent ? [self.groups indexOfObject:self.node.parent] : 0;
    
    if(origIdx != NSNotFound) {
        [self.comboGroup selectItemAtIndex:origIdx];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onPreferencesChanged:(NSNotification*)notification {
    NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableViewCustomFields reloadData];
    });
}

@end
