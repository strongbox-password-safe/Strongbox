//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "MacAlerts.h"
#import "CreateFormatAndSetCredentialsWizard.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "CHCSVParser.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "DatabasesManager.h"
#import "BiometricIdHelper.h"
#import "PreferencesWindowController.h"
#import "Csv.h"
#import "AttachmentItem.h"
#import "CustomField.h"
#import "Entry.h"
#import "KeyFileParser.h"
#import "ProgressWindow.h"
#import "SelectPredefinedIconController.h"
#import "MacKeePassHistoryViewController.h"
#import "NodeIconHelper.h"
#import "OTPToken+Generation.h"
#import "MBProgressHUD.h"
#import "CustomFieldTableCellView.h"
#import "SearchScope.h"
#import <WebKit/WebKit.h>
#import "FavIconDownloader.h"
#import "FavIconManager.h"
#import "NodeDetailsViewController.h"
#import "DocumentController.h"
#import "ClipboardManager.h"
#import "BookmarksHelper.h"
#import "DatabaseSettingsTabViewController.h"
#import "MacYubiKeyManager.h"
#import "ColoredStringHelper.h"
#import "NSString+Extensions.h"
#import "FileManager.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"
#import "NSDate+Extensions.h"
#import "DatabaseOnboardingTabViewController.h"
#import "DatabasesManagerVC.h"
#import "AutoFillManager.h"
#import "MMWormhole.h"
#import "AutoFillWormhole.h"
#import "QuickTypeRecordIdentifier.h"
#import "SecretStore.h"
#import "OutlineView.h"
#import "Document.h"
#import "SyncAndMergeSequenceManager.h"
#import "PasswordStrengthTester.h"
#import "StrongboxErrorCodes.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif





static const CGFloat kExpiredOutlineViewCellAlpha = 0.35f;

static NSString* const kPasswordCellIdentifier = @"CustomFieldValueCellIdentifier";
static NSString* const kDefaultNewTitle = @"Untitled";

static NSString* const kItemKey = @"item";
static NSString* const kNewEntryKey = @"newEntry";

@interface ViewController () <  NSWindowDelegate,
                                NSTextFieldDelegate,
                                QLPreviewPanelDataSource,
                                QLPreviewPanelDelegate,
                                NSSearchFieldDelegate,
                                NSOutlineViewDelegate,
                                NSOutlineViewDataSource,
                                NSTableViewDelegate,
                                NSTableViewDataSource>

@property (strong, nonatomic) SelectPredefinedIconController* selectPredefinedIconController;
@property (strong, nonatomic) CreateFormatAndSetCredentialsWizard *changeMasterPassword;
@property (nonatomic) BOOL showPassword;

@property NSMutableDictionary<NSUUID*, NSArray<Node*>*> *itemsCache;

@property NSTimer* timerRefreshOtp;
@property NSFont* italicFont;
@property NSFont* regularFont;

@property (weak) IBOutlet NSButton *buttonToggleRevealMasterPasswordTip;
@property (weak) IBOutlet NSTextField *labelTitle;
@property (weak) IBOutlet NSTextField *labelUsername;
@property (weak) IBOutlet NSTextField *labelEmail;
@property (weak) IBOutlet NSTextField *labelPassword;
@property (weak) IBOutlet NSTextField *labelUrl;
@property (weak) IBOutlet NSTextField *labelHiddenPassword;
@property (weak) IBOutlet ClickableImageView *imageViewTogglePassword;
@property (weak) IBOutlet NSView *totpRow;
@property (weak) IBOutlet NSTabView *quickViewColumn;
@property (weak) IBOutlet NSButton *buttonToggleQuickViewPanel;
@property (weak) IBOutlet ClickableImageView *imageViewGroupDetails;
@property (weak) IBOutlet NSTableView *tableViewSummary;
@property (weak) IBOutlet OutlineView *outlineView;
@property (weak) IBOutlet NSTabView *tabViewLockUnlock;
@property (weak) IBOutlet NSTabView *tabViewRightPane;
@property (weak) IBOutlet NSButton *buttonCreateGroup;
@property (weak) IBOutlet NSButton *buttonCreateRecord;
@property (weak) IBOutlet NSView *emailRow;
@property (weak) IBOutlet KSPasswordField *textFieldMasterPassword;
@property (weak) IBOutlet NSSegmentedControl *searchSegmentedControl;
@property (weak) IBOutlet NSSearchField *searchField;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet NSButton *buttonUnlockWithPassword;



@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;
@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;
@property (weak) IBOutlet NSTextField *textFieldTotp;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;
@property (strong) IBOutlet NSMenu *outlineHeaderColumnsMenu;
@property (weak) IBOutlet NSView *customFieldsRow;
@property (weak) IBOutlet NSTableView *customFieldsTable;
@property (weak) IBOutlet NSImageView *imageViewIcon;
@property (weak) IBOutlet NSView *containerViewForEnterMasterCredentials;
@property (weak) IBOutlet NSView *attachmentsRow;
@property (weak) IBOutlet NSTableView *attachmentsTable;
@property NSDictionary<NSString*, NSImage*> *attachmentsIconCache;
@property (weak) IBOutlet NSView *expiresRow;
@property (weak) IBOutlet NSTextField *labelExpires;

@property (weak) IBOutlet NSStackView *stackViewUnlock;
@property (weak) IBOutlet NSStackView *stackViewMasterPasswordHeader;
@property (weak) IBOutlet NSTextField *labelUnlockKeyFileHeader;
@property (weak) IBOutlet NSTextField *labelUnlockYubiKeyHeader;
@property (weak) IBOutlet NSButton *checkboxShowAdvanced;
@property (weak) IBOutlet NSImageView *unlockImageViewLogo;



@property NSArray<NSString*>* sortedAttachmentsFilenames;
@property NSDictionary<NSString*, DatabaseAttachment*>* attachments;

@property BOOL isPromptingAboutUnderlyingFileChange;
@property NSArray* customFields;
@property NSMutableDictionary<NSUUID*, NodeDetailsViewController*>* detailsViewControllers;






@property NSDate* lastAutoPromptForTouchIdThrottle; 

@property (weak) IBOutlet NSPopUpButton *keyFilePopup;
@property NSString* selectedKeyFileBookmark;

@property (weak) IBOutlet NSTextField *labelYubiKey;
@property (weak) IBOutlet NSPopUpButton *yubiKeyPopup;
@property (weak) IBOutlet NSButton *checkboxAllowEmpty;
@property (weak) IBOutlet NSButton *upgradeButton;

@property YubiKeyConfiguration *selectedYubiKeyConfiguration;

@property BOOL currentYubiKeySlot1IsBlocking;
@property BOOL currentYubiKeySlot2IsBlocking;
@property NSString* currentYubiKeySerial;
@property MMWormhole* wormhole;

@property Document*_Nullable document;
@property (readonly) ViewModel*_Nullable viewModel;
@property (readonly) DatabaseMetadata*_Nullable databaseMetadata;

@property BOOL hasLoaded;

@property ProgressWindow* progressWindow;
@property (weak) IBOutlet NSTextField *textFieldVersion;

@property (weak) IBOutlet NSTextField *labelStrength;
@property (weak) IBOutlet NSProgressIndicator *progressStrength;

@end

static NSImage* kStrongBox256Image;

@implementation ViewController

+ (void)initialize {
    if(self == [ViewController class]) {
        kStrongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
    }
}

- (ViewModel *)viewModel {
    return self.document.viewModel;
}

- (DatabaseMetadata*)databaseMetadata {
    return self.viewModel.databaseMetadata;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    
    self.detailsViewControllers = @{}.mutableCopy;
    
    [self enableDragDrop];
}

- (void)onDocumentLoaded { 


    [self load];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    


    [self load];
}

- (void)viewDidAppear {
    [super viewDidAppear];
        
    [self.view.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];

    [self initializeFullOrTrialOrLiteUI];
    [self setInitialFocus];
    [self startRefreshOtpTimer];
}

- (void)load {
    if(self.hasLoaded) {
        return;
    }
    
    self.hasLoaded = YES;
    _document = self.view.window.windowController.document;
    self.view.window.delegate = self;

    [self customizeUi];

    NSLog(@"ViewController::load - Initial Load - doc=[%@] - vm=[%@]", self.document, self.viewModel);

    [self fullModelReload];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoPromptForTouchIdIfDesired];
    });
    
    [self listenToEventsOfInterest];
    
    [self listenToAutoFillWormhole];
}

- (void)listenToEventsOfInterest {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAutoLock:) name:kAutoLockTime object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];







    NSString* notificationName = [NSString stringWithFormat:@"%@.%@", @"com.apple", @"screenIsLocked"];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(onScreenLocked) name:notificationName object:nil];
}

- (void)onScreenLocked {
    if ( self.viewModel.lockOnScreenLock ) {
        NSLog(@"onScreenLocked: Locking Database");
        [self onLock:nil];
    }
}

- (void)fullModelReload { 

    
    [self stopObservingModelChanges];
    [self closeAllDetailsWindows:nil];
    [self bindToModel];
    [self.view.window.windowController synchronizeWindowTitleWithDocumentName]; 
    [self setInitialFocus];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {


    if(self.viewModel && self.viewModel.locked) {
        [self bindLockScreenUi];
    }

    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoPromptForTouchIdIfDesired];
    });
}

- (void)windowWillClose:(NSNotification *)notification {
    if ( notification.object == self.view.window) {

        [self cleanupOnClose];
    }
}








- (void)cleanupOnClose {

    
    [self stopRefreshOtpTimer];
    [self closeAllDetailsWindows:nil];
    [self cleanupWormhole];
}

- (void)closeAllDetailsWindows:(void (^)(void))completion {
    if (self.detailsViewControllers.count == 0) {
        if(completion) {
            completion();
        }
        return;
    }
    
    NSArray<NodeDetailsViewController*>* vcs = [self.detailsViewControllers.allValues copy];
    [self.detailsViewControllers removeAllObjects];

    

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{

        dispatch_group_t group = dispatch_group_create();

        for (NodeDetailsViewController *vc in vcs) {
            dispatch_group_enter(group);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [vc closeWithCompletion:^{
                    dispatch_group_leave(group);
                }];
            });
        }

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        if(completion) {
            completion();
        }
    });
}

- (IBAction)onViewItemDetails:(id)sender {
    [self showItemDetails];
}

- (void)showItemDetails {
    Node* item = [self getCurrentSelectedItem];
    [self openItemDetails:item newEntry:NO];
}

- (void)openItemDetails:(Node*)item newEntry:(BOOL)newEntry {
    if(!item) {
        return;
    }
    
    if (item.isGroup) {

    }
    else {
        NodeDetailsViewController* vc = self.detailsViewControllers[item.uuid];
        
        if(vc) {
            NSLog(@"Details window already exists... Activating... [%@]", item.title);
            [vc.view.window makeKeyAndOrderFront:nil];
        }
        else {
            [self performSegueWithIdentifier:@"segueToShowItemDetails" sender:@{ kItemKey : item, kNewEntryKey : @(newEntry)}];
        }
    }
}

- (void)showGroupDetails {
    if (@available(macOS 10.15, *)) {
        NSViewController *vc = [SwiftUIViewFactory makeSwiftUIViewWithDismissHandler:^{
            NSLog(@"Dismiss");
        }];
        
        [self presentViewControllerAsSheet:vc];
    } else {
        
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToShowItemDetails"]) {
        NSDictionary<NSString*, id> *params = sender;
        Node* item = params[kItemKey];

        NSNumber* newEntry = params[kNewEntryKey];
        
        NSWindowController *wc = segue.destinationController;
        NodeDetailsViewController* vc = (NodeDetailsViewController*)(wc.contentViewController);
        
        vc.node = item;
        vc.model = self.viewModel;
        vc.newEntry = newEntry.boolValue;
        
        vc.onClosed = ^{
            NSLog(@"Removing Details View from List: [%@]", item.title);
            [self.detailsViewControllers removeObjectForKey:item.uuid];
        };
                
        NSLog(@"Adding Details View to List: [%@]", item.title);
        
        self.detailsViewControllers[item.uuid] = vc;
    }
    else if([segue.identifier isEqualToString:@"segueToItemHistory"]) {
        NSDictionary<NSString*, id> *params = sender;
        Node* item = params[kItemKey];

        MacKeePassHistoryViewController* vc = (MacKeePassHistoryViewController*)segue.destinationController;
        
        vc.onDeleteHistoryItem = ^(Node * _Nonnull node) {
            [self.viewModel deleteHistoryItem:item historicalItem:node];
        };
        vc.onRestoreHistoryItem = ^(Node * _Nonnull node) {
            [self.viewModel restoreHistoryItem:item historicalItem:node];
        };
        
        vc.model = self.viewModel;
        vc.history = item.fields.keePassHistory;
    }
    else if([segue.identifier isEqualToString:@"segueToDatabasePreferences"]) {
        DatabaseSettingsTabViewController *vc = (DatabaseSettingsTabViewController*)segue.destinationController;
        
        NSNumber* tab = (NSNumber*)sender;
        [vc setModel:self.viewModel initialTab:tab.intValue];
    }
    else if ([segue.identifier isEqualToString:@"segueToDatabaseOnboarding"]) {
        DatabaseOnboardingTabViewController *vc = (DatabaseOnboardingTabViewController*)segue.destinationController;
        
        NSDictionary<NSString*, id>* foo = sender;
        
        vc.convenienceUnlock = ((NSNumber*)foo[@"convenienceUnlock"]).boolValue;
        vc.autoFill = ((NSNumber*)foo[@"autoFill"]).boolValue;
        vc.ckfs = foo[@"compositeKeyFactors"];
        vc.databaseUuid = self.databaseMetadata.uuid;
        vc.model = foo[@"model"];
    }
    else if ( [segue.identifier isEqualToString:@"segueToFavIconDownloader"] ) {
        Node* item = sender;
        NSArray* items = item ? (item.isGroup ? item.allChildRecords : @[item]) : self.viewModel.activeRecords;
        
        FavIconDownloader *vc = segue.destinationController;
        vc.nodes = items;
        vc.viewModel = self.viewModel;

        vc.onDone = ^(BOOL go, NSDictionary<NSUUID *,NSImage *> * _Nullable selectedFavIcons) {
            if(go) {
                [self.viewModel batchSetIcons:selectedFavIcons];
            }
        };
    }
}

- (void)bindShowAdvancedOnUnlockScreen {
    BOOL show = self.viewModel.showAdvancedUnlockOptions;
    
    self.checkboxShowAdvanced.state = show ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.checkboxAllowEmpty.hidden = !show;
    self.labelUnlockKeyFileHeader.hidden = !show;
    self.keyFilePopup.hidden = !show;
    self.labelUnlockYubiKeyHeader.hidden = !show;
    self.yubiKeyPopup.hidden = !show;
}

- (IBAction)onShowAdvancedOnUnlockScreen:(id)sender {
    self.viewModel.showAdvancedUnlockOptions = !self.viewModel.showAdvancedUnlockOptions;
    
    [self bindShowAdvancedOnUnlockScreen];
}

- (void)customizeLockStackViewSpacing {
    [self.stackViewUnlock setCustomSpacing:3 afterView:self.stackViewMasterPasswordHeader];
    [self.stackViewUnlock setCustomSpacing:4 afterView:self.labelUnlockKeyFileHeader];
    [self.stackViewUnlock setCustomSpacing:4 afterView:self.labelUnlockYubiKeyHeader];
}

- (void)customizeUi {
    NSString* fmt2 = Settings.sharedInstance.fullVersion ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt2, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;
    
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
    
    [self customizeLockStackViewSpacing];
    
    [self bindShowAdvancedOnUnlockScreen];
            
    NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    self.buttonUnlockWithTouchId.hidden = YES;
    
    self.imageViewTogglePassword.clickable = YES;
    self.imageViewTogglePassword.onClick = ^{
        [self onToggleShowHideQuickViewPassword:nil];
    };
    [self bindRevealMasterPasswordTextField];
    
    self.textFieldMasterPassword.delegate = self;
    
    self.showPassword = Settings.sharedInstance.alwaysShowPassword;

    self.tableViewSummary.dataSource = self;
    self.tableViewSummary.delegate = self;
    
    [self.customFieldsTable registerNib:[[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil] forIdentifier:@"CustomFieldValueCellIdentifier"];
    self.customFieldsTable.delegate = self;
    self.customFieldsTable.dataSource = self;
    self.customFieldsTable.doubleAction = @selector(onDoubleClickCustomField:);
   
    self.attachmentsTable.delegate = self;
    self.attachmentsTable.dataSource = self;
    self.attachmentsTable.doubleAction = @selector(onPreviewQuickViewAttachment:);
    
    [self customizeOutlineView];
    
    self.quickViewColumn.hidden = !self.viewModel.showQuickView;
    [self bindQuickViewButton];
    
    
    
    NSString* loc = NSLocalizedString(@"mac_search_placeholder", @"Search (⌘F)");
    [self.searchField setPlaceholderString:loc];
    self.searchField.enabled = YES;
    self.searchField.delegate = self;
    self.searchSegmentedControl.enabled = YES;
}

- (void)customizeOutlineView {
    
    
    
    NSNib* nib = [[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil];
    [self.outlineView registerNib:nib forIdentifier:kPasswordCellIdentifier];

    self.outlineView.usesAlternatingRowBackgroundColors = self.viewModel.showAlternatingRows;
    self.outlineView.gridStyleMask = (self.viewModel.showVerticalGrid ? NSTableViewSolidVerticalGridLineMask : 0) | (self.viewModel.showHorizontalGrid ? NSTableViewSolidHorizontalGridLineMask : 0);
    
    self.outlineView.headerView.menu = self.outlineHeaderColumnsMenu;
    self.outlineView.autosaveTableColumns = YES;
    
    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    
    __weak ViewController* weakSelf = self;
    self.outlineView.onEnterKey = ^{
        [weakSelf outlineViewOnEnterKey];
    };
    
    self.outlineView.onDeleteKey = ^{
        [weakSelf outlineViewOnDeleteKey];
    };
    
    [self bindColumnsToSettings];
}

- (void)bindColumnsToSettings {
    NSArray<NSString*>* visible = self.viewModel.visibleColumns;
    
    
    
    for (NSString* column in [Settings kAllColumns]) {
        [self showHideOutlineViewColumn:column show:[visible containsObject:column] && [self isColumnAvailableForModel:column]];
    }
    
    
    
    int i=0;
    for (NSString* column in visible) {
        NSInteger colIdx = [self.outlineView columnWithIdentifier:column];
        if(colIdx != -1) { 
            NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
            
            if(!col.hidden) { 
                [self.outlineView moveColumn:colIdx toColumn:i++];
            }
        }
    }
    

}

- (IBAction)onOutlineHeaderColumnsChanged:(id)sender {
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    
    
    
    NSMutableArray<NSString*>* newColumns = [self.viewModel.visibleColumns mutableCopy];
    
    if(menuItem.state == NSOnState) 
    {
        [newColumns removeObject:menuItem.identifier];
        self.viewModel.visibleColumns = newColumns;
        [self showHideOutlineViewColumn:menuItem.identifier show:NO];
        [self.outlineView reloadData];
    }
    else { 
        if(![newColumns containsObject:menuItem.identifier]) { 
            [newColumns addObject:menuItem.identifier];
            self.viewModel.visibleColumns = newColumns;
        }
        [self showHideOutlineViewColumn:menuItem.identifier show:[self isColumnAvailableForModel:menuItem.identifier]];
        [self.outlineView reloadData];
    }
}

- (void)showHideOutlineViewColumn:(NSString*)identifier show:(BOOL)show {
    NSInteger colIdx = [self.outlineView columnWithIdentifier:identifier];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    
    
    if(col.hidden != !show) {
        col.hidden = !show;
    }
}

- (BOOL)isColumnAvailableForModel:(NSString*)identifier {
    if(!self.viewModel) {
        return NO;
    }
    
    BOOL ret;
    if (self.viewModel.format == kPasswordSafe) {
        ret = (![identifier isEqualToString:kCustomFieldsColumn] && ![identifier isEqualToString:kAttachmentsColumn]);
    }
    else {
        ret = ![identifier isEqualToString:kEmailColumn];
    }
    
    
    
    return ret;
}

- (BOOL)isColumnVisible:(NSString*)identifier {
    return [self.viewModel.visibleColumns containsObject:identifier];
}

- (void)initializeFullOrTrialOrLiteUI {
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial) {

    }
    else {

    }
}



- (NSImage * )getIconForNode:(Node *)vm large:(BOOL)large {
    return [NodeIconHelper getIconForNode:vm predefinedIconSet:kKeePassIconSetClassic format:self.viewModel.format large:large];
}

- (void)onDeleteHistoryItem:(Node*)node historicalItem:(Node*)historicalItem {
    
    NSLog(@"Deleted History Item... no need to update UI");
}

- (void)onRestoreHistoryItem:(Node*)node historicalItem:(Node*)historicalItem {
    self.itemsCache = nil; 
    Node* selectionToMaintain = [self getCurrentSelectedItem];
    [self.outlineView reloadData]; 
    NSInteger row = [self.outlineView rowForItem:selectionToMaintain];
    
    if(row != -1) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        
    }
}

- (void)onItemsDeletedNotification:(NSNotification*)param {
    if(param.object != self.viewModel) {
        return;
    }
    
    NSArray<Node*>* deletedItems = param.userInfo[kNotificationUserInfoKeyNode];
    if (deletedItems) {
        NSArray<NSUUID*> *ids = [deletedItems map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }];
        NSSet<NSUUID*>* idSet = [NSSet setWithArray:ids];
        NSArray<NSUUID*> *idsToClose = [self.detailsViewControllers.allKeys filter:^BOOL(NSUUID * _Nonnull obj) {
            return [idSet containsObject:obj];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            for (NSUUID* idToClose in idsToClose) {
                NodeDetailsViewController* vc = self.detailsViewControllers[idToClose];
                [vc closeWithCompletion:^{}];
            }
        });
    }
    
    self.itemsCache = nil; 
    [self.outlineView reloadData]; 
    [self bindDetailsPane];
}

- (void)onItemsUnDeletedNotification:(NSNotification*)param {
    if(param.object != self.viewModel) {
        return;
    }

    self.itemsCache = nil; 
    [self.outlineView reloadData]; 
    [self bindDetailsPane];
}

- (void)onItemsMovedNotification:(NSNotification*)param {
    if(param.object != self.viewModel) {
        return;
    }

    self.itemsCache = nil; 
    [self.outlineView reloadData];
    [self bindDetailsPane];
}



- (void)onItemIconChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_icon", @"Icon");
    
    NSNumber* foo = (NSNumber*)notification.userInfo[kNotificationUserInfoKeyIsBatchIconUpdate];
    
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc suppressPopupMessage:foo == nil || foo.boolValue == YES];
}

- (void)onItemTitleChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_title", @"Title");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onItemPasswordChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_password", @"Password");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onItemUsernameChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_username", @"Username");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onItemExpiryDateChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_expiry_date", @"Expiry Date");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onItemEmailChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_email", @"Email");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onItemUrlChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_url", @"URL");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];

    if(notification.object != self.viewModel) {
        return;
    }
    
    Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];
    [self expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:node];
}

- (void)expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:(Node*)node {
    NSURL* url = node.fields.url.urlExtendedParse;
        
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    if( url && featureAvailable && self.viewModel.downloadFavIconOnChange ) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
            [FavIconManager.sharedInstance downloadPreferred:url
                                                     options:FavIconDownloadOptions.express
                                                  completion:^(IMAGE_TYPE_PTR  _Nullable image) {
                    NSLog(@"Got FavIcon on Change URL or New Entry: [%@]", image);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(image) {
                            [self.viewModel setItemIcon:node image:image];
                        }
                    });
            }];
        });
    }
}

- (void)onItemNotesChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_notes", @"Notes");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onCustomFieldsChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_custom_fields", @"Custom Fields");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onTotpChanged:(NSNotification*)notification {
    NSString *loc = NSLocalizedString(@"generic_fieldname_totp", @"TOTP");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)onAttachmentsChanged:(NSNotification*)notification {
    self.attachmentsIconCache = nil;
    
    NSString *loc = NSLocalizedString(@"generic_fieldname_attachments", @"Attachments");
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:loc];
}

- (void)genericReloadOnUpdateAndMaintainSelection:(NSNotification*)notification popupMessage:(NSString*)popupMessage {
    [self genericReloadOnUpdateAndMaintainSelection:notification popupMessage:popupMessage suppressPopupMessage:NO];
}

- (void)genericReloadOnUpdateAndMaintainSelection:(NSNotification*)notification popupMessage:(NSString*)popupMessage suppressPopupMessage:(BOOL)suppressPopupMessage {
    if(notification.object != self.viewModel) {
        return;
    }
    
    self.itemsCache = nil; 
    
    Node* selectionToMaintain = [self getCurrentSelectedItem];
    [self.outlineView reloadData]; 
    
    if(selectionToMaintain) {
        NSInteger row = [self.outlineView rowForItem:selectionToMaintain];
        if(row != -1) {
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    
    if(!suppressPopupMessage) {
        Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];

        NSString *loc = NSLocalizedString(@"mac_field_changed_popup_notification_fmt", @"'%@' %@ Changed... First parameter Title of Item, second parameter which field changed, e.g. Username or Password");
        [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, node.title, popupMessage]];
    }
}



- (void)bindToModel {
    [self stopObservingModelChanges];
    [self closeAllDetailsWindows:nil];
    
    self.itemsCache = nil; 
    
    if(self.viewModel == nil || self.viewModel.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
        
        self.selectedKeyFileBookmark = self.viewModel ? self.databaseMetadata.keyFileBookmark : nil;
        self.selectedYubiKeyConfiguration = self.viewModel ? self.databaseMetadata.yubiKeyConfiguration : nil;
        
        [self bindLockScreenUi];
    }
    else {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
        
        [self bindColumnsToSettings];
        [self.outlineView reloadData];
        
        Node* selectedItem = [self.viewModel getItemFromSerializationId:self.viewModel.selectedItem];
        [self selectItem:selectedItem];
        
        self.buttonCreateGroup.enabled = !self.viewModel.isEffectivelyReadOnly;
        self.buttonCreateRecord.enabled = !self.viewModel.isEffectivelyReadOnly;
        
        [self bindDetailsPane];
        
        if ( self.viewModel.startWithSearch ) {
            [self.view.window makeFirstResponder:self.searchField];
        }
        else {
            [self.view.window makeFirstResponder:self.outlineView];
        }
    }
    
    [self startObservingModelChanges];
}

- (void)stopObservingModelChanges {


    if(self.viewModel) {
        self.viewModel.onNewItemAdded = nil;
        self.viewModel.onDeleteHistoryItem = nil;
        self.viewModel.onRestoreHistoryItem = nil;
    }

    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationItemsMoved object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationItemsUnDeleted object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationItemsDeleted object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationCustomFieldsChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationTitleChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationUsernameChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationExpiryChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationUrlChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationEmailChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationNotesChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationPasswordChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationIconChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationAttachmentsChanged object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationTotpChanged object:nil];
    
    
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationLongRunningOperationStart object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationLongRunningOperationDone object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationFullReload object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationDatabaseChangedByOther object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kModelUpdateNotificationSyncDone object:nil];
}

- (void)startObservingModelChanges {

    
    __weak ViewController* weakSelf = self;
    
    if ( self.viewModel ) { 
        self.viewModel.onNewItemAdded = ^(Node * _Nonnull node, BOOL openEntryDetailsWindowWhenDone) {
            [weakSelf onNewItemAdded:node openEntryDetailsWindowWhenDone:openEntryDetailsWindowWhenDone];
        };
        self.viewModel.onDeleteHistoryItem = ^(Node * _Nonnull item, Node * _Nonnull historicalItem) {
            [weakSelf onDeleteHistoryItem:item historicalItem:historicalItem];
        };
        self.viewModel.onRestoreHistoryItem = ^(Node * _Nonnull item, Node * _Nonnull historicalItem) {
            [weakSelf onRestoreHistoryItem:item historicalItem:historicalItem];
        };
    }
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onCustomFieldsChanged:) name:kModelUpdateNotificationCustomFieldsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemTitleChanged:) name: kModelUpdateNotificationTitleChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemUsernameChanged:) name: kModelUpdateNotificationUsernameChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemUrlChanged:) name: kModelUpdateNotificationUrlChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemEmailChanged:) name: kModelUpdateNotificationEmailChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemExpiryDateChanged:) name: kModelUpdateNotificationExpiryChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemNotesChanged:) name: kModelUpdateNotificationNotesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemPasswordChanged:) name:kModelUpdateNotificationPasswordChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemIconChanged:) name:kModelUpdateNotificationIconChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onAttachmentsChanged:) name:kModelUpdateNotificationAttachmentsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onTotpChanged:) name:kModelUpdateNotificationTotpChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemsDeletedNotification:) name:kModelUpdateNotificationItemsDeleted object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemsUnDeletedNotification:) name:kModelUpdateNotificationItemsUnDeleted object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onItemsMovedNotification:) name:kModelUpdateNotificationItemsMoved object:nil];
    
    
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onModelLongRunningOpStart:) name:kModelUpdateNotificationLongRunningOperationStart object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onModelLongRunningOpDone:) name:kModelUpdateNotificationLongRunningOperationDone object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onFullModelReloadNotification:) name:kModelUpdateNotificationFullReload object:nil];    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onFileChangedByOtherApplication:) name:kModelUpdateNotificationDatabaseChangedByOther object:nil];
    [NSNotificationCenter.defaultCenter addObserver:weakSelf selector:@selector(onSyncDone:) name:kModelUpdateNotificationSyncDone object:nil];
}

- (void)setInitialFocus {
    if(self.viewModel == nil || self.viewModel.locked) {
        if([self convenienceUnlockIsPossible]) {
            [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
        }
        else {
            [self.textFieldMasterPassword becomeFirstResponder];
        }
    }
}

- (void)bindDetailsPane {
    Node* it = [self getCurrentSelectedItem];
    
    if(!it) {
        [self.tabViewRightPane selectTabViewItemAtIndex:2];
        [self.tableViewSummary reloadData];
    }
    else if (it.isGroup) {
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        self.imageViewGroupDetails.image = [self getIconForNode:it large:YES];
        self.imageViewGroupDetails.clickable = self.viewModel.format != kPasswordSafe;
        self.imageViewGroupDetails.showClickableBorder = YES;
        self.imageViewGroupDetails.onClick = ^{ [self onEditNodeIcon:it]; };

        self.textFieldSummaryTitle.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInQuickView];;
    }
    else {
        [self.tabViewRightPane selectTabViewItemAtIndex:0];
        self.emailRow.hidden = self.viewModel.format != kPasswordSafe;
        
        self.imageViewIcon.image = [self getIconForNode:it large:YES];
        self.imageViewIcon.hidden = self.viewModel.format == kPasswordSafe;

        
        self.labelTitle.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        
        NSString* pw = [self maybeDereference:it.fields.password node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        
        BOOL colorize = Settings.sharedInstance.colorizePasswords;
        
        NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
        BOOL dark = ([osxMode isEqualToString:@"Dark"]);
        BOOL colorBlind = Settings.sharedInstance.colorizeUseColorBlindPalette;
        
        self.labelPassword.attributedStringValue = [ColoredStringHelper getColorizedAttributedString:pw
                                                                                            colorize:colorize
                                                                                            darkMode:dark
                                                                                          colorBlind:colorBlind
                                                                                                font:self.labelPassword.font];
        
        [self bindPasswordStrength:pw];
        
        self.labelUrl.stringValue = [self maybeDereference:it.fields.url node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelUsername.stringValue = [self maybeDereference:it.fields.username node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelEmail.stringValue = it.fields.email;
        self.textViewNotes.string = [self maybeDereference:it.fields.notes node:it maybe:Settings.sharedInstance.dereferenceInQuickView];

        
        
        [self.textViewNotes setEditable:YES];
        [self.textViewNotes checkTextInDocument:nil];
        [self.textViewNotes setEditable:NO];
        
        self.imageViewTogglePassword.hidden = (self.labelPassword.stringValue.length == 0 && !self.viewModel.concealEmptyProtectedFields);
        self.showPassword = Settings.sharedInstance.alwaysShowPassword || (self.labelPassword.stringValue.length == 0 && !self.viewModel.concealEmptyProtectedFields);
        [self showOrHideQuickViewPassword];
        
        
        
        self.expiresRow.hidden = it.fields.expires == nil;
        self.labelExpires.stringValue = it.fields.expires ? it.fields.expires.friendlyDateTimeString : @"";
        self.labelExpires.textColor = it.expired ? NSColor.redColor : it.nearlyExpired ? NSColor.orangeColor : nil;
        
        

        [self refreshOtpCode:nil];
        
        
        
        NSArray* sortedKeys = [it.fields.customFields.allKeys sortedArrayUsingComparator:finderStringComparator];
        
        self.customFields = [sortedKeys map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            CustomField* field = [[CustomField alloc] init];
            StringValue* value = it.fields.customFields[obj];
            
            field.key = obj;
            field.value = value.value;
            field.protected = value.protected;
            
            return field;
        }];
        
        self.customFieldsRow.hidden = self.viewModel.format == kPasswordSafe || self.customFields.count == 0 || !Settings.sharedInstance.showCustomFieldsOnQuickViewPanel;
        [self.customFieldsTable reloadData];
        
        
        
        self.sortedAttachmentsFilenames = [it.fields.attachments.allKeys sortedArrayUsingComparator:finderStringComparator];
        self.attachments = it.fields.attachments.copy;
        
        self.attachmentsRow.hidden = self.viewModel.format == kPasswordSafe || self.sortedAttachmentsFilenames.count == 0 || !Settings.sharedInstance.showAttachmentsOnQuickViewPanel;
        [self.attachmentsTable reloadData];
    }
}

- (NSString*)maybeDereference:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self.viewModel dereference:text node:node] : text;
}

- (void)startRefreshOtpTimer {
    if(self.timerRefreshOtp == nil) {
        self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(refreshOtpCode:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
    }
}

- (void)stopRefreshOtpTimer {
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.viewModel || self.viewModel.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<Node*> *items = [self getItems:self.viewModel.rootGroup];
        
        return items.count > 0;
    }
    else {
        Node *it = (Node*)item;
        
        if(it.isGroup) {
            NSArray<Node*> *items = [self getItems:it];
            
            return items.count > 0;
        }
        else {
            return NO;
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if(!self.viewModel || self.viewModel.locked) {
        return 0;
    }
    
    Node* group = (item == nil) ? self.viewModel.rootGroup : ((Node*)item);
    NSArray<Node*> *items = [self getItems:group];
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    Node* group = (item == nil) ? self.viewModel.rootGroup : ((Node*)item);
    NSArray<Node*> *items = [self getItems:group];
    return items.count == 0 ? nil : items[index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
    Node *it = (Node*)item;
    
    if ( it.isGroup ) {
        if([tableColumn.identifier isEqualToString:kTitleColumn]) {
            return [self getTitleCell:it];
        }
        else {
            return [self getReadOnlyCell:@"" node:it];
        }
    }
    
    if([tableColumn.identifier isEqualToString:kTitleColumn]) {
        return [self getTitleCell:it];
    }
    else if([tableColumn.identifier isEqualToString:kUsernameColumn]) {
        return [self getEditableCell:it.fields.username node:it selector:@selector(onOutlineViewItemUsernameEdited:)];
    }
    else if([tableColumn.identifier isEqualToString:kPasswordColumn]) {
        CustomFieldTableCellView* cell = [self.outlineView makeViewWithIdentifier:kPasswordCellIdentifier owner:nil];
        
        NSString* password = [self maybeDereference:it.fields.password node:it maybe:Settings.sharedInstance.dereferenceInOutlineView];
        
        cell.value = it.isGroup ? @"" : password;
        cell.protected = !it.isGroup && !(password.length == 0 && !self.viewModel.concealEmptyProtectedFields);
        cell.valueHidden = !it.isGroup && !(password.length == 0 && !self.viewModel.concealEmptyProtectedFields) && !Settings.sharedInstance.showPasswordImmediatelyInOutline;
        
        cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

        return cell;
    }
    else if([tableColumn.identifier isEqualToString:kTOTPColumn]) {
        NSString* totp = it.fields.otpToken ? it.fields.otpToken.password : @"";
        
        NSTableCellView* cell = [self getReadOnlyCell:totp node:it];

        if(it.fields.otpToken) {
            uint64_t remainingSeconds = [self getTotpRemainingSeconds:item];
            
            cell.textField.textColor = (remainingSeconds < 5) ? NSColor.redColor : (remainingSeconds < 9) ? NSColor.orangeColor : NSColor.controlTextColor;
        }

        cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

        return cell;
    }
    else if([tableColumn.identifier isEqualToString:kURLColumn]) {
        return [self getUrlCell:it.fields.url node:it];
    }
    else if([tableColumn.identifier isEqualToString:kEmailColumn]) {
        return [self getEditableCell:it.fields.email node:it selector:@selector(onOutlineViewItemEmailEdited:)];
    }
    else if([tableColumn.identifier isEqualToString:kExpiresColumn]) {
        NSString* exp = it.fields.expires ? it.fields.expires.friendlyDateStringVeryShort : @"";
        NSTableCellView* cell = [self getReadOnlyCell:exp node:it];
        cell.textField.textColor = it.expired ? NSColor.redColor : it.nearlyExpired ? NSColor.orangeColor : nil;
        
        cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

        return cell;
    }
    else if([tableColumn.identifier isEqualToString:kNotesColumn]) {
        return [self getEditableCell:it.fields.notes node:it selector:@selector(onOutlineViewItemNotesEdited:)];
    }
    else if([tableColumn.identifier isEqualToString:kAttachmentsColumn]) {
        return [self getReadOnlyCell:it.isGroup ? @"" : @(it.fields.attachments.count).stringValue node:it];
    }
    else if([tableColumn.identifier isEqualToString:kCustomFieldsColumn]) {
        return [self getReadOnlyCell:it.isGroup ? @"" : @(it.fields.customFields.count).stringValue node:it];
    }
    else {
        return [self getReadOnlyCell:@"< Unknown Column TO DO >" node:it];
    }
}

- (NSTableCellView*)getReadOnlyCell:(NSString*)text node:(Node*)node {
    NSTableCellView* cell = (NSTableCellView*)[self.outlineView makeViewWithIdentifier:@"ReadOnlyCell" owner:self];
    
    cell.textField.stringValue = text;
    cell.textField.editable = NO;
    cell.textField.textColor = nil;
    
    cell.alphaValue = node.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

    return cell;
}

- (NSTableCellView*)getUrlCell:(NSString*)text node:(Node*)node {
    NSTableCellView* cell = [self getEditableCell:text node:node selector:@selector(onOutlineViewItemUrlEdited:)];

    
    
    




















    
    cell.alphaValue = node.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

    return cell;
}

- (NSTableCellView*)getEditableCell:(NSString*)text node:(Node*)node selector:(SEL)selector {
    NSTableCellView* cell = (NSTableCellView*)[self.outlineView makeViewWithIdentifier:@"GenericCell" owner:self];
    
    cell.textField.stringValue = [self maybeDereference:text node:node maybe:Settings.sharedInstance.dereferenceInOutlineView];
    
    
    
    BOOL possiblyDereferencedText = Settings.sharedInstance.dereferenceInOutlineView && [self.viewModel isDereferenceableText:text];
    
    cell.textField.editable = !possiblyDereferencedText &&
        !self.viewModel.outlineViewEditableFieldsAreReadonly &&
        !self.viewModel.isEffectivelyReadOnly;
    
    cell.textField.action = selector;
    
    cell.alphaValue = node.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

    return cell;
}

- (NSTableCellView*)getTitleCell:(Node*)it {
    NSTableCellView* cell = (NSTableCellView*)[self.outlineView makeViewWithIdentifier:@"TitleCell" owner:self];
    if(!self.italicFont) {
        self.regularFont = cell.textField.font;
        self.italicFont = [NSFontManager.sharedFontManager convertFont:cell.textField.font toHaveTrait:NSFontItalicTrait];
    }
    
    if(it.isGroup && self.viewModel.recycleBinEnabled && self.viewModel.recycleBinNode && self.viewModel.recycleBinNode == it) {
        cell.textField.font = self.italicFont;
    }
    else {
        cell.textField.font = self.regularFont;
    }

    cell.imageView.objectValue = [self getIconForNode:it large:NO];
    cell.textField.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInOutlineView];

    BOOL possiblyDereferencedText = Settings.sharedInstance.dereferenceInOutlineView && [self.viewModel isDereferenceableText:it.title];
    cell.textField.editable = !possiblyDereferencedText
        && !self.viewModel.isEffectivelyReadOnly
        && (it.isGroup || (!self.viewModel.outlineViewTitleIsReadonly));
    
    cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;
    
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    
    [self bindDetailsPane];
}

- (IBAction)onOutlineViewItemEmailEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  [Utils trim:textField.stringValue];
    if(![item.fields.email isEqualToString:newString]) {
        [self.viewModel setItemEmail:item email:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; 
}

- (IBAction)onOutlineViewItemNotesEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  textField.stringValue;
    if(![item.fields.notes isEqualToString:newString]) {
        [self.viewModel setItemNotes:item notes:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; 
}

- (IBAction)onOutlineViewItemUrlEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  [Utils trim:textField.stringValue];
    if(![item.fields.url isEqualToString:newString]) {
        [self.viewModel setItemUrl:item url:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; 
}

- (IBAction)onOutlineViewItemUsernameEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  [Utils trim:textField.stringValue];
    if(![item.fields.username isEqualToString:newString]) {
        [self.viewModel setItemUsername:item username:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; 
}

- (IBAction)onOutlineViewItemTitleEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    
    NSString* newTitle = [Utils trim:textField.stringValue];
    if(![item.title isEqualToString:newTitle]) {
        if(![self.viewModel setItemTitle:item title:newTitle]) {
            textField.stringValue = item.title;
        }
    }
    else {
        textField.stringValue = newTitle;
    }

    [self.view.window makeFirstResponder:self.outlineView]; 
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    
    NSLog(@"sortDescriptors did change!");
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification {
    NSNumber* newNum = notification.userInfo[@"NSNewColumn"];

    NSTableColumn* column = self.outlineView.tableColumns[newNum.intValue];
    
    
    
    NSMutableArray<NSString*>* newColumns = [self.viewModel.visibleColumns mutableCopy];
   
    [newColumns removeObject:column.identifier];
    [newColumns insertObject:column.identifier atIndex:newNum.integerValue];
    
    self.viewModel.visibleColumns = newColumns;
}

- (IBAction)onOutlineViewDoubleClick:(id)sender {
    NSInteger colIdx = [sender clickedColumn];
    NSInteger rowIdx = [sender clickedRow];
    
    if(colIdx != -1 && rowIdx != -1) {
        NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
        Node *item = [sender itemAtRow:rowIdx];
        
        if([col.identifier isEqualToString:kTitleColumn]) {
            [self openItemDetails:item newEntry:NO];
        }
        else if([col.identifier isEqualToString:kUsernameColumn]) {
            [self copyUsername:item];
        }
        else if([col.identifier isEqualToString:kPasswordColumn]) {
            [self copyPassword:item];
        }
        else if([col.identifier isEqualToString:kTOTPColumn]) {
            [self copyTotp:item];
        }
        else if([col.identifier isEqualToString:kURLColumn]) {
            [self copyUrl:item];
        }
        else if([col.identifier isEqualToString:kEmailColumn]) {
            [self copyEmail:item];
        }
        else if([col.identifier isEqualToString:kNotesColumn]) {
            [self copyNotes:item];
        }
    }
}

- (void)outlineViewOnEnterKey {
    Node* item = [self getCurrentSelectedItem];
    
    if (item) {
        [self openItemDetails:item newEntry:NO];
    }
}

- (void)outlineViewOnDeleteKey {
    [self onDelete:nil];
}



- (NSArray<Node*> *)getItems:(Node*)parentGroup {
    if(!self.viewModel || self.viewModel.locked) {
        NSLog(@"Request for safe items while model nil or locked!");
        return @[];
    }
    
    if(self.itemsCache == nil) {
        self.itemsCache = [NSMutableDictionary dictionary];
    }
    
    if(self.itemsCache[parentGroup.uuid] == nil) {
        NSArray<Node*>* items = [self loadItems:parentGroup];
        self.itemsCache[parentGroup.uuid] = items;
    }
    
    return self.itemsCache[parentGroup.uuid];
}

-(NSArray<Node*>*)loadItems:(Node*)parentGroup {
    
    if(!parentGroup.isGroup) { 
        return @[];
    }
    
    BOOL sort = self.viewModel.sortKeePassNodes || self.viewModel.format == kPasswordSafe;
    
    NSArray<Node*>* sorted = sort ? [parentGroup.children sortedArrayUsingComparator:finderStyleNodeComparator] : parentGroup.children;
    
    NSString* searchText = self.searchField.stringValue;
    BOOL isSearching = searchText.length != 0;
    BOOL showRecycleBin = isSearching ? self.viewModel.showRecycleBinInSearchResults : self.viewModel.showRecycleBinInBrowse;

    NSArray<Node*> *filtered = sorted;
    if(self.viewModel.format == kKeePass1) {
        if(!showRecycleBin && self.viewModel.keePass1BackupNode) {
            filtered = [sorted filter:^BOOL(Node * _Nonnull obj) {
                return obj != self.viewModel.keePass1BackupNode;
            }];
        }
    }
    else {
        if(!showRecycleBin && self.viewModel.recycleBinNode) {
            filtered = [sorted filter:^BOOL(Node * _Nonnull obj) {
                return obj != self.viewModel.recycleBinNode;
            }];
        }
    }

    
     
    NSArray<Node*> *matches = !isSearching ? filtered : [filtered filter:^BOOL(Node * _Nonnull obj) {
        return [self isSafeItemMatchesSearchCriteria:obj recurse:YES];
    }];
    
    return matches;
}

- (BOOL)isSafeItemMatchesSearchCriteria:(Node*)item recurse:(BOOL)recurse {
    NSString* searchText = self.searchField.stringValue;
    if(![searchText length]) {
        return YES;
    }
    
    if([self immediateMatch:searchText item:item scope:self.searchSegmentedControl.selectedSegment]) {
        return YES;
    }
    
    if(item.isGroup && recurse) {
        for(Node* child in item.children) {
            if([self isSafeItemMatchesSearchCriteria:child recurse:YES]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)immediateMatch:(NSString*)searchText item:(Node*)item scope:(NSInteger)scope {
    if ( !item.isSearchable ) {
        return NO;
    }
    
    BOOL immediateMatch = NO;

    NSArray<NSString*> *terms = [self.viewModel getSearchTerms:searchText];
    
    
    
    for (NSString* term in terms) {
        if (scope == kSearchScopeTitle) {
            immediateMatch = [self.viewModel isTitleMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopeUsername) {
            immediateMatch = [self.viewModel isUsernameMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopePassword) {
            immediateMatch = [self.viewModel isPasswordMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopeUrl) {
            immediateMatch = [self.viewModel isUrlMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else {
            immediateMatch = [self.viewModel isAllFieldsMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        
        if(!immediateMatch) { 
            return NO;
        }
    }
    
    return immediateMatch;
}



- (NSString*)selectedItemSerializationId {
    Node* item = [self getCurrentSelectedItem];
    return [self.viewModel.database getCrossSerializationFriendlyIdId:item.uuid];
}

- (void)showProgressModal:(NSString*)operationDescription {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.progressWindow ) {
            [self.progressWindow hide];
        }
        
        if ( self.view.window.isMiniaturized ) {
            NSLog(@"Not showing Progress Modal because miniaturized...");
            return; 
        }
        
        self.progressWindow = [ProgressWindow newProgress:operationDescription];
        [self.view.window beginSheet:self.progressWindow.window completionHandler:nil];
    });
}

- (void)hideProgressModal {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressWindow hide];
    });
}

- (NSData*)getSelectedKeyFileDigest:(NSError**)error {
    NSData* keyFileDigest = nil;
    if(self.selectedKeyFileBookmark) {
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:self.selectedKeyFileBookmark error:error];
                
        if(data) {
            keyFileDigest = [KeyFileParser getNonePerformantKeyFileDigest:data checkForXml:self.viewModel.format != kKeePass1];
            
        }
        else {
            if (error) {
                *error = [Utils createNSError:@"Could not read key file..."  errorCode:-1];
            }
        }
    }
    
    return keyFileDigest;
}

- (IBAction)onEnterMasterPassword:(id)sender {
    if(![self manualCredentialsAreValid]) {
        return;
    }
    
    NSString* password = self.textFieldMasterPassword.stringValue;
    
    if(password.length == 0) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
                     informativeText:NSLocalizedString(@"casg_question_message_empty_password", @"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want.")
                   option1AndDefault:NSLocalizedString(@"casg_question_option_empty", @"Empty Password")
                             option2:NSLocalizedString(@"casg_question_option_none", @"No Password")
                              window:self.view.window
                          completion:^(NSUInteger zeroForCancel) {
            if (zeroForCancel == 1) {
                [self continueManualUnlockWithPassword:@""];
            }
            else if(zeroForCancel == 2) {
                [self continueManualUnlockWithPassword:nil];
            }
        }];
    }
    else {
        [self continueManualUnlockWithPassword:password];
    }
}

- (void)continueManualUnlockWithPassword:(NSString*_Nullable)password {
    NSError* error;
    CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:password error:&error];

    if(error) {
        [MacAlerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                error:error
               window:self.view.window];
        return;
    }

    [self reloadAndUnlock:ckf isBiometricOpen:NO];
}

- (CompositeKeyFactors*)getCompositeKeyFactorsWithSelectedUiFactors:(NSString*)password error:(NSError**)error {
    NSData* keyFileDigest = [self getSelectedKeyFileDigest:error];

    if(*error) {
        return nil;
    }
        
    if (self.selectedYubiKeyConfiguration == nil) {
        return [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest];
    }
    else {
        NSWindow* windowHint = self.view.window; 

        NSInteger slot = self.selectedYubiKeyConfiguration.slot;
        BOOL blocking = slot == 1 ? self.currentYubiKeySlot1IsBlocking : self.currentYubiKeySlot2IsBlocking;

        return [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest
                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
                [MacYubiKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                            windowHint:windowHint
                                                                  slot:slot
                                                        slotIsBlocking:blocking
                                                            completion:completion];
        }];
    }
}



- (BOOL)convenienceUnlockIsPossible {
    DatabaseMetadata* metaData = self.databaseMetadata;
    
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;

    BOOL convenienceMethodPossible = (watchAvailable && self.databaseMetadata.isWatchUnlockEnabled) || (touchAvailable && self.databaseMetadata.isTouchIdEnabled);

    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    BOOL ret = metaData && convenienceMethodPossible && featureAvailable && passwordAvailable;


    
    return ret;
}

- (void)autoPromptForTouchIdIfDesired {
    if(self.viewModel && self.viewModel.locked) {
        BOOL weAreKeyWindow = NSApplication.sharedApplication.keyWindow == self.view.window;

        if( weAreKeyWindow && self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate && [self convenienceUnlockIsPossible] ) {
            NSTimeInterval secondsBetween = [NSDate.date timeIntervalSinceDate:self.lastAutoPromptForTouchIdThrottle];
            if(self.lastAutoPromptForTouchIdThrottle != nil && secondsBetween < 1.5) {
                NSLog(@"Too many auto biometric requests too soon - ignoring...");
                return;
            }

            [self onUnlockWithTouchId:nil];
        }
    }
}

- (IBAction)onUnlockWithTouchId:(id)sender {
    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    if( [self convenienceUnlockIsPossible] ) {
        [BiometricIdHelper.sharedInstance authorize:self.databaseMetadata completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.lastAutoPromptForTouchIdThrottle = NSDate.date;

                if(success) {
                    DatabaseMetadata* metaData = self.databaseMetadata;

                    NSError* err;
                    CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:metaData.conveniencePassword
                                                                                           error:&err];

                    if(err) {
                        [MacAlerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                                error:error
                               window:self.view.window];
                        return;
                    }

                    [self reloadAndUnlock:ckf isBiometricOpen:YES];
                }
                else {
                    NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                    
                    if(error && (error.code == LAErrorUserFallback || error.code == LAErrorUserCancel || error.code == -2412)) {
                        NSLog(@"User cancelled or selected fallback. Ignore...");
                    }
                    else {
                        [MacAlerts error:error window:self.view.window];
                    }
                }
            });
        }];
    }
    else if( !passwordAvailable ) {
        NSLog(@"Touch ID button pressed but no Touch ID Stored? Probably Expired...");
        
        NSString* loc = NSLocalizedString(@"mac_could_not_find_stored_credentials", @"Touch ID/Apple Watch Unlock is not possible because the stored credentials are unavailable. This is probably because they have expired. Please enter the password manually.");
        
        [MacAlerts info:loc window:self.view.window];
  
        [self bindLockScreenUi];
    }
    else {
        NSString* loc = NSLocalizedString(@"mac_info_biometric_unlock_not_possible_right_now", @"Touch ID/Apple Watch Unlock is not possible at the moment because Biometrics/Apple Watch is not available.");
        
        [MacAlerts info:loc window:self.view.window];
    }
}

- (void)onDatabaseChangedByExternalOther {
    if(self.isPromptingAboutUnderlyingFileChange) {
        NSLog(@"Already in Use...");
        return;
    }
    
    self.isPromptingAboutUnderlyingFileChange = YES;
    if(self.viewModel && !self.viewModel.locked) {
        NSLog(@"ViewController::onDatabaseChangedByExternalOther - Reloading...");
        
        if(!self.viewModel.document.isDocumentEdited) {
            if( !self.databaseMetadata.autoReloadAfterExternalChanges ) {
                NSString* loc = NSLocalizedString(@"mac_db_changed_externally_reload_yes_or_no", @"The database has been changed by another application, would you like to reload this latest version and automatically unlock?");

                [MacAlerts yesNo:loc
                       window:self.view.window
                   completion:^(BOOL yesNo) {
                    if(yesNo) {
                        NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                        [self showPopupChangeToastNotification:loc];
                        
                        self.viewModel.selectedItem = [self selectedItemSerializationId];
                        
                        [self reloadAndUnlock:self.viewModel.compositeKeyFactors isBiometricOpen:NO];
                    }
                    
                    self.isPromptingAboutUnderlyingFileChange = NO;
                }];
                return;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                [self showPopupChangeToastNotification:loc];

                self.viewModel.selectedItem = [self selectedItemSerializationId];
                
                BOOL background = self.view.window.isMiniaturized;
                [self reloadAndUnlock:self.viewModel.compositeKeyFactors isBiometricOpen:NO backgroundSync:background];
            
                self.isPromptingAboutUnderlyingFileChange = NO;

                return;
            }
        }
        else {
            NSLog(@"Local Changes Present... ignore this, we can't auto reload...");
        }
    }
    else {
        NSLog(@"Ignoring File Change by Other Application because Database is locked/not set.");
    }
    self.isPromptingAboutUnderlyingFileChange = NO;
}

- (void)enableMasterCredentialsEntry:(BOOL)enable {
    [self.textFieldMasterPassword setEnabled:enable];
    [self.buttonUnlockWithTouchId setEnabled:enable];
    [self.buttonUnlockWithPassword setEnabled:enable];
    [self.keyFilePopup setEnabled:enable];
}

- (void)reloadAndUnlock:(CompositeKeyFactors*)compositeKeyFactors
        isBiometricOpen:(BOOL)isBiometricOpen {
    [self reloadAndUnlock:compositeKeyFactors isBiometricOpen:isBiometricOpen backgroundSync:NO];
}

- (void)reloadAndUnlock:(CompositeKeyFactors*)compositeKeyFactors
        isBiometricOpen:(BOOL)isBiometricOpen
         backgroundSync:(BOOL)backgroundSync {
    if( self.viewModel ) {
        
        
        if ( self.databaseMetadata &&
            self.databaseMetadata.storageProvider != kMacFile &&
            !Settings.sharedInstance.isProOrFreeTrial ) {
            [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                     window:self.view.window];
            return;
        }
        
        [self enableMasterCredentialsEntry:NO];
                
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.document revertWithUnlock:compositeKeyFactors
                             viewController:backgroundSync ? nil : self
                                completion:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(success) {
                        self.textFieldMasterPassword.stringValue = @"";
                    }
                    [self onUnlocked:success error:error compositeKeyFactors:compositeKeyFactors isBiometricUnlock:isBiometricOpen];
                });
            }];
        });
    }
    else { 
        [MacAlerts info:@"Model is not set. Could not unlock. Please close and reopen your database"
              window:self.view.window];
    }
}

- (void)onUnlocked:(BOOL)success
             error:(NSError*)error
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
 isBiometricUnlock:(BOOL)isBiometricUnlock {
    [self enableMasterCredentialsEntry:YES];
    
    if(success) {
        DatabaseMetadata* databaseMetadata = self.databaseMetadata;
                
        BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
        BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
        BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
        BOOL convenienceAvailable = watchAvailable || touchAvailable;
        BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
        
        BOOL convenienceIsPossible = convenienceAvailable && featureAvailable;
        BOOL shouldPromptForBiometricEnrol = convenienceIsPossible && !databaseMetadata.hasPromptedForTouchIdEnrol && !convenienceEnabled;
        
        BOOL autoFillAvailable = NO;
        if ( @available(macOS 11.0, *) ) {
            autoFillAvailable = YES;
        }
        
        BOOL shouldPromptForAutoFillEnrol = featureAvailable && autoFillAvailable && !databaseMetadata.autoFillEnabled && !databaseMetadata.hasPromptedForAutoFillEnrol;
        
        if(shouldPromptForBiometricEnrol || shouldPromptForAutoFillEnrol) {
            [self onboardForBiometricsAndOrAutoFill:shouldPromptForBiometricEnrol
                       shouldPromptForAutoFillEnrol:shouldPromptForAutoFillEnrol
                                compositeKeyFactors:compositeKeyFactors];            
        }
                
        NSString* password = self.viewModel.compositeKeyFactors.password;
        if( !isBiometricUnlock && convenienceIsPossible && convenienceEnabled && databaseMetadata.isTouchIdEnrolled && databaseMetadata.conveniencePassword == nil && password.length) {
            
            [self.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:password];
        }
    
        [DatabasesManager.sharedInstance atomicUpdate:databaseMetadata.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            
            
            metadata.keyFileBookmark = Settings.sharedInstance.doNotRememberKeyFile ? nil : self.selectedKeyFileBookmark;
            metadata.yubiKeyConfiguration = self.selectedYubiKeyConfiguration;
        }];
    }
    else {
        if ( error && error.code == StrongboxErrorCodes.incorrectCredentials ) {
            if(isBiometricUnlock) { 
                [self clearTouchId];
            
                [MacAlerts info:NSLocalizedString(@"open_sequence_problem_opening_title", @"Could not open database")
                informativeText:NSLocalizedString(@"open_sequence_problem_opening_convenience_incorrect_message", @"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled.")
                         window:self.view.window
                     completion:nil];
            }
            else {
                if (compositeKeyFactors.keyFileDigest) {
                    [MacAlerts info:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                    informativeText:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message_verify_key_file", @"The credentials were incorrect for this database. Are you sure you are using this key file?\n\nNB: A key files are not the same as your database file.")
                             window:self.view.window
                         completion:nil];
                }
                else {
                    CGFloat yOffset = self.checkboxShowAdvanced.state == NSControlStateValueOn ? -75.0f : 0.0f; 
                    [self showToastNotification:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.") error:YES yOffset:yOffset];
                }
            }
        }
        else {
            NSString* loc = NSLocalizedString(@"mac_could_not_unlock_database", @"Could Not Unlock Database");
            [MacAlerts error:loc error:error window:self.view.window];
        }
        
        [self bindBiometricButtonsOnLockScreen];
        
        [self setInitialFocus];
    }
}

- (void)onboardForBiometricsAndOrAutoFill:(BOOL)shouldPromptForBiometricEnrol
             shouldPromptForAutoFillEnrol:(BOOL)shouldPromptForAutoFillEnrol
                      compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    NSDictionary* foo = @ {
        @"convenienceUnlock" : @(shouldPromptForBiometricEnrol),
        @"autoFill" : @(shouldPromptForAutoFillEnrol),
        @"compositeKeyFactors" : compositeKeyFactors,
        @"model" : self.viewModel.database,
    };
    
    [self performSegueWithIdentifier:@"segueToDatabaseOnboarding" sender:foo];
}



- (void)onAutoLock:(NSNotification*)notification {
    if(self.viewModel && !self.viewModel.locked && !self.viewModel.document.isDocumentEdited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLock:nil];
        });
    }
}

- (IBAction)onLock:(id)sender {
    if(self.viewModel && !self.viewModel.locked) {
        if([self.viewModel.document isDocumentEdited]) {
            NSString* loc = NSLocalizedString(@"mac_cant_lock_db_while_changes_pending", @"You cannot lock a database while changes are pending. Save changes and lock now?");
            
            [MacAlerts yesNo:loc window:self.view.window completion:^(BOOL yesNo) {
                if(yesNo) {
                    NSString* loc = NSLocalizedString(@"generic_locking_ellipsis", @"Locking...");
                    [self showProgressModal:loc];
                    [self.viewModel.document saveDocumentWithDelegate:self didSaveSelector:@selector(lockSafeContinuation:) contextInfo:nil];
                }
                else {
                    return;
                }
            }];
        }
        else {
            
            
            
            

            [self lockSafeContinuation:nil];
        }
    }
}

- (IBAction)lockSafeContinuation:(id)sender {
    NSString* sid = [self selectedItemSerializationId];
    [self closeAllDetailsWindows:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.viewModel lock:sid];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onLockDone];
            });
        });
    }];
}

- (void)onLockDone {
    [self hideProgressModal];
    
    [self bindToModel];
    
    self.textFieldMasterPassword.stringValue = @"";
    [self setInitialFocus];
    
    [self.view setNeedsDisplay:YES];
    
    
    
    if(Settings.sharedInstance.clearClipboardEnabled) {
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate clearClipboardWhereAppropriate];
    }
}

- (void)changeMasterCredentials:(CompositeKeyFactors*)ckf {
    [self.viewModel setCompositeKeyFactors:ckf];

    DatabaseMetadata* md = self.databaseMetadata;
        
    [md resetConveniencePasswordWithCurrentConfiguration:ckf.password];
    
    [DatabasesManager.sharedInstance atomicUpdate:md.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
        if(self.changeMasterPassword.selectedKeyFileBookmark && !Settings.sharedInstance.doNotRememberKeyFile) {
            metadata.keyFileBookmark = self.changeMasterPassword.selectedKeyFileBookmark;
        }
        else {
            metadata.keyFileBookmark = nil;
        }
        metadata.yubiKeyConfiguration = self.changeMasterPassword.selectedYubiKeyConfiguration;
    }];
}

- (void)promptForMasterPassword:(BOOL)new completion:(void (^)(BOOL okCancel))completion {
    if(self.viewModel && !self.viewModel.locked) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.changeMasterPassword = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
            
            NSString* loc = new ?
            NSLocalizedString(@"mac_please_set_master_credentials", @"Please Enter the Master Credentials for this Database") :
            NSLocalizedString(@"mac_change_master_credentials", @"Change Master Credentials");
            
            self.changeMasterPassword.titleText = loc;
            self.changeMasterPassword.initialDatabaseFormat = self.viewModel.format;
            self.changeMasterPassword.initialYubiKeyConfiguration = self.databaseMetadata.yubiKeyConfiguration;
            self.changeMasterPassword.initialKeyFileBookmark = self.databaseMetadata.keyFileBookmark;
            
            [self.view.window beginSheet:self.changeMasterPassword.window
                       completionHandler:^(NSModalResponse returnCode) {
                if(returnCode == NSModalResponseOK) {
                    CompositeKeyFactors* ckf = [self.changeMasterPassword generateCkfFromSelected:self.view.window];
                    if (ckf) {
                        [self changeMasterCredentials:ckf];
                    }
                    else {
                        NSString* loc = NSLocalizedString(@"mac_error_could_not_generate_composite_key", @"Could not generate Composite Key");
                        [MacAlerts info:loc window:self.view.window];
                    }
                }
                
                if(completion) {
                    completion(returnCode == NSModalResponseOK);
                }
            }];
        });
    }
}

- (IBAction)onChangeMasterPassword:(id)sender {
    [self promptForMasterPassword:NO
                       completion:^(BOOL okCancel) {
        if(okCancel) {
            [self.viewModel.document saveDocumentWithDelegate:self
                                              didSaveSelector:@selector(onMasterCredentialsChangedAndSaved:)
                                                  contextInfo:nil];
        }
    }];
}

- (void)onMasterCredentialsChangedAndSaved:(id)param {
    NSString* loc = NSLocalizedString(@"mac_master_credentials_changed_and_saved", @"Master Credentials Changed and Database Saved");
    
    [MacAlerts info:loc window:self.view.window];
}



- (IBAction)onFind:(id)sender {
    [self.view.window makeFirstResponder:self.searchField];
}

- (IBAction)onSearch:(id)sender {    
    self.itemsCache = nil; 
    
    Node* currentSelection = [self getCurrentSelectedItem];
    
    [self.outlineView reloadData];
    
    if( self.searchField.stringValue.length > 0) {
        
        
        [self.outlineView expandItem:nil expandChildren:YES];

        BOOL found = NO;
        for(int i=0;i < [self.outlineView numberOfRows];i++) {
            
            Node* node = [self.outlineView itemAtRow:i];

            if([self isSafeItemMatchesSearchCriteria:node recurse:NO]) {
                
                [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
                found = YES;
                break;
            }
        }
        
        if ( !found ) { 
            NSLog(@"No matches...");
            [self.outlineView deselectAll:nil]; 
            [self bindDetailsPane];
        }
    }
    else {
        
        
        [self selectItem:currentSelection];
    }
}

- (IBAction)toggleRevealMasterPasswordTextField:(id)sender {
    self.textFieldMasterPassword.showsText = !self.textFieldMasterPassword.showsText;

    [self bindRevealMasterPasswordTextField];
}

- (void)bindRevealMasterPasswordTextField {
    NSImage* img = nil;
    
    if (@available(macOS 11.0, *)) {
        img = [NSImage imageWithSystemSymbolName:!self.textFieldMasterPassword.showsText ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""];
    } else {
        img = !self.textFieldMasterPassword.showsText ?
         [NSImage imageNamed:@"show"] : [NSImage imageNamed:@"hide"];
    }
    
    [self.buttonToggleRevealMasterPasswordTip setImage:img];
}

- (IBAction)onToggleShowHideQuickViewPassword:(id)sender {
    self.showPassword = !self.showPassword;
    [self showOrHideQuickViewPassword];
}

- (void)showOrHideQuickViewPassword {
    self.labelHiddenPassword.hidden = self.showPassword;
    self.labelPassword.hidden = !self.showPassword;
    self.imageViewTogglePassword.image = [NSImage imageNamed:self.showPassword ? @"hide" : @"show"];
}



-(void)dereferenceAndCopyToPasteboard:(NSString*)text item:(Node*)item {
    if(!item || !text.length) {
        [[NSPasteboard generalPasteboard] clearContents];
        return;
    }
    
    NSString* deref = [self.viewModel dereference:text node:item];
    
    [ClipboardManager.sharedInstance copyConcealedString:deref];
}

- (IBAction)onCopyTitle:(id)sender {
    [self copyTitle:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyUsername:(id)sender {
    [self copyUsername:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyEmail:(id)sender {
    [self copyEmail:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyUrl:(id)sender {
    [self copyUrl:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    Node* item = [self getCurrentSelectedItem];
    [self copyPassword:item];
    [self onLaunchUrl:sender];
}

- (IBAction)onCopyNotes:(id)sender {
    [self copyNotes:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyPassword:(id)sender {
    [self copyPassword:[self getCurrentSelectedItem]];
}

- (IBAction)onCopyTotp:(id)sender {
    [self copyTotp:[self getCurrentSelectedItem]];
}

- (void)onDoubleClickCustomField:(id)sender {
    NSInteger row = self.customFieldsTable.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [self copyCustomField:field];
}

- (IBAction)onCopyCustomFieldValue:(id)sender {
    NSInteger row = self.customFieldsTable.selectedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [self copyCustomField:field];
}

- (void)copyCustomField:(CustomField*)field {
    Node* it = [self getCurrentSelectedItem];
    NSString* derefed = [self maybeDereference:field.value node:it maybe:YES];

    [ClipboardManager.sharedInstance copyConcealedString:derefed];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, field.key, NSLocalizedString(@"generic_fieldname_custom_field", @"Custom Field")]];
}

- (void)copyTitle:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.title item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_title", @"Title")]];
}

- (void)copyUsername:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.username item:item];
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_username", @"Username")]];
}

- (void)copyEmail:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.email item:item];
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_email", @"Email")]];
}

- (void)copyUrl:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.url item:item];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_url", @"URL")]];
}

- (void)copyNotes:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.notes item:item];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_notes", @"Notes")]];
}

- (void)copyPassword:(Node*)item {
    if(!item || item.isGroup) {
        return;
    }

    [self dereferenceAndCopyToPasteboard:item.fields.password item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_password", @"Password")]];
}

- (void)copyTotp:(Node*)item {
    if(!item || !item.fields.otpToken) {
        return;
    }

    NSString *password = item.fields.otpToken.password;
    [ClipboardManager.sharedInstance copyConcealedString:password];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_totp", @"TOTP")]];
}



- (void)expandParentsOfItem:(Node*)item {
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    
    while (item.parent != nil) {
        item = item.parent;
        
        
        
        [stack addObject:item];
    }
    
    while ([stack count]) {
        Node *group = [stack lastObject];
        
        
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
    [self.outlineView registerForDraggedTypes:@[kDragAndDropInternalUti, kDragAndDropExternalUti]];
}

- (Node*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    
    
    return [self.outlineView itemAtRow:selectedRow];
}

- (NSArray<Node*>*)getSelectedItems {
    NSIndexSet *rows = [self.outlineView selectedRowIndexes];
    
    NSMutableArray<Node*>* items = @[].mutableCopy;
    [rows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        Node* node = [self.outlineView itemAtRow:idx];
        [items addObject:node];
    }];
    
    return items;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         writeItems:(NSArray *)items
       toPasteboard:(NSPasteboard *)pasteboard {
    return [self placeItemsOnPasteboard:pasteboard items:items];
}

- (BOOL)placeItemsOnPasteboard:(NSPasteboard*)pasteboard items:(NSArray<Node*>*)items {
    [pasteboard declareTypes:@[kDragAndDropInternalUti,
                               kDragAndDropExternalUti]
                       owner:self];
    
    NSArray<Node*>* minimalNodeSet = [self.viewModel getMinimalNodeSet:items].allObjects;
    
    
    
    NSArray<NSString*>* internalSerializationIds = [self getInternalSerializationIds:minimalNodeSet];
    [pasteboard setPropertyList:internalSerializationIds forType:kDragAndDropInternalUti];
    
    
    
    NSData* json = [self getJsonForNodes:minimalNodeSet];
    [pasteboard setData:json forType:kDragAndDropExternalUti];
    
    return YES;
}

- (NSArray<NSString*>*)getInternalSerializationIds:(NSArray<Node*>*)nodes {
    return [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [self.viewModel.database getCrossSerializationFriendlyIdId:obj.uuid];
    }];
}

- (NSData*)getJsonForNodes:(NSArray<Node*>*)nodes {
    SerializationPackage *serializationPackage = [[SerializationPackage alloc] init];
    
    
    
    NSArray<NSDictionary*>* nodeDictionaries = [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj serialize:serializationPackage];
    }];
            
    
    
    NSDictionary *serialized = @{ @"sourceFormat" : @(self.viewModel.format),
                                  @"nodes" : nodeDictionaries };
    
    
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:serialized options:kNilOptions error:&error];

    if(!data) {
        [MacAlerts error:@"Could not serialize these items!" error:error window:self.view.window];
    }
    
    return data;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
    Node* destinationItem = (item == nil) ? self.viewModel.rootGroup : item;

    if ([info draggingSource] == self.outlineView) {
        NSArray<NSString*>* serializationIds = [info.draggingPasteboard propertyListForType:kDragAndDropInternalUti];
        NSArray<Node*>* sourceItems = [serializationIds map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self.viewModel getItemFromSerializationId:obj];
        }];

        BOOL valid = [self.viewModel validateMove:sourceItems destination:destinationItem];

        return valid ? NSDragOperationMove : NSDragOperationNone;
    }
    else {
        NSData* json = [info.draggingPasteboard dataForType:kDragAndDropExternalUti];
        return json && destinationItem.isGroup ? NSDragOperationCopy : NSDragOperationNone;
    }
}

-(BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info
              item:(id)item
        childIndex:(NSInteger)index {
    
    Node* destinationItem = (item == nil) ? self.viewModel.rootGroup : item;

    return [self pasteItemsFromPasteboard:info.draggingPasteboard destinationItem:destinationItem source:info.draggingSource clear:YES] != 0;
}

- (NSUInteger)pasteItemsFromPasteboard:(NSPasteboard*)pasteboard
                 destinationItem:(Node*)destinationItem
                          source:(id)source
                           clear:(BOOL)clear {
    if(![pasteboard propertyListForType:kDragAndDropExternalUti] &&
       ![pasteboard dataForType:kDragAndDropInternalUti]) {
        return NO;
    }
    
    if (source == self.outlineView) {
        NSArray<NSString*>* serializationIds = [pasteboard propertyListForType:kDragAndDropInternalUti];
        NSArray<Node*>* sourceItems = [serializationIds map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self.viewModel getItemFromSerializationId:obj];
        }];

        BOOL result = [self.viewModel move:sourceItems destination:destinationItem];
        
        if(clear) {
            [pasteboard clearContents];
        }
        
        return result ? sourceItems.count : 0;
    }
    else if(destinationItem.isGroup) { 
        NSData* json = [pasteboard dataForType:kDragAndDropExternalUti];
        if(json && destinationItem.isGroup) {
            NSUInteger ret = [self pasteFromExternal:json destinationItem:destinationItem];
            if(clear) {
                [pasteboard clearContents];
            }
            return ret;
        }
    }
    
    if(clear) {
        [pasteboard clearContents];
    }
    
    return 0;
}

- (NSUInteger)pasteFromExternal:(NSData*)json destinationItem:(Node*)destinationItem {
    NSError* error;
    NSDictionary* serialized = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if(!serialized) {
        [MacAlerts error:@"Could not deserialize!" error:error window:self.view.window];
        return NO;
    }
    
    NSNumber* sourceFormatNum = serialized[@"sourceFormat"];
    DatabaseFormat sourceFormat = sourceFormatNum.integerValue;
    NSArray<NSDictionary*>* serializedNodes = serialized[@"nodes"];
    
    BOOL keePassGroupTitleRules = self.viewModel.format != kPasswordSafe;
    
    
    
    NSMutableArray<Node*>* nodes = @[].mutableCopy;
    NSError* err;
    for (NSDictionary* obj in serializedNodes) {
        Node* n = [Node deserialize:obj parent:destinationItem keePassGroupTitleRules:keePassGroupTitleRules error:&err];
        
        if(!n) {
            [MacAlerts error:err window:self.view.window];
            return 0;
        }
        
        [nodes addObject:n];
    }
    
    [self processFormatIncompatibilities:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    
    return nodes.count;
}

- (void)processPasswordSafeToKeePass2:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    
    
    NSArray<Node*>* allRecords = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildRecords;
    }];
    NSMutableArray<Node*>* all = allRecords.mutableCopy;
    [all addObjectsFromArray:nodes];
    NSArray<Node*>* nodesWithEmails = [all filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.email.length;
    }];
    
    if(nodesWithEmails.count) {
        NSString* loc = NSLocalizedString(@"mac_drag_drop_between_databases_keepass_email_field_not_supported", @"KeePass does not natively support the 'Email' field. Strongbox will add it instead as a custom field.\nDo you want to continue?");

        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* nodeWithEmail in nodesWithEmails) {
                       [nodeWithEmail.fields setCustomField:@"Email" value:[StringValue valueWithString:nodeWithEmail.fields.email]];
                   }
                   
                   [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
               }
           }];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)processPasswordSafeToKeePass1:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    
   
    NSArray<Node*>* allRecords = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildRecords;
    }];
    NSMutableArray<Node*>* all = allRecords.mutableCopy;
    [all addObjectsFromArray:nodes];
    NSArray<Node*>* nodesWithEmails = [all filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.email.length;
    }];
    
    NSArray<Node*>* rootEntries = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
    
    BOOL pastingEntriesToRoot = ((destinationItem == nil || destinationItem == self.viewModel.rootGroup) && rootEntries.count);
    
    if(nodesWithEmails.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries", @"KeePass 1 does not support entries at the root level, these will be discarded. KeePass 1 also does not natively support the 'Email' field. Strongbox will append it instead to the end of the 'Notes' field.\nDo you want to continue?");
        
        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* nodeWithEmail in nodesWithEmails) {
                       nodeWithEmail.fields.notes = [nodeWithEmail.fields.notes stringByAppendingFormat:@"%@Email: %@",
                                                     nodeWithEmail.fields.notes.length ? @"\n\n" : @"",
                                                     nodeWithEmail.fields.email];
                   }
                   
                   NSArray* filtered = nodes;
                   if(pastingEntriesToRoot) {
                       filtered = [nodes filter:^BOOL(Node * _Nonnull obj) {
                           return obj.isGroup;
                       }];
                   }
                   
                   [self continuePaste:serialized nodes:filtered destinationItem:destinationItem sourceFormat:sourceFormat];
               }
           }];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)processKeePass2ToPasswordSafe:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = !obj.isUsingKeePassDefaultIcon;
        BOOL attachments = obj.fields.attachments.count;
        BOOL customFields = obj.fields.customFields.count;
        
        return customIcon || attachments || customFields;
    }];

    if(incompatibles.count) {
        NSString* loc = NSLocalizedString(@"mac_password_safe_fmt_does_not_support_icons_attachments_warning", @"The Password Safe format does not support icons, attachments or custom fields. If you continue, these fields will not be copied to this database.\nDo you want to continue without these fields?");
        
        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.icon = nil;
                       [incompatible.fields.attachments removeAllObjects];
                       [incompatible.fields removeAllCustomFields];
                   }
                   
                   [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
               }
           }];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)processKeePass2ToKeePass1:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = obj.icon.isCustom;
        BOOL tooManyAttachments = obj.fields.attachments.count > 1;
        BOOL customFields = obj.fields.customFields.count;
        
        return customIcon || tooManyAttachments || customFields;
    }];
    
    NSArray<Node*>* rootEntries = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
    BOOL pastingEntriesToRoot = ((destinationItem == nil || destinationItem == self.viewModel.rootGroup) && rootEntries.count);

    if(incompatibles.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries_or_attachments", @"The KeePass 1 (KDB) does not support entries at the root level, these will be discarded.\n\nThe KeePass 1 (KDB) format also does not support multiple attachments, custom fields or custom icons. If you continue only the first attachment from each item will be copied to this database. Custom Fields and Icons will be discarded.\nDo you want to continue?");

        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.icon = nil;
                       NSString* firstAttachmentFilename = incompatible.fields.attachments.allKeys.firstObject;
                       if ( firstAttachmentFilename ) { 
                           DatabaseAttachment* dbA = incompatible.fields.attachments[firstAttachmentFilename];
                           
                           [incompatible.fields.attachments removeAllObjects];
                           
                           incompatible.fields.attachments[firstAttachmentFilename] = dbA;
                       }
                       else {
                           [incompatible.fields.attachments removeAllObjects];
                       }
                       [incompatible.fields removeAllCustomFields];
                   }
                   
                   NSArray* filtered = nodes;
                   if(pastingEntriesToRoot) {
                       filtered = [nodes filter:^BOOL(Node * _Nonnull obj) {
                           return obj.isGroup;
                       }];
                   }
                   
                   [self continuePaste:serialized nodes:filtered destinationItem:destinationItem sourceFormat:sourceFormat];
               }
           }];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)processKeePass1ToPasswordSafe:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = !obj.isUsingKeePassDefaultIcon;
        BOOL attachments = obj.fields.attachments.count;
        
        return customIcon || attachments;
    }];
    
    if(incompatibles.count) {
        NSString* loc = NSLocalizedString(@"mac_password_safe_does_not_support_attachments_icons_continue_yes_no", @"The Password Safe format does not support attachments or icons. If you continue, these fields will not be copied to this database.\nDo you want to continue without these fields?");
        
        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.icon = nil;
                       [incompatible.fields.attachments removeAllObjects];
                       [incompatible.fields removeAllCustomFields];
                   }
                   
                   [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
               }
           }];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)processFormatIncompatibilities:(NSDictionary*)serialized
                                 nodes:(NSArray<Node*>*)nodes
                       destinationItem:(Node*_Nonnull)destinationItem
                          sourceFormat:(DatabaseFormat)sourceFormat {
    if (sourceFormat == kPasswordSafe && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4)) {
        [self processPasswordSafeToKeePass2:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if (sourceFormat == kPasswordSafe && self.viewModel.format == kKeePass1) {
        [self processPasswordSafeToKeePass1:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && self.viewModel.format == kPasswordSafe) {
        [self processKeePass2ToPasswordSafe:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && self.viewModel.format == kKeePass1) {
        [self processKeePass2ToKeePass1:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if (sourceFormat == kKeePass1 && self.viewModel.format == kPasswordSafe) {
        [self processKeePass1ToPasswordSafe:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else {
        [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
}

- (void)continuePaste:(NSDictionary*)serialized
                nodes:(NSArray<Node*>*)nodes
      destinationItem:(Node*)destinationItem
         sourceFormat:(DatabaseFormat)sourceFormat {
    BOOL success = [self.viewModel addChildren:nodes parent:destinationItem];
    
    if(!success) {
        [MacAlerts info:@"Could Not Paste"
     informativeText:@"Could not place these items here. Unknown error."
              window:self.view.window
          completion:nil];
    }
}



- (IBAction)onCreateRecord:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item ? (item.isGroup ? item : item.parent) : self.viewModel.rootGroup;
    
    if(![self.viewModel addNewRecord:parent]) {
        NSString* loc = NSLocalizedString(@"mac_alert_cannot_create_item_here", @"You cannot create a new item here. It must be within an existing folder.");
        [MacAlerts info:loc window:self.view.window];
        return;
    }
}

- (IBAction)onCreateGroup:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item ? (item.isGroup ? item : item.parent) : self.viewModel.rootGroup;
        
    NSString* loc = NSLocalizedString(@"mac_please_enter_a_title_for_new_group", @"Please enter a Title for your new Group");
    NSString* title = [[[MacAlerts alloc] init] input:loc defaultValue:kDefaultNewTitle allowEmpty:NO];
    
    if(title.length) {
        [self.viewModel addNewGroup:parent title:title];
    }
}

- (void)onNewItemAdded:(Node*)node openEntryDetailsWindowWhenDone:(BOOL)openEntryDetailsWindowWhenDone {
    self.itemsCache = nil; 
    self.searchField.stringValue = @""; 
    [self.outlineView reloadData];
    NSInteger row = [self findRowForItemExpandIfNecessary:node];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
    }

    if(openEntryDetailsWindowWhenDone) {
        [self openItemDetails:node newEntry:YES];
        [self expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:node];
    }    
}

- (IBAction)onDelete:(id)sender {
    NSArray<Node *> *items = [self getSelectedItems];
    if (items.count == 0) {
        return;
    }
    
    NSDictionary* grouped = [items groupBy:^id _Nonnull(Node * _Nonnull obj) {
        BOOL delete = [self.viewModel canRecycle:obj];
        return @(delete);
    }];

    const NSArray<Node*> *toBeDeleted = grouped[@(NO)];
    const NSArray<Node*> *toBeRecycled = grouped[@(YES)];

    if ( toBeDeleted == nil ) {
        [self postValidationRecycleAllItemsWithConfirmPrompt:toBeRecycled];
    }
    else {
        if ( toBeRecycled == nil ) {
            [self postValidationDeleteAllItemsWithConfirmPrompt:toBeDeleted];
        }
        else { 
            [self postValidationPartialDeleteAndRecycleItemsWithConfirmPrompt:toBeDeleted toBeRecycled:toBeRecycled];
        }
    }
}

- (void)postValidationPartialDeleteAndRecycleItemsWithConfirmPrompt:(const NSArray<Node*>*)toBeDeleted toBeRecycled:(const NSArray<Node*>*)toBeRecycled {
    [MacAlerts yesNo:NSLocalizedString(@"browse_vc_partial_recycle_alert_title", @"Partial Recycle")
  informativeText:NSLocalizedString(@"browse_vc_partial_recycle_alert_message", @"Some of the items you have selected cannot be recycled and will be permanently deleted. Is that ok?")
           window:self.view.window
       completion:^(BOOL yesNo) {
        if (yesNo) {
                   
                   
                   
                   [self.viewModel deleteItems:toBeDeleted];
                   
                   BOOL fail = ![self.viewModel recycleItems:toBeRecycled];
                   
                   if(fail) {
                       [MacAlerts info:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                    informativeText:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")
                             window:self.view.window
                         completion:nil];
                   }
               }
    }];
}

- (void)postValidationDeleteAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items {
    NSString* title = NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?");
    
    NSString* message;
    
    if (items.count > 1) {
        message = NSLocalizedString(@"browse_vc_are_you_sure_delete", @"Are you sure you want to permanently delete these item(s)?");
    }
    else {
        Node* item = items.firstObject;
        message = [NSString stringWithFormat:NSLocalizedString(@"browse_vc_are_you_sure_delete_fmt", @"Are you sure you want to permanently delete '%@'?"),
                   [self.viewModel dereference:item.title node:item]];
    }
    
    [MacAlerts yesNo:title informativeText:message window:self.view.window completion:^(BOOL yesNo) {
        if (yesNo) {
            [self.viewModel deleteItems:items];
        }
    }];
}

- (void)postValidationRecycleAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items {
    NSString* title = NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?");
    NSString* message;
    if (items.count > 1) {
        message = NSLocalizedString(@"browse_vc_are_you_sure_recycle", @"Are you sure you want to send these item(s) to the Recycle Bin?");
    }
    else {
        Node* item = items.firstObject;
        message = [NSString stringWithFormat:NSLocalizedString(@"mac_are_you_sure_recycle_bin_yes_no_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?"),
                                [self.viewModel dereference:item.title node:item]];
    }
    
    [MacAlerts yesNo:title informativeText:message window:self.view.window completion:^(BOOL yesNo) {
        if (yesNo) {
            BOOL fail = ![self.viewModel recycleItems:items];

            if(fail) {
               [MacAlerts info:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
            informativeText:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")
                     window:self.view.window
                 completion:nil];
            }
        }
    }];
}

- (IBAction)onLaunchUrl:(id)sender {
    Node* item = [self getCurrentSelectedItem];
    
    [self.viewModel launchUrl:item];
}

- (void)clearTouchId {
    NSLog(@"Clearing Touch ID data...");
    
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseMetadata.uuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForTouchIdEnrol = NO; 
        metadata.isTouchIdEnrolled = NO;
        [metadata resetConveniencePasswordWithCurrentConfiguration:nil];
    }];

    [self bindLockScreenUi];
}

- (IBAction)onGeneralDatabaseSettings:(id)sender {
    [self performSegueWithIdentifier:@"segueToDatabasePreferences" sender:@(0)];
}

- (IBAction)onConvenienceUnlockProperties:(id)sender {
    [self performSegueWithIdentifier:@"segueToDatabasePreferences" sender:@(1)];
}

- (IBAction)onCopyAsCsv:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.viewModel.database] encoding:NSUTF8StringEncoding];
    
    [[NSPasteboard generalPasteboard] setString:newStr forType:NSStringPboardType];
}

- (NSURL*)getFileThroughFileOpenDialog
{  
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    NSString* loc = NSLocalizedString(@"mac_choose_csv_file_import", @"Choose CSV file to Import");
    [panel setTitle:loc];
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
    NSString* loc = NSLocalizedString(@"mac_csv_file_must_contain_header_and_fields", @"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.");

    NSString* message = [NSString stringWithFormat:loc, kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderNotes];
   
    loc = NSLocalizedString(@"mac_csv_format_info_title", @"CSV Format");
    
    [MacAlerts info:loc
 informativeText:message
          window:self.view.window
      completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{[self importFromCsvFile];});
    }];
}

- (void)importFromCsvFile {
    NSURL* url = [self getFileThroughFileOpenDialog];
        
    if(url) {
        NSError *error = nil;
        NSArray *rows = [NSArray arrayWithContentsOfCSVURL:url options:CHCSVParserOptionsSanitizesFields | CHCSVParserOptionsUsesFirstLineAsKeys];
        
        if (rows == nil) {
            
            NSLog(@"error parsing file: %@", error);
            [MacAlerts error:error window:self.view.window];
            return;
        }
        else if(rows.count == 0){
            NSString* loc = NSLocalizedString(@"mac_csv_file_contains_zero_rows", @"CSV File Contains Zero Rows. Cannot Import.");
            [MacAlerts info:loc window:self.view.window];
        }
        else {
            CHCSVOrderedDictionary *firstRow = [rows firstObject];
            
            if([firstRow objectForKey:kCSVHeaderTitle] ||
               [firstRow objectForKey:kCSVHeaderUsername] ||
               [firstRow objectForKey:kCSVHeaderUrl] ||
               [firstRow objectForKey:kCSVHeaderEmail] ||
               [firstRow objectForKey:kCSVHeaderPassword] ||
               [firstRow objectForKey:kCSVHeaderNotes]) {
                NSString* loc = NSLocalizedString(@"mac_found_n_valid_rows_in_csv_file_prompt_to_import_fmt", @"Found %lu valid rows in CSV file. Are you sure you would like to import now?");
                NSString* message = [NSString stringWithFormat:loc, (unsigned long)rows.count];
                
                [MacAlerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                    if(yesNo) {
                        [self.viewModel importRecordsFromCsvRows:rows];

                        NSString* loc = NSLocalizedString(@"mac_csv_file_successfully_imported", @"CSV File Successfully Imported.");
                        [MacAlerts info:loc window:self.view.window];
                    }
                }];
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_no_valid_csv_rows_found", @"No valid rows found. Ensure CSV file contains a header row and at least one of the required fields.");

                [MacAlerts info:loc window:self.view.window];
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

- (void)onPreferencesChanged:(NSNotification*)notification {
    NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];

        if(self.viewModel == nil || self.viewModel.locked) {
            [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
            [self bindLockScreenUi];
        }
        else {
            Node* currentSelection = [self getCurrentSelectedItem];
                  
            self.itemsCache = nil; 

            [self bindColumnsToSettings];
            [self customizeOutlineView];

            [self.outlineView reloadData];

            [self selectItem:currentSelection];
        }
    });
}

static MutableOrderedDictionary* getSummaryDictionary(ViewModel* model) {
    MutableOrderedDictionary *ret = [[MutableOrderedDictionary alloc] init];
    
    MutableOrderedDictionary<NSString *,NSString *> *kvp = [model.metadata filteredKvpForUIWithFormat:model.format];
    
    for (NSString* key in kvp.allKeys) {
        NSString *value = kvp[key];
        [ret addKey:key andValue:value];
    }
    
    [ret addKey:NSLocalizedString(@"mac_database_summary_unique_usernames", @"Unique Usernames")
       andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.usernameSet.count]];
    [ret addKey:NSLocalizedString(@"mac_database_summary_unique_passwords", @"Unique Passwords")
       andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.passwordSet.count]];
    [ret addKey:NSLocalizedString(@"mac_database_summary_most_popular_username", @"Most Popular Username")
       andValue:model.mostPopularUsername ? model.mostPopularUsername : @"<None>"];
    [ret addKey:NSLocalizedString(@"mac_database_summary_number_of_entries", @"Number of Entries")
       andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.numberOfRecords]];
    [ret addKey:NSLocalizedString(@"mac_database_summary_number_of_folders", @"Number of Folders")
       andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.numberOfGroups]];
    
    return ret;
}

- (IBAction)onShowSafeSummary:(id)sender {
    [self.outlineView deselectAll:nil]; 
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.tableViewSummary) {
        MutableOrderedDictionary* dictionary = getSummaryDictionary(self.viewModel);
        return dictionary.count;
    }
    else if (tableView == self.attachmentsTable) {
        return self.sortedAttachmentsFilenames.count;
    }
    else {
        return self.customFields.count;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView == self.tableViewSummary) {
        NSTableCellView* cell = [self.tableViewSummary makeViewWithIdentifier:@"KeyCellIdentifier" owner:nil];

        MutableOrderedDictionary *dict = getSummaryDictionary(self.viewModel);
        
        NSString *key = dict.allKeys[row];
        NSString *value = dict[key];
        
        value = value == nil ? @"" : value; 
        
        cell.textField.stringValue = [tableColumn.identifier isEqualToString:@"KeyColumn"] ? key : value;
        
        return cell;
    }
    else if (tableView == self.attachmentsTable) {
        NSString* filename = self.sortedAttachmentsFilenames[row];
        DatabaseAttachment* dbAttachment = self.attachments[filename];

        BOOL isFileNameColumn = [tableColumn.identifier isEqualToString:@"filename"];
        NSString* cellId = isFileNameColumn ? @"AttachmentFileNameCellIdentifier" : @"AttachmentFileSizeCellIdentifier";
        NSTableCellView* cell = [self.attachmentsTable makeViewWithIdentifier:cellId owner:nil];

        cell.textField.stringValue = isFileNameColumn ? filename : [NSByteCountFormatter stringFromByteCount:dbAttachment.length countStyle:NSByteCountFormatterCountStyleFile];
        
        if(self.attachmentsIconCache == nil) {
            self.attachmentsIconCache = @{};
            [self buildAttachmentsIconCache];
        }
        
        NSImage* cachedIcon = self.attachmentsIconCache[dbAttachment.digestHash];
        if(cachedIcon && Settings.sharedInstance.showAttachmentImagePreviewsOnQuickViewPanel) {
            cell.imageView.image = cachedIcon;
        }
        else {
            NSImage* img = [[NSWorkspace sharedWorkspace] iconForFileType:filename.pathExtension];
            cell.imageView.image = img;
        }

        return cell;
    }
    else  {
        BOOL isKeyColumn = [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"];
        NSString* cellId = isKeyColumn ? @"CustomFieldKeyCellIdentifier" : @"CustomFieldValueCellIdentifier";
        
        CustomField* field = [self.customFields objectAtIndex:row];
        
        if(isKeyColumn) {
            NSTableCellView* cell = [self.customFieldsTable makeViewWithIdentifier:cellId owner:nil];
            cell.textField.stringValue = field.key;
            return cell;
        }
        else {
            CustomFieldTableCellView* cell = [self.customFieldsTable makeViewWithIdentifier:cellId owner:nil];
            
            Node* it = [self getCurrentSelectedItem];
            NSString* derefed = [self maybeDereference:field.value node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
            
            cell.value = derefed;
            cell.protected = field.protected && !(derefed.length == 0 && !self.viewModel.concealEmptyProtectedFields);
            cell.valueHidden = field.protected && !(derefed.length == 0 && !self.viewModel.concealEmptyProtectedFields); 
            
            return cell;
        }
    }
}

- (void)buildAttachmentsIconCache {
    NSArray *workingCopy = self.viewModel.database.attachmentPool;
    NSMutableDictionary *tmp = @{}.mutableCopy;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0;i<workingCopy.count;i++) {
            DatabaseAttachment* dbAttachment = workingCopy[i];
            
            NSData* data = [NSData dataWithContentsOfStream:[dbAttachment getPlainTextInputStream]];
            NSImage* img = [[NSImage alloc] initWithData:data];
            if(img) {
                img = scaleImage(img, CGSizeMake(17, 17));
                if (img.isValid) {
                    tmp[@(i)] = img;
                }
            }
        }
        
        self.attachmentsIconCache = tmp.copy;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.attachmentsTable reloadData];
            [self.view setNeedsDisplay:YES];
        });
    });
}



- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    NSUInteger idx = self.attachmentsTable.selectedRow;
    if(idx == -1) {
        return 0;
    }
    
    return 1;
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    if(index != 0) {
        return nil;
    }
    
    NSUInteger idx = self.attachmentsTable.selectedRow;
    if(idx == -1) {
        return nil;
    }
    NSString* filename = self.sortedAttachmentsFilenames[idx];
    
    DatabaseAttachment* dbAttachment = self.attachments[filename];
    
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

- (IBAction)onPreviewQuickViewAttachment:(id)sender {
    NSInteger selected = self.attachmentsTable.selectedRow;
    if(selected >= 0 && selected < self.sortedAttachmentsFilenames.count) {
        [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:self];
    }
}

- (IBAction)onSaveQuickViewAttachmentAs:(id)sender {
    NSInteger selected = self.attachmentsTable.selectedRow;
    if(selected < 0 || selected >= self.sortedAttachmentsFilenames.count) {
        return;
    }
    
    NSString* filename = self.sortedAttachmentsFilenames[selected];
    
    
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = filename;
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            DatabaseAttachment* dbAttachment = self.attachments[filename];
            NSInputStream* inStream = [dbAttachment getPlainTextInputStream];
            NSOutputStream* outStream = [NSOutputStream outputStreamToFileAtPath:savePanel.URL.path append:NO];

            [StreamUtils pipeFromStream:inStream to:outStream];
            
            [savePanel orderOut:self];
        }
    }];
}

- (IBAction)onSetItemIcon:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(!item) {
        return;
    }
    
    [self onEditNodeIcon:item];
}

- (void)onEditNodeIcon:(Node*)item {
    if(self.viewModel.format == kPasswordSafe) {
        return;
    }
    
    __weak ViewController* weakSelf = self;
    self.selectPredefinedIconController = [[SelectPredefinedIconController alloc] initWithWindowNibName:@"SelectPredefinedIconController"];
    self.selectPredefinedIconController.customIcons = self.viewModel.customIcons.allObjects;
    self.selectPredefinedIconController.hideSelectFile = self.viewModel.format == kKeePass1;
    self.selectPredefinedIconController.onSelectedItem = ^(NodeIcon * _Nullable icon, BOOL showFindFavIcons) { 
        if(showFindFavIcons) {
            [weakSelf showFindFavIconsForItem:item];
        }
        else {
            [weakSelf.viewModel setItemIcon:item icon:icon];
        }
    };

    
    [self.view.window beginSheet:self.selectPredefinedIconController.window  completionHandler:nil];
}

- (IBAction)onViewItemHistory:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil ||
       item.isGroup || item.fields.keePassHistory.count == 0 ||
       (!(self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4))) {
        return;
    }

    [self performSegueWithIdentifier:@"segueToItemHistory" sender:@{ kItemKey : item }];
}

- (IBAction)refreshOtpCode:(id)sender {
    if([self isColumnVisible:kTOTPColumn]) {
        NSScrollView* scrollView = [self.outlineView enclosingScrollView];
        CGRect visibleRect = scrollView.contentView.visibleRect;
        NSRange rowRange = [self.outlineView rowsInRect:visibleRect];
        NSInteger totpColumnIndex = [self.outlineView columnWithIdentifier:kTOTPColumn];

        if(rowRange.length) {
            [self.outlineView beginUpdates];
            for(int i=0;i<rowRange.length;i++) {
                Node* item = (Node*)[self.outlineView itemAtRow:rowRange.location + i];
                if(item.fields.otpToken) {
                    [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowRange.location + i]
                                                columnIndexes:[NSIndexSet indexSetWithIndex:totpColumnIndex]];

                }
            }
            [self.outlineView endUpdates];
        }
    }
    
    [self refreshQuickViewOtpCode];
}

- (void)refreshQuickViewOtpCode {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil || item.isGroup) {
        return;
    }
    
    if( self.viewModel.showTotp && item.fields.otpToken ) {
        self.totpRow.hidden = NO;
        
        
        
        self.textFieldTotp.stringValue = item.fields.otpToken.password;
        
        uint64_t remainingSeconds = [self getTotpRemainingSeconds:item];
        
        self.textFieldTotp.textColor = (remainingSeconds < 5) ? NSColor.redColor : (remainingSeconds < 9) ? NSColor.orangeColor : NSColor.controlTextColor;

        self.progressTotp.minValue = 0;
        self.progressTotp.maxValue = item.fields.otpToken.period;
        self.progressTotp.doubleValue = remainingSeconds;
    }
    else {
        self.totpRow.hidden = YES;
        self.textFieldTotp.stringValue = @"000000";
    }
}

- (uint64_t)getTotpRemainingSeconds:(Node*)item {
    return item.fields.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)item.fields.otpToken.period);
}

- (IBAction)onSetTotp:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil || item.isGroup) {
        return;
    }
    
    NSString* loc = NSLocalizedString(@"mac_please_enter_totp_secret_or_otpauth_url", @"Please enter the secret or an OTPAuth URL");
    NSString* response = [[MacAlerts alloc] input:loc defaultValue:@"" allowEmpty:NO];
    
    if(response) {
        NSString* loc = NSLocalizedString(@"mac_is_this_a_stream_token_yes_no", @"Is this a Steam Token? (Say 'No' if you're unsure)");
        [MacAlerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
            [self.viewModel setTotp:item otp:response steam:yesNo];
        }];
    }
}

- (IBAction)onClearTotp:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil || item.isGroup || !item.fields.otpToken) {
        return;
    }
    
    [self.viewModel clearTotp:item];
}

- (void)showPopupChangeToastNotification:(NSString*)message {
    if( !self.viewModel.showChangeNotifications ) {
        return;
    }
        
    [self showToastNotification:message error:NO];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.view.window.isMiniaturized ) {
        NSLog(@"Not Showing Popup Change notification because window is miniaturized");
        return;
    }

    [self showToastNotification:message error:error yOffset:150.f];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error yOffset:(CGFloat)yOffset {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSColor *defaultColor = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
        NSColor *errorColor = [NSColor colorWithDeviceRed:1 green:0.55 blue:0.05 alpha:0.90];

        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = message;
        hud.color = error ? errorColor : defaultColor;
        hud.mode = MBProgressHUDModeText;
        hud.margin = 10.f;
        hud.yOffset = yOffset;
        hud.removeFromSuperViewOnHide = YES;
        hud.dismissible = YES;
        
        NSTimeInterval delay = error ? 3.0f : 1.0f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [hud hide:YES];
        });
    });
}

- (IBAction)onShowHideQuickView:(id)sender {
    self.viewModel.showQuickView = !self.viewModel.showQuickView;
    self.quickViewColumn.hidden = !self.viewModel.showQuickView;
    [self bindQuickViewButton];
}

- (void)bindQuickViewButton {
    NSString* loc = self.quickViewColumn.hidden ?
        NSLocalizedString(@"mac_show_quick_view_panel", @"Show Quick View Panel") :
        NSLocalizedString(@"mac_hide_quick_view_panel", @"Hide Quick View Panel");

    [self.buttonToggleQuickViewPanel setTitle:loc];
}

- (IBAction)onCollapseAll:(id)sender {
    [self.outlineView collapseItem:nil collapseChildren:YES];
}

- (IBAction)onExpandAll:(id)sender {
    [self.outlineView expandItem:nil expandChildren:YES];
}

- (IBAction)onPrintDatabase:(id)sender {
    NSString* loc = NSLocalizedString(@"mac_database_print_emergency_sheet_fmt", @"%@ Emergency Sheet");
    
    NSString* databaseName = [NSString stringWithFormat:loc, self.databaseMetadata.nickName];
    NSString* htmlString = [self.viewModel getHtmlPrintString:databaseName];

    
    
    
    
    
    

    
    
    
    
    WebView *webView = [[WebView alloc] init];
    [webView.mainFrame loadHTMLString:htmlString baseURL:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:webView.mainFrame.frameView.documentView
                                                                   printInfo:NSPrintInfo.sharedPrintInfo];
                                  
        [printOp runOperation];
    });
}

- (IBAction)onDownloadFavIcons:(id)sender {
    Node* item = [self getCurrentSelectedItem];

    [self showFindFavIconsForItem:item];
}

- (void)showFindFavIconsForItem:(Node*)item {
    [self performSegueWithIdentifier:@"segueToFavIconDownloader" sender:item];
}



- (void)refreshKeyFileDropdown {
    [self.keyFilePopup.menu removeAllItems];
    
    
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_key_file_none", @"None")
                                      action:@selector(onSelectNoneKeyFile)
                               keyEquivalent:@""];
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_browse_for_key_file", @"Browse...")
                                      action:@selector(onBrowseForKeyFile)
                               keyEquivalent:@""];
    
    

    DatabaseMetadata *database = self.databaseMetadata;
    NSURL* configuredUrl;
    if(database && database.keyFileBookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:database.keyFileBookmark
                                                   readOnly:YES updatedBookmark:&updatedBookmark
                                                      error:&error];
            
        if(!configuredUrl) {
            NSLog(@"getUrlFromBookmark: [%@]", error);
        }
        else {
           
        }
        
        if(updatedBookmark) {
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                                    touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.keyFileBookmark = updatedBookmark;
            }];
        }
    }

    
    
    NSString* bookmark = self.selectedKeyFileBookmark;
    NSURL* currentlySelectedUrl;
    if(bookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        currentlySelectedUrl = [BookmarksHelper getUrlFromBookmark:bookmark readOnly:YES updatedBookmark:&updatedBookmark error:&error];
        
        if(currentlySelectedUrl == nil) {
            self.selectedKeyFileBookmark = nil;
        }
        
        if(updatedBookmark) {
            self.selectedKeyFileBookmark = updatedBookmark;
        }
    }

    if (configuredUrl) {
        NSString* configuredTitle = Settings.sharedInstance.hideKeyFileNameOnLockScreen ?
                                        NSLocalizedString(@"mac_key_file_configured_but_filename_hidden", @"[Configured]") :
                                        [NSString stringWithFormat:NSLocalizedString(@"mac_key_file_filename_configured_fmt", @"%@ [Configured]"), configuredUrl.lastPathComponent];
        
        [self.keyFilePopup.menu addItemWithTitle:configuredTitle action:@selector(onSelectPreconfiguredKeyFile) keyEquivalent:@""];
    
        if(currentlySelectedUrl) {
            if(![configuredUrl.absoluteString isEqualToString:currentlySelectedUrl.absoluteString]) {
                NSString* filename = currentlySelectedUrl.lastPathComponent;
                
                [self.keyFilePopup.menu addItemWithTitle:filename action:nil keyEquivalent:@""];
                [self.keyFilePopup selectItemAtIndex:3];
            }
            else {
                [self.keyFilePopup selectItemAtIndex:2];
            }
        }
    }
    else if(currentlySelectedUrl) {
        [self.keyFilePopup.menu addItemWithTitle:currentlySelectedUrl.lastPathComponent action:nil keyEquivalent:@""];
        [self.keyFilePopup selectItemAtIndex:2];
    }
    else {
        [self.keyFilePopup selectItemAtIndex:0];
    }
}

- (void)onBrowseForKeyFile {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"Open Key File: %@", openPanel.URL);
            
            NSError* error;
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:openPanel.URL readOnly:YES error:&error];
            
            if(!bookmark) {
                [MacAlerts error:error window:self.view.window];
                [self refreshKeyFileDropdown];
                return;
            }

            self.selectedKeyFileBookmark = bookmark;
        }

        [self refreshKeyFileDropdown];
    }];
}

- (void)onSelectNoneKeyFile {
    self.selectedKeyFileBookmark = nil;
    [self refreshKeyFileDropdown];
}

- (void)onSelectPreconfiguredKeyFile {
    self.selectedKeyFileBookmark = self.databaseMetadata.keyFileBookmark;
    [self refreshKeyFileDropdown];
}



- (BOOL)keyFileIsSet {
    return self.selectedKeyFileBookmark != nil;
}

- (DatabaseFormat)getHeuristicFormat {
    BOOL probablyPasswordSafe = [self.viewModel.fileUrl.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; 

    return heuristicFormat;
}

- (BOOL)manualCredentialsAreValid {
    DatabaseFormat heuristicFormat = [self getHeuristicFormat];
    
    BOOL formatAllowsEmptyOrNone =  heuristicFormat == kKeePass4 ||
                                    heuristicFormat == kKeePass ||
                                    heuristicFormat == kFormatUnknown ||
                                    (heuristicFormat == kKeePass1 && [self keyFileIsSet]);
    
    return self.textFieldMasterPassword.stringValue.length || (formatAllowsEmptyOrNone && Settings.sharedInstance.allowEmptyOrNoPasswordEntry);
}

- (IBAction)controlTextDidChange:(NSSecureTextField *)obj {

    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlockWithPassword setEnabled:enabled];
}

- (void)bindLockScreenUi {
    self.checkboxAllowEmpty.state = Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSOnState : NSOffState;
    self.upgradeButton.hidden = Settings.sharedInstance.fullVersion;
    
    if (!Settings.sharedInstance.fullVersion && !Settings.sharedInstance.freeTrial) {
        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:self.upgradeButton.title];
        NSUInteger len = [attrTitle length];
        NSRange range = NSMakeRange(0, len);
        [attrTitle addAttribute:NSForegroundColorAttributeName value:NSColor.systemRedColor range:range];
        [attrTitle addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:NSFont.systemFontSize] range:range];

        [attrTitle fixAttributesInRange:range];
        [self.upgradeButton setAttributedTitle:attrTitle];
    }
    
    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlockWithPassword setEnabled:enabled];
        
    [self bindBiometricButtonsOnLockScreen];
        
    [self refreshKeyFileDropdown];
    
    [self bindYubiKeyOnLockScreen];
}

- (void)bindBiometricButtonsOnLockScreen {
    DatabaseMetadata* metaData = self.databaseMetadata;
    
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;

    BOOL convenienceMethodPossible = (watchAvailable && self.databaseMetadata.isWatchUnlockEnabled) || (touchAvailable && self.databaseMetadata.isTouchIdEnabled);

    BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    NSString* convenienceTitle;
    if ( (self.databaseMetadata.isTouchIdEnabled && touchAvailable) && (self.databaseMetadata.isWatchUnlockEnabled && watchAvailable) ) {
        NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
        convenienceTitle = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    }
    else if ( self.databaseMetadata.isTouchIdEnabled && touchAvailable) {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_touch_id", @"Unlock with Touch ID");
    }
    else {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_apple_watch", @"Unlock with Watch");
    }
    
    [self.buttonUnlockWithTouchId setTitle:convenienceTitle];
    self.buttonUnlockWithTouchId.hidden = NO;
    self.buttonUnlockWithTouchId.enabled = YES;

    if( convenienceEnabled ) {
        if( metaData.isTouchIdEnrolled ) {
            if( convenienceMethodPossible ) {
                if ( featureAvailable ) {
                    if( passwordAvailable ) {
                        [self.buttonUnlockWithTouchId setKeyEquivalent:@"\r"];
                    }
                    else {
                        self.buttonUnlockWithTouchId.enabled = NO;
                        [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_expired", @"Convenience Unlock Expired")];
                    }
                }
                else {
                    [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_pro_only", @"Biometrics/Watch Unlock (Pro Only)")];
                    self.buttonUnlockWithTouchId.enabled = NO;
                }
            }
            else {
                [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_bio_unavailable", @"Biometrics/Watch Unavailable")];
                self.buttonUnlockWithTouchId.enabled = NO;
            }
        }
        else {
            self.buttonUnlockWithTouchId.hidden = YES;
        }
    }
    else {
        self.buttonUnlockWithTouchId.hidden = YES;
    }
}

- (IBAction)onAllowEmptyChanged:(id)sender {
    Settings.sharedInstance.allowEmptyOrNoPasswordEntry = self.checkboxAllowEmpty.state == NSOnState;
    
    [self bindLockScreenUi];
}

- (IBAction)onUpgrade:(id)sender {
    AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    [appDelegate showUpgradeModal:0];
}
            
- (void)bindYubiKeyOnLockScreen {
    self.currentYubiKeySerial = nil;
    self.currentYubiKeySlot1IsBlocking = NO;
    self.currentYubiKeySlot2IsBlocking = NO;
    
    

    [self.yubiKeyPopup.menu removeAllItems];

    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    [self.yubiKeyPopup.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];
    self.yubiKeyPopup.enabled = NO;
    
    [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yk) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKey:yk];
        });}];
}

- (void)onGotAvailableYubiKey:(YubiKeyData*)yk {
    self.currentYubiKeySerial = yk.serial;
    self.currentYubiKeySlot1IsBlocking = yk.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking;
    self.currentYubiKeySlot2IsBlocking = yk.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking;
    
    [self.yubiKeyPopup.menu removeAllItems];

    if (!Settings.sharedInstance.fullVersion && !Settings.sharedInstance.freeTrial) {
        NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");
        
        [self.yubiKeyPopup.menu addItemWithTitle:loc
                                          action:nil
                                   keyEquivalent:@""];

        [self.yubiKeyPopup selectItemAtIndex:0];
        return;
    }
    
    
    
    NSString* loc = NSLocalizedString(@"generic_none", @"None");
    NSMenuItem* noneMenuItem = [self.yubiKeyPopup.menu addItemWithTitle:loc
                                                                 action:@selector(onSelectNoYubiKey)
                                                          keyEquivalent:@""];

    NSMenuItem* slot1MenuItem;
    NSMenuItem* slot2MenuItem;
    
    
    
    BOOL availableSlots = NO;
    NSString* loc1 = NSLocalizedString(@"mac_yubikey_slot_n_touch_required_fmt", @"Yubikey Slot %ld (Touch Required)");
    NSString* loc2 = NSLocalizedString(@"mac_yubikey_slot_n_fmt", @"Yubikey Slot %ld");

    if ( [self yubiKeyCrIsSupported:yk.slot1CrStatus] ) {
        NSString* loc = self.currentYubiKeySlot1IsBlocking ? loc1 : loc2;
        NSString* locFmt = [NSString stringWithFormat:loc, 1];
        slot1MenuItem = [self.yubiKeyPopup.menu addItemWithTitle:locFmt
                                                          action:@selector(onSelectYubiKeySlot1)
                                                   keyEquivalent:@""];
        availableSlots = YES;
    }
    
    if ( [self yubiKeyCrIsSupported:yk.slot2CrStatus] ) {
        NSString* loc = self.currentYubiKeySlot2IsBlocking ? loc1 : loc2;
        NSString* locFmt = [NSString stringWithFormat:loc, 2];
        
        slot2MenuItem = [self.yubiKeyPopup.menu addItemWithTitle:locFmt
                                                          action:@selector(onSelectYubiKeySlot2)
                                                   keyEquivalent:@""];
        availableSlots = YES;
    }
    
    BOOL selectedItem = NO;

    if (availableSlots) {
        if (self.selectedYubiKeyConfiguration && ([self.selectedYubiKeyConfiguration.deviceSerial isEqualToString:yk.serial])) {
            
            
            YubiKeySlotCrStatus slotStatus = self.selectedYubiKeyConfiguration.slot == 1 ? yk.slot1CrStatus : yk.slot2CrStatus;
            
            if ([self yubiKeyCrIsSupported:slotStatus]) {
                
                if (self.selectedYubiKeyConfiguration.slot == 1 && slot1MenuItem) {
                    [self.yubiKeyPopup selectItem:slot1MenuItem];
                    selectedItem = YES;
                }
                else if (self.selectedYubiKeyConfiguration.slot == 2 && slot2MenuItem){
                    [self.yubiKeyPopup selectItem:slot2MenuItem];
                    selectedItem = YES;
                }
            }
        }
    }
    
    if (!selectedItem) { 
        [self.yubiKeyPopup selectItem:noneMenuItem];
        self.selectedYubiKeyConfiguration = nil;
    }
    
    self.yubiKeyPopup.enabled = YES;
}

- (BOOL)yubiKeyCrIsSupported:(YubiKeySlotCrStatus)status {
    return status == YubiKeySlotCrStatusSupportedBlocking || status == YubiKeySlotCrStatusSupportedNonBlocking;
}

- (void)onSelectNoYubiKey {
    self.selectedYubiKeyConfiguration = nil;
}

- (void)onSelectYubiKeySlot1 {
    self.selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    self.selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    self.selectedYubiKeyConfiguration.slot = 1;
}

- (void)onSelectYubiKeySlot2 {
    self.selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    self.selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    self.selectedYubiKeyConfiguration.slot = 2;
}

- (IBAction)onViewAllDatabases:(id)sender {
    [DatabasesManagerVC show];
}

- (IBAction)onDuplicateEntry:(id)sender {
    NSLog(@"onDuplicateEntry");
    
    Node* item = nil;
    
    if( self.viewModel && !self.viewModel.locked ) {
        item = [self getCurrentSelectedItem];
    }
    
    if ( item ) {
        Node* destinationItem = item.parent ? item.parent : self.viewModel.rootGroup;
    
        Node* dupe = [item duplicate:[item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")]];
        [item touch:NO touchParents:YES];
        if ( [self.viewModel addChildren:@[dupe] parent:destinationItem] ) {
            NSString* loc = NSLocalizedString(@"mac_item_duplicated", @"Item Duplicated");
            [self showPopupChangeToastNotification:loc];
        }
    }
}



- (void)cleanupWormhole {
    if ( self.wormhole ) {

        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId];

        NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusRequestId, self.databaseMetadata.uuid];
        [self.wormhole stopListeningForMessageWithIdentifier:requestId];
        
        NSString* convRequestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, self.databaseMetadata.uuid];
        [self.wormhole stopListeningForMessageWithIdentifier:convRequestId];

        [self.wormhole clearAllMessageContents];
        self.wormhole = nil;
    }
}

- (void)listenToAutoFillWormhole {
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                         optionalDirectory:kAutoFillWormholeName];

    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ([userSession isEqualToString:NSUserName()]) { 
            NSString* json = dict ? dict[@"id"] : nil;
            [self onQuickTypeAutoFillWormholeRequest:json];
        }
    }];
    
    
    
    NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusRequestId, self.databaseMetadata.uuid];

    [self.wormhole listenForMessageWithIdentifier:requestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [self onAutoFillDatabaseUnlockedStatusWormholeRequest:databaseId];
        }
    }];
    
    

    NSString* convRequestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, self.databaseMetadata.uuid];

    [self.wormhole listenForMessageWithIdentifier:convRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [self onAutoFillWormholeMasterCredentialsRequest:databaseId];
        }
    }];
}

- (void)onAutoFillWormholeMasterCredentialsRequest:(NSString*)databaseId {
    if ( self.viewModel && !self.viewModel.locked && databaseId) {
        if (!self.databaseMetadata.quickWormholeFillEnabled ) {
            return;
        }

        if ( [self.databaseMetadata.uuid isEqualToString:databaseId] ) {
            NSLog(@"Responding to Conv Unlock Req for Database - [%@]-%@", self, databaseId);

            NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockResponseId, databaseId];
            NSString* secretStoreId = NSUUID.UUID.UUIDString;
            NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
            [SecretStore.sharedInstance setSecureObject:self.viewModel.compositeKeyFactors.password
                                          forIdentifier:secretStoreId
                                              expiresAt:expiry];

            [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(),
                                                 @"secret-store-id" : secretStoreId }
                                  identifier:responseId];
        }
    }
}

- (void)onAutoFillDatabaseUnlockedStatusWormholeRequest:(NSString*)databaseId {
    if ( self.viewModel && !self.viewModel.locked && databaseId) {
        if (!self.databaseMetadata.quickWormholeFillEnabled ) {
            return;
        }
        
        if ( [self.databaseMetadata.uuid isEqualToString:databaseId] ) {


            NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusResponseId, databaseId];

            [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(), @"unlocked" : databaseId }
                                  identifier:responseId];
        }
    }
}

- (void)onQuickTypeAutoFillWormholeRequest:(NSString*)json {
    if ( self.viewModel && !self.viewModel.locked && json) {
        QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:json];
        
        if( identifier && self.databaseMetadata && [self.databaseMetadata.uuid isEqualToString:identifier.databaseId] ) {
            if (!self.databaseMetadata.quickWormholeFillEnabled || !self.databaseMetadata.quickTypeEnabled ) {
                return;
            }
            
            
            
            DatabaseModel* model = self.viewModel.database;
            Node* node = [model.effectiveRootGroup.allChildRecords firstOrDefault:^BOOL(Node * _Nonnull obj) {
                return [obj.uuid.UUIDString isEqualToString:identifier.nodeId]; 
            }];

            NSString* secretStoreId = NSUUID.UUID.UUIDString;

            if(node) {


                NSString* user = [model dereference:node.fields.username node:node];
                NSString* password = [model dereference:node.fields.password node:node];
                NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
                
                NSDictionary* securePayload = @{
                    @"user" : user,
                    @"password" : password,
                    @"totp" : totp,
                };
                
                NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
                [SecretStore.sharedInstance setSecureObject:securePayload forIdentifier:secretStoreId expiresAt:expiry];
            }
            else {

            }
            
            [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(),
                                                @"success" : @(node != nil),
                                                @"secret-store-id" : secretStoreId }
                                  identifier:kAutoFillWormholeQuickTypeResponseId];
        }
    }
}



- (void)onModelLongRunningOpStart:(NSNotification*)notification {
    if( notification.object != self.viewModel.document ) {
        return;
    }
    


    NSString* status = (NSString*)notification.userInfo[kNotificationUserInfoLongRunningOperationStatus];



    [self showProgressModal:status];
}

- (void)onModelLongRunningOpDone:(NSNotification*)notification {
    if( notification.object != self.viewModel.document ) {
        return;
    }

    NSLog(@"onModelLongRunningOpDone notification.object = [%@]", notification.object);

    [self hideProgressModal];
}

- (void)onFullModelReloadNotification:(NSNotification*)notification {
    if( notification.object != self.viewModel.document ) {
        return;
    }



    dispatch_async(dispatch_get_main_queue(), ^{
        [self fullModelReload];
    });
}

- (void)onSyncDone:(NSNotification*)notification {
    if( notification.object != self.viewModel.document ) {
        return;
    }

    NSLog(@"onSyncDone notification.object = [%@]", notification.object);

    NSNumber* r = notification.userInfo[@"result"];
    NSNumber* l = notification.userInfo[@"localWasChanged"];
    
    SyncAndMergeResult result = r.integerValue;
    BOOL localWasChanged = l.boolValue;
    NSError* error = notification.userInfo[@"error"];
       
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( result == kSyncAndMergeResultUserInteractionRequired ) {
            NSLog(@"Background sync failed, will now try an interactive sync...");
            [self.document performFullInteractiveSync:self key:self.viewModel.compositeKeyFactors];
        }
        else if ( error ) {
            NSString* message = [NSString stringWithFormat:@"%@: %@",
                                 NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error"),
                                 error.localizedDescription];
            [self showToastNotification:message error:YES];
        }
        else {
            [self showToastNotification:NSLocalizedString(@"notification_sync_successful", @"Sync Successful") error:NO];
            
            if ( localWasChanged ) {
                NSLog(@"Sync successful and local was changed, reloading...");
                [self.document reloadFromLocalWorkingCopy:self.viewModel.compositeKeyFactors
                                             selectedItem:[self selectedItemSerializationId]];
            }
        }
    });
}

- (void)onFileChangedByOtherApplication:(NSNotification*)notification {
    if( notification.object != self.viewModel.document ) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self onDatabaseChangedByExternalOther];
    });
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];



    Node* item = nil;
    
    if(self.viewModel && !self.viewModel.locked) {
        item = [self getCurrentSelectedItem];
    }
    
    if (theAction == @selector(onViewItemDetails:)) {
        return item != nil; 
    }
    else if ( theAction == @selector(onVCToggleReadOnly:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.isEffectivelyReadOnly ? NSControlStateValueOn : NSControlStateValueOff;
        return !self.viewModel.offlineMode; 
    }
    else if ( theAction == @selector(onVCToggleOfflineMode:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.databaseMetadata.offlineMode ? NSControlStateValueOn : NSControlStateValueOff;
        return !self.databaseMetadata.isLocalDeviceDatabase;
    }
    else if ( theAction == @selector(onVCToggleLaunchAtStartup:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.databaseMetadata.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleStartInSearchMode:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.startWithSearch ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowVerticalGridlines:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.showVerticalGrid ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowHorizontalGridlines:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.showHorizontalGrid ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowAlternatingGridRows:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.showAlternatingRows ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowTotpCodes:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.showTotp ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowEditToasts:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = self.viewModel.showChangeNotifications ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if (theAction == @selector(onDuplicateEntry:)) {
        return item != nil && !self.viewModel.isEffectivelyReadOnly; 
    }
    else if (theAction == @selector(copy:)) {
        return item != nil;
    }
    else if (theAction == @selector(onCopySelectedItemsToClipboard:)) {
        return item != nil;
    }
    else if (theAction == @selector(paste:)) {
        NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
        NSData* blah = [pasteboard dataForType:kDragAndDropExternalUti];
        NSLog(@"Validate Paste - %d", blah != nil);
        return blah != nil && !self.viewModel.isEffectivelyReadOnly;
    }
    else if (theAction == @selector(onDelete:)) {
        if(self.outlineView.selectedRowIndexes.count > 1) {
            NSMenuItem* mi = (NSMenuItem*)anItem;
            NSString* loc = NSLocalizedString(@"mac_menu_item_delete_items", @"Delete Items");
            [mi setTitle:loc];
        }
        else {
            NSMenuItem* mi = (NSMenuItem*)anItem;
            NSString* loc = NSLocalizedString(@"mac_menu_item_delete_item", @"Delete Item");
            [mi setTitle:loc];
        }
        

        
        return item != nil && self.view.window.firstResponder == self.outlineView && !self.viewModel.isEffectivelyReadOnly; 
    }
    else if(theAction == @selector(onCreateGroup:) ||
            theAction == @selector(onCreateRecord:)) {
        return self.viewModel && !self.viewModel.locked && !self.viewModel.isEffectivelyReadOnly;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onImportFromCsvFile:)) {
        return self.viewModel && !self.viewModel.locked && !self.viewModel.isEffectivelyReadOnly;
    }
    else if (theAction == @selector(onCopyAsCsv:) ||
             theAction == @selector(onLock:)) {
        return self.viewModel && !self.viewModel.locked;
    }
    else if (theAction == @selector(onShowSafeSummary:)) {
        return self.viewModel && !self.viewModel.locked;
    }
    else if (theAction == @selector(onFind:)) {
        return self.viewModel && !self.viewModel.locked;
            
    }
    else if(theAction == @selector(onLaunchUrl:) ||
            theAction == @selector(onCopyUrl:)) {
        return item && !item.isGroup;
    }
    else if (theAction == @selector(onCopyTitle:)) {
        return item && !item.isGroup;
    }
    else if (theAction == @selector(onCopyUsername:)) {
        return item && !item.isGroup;
    }
    else if (theAction == @selector(onCopyEmail:)) {
        return item && !item.isGroup && self.viewModel.format == kPasswordSafe;
    }
    else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
        return item && !item.isGroup && item.fields.password.length;
    }
    else if (theAction == @selector(onCopyPassword:)) {
        return item && !item.isGroup && item.fields.password.length;
    }
    else if (theAction == @selector(onCopyTotp:)) {
        return item && !item.isGroup && item.fields.otpToken;
    }
    else if (theAction == @selector(onCopyNotes:)) {
        return item && !item.isGroup && self.textViewNotes.textStorage.string.length;
    }
    else if (theAction == @selector(onConvenienceUnlockProperties:)) {
        return self.viewModel && !self.viewModel.locked;
    }
    else if (theAction == @selector(onGeneralDatabaseSettings:)) {
        return self.viewModel && !self.viewModel.locked;
    }
    else if (theAction == @selector(saveDocument:)) {
        return !self.viewModel.locked && !self.viewModel.isEffectivelyReadOnly;
    }
    else if (theAction == @selector(onSetItemIcon:)) {
        return item != nil && self.viewModel.format != kPasswordSafe && !self.viewModel.isEffectivelyReadOnly;
    }
    else if(theAction == @selector(onSetTotp:)) {
        return item && !item.isGroup && !self.viewModel.isEffectivelyReadOnly;
    }
    else if(theAction == @selector(onClearTotp:)) {
        return item && !item.isGroup && item.fields.otpToken && !self.viewModel.isEffectivelyReadOnly;
    }
    else if (theAction == @selector(onViewItemHistory:)) {
        return
            item != nil &&
            !item.isGroup &&
            item.fields.keePassHistory.count > 0 &&
            (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    }
    else if(theAction == @selector(onOutlineHeaderColumnsChanged:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = [self isColumnVisible:menuItem.identifier];
        return [self isColumnAvailableForModel:menuItem.identifier];
    }
    else if(theAction == @selector(onPrintDatabase:)) {
        return self.viewModel && !self.viewModel.locked;
    }
    else if (theAction == @selector(onDownloadFavIcons:)) {
        return !self.viewModel.locked && !self.viewModel.isEffectivelyReadOnly && (item == nil || ((self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4) && (item.isGroup || item.fields.url.length)));
    }
    else if (theAction == @selector(onPreviewQuickViewAttachment:)) {
        return !self.viewModel.locked && item != nil && !item.isGroup && self.viewModel.format != kPasswordSafe && self.sortedAttachmentsFilenames.count > 0 && self.attachmentsTable.selectedRow != -1;
    }
    else if (theAction == @selector(onSaveQuickViewAttachmentAs:)) {
        return !self.viewModel.locked && item != nil && !item.isGroup && self.viewModel.format != kPasswordSafe && self.sortedAttachmentsFilenames.count > 0 && self.attachmentsTable.selectedRow != -1;
    }
    
    return YES;
}

- (id)copy:(id)sender {
    NSLog(@"ViewController::copy");
    
    NSArray<Node*>* selected = [self getSelectedItems];
    
    if ( selected.count == 0) {
        NSLog(@"Nothing selected!");
        return nil;
    }
    
    if (selected.count == 1 && !selected.firstObject.isGroup ) {
        NSLog(@"Only one selected item and non group... copying password");
        [self onCopyPassword:nil];
    }
    else {
        NSLog(@"Multiple selected or group... copying items to clipboard");
        [self onCopySelectedItemsToClipboard:nil];
    }
    
    return nil;
}

- (id)paste:(id)sender {
    NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    NSData* blah = [pasteboard dataForType:kDragAndDropExternalUti];
    if ( blah == nil ) {
        return nil;
    }

    Node* selected = [self getCurrentSelectedItem];
    Node* destinationItem = self.viewModel.rootGroup;
    if(selected) {
        destinationItem = selected.isGroup ? selected : selected.parent;
    }

    NSUInteger itemCount = [self pasteItemsFromPasteboard:pasteboard destinationItem:destinationItem source:nil clear:NO];
    if ( itemCount == 0 ) {
        [MacAlerts info:@"Could not paste! Unknown Error." window:self.view.window];
    }
    else {
        NSString* loc = itemCount == 1 ? NSLocalizedString(@"mac_item_pasted_from_clipboard", @"Item Pasted from Clipboard") :
            NSLocalizedString(@"mac_items_pasted_from_clipboard", @"Items Pasted from Clipboard");
        
        [self showPopupChangeToastNotification:loc];
    }

    return nil;
}

- (IBAction)onCopySelectedItemsToClipboard:(id)sender {
    NSArray* selected = [self getSelectedItems];
    
    if (selected.count) {
        NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
        [self placeItemsOnPasteboard:pasteboard items:selected];

        NSString* loc = selected.count == 1 ? NSLocalizedString(@"mac_copied_item_to_clipboard", @"Item Copied to Clipboard") :
            NSLocalizedString(@"mac_copied_items_to_clipboard", @"Items Copied to Clipboard");
        
        [self showPopupChangeToastNotification:loc];
    }
}

- (void)bindPasswordStrength:(NSString*)pw {
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



- (IBAction)onVCToggleOfflineMode:(id)sender {
    self.viewModel.offlineMode = !self.viewModel.offlineMode;
    [self fullModelReload];
}

- (IBAction)onVCToggleLaunchAtStartup:(id)sender {
    self.viewModel.launchAtStartup = !self.viewModel.launchAtStartup;
}

- (IBAction)onVCToggleReadOnly:(id)sender {
    self.viewModel.readOnly = !self.viewModel.readOnly;
    [self fullModelReload];
}

- (IBAction)onVCToggleStartInSearchMode:(id)sender {
    self.viewModel.startWithSearch = !self.viewModel.startWithSearch;
}

- (IBAction)onVCToggleShowVerticalGridlines:(id)sender {
    self.viewModel.showVerticalGrid = !self.viewModel.showVerticalGrid;
    [self onPreferencesChanged:nil];
}

- (IBAction)onVCToggleShowHorizontalGridlines:(id)sender {
    self.viewModel.showHorizontalGrid = !self.viewModel.showHorizontalGrid;
    [self onPreferencesChanged:nil];
}

- (IBAction)onVCToggleShowAlternatingGridRows:(id)sender {
    self.viewModel.showAlternatingRows = !self.viewModel.showAlternatingRows;
    [self onPreferencesChanged:nil];
}

- (IBAction)onVCToggleShowTotpCodes:(id)sender {
    self.viewModel.showTotp = !self.viewModel.showTotp;
    [self onPreferencesChanged:nil];
}

- (IBAction)onVCToggleShowEditToasts:(id)sender {
    self.viewModel.showChangeNotifications = !self.viewModel.showChangeNotifications;
}



- (void)keyDown:(NSEvent *)event {
    BOOL cmd = ((event.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    
    if ( cmd && key > 48 && key < 58 ) {
        NSUInteger number = key - 48;



        [self onCmdPlusNumberPressed:number];
        return;
    }
    
    [super keyDown:event];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSEvent *event = [control.window currentEvent];


    if (commandSelector == NSSelectorFromString(@"noop:")) { 
        if ( (event.modifierFlags & NSCommandKeyMask ) == NSCommandKeyMask) {
            NSString *chars = event.charactersIgnoringModifiers;
            unichar aChar = [chars characterAtIndex:0];
            
            if ( aChar > 48 && aChar < 58 ) {
                NSUInteger number = aChar - 48;

                [self onCmdPlusNumberPressed:number];
                return YES;
            }
        }
    }
    
    if(control == self.searchField) { 
        if (commandSelector == NSSelectorFromString(@"noop:")) { 
            if ( (event.modifierFlags & NSCommandKeyMask) == NSCommandKeyMask) {
                NSString *chars = event.charactersIgnoringModifiers;
                unichar aChar = [chars characterAtIndex:0];

                
                
                if (aChar == 'c') {
                    Node* item = [self getCurrentSelectedItem];
                    if ( item && !item.isGroup ) {
                        [self onCopyPassword:nil];
                        return YES;
                    }
                }
            }
        }
        
        if (commandSelector == @selector(moveDown:)) {
            if (self.outlineView.numberOfRows > 0) {
                [self.view.window makeFirstResponder:self.outlineView];
                return YES;
            }
        }
    }
    else if( control == self.textFieldMasterPassword ) {
        if (commandSelector == @selector(insertTab:)) {
            if([self convenienceUnlockIsPossible]) {
                [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
            }
            else {
                [self.view.window makeFirstResponder:self.buttonUnlockWithPassword];
            }

            return YES;
        }
    }

    return NO;
}

- (void)onCmdPlusNumberPressed:(NSUInteger)number {
    NSLog(@"Cmd+Number %lu", (unsigned long)number);
    
    if (@available(macOS 10.13, *)) {

      
        NSWindowTabGroup* group = self.view.window.tabGroup;
        
        if ( self.view.window.tabbedWindows && number <= self.view.window.tabbedWindows.count ) {
            group.selectedWindow = self.view.window.tabbedWindows[number - 1];
        }
    }
}

@end










