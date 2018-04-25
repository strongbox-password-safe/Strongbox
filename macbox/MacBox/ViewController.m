//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "Alerts.h"
#import "ChangeMasterPasswordWindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "CHCSVParser.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SafesList.h"
#import "BiometricIdHelper.h"
#import "PreferencesWindowController.h"

#define kDragAndDropUti @"com.markmcguill.strongbox.drag.and.drop.internal.uti"

@interface ViewController ()

@property (strong, nonatomic) ChangeMasterPasswordWindowController *changeMasterPassword;
@property (strong, nonatomic) NSImage *folderImage;
@property (strong, nonatomic) NSImage *strongBox256Image;
@property (strong, nonatomic) NSImage *smallYellowFolderImage;
@property (strong, nonatomic) NSImage *smallLockImage;
@property (nonatomic) BOOL showPassword;
@property (strong, nonatomic) NSArray<NSString*>* emailAutoCompleteCache;
@property (strong, nonatomic) NSArray<NSString*>* usernameAutoCompleteCache;

@end

@implementation ViewController

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self initializeFullOrTrialOrLiteUI];
    
    [self setInitialFocus];
}

- (void)updateAutocompleteCaches {
    // NB: We use these caches tso that we don't get a feedback when entering entries in the fields and setting them on the model. Also PERF
    
    self.emailAutoCompleteCache = self.model ? [[self.model.emailSet allObjects] sortedArrayUsingComparator:finderStringComparator] : [NSArray array];
    self.usernameAutoCompleteCache = self.model ? [[self.model.usernameSet allObjects] sortedArrayUsingComparator:finderStringComparator] : [NSArray array];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self loadUIImages];
    
    [self enableDragDrop];

    [self customizeUi];

    [self bindToModel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAutoLock:) name:kAutoLockTime object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
}

- (void)customizeUi {
    self.buttonRevealDetail.layer.cornerRadius = 20;
    self.checkboxRevealDetailsImmediately.state = [Settings sharedInstance].revealDetailsImmediately;
    
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
    
    [self.comboboxUsername setDataSource:self];
    [self.comboBoxEmail setDataSource:self];
    
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:@"Unlock with %@", BiometricIdHelper.sharedInstance.biometricIdName];
    
    self.showPassword = Settings.sharedInstance.alwaysShowPassword;
}

- (void)loadUIImages {
    self.folderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
    self.strongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
    self.smallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
    self.smallLockImage = [NSImage imageNamed:@"lock-48"];
}

- (void)disableFeaturesForLiteVersion {
    [self.searchField setPlaceholderString:@"Search Disabled - Please Upgrade"];
    self.searchField.enabled = NO;
    self.searchSegmentedControl.enabled = NO;
}

- (void)enableFeaturesForFullVersion {
    [self.searchField setPlaceholderString:@"Search (⌘F)"];
    self.searchField.enabled = YES;
    self.searchSegmentedControl.enabled = YES;
}

- (void)initializeFullOrTrialOrLiteUI {
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial) {
        [self disableFeaturesForLiteVersion];
    }
    else {
        [self enableFeaturesForFullVersion];
    }
}

-(void)setModel:(ViewModel *)model {
    _model = model;
    [self bindToModel];
}

-(void)updateDocumentUrl {
    [self bindStatusPane];
    
    [self bindDetailsPane];
}

- (NSString * _Nonnull)bindStatusPane {
    return self.labelLeftStatus.stringValue = self.model.fileUrl ?
        //[[[NSFileManager defaultManager] componentsToDisplayForPath:self.model.fileUrl.path] componentsJoinedByString:@"/"]:
    self.model.fileUrl.path :
    @"[Not Saved]";
}

- (BOOL)biometricOpenIsAvailableForSafe {
    SafeMetaData* metaData = [self getMetaDataForModel];
    
    return  metaData == nil ||
            !metaData.isTouchIdEnabled ||
            !metaData.touchIdPassword ||
            !BiometricIdHelper.sharedInstance.biometricIdAvailable ||
    !(Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial);
}

- (void)bindToModel {
    if(self.model == nil) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:2];
        [self.outlineView reloadData];
        return;
    }
    
    if(self.model.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
        
        if([self biometricOpenIsAvailableForSafe]) {
            self.buttonUnlockWithTouchId.hidden = YES;
            [self.buttonUnlockWithTouchId setKeyEquivalent:@""];
            [self.buttonUnlockWithPassword setKeyEquivalent:@"\r"];
        }
        else {
            self.buttonUnlockWithTouchId.hidden = NO;
            [self.buttonUnlockWithTouchId setKeyEquivalent:@"\r"];
            [self.buttonUnlockWithPassword setKeyEquivalent:@""];        }
    }
    else {        
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
    }
    
    NSInteger colIdx = [self.outlineView columnWithIdentifier:@"UsernameColumn"];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    col.hidden = !Settings.sharedInstance.alwaysShowUsernameInOutlineView;
    //self.outlineView.headerView = nil;
    [self.outlineView reloadData];
    
    [self bindDetailsPane];
    
    [self bindStatusPane];
}

- (void)setInitialFocus {
    if(self.model == nil || self.model.locked) {
        if([self biometricOpenIsAvailableForSafe]) {
            [self.view.window makeFirstResponder:self.textFieldMasterPassword];
        }
        else {
            [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
        }
    }
    else {
        [self.view.window makeFirstResponder:self.outlineView];
    }
}

- (void)bindDetailsPane {
    Node* it = [self getCurrentSelectedItem];
    
    [self updateAutocompleteCaches];
    
    if(!it) {        
        [self.tabViewRightPane selectTabViewItemAtIndex:2];
        [self updateSafeSummaryFields];
    }
    else if (it.isGroup) {
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        self.textFieldSummaryTitle.stringValue = it.title;
    }
    else {
        self.textFieldTitle.stringValue = it.title;
        self.textFieldPw.stringValue = it.fields.password;
        self.textFieldUrl.stringValue = it.fields.url;
        self.comboboxUsername.stringValue = it.fields.username;
        self.comboBoxEmail.stringValue = it.fields.email;
        self.textViewNotes.string = it.fields.notes;
        self.textFieldSummaryTitle.stringValue = it.title;

        if([Settings sharedInstance].revealDetailsImmediately) {
            [self revealDetails];
        }
        else {
            [self concealDetails];
        }
        
        self.showPassword = Settings.sharedInstance.alwaysShowPassword;
        [self showOrHidePassword];
    }
}

- (IBAction)onRevealDetails:(id)sender {
    [self revealDetails];
}

- (IBAction)onConcealDetails:(id)sender {
    [self concealDetails];
}

- (void)revealDetails {
    [self.tabViewRightPane selectTabViewItemAtIndex:0];
}

- (void)concealDetails {
    [self.tabViewRightPane selectTabViewItemAtIndex:3];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.model || self.model.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<Node*> *items = [self getSafeItems:self.model.rootGroup];
        
        return items.count > 0;
    }
    else {
        Node *it = (Node*)item;
        
        if(it.isGroup) {
            NSArray<Node*> *items = [self getSafeItems:it];
            
            return items.count > 0;
        }
        else {
            return NO;
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if(!self.model || self.model.locked) {
        return 0;
    }
    
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    
    NSArray<Node*> *items = [self getSafeItems:group];
    
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    
    NSArray<Node*> *items = [self getSafeItems:group];
    
    return items[index];
}

- (NSArray<Node*> *)getSafeItems:(Node*)parentGroup {
    if(!self.model || self.model.locked) {
        NSLog(@"Request for safe items while model nil or locked!");
        return @[];
    }
    
    return [parentGroup.children filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self isSafeItemMatchesSearchCriteria:evaluatedObject recurse:YES];
    }]];
}

- (BOOL)isSafeItemMatchesSearchCriteria:(Node*)item recurse:(BOOL)recurse {
    NSString* searchText = self.searchField.stringValue;
    
    if(![searchText length]) {
        return YES;
    }
    
    NSPredicate *predicate;
    
    NSInteger scope = self.searchSegmentedControl.selectedSegment;
    if (scope == 0) {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    else if (scope == 1)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.username contains[c] %@", searchText];
    }
    else if (scope == 2)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.password contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@  "
                     @"OR fields.password contains[c] %@  "
                     @"OR fields.username contains[c] %@  "
                     @"OR fields.email contains[c] %@  "
                     @"OR fields.url contains[c] %@  "
                     @"OR fields.notes contains[c] %@", searchText, searchText, searchText, searchText, searchText, searchText];
    }

    if([predicate evaluateWithObject:item]) {
        return YES;
    }
    else if(item.isGroup && recurse) {
        for(Node* child in item.children) {
            if(child.isGroup) {
                if([[self getSafeItems:child] count] > 0) {
                    return YES;
                }
            }
            else {
                if([self isSafeItemMatchesSearchCriteria:child recurse:YES]) {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item
{
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
    if([tableColumn.identifier isEqualToString:@"TitleColumn"]) {
        NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"TitleCell" owner:self];

        Node *it = (Node*)item;
        
        cell.textField.stringValue = it.title;
        cell.imageView.objectValue = it.isGroup ? self.smallYellowFolderImage : self.smallLockImage;
        
        return cell;
    }
    else {
        NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"UsernameCell" owner:self];
        
        Node *it = (Node*)item;
        
        cell.textField.stringValue = it.fields.username;
        
        return cell;
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    //NSLog(@"Selection Change Outline View");
    [self bindDetailsPane];
}

- (IBAction)onEnterMasterPassword:(id)sender {
    NSError* error = [self unlock:self.textFieldMasterPassword.stringValue];
    
    if(error) {
        [Alerts error:@"Could not open safe" error:error window:self.view.window];
    }
}

- (IBAction)onUnlockWithTouchId:(id)sender {
    if(BiometricIdHelper.sharedInstance.biometricIdAvailable) {
        SafeMetaData *safe = [self getMetaDataForModel];
        
        if(safe && safe.isTouchIdEnabled && safe.touchIdPassword) {
            [BiometricIdHelper.sharedInstance authorize:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(success) {
                        NSError* error = [self unlock:safe.touchIdPassword];
                        
                        if(error) {
                            [safe removeTouchIdPassword];
                            [SafesList.sharedInstance remove:safe.uuid];

                            [Alerts error:@"Could not open safe with stored Touch ID Password. The stored password will now be removed from secure storage. You will need to enter the correct password to unlock the safe, and enrol again for Touch ID." error:error window:self.view.window];

                            [self bindToModel];
                        }
                    }
                    else {
                        NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                        
                        if(error && (error.code == LAErrorUserFallback || error.code == LAErrorUserCancel)) {
                            NSLog(@"User cancelled or selected fallback. Ignore...");
                        }
                        else {
                            [Alerts error:error window:self.view.window];
                        }
                    }
                });}];
        }
        else {
            NSLog(@"Touch ID button pressed but no Touch ID Stored?");
            [Alerts info:@"The stored password is unavailable for some reason. Please enter the password manually. Metadata for this safe will be cleared." window:self.view.window];
            if(safe) {
                [SafesList.sharedInstance remove:safe.uuid];
            }
        }
    }
}

- (SafeMetaData*)getMetaDataForModel {
    if(!self.model || !self.model.fileUrl) {
        return nil;
    }
    
    NSArray<SafeMetaData*>* matches = [SafesList.sharedInstance.snapshot filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [((SafeMetaData*)evaluatedObject).fileIdentifier isEqualToString:self.model.fileUrl.absoluteString];
    }]];
    
    return [matches firstObject];
}

- (void)onSuccessfulUnlock:(NSString *)selectedItemId {
    if ( BiometricIdHelper.sharedInstance.biometricIdAvailable && (Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial)) {
        NSLog(@"Biometric ID is available on Device. Should we enrol?");
        
        if(!Settings.sharedInstance.warnedAboutTouchId) {
            Settings.sharedInstance.warnedAboutTouchId = YES;
            
            [Alerts info:@"Touch ID Considerations\n\nWhile this is very convenient, it is not a perfect system for protecting your passwords. It is provided for convenience only. It is within the realm of possibilities that someone with access to your device or your fingerprint, can produce a good enough fake fingerprint to fool Apple’s Touch ID. In addition, on your Mac, your master password will be securely stored in the Keychain. This means it is possible for someone with administrative privileges to search your Keychain for your master password. You should be aware that a strong passphrase held only in your mind provides the most secure experience with StrongBox.\n\nPlease take all of this into account, and make your decision to use Touch ID based on your preferred balance of convenience and security."
                  window:self.view.window];
        }
        
        SafeMetaData* metaData = [self getMetaDataForModel];
        
        if(!metaData) {
            // First Time? Display Touch ID Caveat
            
            NSString* message = [NSString stringWithFormat:@"Would you like to use %@ to open this safe in the future?", BiometricIdHelper.sharedInstance.biometricIdName];
            
            [Alerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                NSURL* url = self.model.fileUrl;
                SafeMetaData* safeMetaData = [[SafeMetaData alloc] initWithNickName:[url.lastPathComponent stringByDeletingPathExtension]
                                                                    storageProvider:kLocalDevice
                                                                           fileName:url.lastPathComponent
                                                                     fileIdentifier:url.absoluteString];
                
                if(yesNo) {
                    safeMetaData.isTouchIdEnabled = YES;
                    safeMetaData.touchIdPassword = self.textFieldMasterPassword.stringValue;
                }
                else {
                    safeMetaData.isTouchIdEnabled = NO;
                }
                
                [SafesList.sharedInstance add:safeMetaData];
                
                [self openSafeForDisplayAfterUnlock:selectedItemId];
            }];
        }
        else {
            NSLog(@"Found meta data for this file, no need to enrol.");
            [self openSafeForDisplayAfterUnlock:selectedItemId];
        }
    }
    else {
        [self openSafeForDisplayAfterUnlock:selectedItemId];
    }
}

- (void)openSafeForDisplayAfterUnlock:(NSString *)selectedItemId {
    [self bindToModel];
    
    self.textFieldMasterPassword.stringValue = @"";
    
    Node* selectedItem = [self.model getItemFromSerializationId:selectedItemId];
    
    [self selectItem:selectedItem];
    
    [self setInitialFocus];
}

- (NSError*)unlock:(NSString*)password {
    if(self.model && self.model.locked) {
        NSError *error;
        NSString *selectedItemId;
        
        if([self.model unlock:password selectedItem:&selectedItemId error:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onSuccessfulUnlock:selectedItemId];
            });
        }
        else {
            return error;
        }
    }
    
    return nil;
}

- (void)onAutoLock:(NSNotification*)notification {
    if(self.model && !self.model.locked && !self.model.dirty) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLock:nil];
        });
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        if(self.model.dirty) {
            [Alerts info:@"You cannot lock a safe while changes are pending. Save your changes first." window:self.view.window];
            //            NSLog(@"Saving...");
            //            
            //            SEL selector = NSSelectorFromString(@"saveDocument:");
            //            [[NSApplication sharedApplication] sendAction:selector to:nil from:self];
            //            
            //[NSApplication sharedApplication] sendAction:NSSelectorFromString(saveDocument: to:]; from:(nullable id)
        }
        else {
            NSError* error;
            
            Node* item = [self getCurrentSelectedItem];
            
            if(![self.model lock:&error selectedItem:item.serializationId]) {
                [Alerts error:error window:self.view.window];
                return;
            }
            
            [self bindToModel];
            
            self.textFieldMasterPassword.stringValue = @"";
            [self setInitialFocus];
            
            [self.view setNeedsDisplay:YES];
        }
    }
}

- (IBAction)onOutlineViewDoubleClick:(id)sender {
    Node *item = [sender itemAtRow:[sender clickedRow]];
    
    if ([sender isItemExpanded:item]) {
        [sender collapseItem:item];
    }
    else {
        [sender expandItem:item];
    }
}

- (IBAction)onFind:(id)sender {
    [self.view.window makeFirstResponder:self.searchField];
}

- (IBAction)onChangeMasterPassword:(id)sender {
    if(self.model && !self.model.locked) {
        self.changeMasterPassword = [[ChangeMasterPasswordWindowController alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
        
        self.changeMasterPassword.titleText = @"Change Master Password";
        
        [self.view.window beginSheet:self.changeMasterPassword.window  completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSModalResponseOK) {
                [self.model setMasterPassword:self.changeMasterPassword.confirmedPassword];
                
                // Update Touch Id Password
                
                SafeMetaData* safe = [self getMetaDataForModel];
                if(safe && safe.isTouchIdEnabled && safe.touchIdPassword) {
                    NSLog(@"Updating Touch ID Password");
                    safe.touchIdPassword = self.changeMasterPassword.confirmedPassword;
                }
    
                // Autosaving here as I think it makes sense, also avoids issue with Touch ID Password getting out of sync some how
                
                [[NSApplication sharedApplication] sendAction:@selector(saveDocument:) to:nil from:self];
                
                [Alerts info:@"Master Password Changed" window:self.view.window];
            }
        }];
    }
}

- (IBAction)onSearch:(id)sender {
    //NSLog(@"Search For: %@", self.searchField.stringValue);
    
    [self.outlineView reloadData];
    
    NSInteger colIdx = [self.outlineView columnWithIdentifier:@"UsernameColumn"];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    
    if( self.searchField.stringValue.length > 0) {
        col.hidden = NO;
        self.buttonCreateGroup.enabled = NO;
        self.buttonCreateRecord.enabled = NO;
        [self.outlineView expandItem:nil expandChildren:YES];

        for(int i=0;i < [self.outlineView numberOfRows];i++) {
            //NSLog(@"Searching: %d", i);
            Node* node = [self.outlineView itemAtRow:i];
            
            if([self isSafeItemMatchesSearchCriteria:node recurse:NO]) {
                //NSLog(@"Found: %@", node.title);
                [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
                break;
            }
        }
    }
    else {
        col.hidden = !Settings.sharedInstance.alwaysShowUsernameInOutlineView;
        self.buttonCreateGroup.enabled = YES;
        self.buttonCreateRecord.enabled = YES;
        [self.outlineView collapseItem:nil collapseChildren:YES];
    }
    
    [self bindDetailsPane];
}

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender {
    [Settings sharedInstance].revealDetailsImmediately = self.checkboxRevealDetailsImmediately.state;
}

- (IBAction)onToggleShowHidePassword:(id)sender {
    self.showPassword = !self.showPassword;
    
    [self showOrHidePassword];
}

- (void)showOrHidePassword {
    Node* item = [self getCurrentSelectedItem];
    if(!item)
    {
        return;
    }
    
    if(self.showPassword) {
        
        self.textFieldPw.enabled = YES;
        self.textFieldPw.stringValue = item.fields.password;
        self.textFieldPw.textColor = [NSColor purpleColor];// disabledControlTextColor]
        //self.buttonShowHidePassword.title = @"Hide Password (⌘P)";
        self.buttonGeneratePassword.hidden = NO;
    }
    else {
        self.textFieldPw.enabled = NO;
        self.textFieldPw.stringValue = @"***********************";
        self.textFieldPw.textColor = [NSColor disabledControlTextColor];
        self.buttonGeneratePassword.hidden = YES;
        //self.buttonShowHidePassword.title = @"Show Password (⌘P)";
    }
}

- (IBAction)onCopyTitle:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldTitle.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUsername:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.comboboxUsername.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyEmail:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.comboBoxEmail.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldUrl.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyNotes:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textViewNotes.textStorage.string forType:NSStringPboardType];
}

- (IBAction)onCopyPassword:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    Node* item = [self getCurrentSelectedItem];
    
    NSString *password = item.fields.password;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];
}

- (Node*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    //NSLog(@"Selected Row: %ld", (long)selectedRow);
    
    return [self.outlineView itemAtRow:selectedRow];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    NSArray<NSString*>* src = aComboBox == self.comboboxUsername ? self.usernameAutoCompleteCache : self.emailAutoCompleteCache;
    return src.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    NSArray<NSString*>* src = aComboBox == self.comboboxUsername ? self.usernameAutoCompleteCache : self.emailAutoCompleteCache;
    return [src objectAtIndex:index];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification{
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    //    NSLog(@"comboBoxSelectionDidChange");

    if(notification.object == self.comboboxUsername) {
        NSString *strValue = [self.usernameAutoCompleteCache objectAtIndex:[notification.object indexOfSelectedItem]];
        strValue = [Utils trim:strValue];
        
        Node* item = [self getCurrentSelectedItem];

        if(![item.fields.username isEqualToString:strValue]) {
            [self.model setItemUsername:item username:strValue];
            item.fields.accessed = [[NSDate alloc] init];
            item.fields.modified = [[NSDate alloc] init];
        }
    }
    else if(notification.object == self.comboBoxEmail) {
        NSString *strValue = [self.emailAutoCompleteCache objectAtIndex:[notification.object indexOfSelectedItem]];
        strValue = [Utils trim:strValue];
        
        Node* item = [self getCurrentSelectedItem];
        
        if(![item.fields.email isEqualToString:strValue]) {
            [self.model setItemEmail:item email:strValue];
            item.fields.accessed = [[NSDate alloc] init];
            item.fields.modified = [[NSDate alloc] init];
        }
    }
}

- (void)textDidChange:(NSNotification *)notification {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    //    NSLog(@"textDidChange");
    
    if(notification.object == self.textViewNotes) {
        Node* item = [self getCurrentSelectedItem];
        
        NSString *current = item.fields.notes;
        NSString *updated = [NSString stringWithString:self.textViewNotes.textStorage.string];
        
        if(![current isEqualToString:updated]) {
            [self.model setItemNotes:item notes:updated];
            item.fields.accessed = [[NSDate alloc] init];
            item.fields.modified = [[NSDate alloc] init];
        }
    }
}

- (IBAction)controlTextDidChange:(NSNotification *)obj
{
    //NSLog(@"controlTextDidChange");
    [self onDetailFieldChange:obj.object];
}

- (IBAction)onDetailFieldChange:(id)sender {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    Node* item = [self getCurrentSelectedItem];
    BOOL recordChanged = NO;
    
    if(sender == self.textFieldTitle) {
        if(![item.title isEqualToString:trimField(self.textFieldTitle)]) {
            [self.model setItemTitle:item title:trimField(self.textFieldTitle)];
            
            NSInteger row = [self.outlineView selectedRow];
            [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        
            recordChanged = YES;
        }
    }
    else if(sender == self.comboboxUsername) {
        if(![item.fields.username isEqualToString:trimField(self.comboboxUsername)]) {
            [self.model setItemUsername:item username:trimField(self.comboboxUsername)];

            NSInteger row = [self.outlineView selectedRow];
            [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:1]];

            recordChanged = YES;
        }
    }
    else if(sender == self.comboBoxEmail) {
        if(![item.fields.email isEqualToString:trimField(self.comboBoxEmail)]) {
            [self.model setItemEmail:item email:trimField(self.comboBoxEmail)];
            
            recordChanged = YES;
        }
    }
    else if(sender == self.textFieldUrl) {
        if(![item.fields.url isEqualToString:trimField(self.textFieldUrl)]) {
            [self.model setItemUrl:item url:trimField(self.textFieldUrl)];
        
            recordChanged = YES;
        }
    }
    else if(sender == self.textFieldPw) {
        if(![item.fields.password isEqualToString:trimField(self.textFieldPw)]) {
            [self.model setItemPassword:item password:trimField(self.textFieldPw)];
        
            recordChanged = YES;
        }
    }
    
    if(recordChanged) {
        item.fields.accessed = [[NSDate alloc] init];
        item.fields.modified = [[NSDate alloc] init];
    }
}

- (IBAction)onOutlineViewItemEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;

    NSString* newTitle = trimField(textField);
    if(![item.title isEqualToString:newTitle]) {
        if((item.isGroup && newTitle.length == 0) || ![self.model setItemTitle:item title:newTitle]) {
            [Alerts info:@"You cannot change the title of this item to this value." window:self.view.window];
        }
        
        [self reloadDataAndSelectItem:item];
         
        [self bindDetailsPane];
    }
    else {
        textField.stringValue = newTitle;
    }
}

NSString* trimField(NSTextField* textField) {
    return [Utils trim:textField.stringValue];
}

- (void)expandParentsOfItem:(Node*)item {
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    
    while (item.parent != nil) {
        item = item.parent;
        
        //NSLog(@"Got Parent == %@", i.title);
        
        [stack addObject:item];
    }
    
    while ([stack count]) {
        Node *group = [stack lastObject];
        
        //NSLog(@"Expanding %@", group.title);
        [self.outlineView expandItem:group];
        
        [stack removeObject:group];
    }
}

- (NSInteger)findRowForItemExpandIfNecessary:(id)item {
    NSInteger itemIndex = [self.outlineView rowForItem:item];
    
    if (itemIndex < 0) {
        [self expandParentsOfItem: item];
        
        itemIndex = [self.outlineView rowForItem:item];
        
        if (itemIndex < 0) {
            return itemIndex;
        }
    }
    
    return itemIndex;
}

- (void)reloadDataAndSelectItem:(Node*)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.outlineView reloadData];
        
        [self selectItem:item];
    });
}
                   
- (void)selectItem:(Node*)item {
    if(item) {
        NSInteger row = [self findRowForItemExpandIfNecessary:item];
        
        if(row >= 0) {
            [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        }
        else {
            NSLog(@"Could not find item row for selection to maintain");
        }
    }
}

- (void)enableDragDrop {
    [self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:kDragAndDropUti]];
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item {
    NSPasteboardItem *paste = [[NSPasteboardItem alloc] init];
    
    Node* it = ((Node*)item);
    
    NSLog(@"pasteboardWriterForItem %@ => [%@]", it.title, it.serializationId);
    
    [paste setString:it.serializationId forType:kDragAndDropUti];

    return paste;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index
{
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];

    Node* sourceItem = [self.model getItemFromSerializationId:itemId];
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;
    
    //NSLog(@"validate Move [%@] [%@] -> [%@]", itemId, sourceItem, destinationItem);
    
    BOOL valid = !destinationItem ||
                (destinationItem.isGroup && [self.model validateChangeParent:destinationItem node:sourceItem]);

    return valid ? NSDragOperationMove : NSDragOperationNone;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info
              item:(id)item
        childIndex:(NSInteger)index {
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];
    Node* sourceItem = [self.model getItemFromSerializationId:itemId];
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;
    
    NSLog(@"acceptDrop Move [%@] -> [%@]", sourceItem, destinationItem);
    
    if([self.model changeParent:destinationItem node:sourceItem]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.outlineView reloadData];
        });
        
        return YES;
    }
    
    return NO;
}

- (IBAction)onCreateRecord:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    Node *newItem = [self.model addNewRecord:parent];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.showPassword = YES;
            [self showOrHidePassword];
            [self.view.window makeFirstResponder:self.textFieldTitle];
        });
    }
}

- (IBAction)onCreateGroup:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    Node *newItem = [self.model addNewGroup:parent];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
            if ([cellView.textField acceptsFirstResponder]) {
                [cellView.window makeFirstResponder:cellView.textField];
            }
        });
    }
}

- (IBAction)onDelete:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(!item) {
        return;
    }
    
    [Alerts yesNo:@"Are you sure you want to delete this item?" window:self.view.window completion:^(BOOL yesNo) {
        if(yesNo) {
            [self.model deleteItem:item];
            
            [self.outlineView reloadData];
            
            [self bindDetailsPane];
        }
    }];
}

- (IBAction)onLaunchUrl:(id)sender {
    NSString *urlString = self.textFieldUrl.stringValue;
    
    if (!urlString.length) {
        return;
    }
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    Node* item = [self getCurrentSelectedItem];
    NSString *password = item.fields.password;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];

    [self onLaunchUrl:sender];
}

- (IBAction)onCopyDiagnosticDump:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *dump = [self.model getDiagnosticDumpString];
    
    [[NSPasteboard generalPasteboard] setString:dump forType:NSStringPboardType];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];
    
    Node* item = [self getCurrentSelectedItem];
    
    if (theAction == @selector(onDelete:)) {
        return item != nil;
    }
    else if(theAction == @selector(onCreateGroup:) ||
            theAction == @selector(onCreateRecord:)) {
        return self.model && !self.model.locked && self.searchField.stringValue.length == 0;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onCopyAsCsv:) ||
             theAction == @selector(onCopyDiagnosticDump:) ||
             theAction == @selector(onImportFromCsvFile:) ||
             theAction == @selector(onLock:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onFind:)) {
        return self.model && !self.model.locked &&
        ([Settings sharedInstance].fullVersion || [Settings sharedInstance].freeTrial);
    }
    else if(theAction == @selector(onLaunchUrl:) ||
            theAction == @selector(onCopyUrl:)) {
        return item && !item.isGroup && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyTitle:)) {
        return item && !item.isGroup && self.textFieldTitle.stringValue.length;
    }
    else if (theAction == @selector(onCopyUsername:)) {
        return item && !item.isGroup && self.comboboxUsername.stringValue.length;
    }
    else if (theAction == @selector(onCopyEmail:)) {
        return item && !item.isGroup && self.comboBoxEmail.stringValue.length;
    }
    else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
        return item && !item.isGroup && item.fields.password.length && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyPassword:)) {
        return item && !item.isGroup && item.fields.password.length;
    }
    else if (theAction == @selector(onCopyNotes:)) {
        return item && !item.isGroup && self.textViewNotes.textStorage.string.length;
    }
    else if (theAction == @selector(onClearTouchId:)) {
        SafeMetaData* metaData = [self getMetaDataForModel];
        return metaData != nil && BiometricIdHelper.sharedInstance.biometricIdAvailable;
    }
    
    return YES;
}

- (IBAction)onClearTouchId:(id)sender {
    SafeMetaData* metaData = [self getMetaDataForModel];
    
    if(metaData) {
        [SafesList.sharedInstance remove:metaData.uuid];
        [metaData removeTouchIdPassword];
        
        [self bindToModel];
    }
}

- (IBAction)onGenerate:(id)sender {
    //self.showPassword = YES;
    //[self showOrHidePassword];

    self.textFieldPw.stringValue = [self.model generatePassword];
    
    [self onDetailFieldChange:self.textFieldPw];
}

- (void)updateSafeSummaryFields {
    self.textFieldSafeSummaryPath.stringValue = self.model.fileUrl ? self.model.fileUrl.path : @"<Not Saved>";
    self.testFieldSafeSummaryUniqueUsernames.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.usernameSet.count];
    self.textFieldSafeSummaryUniquePasswords.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.passwordSet.count];
    self.textFieldSafeSummaryMostPopularUsername.stringValue = self.model.mostPopularUsername ? self.model.mostPopularUsername : @"<None>";
    self.textFieldSafeSummaryRecords.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.numberOfRecords];
    self.textFieldSafeSummaryGroups.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.numberOfGroups];
    self.textFieldSafeSummaryKeyStretchIterations.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.keyStretchIterations];
    self.textFieldSafeSummaryVersion.stringValue = self.model.version ? self.model.version : @"<Unknown>";
    
    self.textFieldSafeSummaryLastUpdateUser.stringValue = self.model.lastUpdateUser ? self.model.lastUpdateUser : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateHost.stringValue = self.model.lastUpdateHost ? self.model.lastUpdateHost : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateApp.stringValue = self.model.lastUpdateApp ? self.model.lastUpdateApp : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateTime.stringValue = [self formatDate:self.model.lastUpdateTime];
}

- (IBAction)onCopyAsCsv:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *newStr = [[NSString alloc] initWithData:[Utils getSafeAsCsv:self.model.rootGroup] encoding:NSUTF8StringEncoding];
    
    [[NSPasteboard generalPasteboard] setString:newStr forType:NSStringPboardType];
}

- (NSURL*)getFileThroughFileOpenDialog
{  
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    [panel setTitle:@"Choose CSV file to Import"];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setFloatingPanel:NO];
    [panel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
     panel.allowedFileTypes = @[@"csv"];

    NSInteger result = [panel runModal];
    if(result == NSModalResponseOK)
    {
        return [[panel URLs] firstObject];
    }
    
    return nil;
}

- (IBAction)onImportFromCsvFile:(id)sender {
    NSString* message = [NSString stringWithFormat:@"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.", kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderNotes];
   
    [Alerts info:@"CSV Format" informativeText:message window:self.view.window completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{[self importFromCsvFile];});
    }];
}

- (void)importFromCsvFile {
    NSURL* url = [self getFileThroughFileOpenDialog];
        
    if(url) {
        NSError *error = nil;
        NSArray *rows = [NSArray arrayWithContentsOfCSVURL:url options:CHCSVParserOptionsSanitizesFields | CHCSVParserOptionsUsesFirstLineAsKeys];
        
        if (rows == nil) {
            //something went wrong; log the error and exit
            NSLog(@"error parsing file: %@", error);
            [Alerts error:error window:self.view.window];
            return;
        }
        else if(rows.count == 0){
            [Alerts info:@"CSV File Contains Zero Rows. Cannot Import." window:self.view.window];
        }
        else {
            CHCSVOrderedDictionary *firstRow = [rows firstObject];
            
            if([firstRow objectForKey:kCSVHeaderTitle] ||
               [firstRow objectForKey:kCSVHeaderUsername] ||
               [firstRow objectForKey:kCSVHeaderUrl] ||
               [firstRow objectForKey:kCSVHeaderEmail] ||
               [firstRow objectForKey:kCSVHeaderPassword] ||
               [firstRow objectForKey:kCSVHeaderNotes]) {
                NSString* message = [NSString stringWithFormat:@"Found %lu valid rows in CSV file. Are you sure you would like to import now?", (unsigned long)rows.count];
                
                [Alerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                    if(yesNo) {
                        [self.model importRecordsFromCsvRows:rows];
                        
                        [Alerts info:@"CSV File Successfully Imported." window:self.view.window];
                        
                        [self bindToModel];
                    }
                }];
            }
            else {
                [Alerts info:@"No valid rows found. Ensure CSV file contains a header row and at least one of the required fields." window:self.view.window];
            }
        }
    }
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) {
        return @"<Unknown>";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

- (IBAction)onPasswordPreferences:(id)sender {
    [PreferencesWindowController.sharedInstance showOnTab:1];
}

- (void)onPreferencesChanged:(NSNotification*)notification {
    //NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");
    
    [self refreshViewAndMaintainSelection];
}

- (void)refreshViewAndMaintainSelection {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    [self bindToModel];
    
    [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: selectedRow] byExtendingSelection: NO];
}

static NSComparator finderStringComparator = ^(id obj1, id obj2)
{
    return [Utils finderStringCompare:obj1 string2:obj2];
};

@end
