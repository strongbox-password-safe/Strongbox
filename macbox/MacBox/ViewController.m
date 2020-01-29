//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "Alerts.h"
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
#import "KeePassPredefinedIcons.h"
#import "MacKeePassHistoryViewController.h"
#import "MacNodeIconHelper.h"
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
#import "DatabasePropertiesController.h"

static const int kMaxRecommendCustomIconSize = 128*1024;
static const int kMaxCustomIconDimension = 256;
static const CGFloat kExpiredOutlineViewCellAlpha = 0.35f;

static NSString* const kPasswordCellIdentifier = @"CustomFieldValueCellIdentifier";
static NSString* const kDefaultNewTitle = @"Untitled";

static NSString* const kItemKey = @"item";
static NSString* const kNewEntryKey = @"newEntry";

@interface ViewController () <  NSWindowDelegate,
                                NSTextFieldDelegate,
                                QLPreviewPanelDataSource,
                                QLPreviewPanelDelegate>

@property (strong, nonatomic) SelectPredefinedIconController* selectPredefinedIconController;
@property (strong, nonatomic) CreateFormatAndSetCredentialsWizard *changeMasterPassword;
@property (strong, nonatomic) ProgressWindow* progressWindow;
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
@property (weak) IBOutlet NSOutlineView *outlineView;
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

// Group View Fields

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;

@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;

@property (weak) IBOutlet ClickableImageView *imageViewShowHidePassword;
@property (weak) IBOutlet NSTextField *textFieldTotp;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;
@property (strong) IBOutlet NSMenu *outlineHeaderColumnsMenu;
@property (weak) IBOutlet NSView *customFieldsRow;
@property (weak) IBOutlet NSTableView *customFieldsTable;
@property (weak) IBOutlet NSImageView *imageViewIcon;
@property (weak) IBOutlet NSView *containerViewForEnterMasterCredentials;

@property (weak) IBOutlet NSView *attachmentsRow;
@property (weak) IBOutlet NSTableView *attachmentsTable;
@property NSDictionary<NSNumber*, NSImage*> *attachmentsIconCache;

@property (weak) IBOutlet NSView *expiresRow;
@property (weak) IBOutlet NSTextField *labelExpires;

@property NSArray* attachments;

@property (strong, nonatomic) ViewModel* model;
@property BOOL isPromptingAboutUnderlyingFileChange;
@property NSArray* customFields;
@property NSMutableDictionary<NSUUID*, NodeDetailsViewController*>* detailsViewControllers;
@property NSDate* lastAutoPromptForTouchIdThrottle; // HACK: Sigh

@property (weak) IBOutlet NSPopUpButton *keyFilePopup;
@property NSString* selectedKeyFileBookmark;

@end

static NSImage* kStrongBox256Image;

@implementation ViewController

+ (void)initialize {
    if(self == [ViewController class]) {
        kStrongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Note: Nothing really important can happen here because we can't access the Document or the View Model
    // The real action kicks off after this function finishes and setInitialModel is called...
    
    self.detailsViewControllers = @{}.mutableCopy;
    
    [self enableDragDrop];

    [self customizeUi];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAutoLock:) name:kAutoLockTime object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
}

- (void)updateModel:(ViewModel *)model {
    NSLog(@"updateModel [%@]", model);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setModelFromMainThread:model];
    });
}

- (void)setInitialModel:(ViewModel*)model {
    // MUST be called on main thread...
    NSLog(@"setInitialModel [%@]", model);

    [self setModelFromMainThread:model];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoPromptForTouchIdIfDesired];
    });
}

- (void)setModelFromMainThread:(ViewModel *)model {
    [self stopObservingModelChanges];
    [self closeAllDetailsWindows];
        
    self.model = model;

    [self bindToModel];
    [self setInitialFocus];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    self.view.window.delegate = self;
    
    [self initializeFullOrTrialOrLiteUI];
    
    [self setInitialFocus];
    
    [self startRefreshOtpTimer];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSLog(@"[%@] Window Became Key!", self.model.databaseMetadata.nickName);

    // MMcG: Seems to be unfortunately required - as key window is not set if we call straight away... hack :(
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoPromptForTouchIdIfDesired];
    });
}

- (void)viewDidDisappear {
    [super viewDidDisappear];

    [self stopRefreshOtpTimer];

    [self closeAllDetailsWindows];
}

- (void)closeAllDetailsWindows {
    // Copy as race condition of windows closing and calling into us will lead to crash

    NSArray<NodeDetailsViewController*>* vcs = [self.detailsViewControllers.allValues copy];
        
    for (NodeDetailsViewController *vc in vcs) {
        [vc close];
    }

    [self.detailsViewControllers removeAllObjects];
}

- (IBAction)onViewItemDetails:(id)sender {
    [self showItemDetails];
}

- (void)showItemDetails {
    Node* item = [self getCurrentSelectedItem];
    [self openItemDetails:item newEntry:NO];
}

- (void)openItemDetails:(Node*)item newEntry:(BOOL)newEntry {
    if(!item || item.isGroup) {
        return;
    }
    
    NodeDetailsViewController* vc = self.detailsViewControllers[item.uuid];
    
    if(vc) {
        NSLog(@"Details window already exists... Activating... [%@]", item.title);
        [vc.view.window makeKeyAndOrderFront:nil];
    }
    else {
        [self performSegueWithIdentifier:@"segueToShowItemDetails" sender:@{ kItemKey : item, kNewEntryKey : @(newEntry)}];
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    NSDictionary<NSString*, id> *params = sender;
    Node* item = params[kItemKey];

    if([segue.identifier isEqualToString:@"segueToShowItemDetails"]) {
        NSNumber* newEntry = params[kNewEntryKey];
        
        NodeDetailsViewController* vc = (segue.destinationController);
        
        vc.node = item;
        vc.model = self.model;
        vc.newEntry = newEntry.boolValue;
        vc.historical = NO;
        
        vc.onClosed = ^{
            NSLog(@"Removing Details View from List: [%@]", item.title);
            [self.detailsViewControllers removeObjectForKey:item.uuid];
        };
        
        NSLog(@"Adding Details View to List: [%@]", item.title);
        
        self.detailsViewControllers[item.uuid] = vc;
    }
    else if([segue.identifier isEqualToString:@"segueToItemHistory"]) {
        MacKeePassHistoryViewController* vc = (MacKeePassHistoryViewController*)segue.destinationController;
        
        vc.onDeleteHistoryItem = ^(Node * _Nonnull node) {
            [self.model deleteHistoryItem:item historicalItem:node];
        };
        vc.onRestoreHistoryItem = ^(Node * _Nonnull node) {
            [self.model restoreHistoryItem:item historicalItem:node];
        };
        
        vc.model = self.model;
        vc.history = item.fields.keePassHistory;
    }
    else if([segue.identifier isEqualToString:@"segueToDatabasePreferences"]) {
        NSWindowController *wc = segue.destinationController;
        [wc.window center];

        DatabasePropertiesController *vc = (DatabasePropertiesController*)wc.contentViewController;
        [vc setModel:self.model.databaseMetadata];
    }
}

- (void)customizeUi {
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
    
    NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch"); // FUTURE: if only one method available then word this more precisely
    
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    self.buttonUnlockWithTouchId.hidden = YES;
    
    self.imageViewTogglePassword.clickable = YES;
    self.imageViewTogglePassword.onClick = ^{
        [self onToggleShowHideQuickViewPassword:nil];
    };
    [self bindRevealMasterPasswordTextField];
    
    self.textFieldMasterPassword.delegate = self;
    
    self.showPassword = Settings.sharedInstance.alwaysShowPassword;

    self.imageViewShowHidePassword.clickable = YES;
    self.imageViewShowHidePassword.showClickableBorder = NO;
    self.imageViewShowHidePassword.onClick = ^{
        [self toggleRevealMasterPasswordTextField:nil];
    };

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
    
    self.quickViewColumn.hidden = !Settings.sharedInstance.revealDetailsImmediately;
    [self bindQuickViewButton];
}

- (void)customizeOutlineView {
    // FUTURE: Sorting...
    //self.outlineView.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES] ];
    
    NSNib* nib = [[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil];
    [self.outlineView registerNib:nib forIdentifier:kPasswordCellIdentifier];

    self.outlineView.usesAlternatingRowBackgroundColors = !Settings.sharedInstance.noAlternatingRows;
    self.outlineView.gridStyleMask = (Settings.sharedInstance.showVerticalGrid ? NSTableViewSolidVerticalGridLineMask : 0) | (Settings.sharedInstance.showHorizontalGrid ? NSTableViewSolidHorizontalGridLineMask : 0);
    
    self.outlineView.headerView.menu = self.outlineHeaderColumnsMenu;
    self.outlineView.autosaveTableColumns = YES;
    
    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    
    [self bindColumnsToSettings];
}

- (void)bindColumnsToSettings {
    NSArray<NSString*>* visible = Settings.sharedInstance.visibleColumns;
    
    // Show / Hide...
    
    for (NSString* column in [Settings kAllColumns]) {
        [self showHideOutlineViewColumn:column show:[visible containsObject:column] && [self isColumnAvailableForModel:column]];
    }
    
    // Order...
    
    int i=0;
    for (NSString* column in visible) {
        NSInteger colIdx = [self.outlineView columnWithIdentifier:column];
        if(colIdx != -1) { // Perhaps we removed a column?!
            NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
            
            if(!col.hidden) { // Maybe hidden because it isn't available in this Model Format (Password Safe/KeePass)
                [self.outlineView moveColumn:colIdx toColumn:i++];
            }
        }
    }
    
//    [self.outlineView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
}

- (IBAction)onOutlineHeaderColumnsChanged:(id)sender {
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    
    //NSLog(@"Columns Changed: %@-%d", menuItem.identifier, menuItem.state == NSOnState);
    
    NSMutableArray<NSString*>* newColumns = [Settings.sharedInstance.visibleColumns mutableCopy];
    
    if(menuItem.state == NSOnState) // We are request to removing an existing column
    {
        [newColumns removeObject:menuItem.identifier];
        Settings.sharedInstance.visibleColumns = newColumns;
        [self showHideOutlineViewColumn:menuItem.identifier show:NO];
        [self.outlineView reloadData];
    }
    else { // We're adding a column
        if(![newColumns containsObject:menuItem.identifier]) { // Don't add a duplicate somehow
            [newColumns addObject:menuItem.identifier];
            Settings.sharedInstance.visibleColumns = newColumns;
        }
        [self showHideOutlineViewColumn:menuItem.identifier show:[self isColumnAvailableForModel:menuItem.identifier]];
        [self.outlineView reloadData];
    }
}

- (void)showHideOutlineViewColumn:(NSString*)identifier show:(BOOL)show {
    NSInteger colIdx = [self.outlineView columnWithIdentifier:identifier];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    
    //NSLog(@"Set hidden: %@->%d", col.identifier, !show);
    if(col.hidden != !show) {
        col.hidden = !show;
    }
}

- (BOOL)isColumnAvailableForModel:(NSString*)identifier {
    if(!self.model) {
        return NO;
    }
    
    BOOL ret;
    if (self.model.format == kPasswordSafe) {
        ret = (![identifier isEqualToString:kCustomFieldsColumn] && ![identifier isEqualToString:kAttachmentsColumn]);
    }
    else {
        ret = ![identifier isEqualToString:kEmailColumn];
    }
    
    //NSLog(@"isColumnAvailableForModel: %d = %@ -> %d", self.model.format == kPasswordSafe, identifier, ret);
    
    return ret;
}

- (BOOL)isColumnVisible:(NSString*)identifier {
    return [Settings.sharedInstance.visibleColumns containsObject:identifier];
}

- (void)disableFeaturesForLiteVersion {
    NSString* loc = NSLocalizedString(@"mac_search_disabled_please_upgrade", @"Search Disabled - Please Upgrade");
    
    [self.searchField setPlaceholderString:loc];
    self.searchField.enabled = NO;
    self.searchSegmentedControl.enabled = NO;
}

- (void)enableFeaturesForFullVersion {
    NSString* loc = NSLocalizedString(@"mac_search_placeholder", @"Search (⌘F)");
    
    [self.searchField setPlaceholderString:loc];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSImage * )getIconForNode:(Node *)vm large:(BOOL)large {
    return [MacNodeIconHelper getIconForNode:self.model vm:vm large:large];
}

- (void)onDeleteHistoryItem:(Node*)node historicalItem:(Node*)historicalItem {
    // NOP - Not displayed in main view...
    NSLog(@"Deleted History Item... no need to update UI");
}

- (void)onRestoreHistoryItem:(Node*)node historicalItem:(Node*)historicalItem {
    self.itemsCache = nil; // Clear items cache
    Node* selectionToMaintain = [self getCurrentSelectedItem];
    [self.outlineView reloadData]; // Full Reload required as item could be sorted to a different location
    NSInteger row = [self.outlineView rowForItem:selectionToMaintain];
    
    if(row != -1) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        // This selection change will lead to a full reload of the details pane via selectionDidChange
    }
}

- (void)onDeleteItem:(Node*)node {
    self.itemsCache = nil; // Clear items cache
    [self.outlineView reloadData]; // Full reload in case we're in search and things have changed removing this item...
    [self bindDetailsPane];
}

- (void)onChangeParent:(Node*)node {
    self.itemsCache = nil; // Clear items cache
    [self.outlineView reloadData];
    [self bindDetailsPane];
}

//////////////

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

    Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];

    [self expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:node];
}

- (void)expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:(Node*)node {
    NSURL* url = [NSURL URLWithString:node.fields.url];
        
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    if(url && featureAvailable && Settings.sharedInstance.expressDownloadFavIconOnNewOrUrlChanged) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
            [FavIconManager.sharedInstance downloadPreferred:url
                                                     options:FavIconDownloadOptions.express
                                                  completion:^(IMAGE_TYPE_PTR  _Nullable image) {
                if(image) {
                    NSLog(@"Got FavIcon on Change URL or New Entry: [%@]", image);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.model setItemIcon:node customImage:image];
                    });
                }
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
    if(notification.object != self.model) {
        return;
    }
    
    self.itemsCache = nil; // Clear items cache
    
    Node* selectionToMaintain = [self getCurrentSelectedItem];
    [self.outlineView reloadData]; // Full Reload required as item could be sorted to a different location
    
    if(selectionToMaintain) {
        NSInteger row = [self.outlineView rowForItem:selectionToMaintain];
        if(row != -1) {
            [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    
    if(!suppressPopupMessage) {
        Node* node = (Node*)notification.userInfo[kNotificationUserInfoKeyNode];

        NSString *loc = NSLocalizedString(@"mac_field_changed_popup_notification_fmt", @"'%@' %@ Changed... First parameter Title of Item, second parameter which field changed, e.g. Username or Password");
        [self showPopupToastNotification:[NSString stringWithFormat:loc, node.title, popupMessage]];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)bindToModel {
    [self stopObservingModelChanges];
    [self closeAllDetailsWindows];
    
    self.itemsCache = nil; // Clear items cache
    
    if(self.model == nil || self.model.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
        [self bindLockScreenUi];
    }
    else {
        [self startObservingModelChanges];
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
        
        [self bindColumnsToSettings];
        [self.outlineView reloadData];
        
        Node* selectedItem = [self.model getItemFromSerializationId:self.model.selectedItem];
        [self selectItem:selectedItem];
        
        [self bindDetailsPane];
    }
}

- (void)stopObservingModelChanges {
    if(self.model) {
        self.model.onNewItemAdded = nil;
        self.model.onDeleteItem = nil;
        self.model.onChangeParent = nil;
        self.model.onDeleteHistoryItem = nil;
        self.model.onRestoreHistoryItem = nil;
    }
    
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
}

- (void)startObservingModelChanges {
    __weak ViewController* weakSelf = self;
    self.model.onNewItemAdded = ^(Node * _Nonnull node, BOOL newRecord) {
        [weakSelf onNewItemAdded:node newRecord:newRecord];
    };
    self.model.onDeleteItem = ^(Node * _Nonnull node) {
        [weakSelf onDeleteItem:node];
    };
    self.model.onChangeParent = ^(Node * _Nonnull node) {
        [weakSelf onChangeParent:node];
    };
    self.model.onDeleteHistoryItem = ^(Node * _Nonnull item, Node * _Nonnull historicalItem) {
        [weakSelf onDeleteHistoryItem:item historicalItem:historicalItem];
    };
    self.model.onRestoreHistoryItem = ^(Node * _Nonnull item, Node * _Nonnull historicalItem) {
        [weakSelf onRestoreHistoryItem:item historicalItem:historicalItem];
    };
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCustomFieldsChanged:) name:kModelUpdateNotificationCustomFieldsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemTitleChanged:) name: kModelUpdateNotificationTitleChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemUsernameChanged:) name: kModelUpdateNotificationUsernameChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemUrlChanged:) name: kModelUpdateNotificationUrlChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemEmailChanged:) name: kModelUpdateNotificationEmailChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemExpiryDateChanged:) name: kModelUpdateNotificationExpiryChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemNotesChanged:) name: kModelUpdateNotificationNotesChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemPasswordChanged:) name:kModelUpdateNotificationPasswordChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onItemIconChanged:) name:kModelUpdateNotificationIconChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onAttachmentsChanged:) name:kModelUpdateNotificationAttachmentsChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onTotpChanged:) name:kModelUpdateNotificationTotpChanged object:nil];
}

- (void)setInitialFocus {
    if(self.model == nil || self.model.locked) {
        if([self biometricOpenIsAvailableForSafe]) {
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
        self.imageViewGroupDetails.clickable = self.model.format != kPasswordSafe;
        self.imageViewGroupDetails.showClickableBorder = YES;
        self.imageViewGroupDetails.onClick = ^{ [self onEditNodeIcon:it]; };

        
        self.textFieldSummaryTitle.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInQuickView];;
    }
    else {
        [self.tabViewRightPane selectTabViewItemAtIndex:0];
        self.emailRow.hidden = self.model.format != kPasswordSafe;
        
        self.imageViewIcon.image = [self getIconForNode:it large:YES];
        self.imageViewIcon.hidden = self.model.format == kPasswordSafe;

        //NSLog(@"Setting Text fields");
        self.labelTitle.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelPassword.stringValue = [self maybeDereference:it.fields.password node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelUrl.stringValue = [self maybeDereference:it.fields.url node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelUsername.stringValue = [self maybeDereference:it.fields.username node:it maybe:Settings.sharedInstance.dereferenceInQuickView];
        self.labelEmail.stringValue = it.fields.email;
        self.textViewNotes.string = [self maybeDereference:it.fields.notes node:it maybe:Settings.sharedInstance.dereferenceInQuickView];

        // Necessary to pick up links... :/
        
        [self.textViewNotes setEditable:YES];
        [self.textViewNotes checkTextInDocument:nil];
        [self.textViewNotes setEditable:NO];
        
        self.imageViewTogglePassword.hidden = (self.labelPassword.stringValue.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields);
        self.showPassword = Settings.sharedInstance.alwaysShowPassword || (self.labelPassword.stringValue.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields);
        [self showOrHideQuickViewPassword];
        
        // Expiry
        
        self.expiresRow.hidden = it.fields.expires == nil;
        self.labelExpires.stringValue = friendlyDateString(it.fields.expires);
        self.labelExpires.textColor = it.expired ? NSColor.redColor : it.nearlyExpired ? NSColor.orangeColor : nil;
        
        // TOTP

        [self refreshOtpCode:nil];
        
        // Custom Fields
        
        NSArray* sortedKeys = [it.fields.customFields.allKeys sortedArrayUsingComparator:finderStringComparator];
        
        self.customFields = [sortedKeys map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            CustomField* field = [[CustomField alloc] init];
            StringValue* value = it.fields.customFields[obj];
            
            field.key = obj;
            field.value = value.value;
            field.protected = value.protected;
            
            return field;
        }];
        
        self.customFieldsRow.hidden = self.model.format == kPasswordSafe || self.customFields.count == 0 || !Settings.sharedInstance.showCustomFieldsOnQuickViewPanel;
        [self.customFieldsTable reloadData];
        
        // Attachments
        
        self.attachments = [it.fields.attachments sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NodeFileAttachment* f1 = obj1;
            NodeFileAttachment* f2 = obj2;
            return finderStringCompare(f1.filename, f2.filename);
        }];
        
        self.attachmentsRow.hidden = self.model.format == kPasswordSafe || self.attachments.count == 0 || !Settings.sharedInstance.showAttachmentsOnQuickViewPanel;
        [self.attachmentsTable reloadData];
    }
}

- (NSString*)maybeDereference:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self.model dereference:text node:node] : text;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.model || self.model.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<Node*> *items = [self getItems:self.model.rootGroup];
        
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
    if(!self.model || self.model.locked) {
        return 0;
    }
    
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    NSArray<Node*> *items = [self getItems:group];
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    NSArray<Node*> *items = [self getItems:group];
    return items.count == 0 ? nil : items[index];
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
    Node *it = (Node*)item;
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
        cell.protected = !it.isGroup && !(password.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields);
        cell.valueHidden = !it.isGroup && !(password.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields) && !Settings.sharedInstance.showPasswordImmediatelyInOutline;
        
        cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

        return cell;
    }
    else if([tableColumn.identifier isEqualToString:kTOTPColumn]) {
        NSString* totp = it.fields.otpToken ? it.fields.otpToken.password : @"";
        //NSLog(@"TOTP: %@", totp);
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
        NSString* exp = friendlyDateStringVeryShort(it.fields.expires);
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

    // MMcG: Valiant attempt but does not work well after edit, or indeed looks poor while selected...
    // no click functionality either... or selection of browser...
    
//    if(text.length) { // Absolutely required because NSDataDetector will die and kill us in strange ways otherwise...
//        NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
//        if(detector) {
//            NSTextCheckingResult* result = [detector firstMatchInString:it.fields.url options:kNilOptions range:NSMakeRange(0, text.length)];
//            if (result.resultType == NSTextCheckingTypeLink && result.range.location == 0 && result.range.length == text.length) {
//                NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:text];
//                NSRange range = NSMakeRange(0, [attrString length]);
//
//                [attrString beginEditing];
//
//                [attrString addAttribute:NSLinkAttributeName value:it.fields.url range:range];
//                [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor systemBlueColor] range:range];
//                [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:range];
//
//                [attrString endEditing];
//
//                cell.textField.attributedStringValue = attrString;
//            }
//        }
//    }
    
    cell.alphaValue = node.expired ? kExpiredOutlineViewCellAlpha : 1.0f;

    return cell;
}

- (NSTableCellView*)getEditableCell:(NSString*)text node:(Node*)node selector:(SEL)selector {
    NSTableCellView* cell = (NSTableCellView*)[self.outlineView makeViewWithIdentifier:@"GenericCell" owner:self];
    
    cell.textField.stringValue = [self maybeDereference:text node:node maybe:Settings.sharedInstance.dereferenceInOutlineView];
    
    // Do not allow editing of dereferenced text in Outline View... impossible to work UI wise at the moment
    
    BOOL possiblyDereferencedText = Settings.sharedInstance.dereferenceInOutlineView && [self.model isDereferenceableText:text];
    
    cell.textField.editable = !possiblyDereferencedText && !Settings.sharedInstance.outlineViewEditableFieldsAreReadonly;
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
    
    if(it.isGroup && self.model.recycleBinEnabled && self.model.recycleBinNode && self.model.recycleBinNode == it) {
        cell.textField.font = self.italicFont;
    }
    else {
        cell.textField.font = self.regularFont;
    }

    cell.imageView.objectValue = [self getIconForNode:it large:NO];
    cell.textField.stringValue = [self maybeDereference:it.title node:it maybe:Settings.sharedInstance.dereferenceInOutlineView];

    BOOL possiblyDereferencedText = Settings.sharedInstance.dereferenceInOutlineView && [self.model isDereferenceableText:it.title];
    cell.textField.editable = !possiblyDereferencedText && !Settings.sharedInstance.outlineViewEditableFieldsAreReadonly && !Settings.sharedInstance.outlineViewTitleIsReadonly;
    
    cell.alphaValue = it.expired ? kExpiredOutlineViewCellAlpha : 1.0f;
    
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    //NSLog(@"Selection Change Outline View");
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
        [self.model setItemEmail:item email:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; // Our TAB order is messed up... don't tab into next cell
}

- (IBAction)onOutlineViewItemNotesEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  textField.stringValue;
    if(![item.fields.notes isEqualToString:newString]) {
        [self.model setItemNotes:item notes:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; // Our TAB order is messed up... don't tab into next cell
}

- (IBAction)onOutlineViewItemUrlEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  [Utils trim:textField.stringValue];
    if(![item.fields.url isEqualToString:newString]) {
        [self.model setItemUrl:item url:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; // Our TAB order is messed up... don't tab into next cell
}

- (IBAction)onOutlineViewItemUsernameEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    NSString* newString =  [Utils trim:textField.stringValue];
    if(![item.fields.username isEqualToString:newString]) {
        [self.model setItemUsername:item username:newString];
    }
    else {
        textField.stringValue = newString;
    }
    
    [self.view.window makeFirstResponder:self.outlineView]; // Our TAB order is messed up... don't tab into next cell
}

- (IBAction)onOutlineViewItemTitleEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;
    
    NSString* newTitle = [Utils trim:textField.stringValue];
    if(![item.title isEqualToString:newTitle]) {
        if(![self.model setItemTitle:item title:newTitle]) {
            textField.stringValue = item.title;
        }
    }
    else {
        textField.stringValue = newTitle;
    }

    [self.view.window makeFirstResponder:self.outlineView]; // Our TAB order is messed up... don't tab into next cell
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    // FUTURE: Sorting...
    NSLog(@"sortDescriptors did change!");
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification {
    NSNumber* newNum = notification.userInfo[@"NSNewColumn"];

    NSTableColumn* column = self.outlineView.tableColumns[newNum.intValue];
    
    //NSLog(@"tableViewColumnDidMove: %@ -> %@", column.identifier, newNum);
    
    NSMutableArray<NSString*>* newColumns = [Settings.sharedInstance.visibleColumns mutableCopy];
   
    [newColumns removeObject:column.identifier];
    [newColumns insertObject:column.identifier atIndex:newNum.integerValue];
    
    Settings.sharedInstance.visibleColumns = newColumns;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray<Node*> *)getItems:(Node*)parentGroup {
    if(!self.model || self.model.locked) {
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
    //NSLog(@"loadSafeItems for [%@]", parentGroup.uuid);
    if(!parentGroup.isGroup) { // This can actually happen somehow - onAttachmentsChanged
        return @[];
    }
    
    BOOL sort = !Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView || self.model.format == kPasswordSafe;
    
    NSArray<Node*>* sorted = sort ? [parentGroup.children sortedArrayUsingComparator:finderStyleNodeComparator] : parentGroup.children;
    
    NSString* searchText = self.searchField.stringValue;
    BOOL isSearching = searchText.length != 0;
    BOOL showRecycleBin = isSearching ? Settings.sharedInstance.showRecycleBinInSearchResults : !Settings.sharedInstance.doNotShowRecycleBinInBrowse;

    NSArray<Node*> *filtered = sorted;
    if(self.model.format == kKeePass1) {
        if(!showRecycleBin && self.model.keePass1BackupNode) {
            filtered = [sorted filter:^BOOL(Node * _Nonnull obj) {
                return obj != self.model.keePass1BackupNode;
            }];
        }
    }
    else {
        if(!showRecycleBin && self.model.recycleBinNode) {
            filtered = [sorted filter:^BOOL(Node * _Nonnull obj) {
                return obj != self.model.recycleBinNode;
            }];
        }
    }

    // Filter by Search term if necessary
     
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
    BOOL immediateMatch = NO;

    NSArray<NSString*> *terms = [self.model getSearchTerms:searchText];
    
    //NSLog(@"Searching for Terms: [%@]", terms);
    
    for (NSString* term in terms) {
        if (scope == kSearchScopeTitle) {
            immediateMatch = [self.model isTitleMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopeUsername) {
            immediateMatch = [self.model isUsernameMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopePassword) {
            immediateMatch = [self.model isPasswordMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else if (scope == kSearchScopeUrl) {
            immediateMatch = [self.model isUrlMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        else {
            immediateMatch = [self.model isAllFieldsMatches:term node:item dereference:Settings.sharedInstance.dereferenceDuringSearch];
        }
        
        if(!immediateMatch) { // MUST match all terms...
            return NO;
        }
    }
    
    return immediateMatch;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)selectedItemSerializationId {
    Node* item = [self getCurrentSelectedItem];
    return item ? [item getSerializationId:self.model.format != kPasswordSafe] : nil;
}

- (void)showProgressModal:(NSString*)operationDescription {
    [self hideProgressModal];
    
    self.progressWindow = [[ProgressWindow alloc] initWithWindowNibName:@"ProgressWindow"];
    self.progressWindow.operationDescription = operationDescription;
    [self.view.window beginSheet:self.progressWindow.window  completionHandler:nil];
}

- (void)hideProgressModal {
    if(self.progressWindow) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view.window endSheet:self.progressWindow.window];
            self.progressWindow = nil;
        });
    }
}

- (NSData*)getSelectedKeyFileDigest:(NSError**)error {
    NSData* keyFileDigest = nil;
    if(self.selectedKeyFileBookmark) {
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:self.selectedKeyFileBookmark error:error];
                
        if(data) {
            keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data checkForXml:self.model.format != kKeePass1];
            // NSLog(@"Got key file digest: [%@]", [keyFileDigest base64EncodedStringWithOptions:kNilOptions]);
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
        [Alerts twoOptionsWithCancel:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
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
    NSData* keyFileDigest = [self getSelectedKeyFileDigest:&error];

    if(error) {
        [Alerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                error:error
               window:self.view.window];
        return;
    }
    
    CompositeKeyFactors* ckf = [CompositeKeyFactors password:password
                                               keyFileDigest:keyFileDigest];
    
    [self reloadAndUnlock:ckf isBiometricOpen:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)biometricOpenIsAvailableForSafe {
    DatabaseMetadata* metaData = self.model.databaseMetadata;
    
    BOOL ret =  (metaData == nil ||
                 !metaData.isTouchIdEnabled ||
                 !(metaData.touchIdPassword) ||
                 !BiometricIdHelper.sharedInstance.biometricIdAvailable ||
                 !(Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial));

    return !ret;
}

- (void)autoPromptForTouchIdIfDesired {
    NSLog(@"autoPromptForTouchIdIfDesired: [%@]", self.model);
    
    if(self.model && self.model.locked) {
        BOOL weAreKeyWindow = NSApplication.sharedApplication.keyWindow == self.view.window;

        NSLog(@"autoPromptForTouchIdIfDesired: weAreKeyWindow = [%d]", weAreKeyWindow);

        if(weAreKeyWindow && [self biometricOpenIsAvailableForSafe] && (Settings.sharedInstance.autoPromptForTouchIdOnActivate)) {
            NSTimeInterval secondsBetween = [NSDate.date timeIntervalSinceDate:self.lastAutoPromptForTouchIdThrottle];
            NSLog(@"seconds: %f", secondsBetween);
            if(self.lastAutoPromptForTouchIdThrottle != nil && secondsBetween < 1.5) {
                NSLog(@"Too many auto biometric requests too soon - ignoring...");
                return;
            }

            [self onUnlockWithTouchId:nil];
        }
    }
}

- (IBAction)onUnlockWithTouchId:(id)sender {
    if([self biometricOpenIsAvailableForSafe]) {
        [BiometricIdHelper.sharedInstance authorize:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.lastAutoPromptForTouchIdThrottle = NSDate.date;

                if(success) {
                    NSError* error;
                    NSData* keyFileDigest = [self getSelectedKeyFileDigest:&error];

                    if(error) {
                        [Alerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                                error:error
                               window:self.view.window];
                        return;
                    }

                    DatabaseMetadata* metaData = self.model.databaseMetadata;
                    
                    CompositeKeyFactors* ckf = [CompositeKeyFactors password:metaData.touchIdPassword
                                                               keyFileDigest:keyFileDigest];

                    [self reloadAndUnlock:ckf isBiometricOpen:YES];
                }
                else {
                    NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                    
                    if(error && (error.code == LAErrorUserFallback || error.code == LAErrorUserCancel || error.code == -2412)) {
                        NSLog(@"User cancelled or selected fallback. Ignore...");
                    }
                    else {
                        [Alerts error:error window:self.view.window];
                    }
                }
            });
        }];
    }
    else if(BiometricIdHelper.sharedInstance.biometricIdAvailable) { // Don't clear if user has just disabled Bio-Id / Watch
        NSLog(@"Touch ID button pressed but no Touch ID Stored?");
        
        NSString* loc = NSLocalizedString(@"mac_could_not_find_stored_credentials", @"The stored credentials are unavailable. Please enter the password manually. Touch ID Metadata for this database will be cleared.");
        [Alerts info:loc window:self.view.window];
        
        [self clearTouchId];
    }
}

- (void)onFileChangedByOtherApplication {
    if(self.isPromptingAboutUnderlyingFileChange) {
        NSLog(@"Already in Use...");
        return;
    }
    
    self.isPromptingAboutUnderlyingFileChange = YES;
    if(self.model && !self.model.locked) {
        if(!self.model.document.isDocumentEdited) {
            if(!Settings.sharedInstance.autoReloadAfterForeignChanges) {
                NSString* loc = NSLocalizedString(@"mac_db_changed_externally_reload_yes_or_no", @"The database has been changed by another application, would you like to reload this latest version and automatically unlock?");

                [Alerts yesNo:loc
                       window:self.view.window
                   completion:^(BOOL yesNo) {
                    if(yesNo) {
                        NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                        [self showPopupToastNotification:loc];
                        
                        self.model.selectedItem = [self selectedItemSerializationId];
                        
                        [self reloadAndUnlock:self.model.compositeKeyFactors isBiometricOpen:NO];
                    }
                }];
                return;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                [self showPopupToastNotification:loc];

                self.model.selectedItem = [self selectedItemSerializationId];
                [self reloadAndUnlock:self.model.compositeKeyFactors isBiometricOpen:NO];
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

- (void)reloadAndUnlock:(CompositeKeyFactors*)compositeKeyFactors isBiometricOpen:(BOOL)isBiometricOpen {
    if(self.model) {
        [self enableMasterCredentialsEntry:NO];
        
        NSString* loc = NSLocalizedString(@"generic_unlocking_ellipsis", @"Unlocking...");
        [self showProgressModal:loc];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.model reloadAndUnlock:compositeKeyFactors completion:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideProgressModal];
                    if(success) {
                        self.textFieldMasterPassword.stringValue = @"";
                    }
                    [self onUnlocked:success error:error compositeKeyFactors:compositeKeyFactors isBiometricUnlock:isBiometricOpen];
                });
            }];
        });
    }
}

- (void)onUnlocked:(BOOL)success
             error:(NSError*)error
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
 isBiometricUnlock:(BOOL)isBiometricUnlock {
    [self enableMasterCredentialsEntry:YES];

    if(success) {
        [self maybePromptForBiometricEnrol:compositeKeyFactors];
        
        // Record Key File if one was used...
        
        self.model.databaseMetadata.keyFileBookmark = Settings.sharedInstance.doNotRememberKeyFile ? nil : self.selectedKeyFileBookmark;
        [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
    }
    else {
        if(isBiometricUnlock && self.model.databaseMetadata != nil) {
            self.model.databaseMetadata.touchIdPassword = nil;
            self.model.databaseMetadata.hasPromptedForTouchIdEnrol = NO;
            [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
        }
        
        NSString* loc = NSLocalizedString(@"mac_could_not_unlock_database", @"Could Not Unlock Database");
        [Alerts error:loc error:error window:self.view.window];
    
        [self bindBiometricButtonsOnLockScreen];
    }
}

- (void)maybePromptForBiometricEnrol:(CompositeKeyFactors*)compositeKeyFactors {
    if ( BiometricIdHelper.sharedInstance.biometricIdAvailable &&
        (Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial) &&
        !self.model.databaseMetadata.hasPromptedForTouchIdEnrol) {
        NSLog(@"Biometric ID is available on Device. Should we enrol?");

        NSString* loc = NSLocalizedString(@"mac_use_biometric_to_open_in_future_fmt", @"Would you like to use %@ to open this database in the future?");        
        NSString* message = [NSString stringWithFormat:loc, BiometricIdHelper.sharedInstance.biometricIdName];

        [Alerts yesNo:message
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   self.model.databaseMetadata.isTouchIdEnabled = YES;
                   self.model.databaseMetadata.touchIdPassword = compositeKeyFactors.password;
                   
                   [self caveatAboutTouchId];
               }
               else {
                   self.model.databaseMetadata.isTouchIdEnabled = NO;
               }
           
               self.model.databaseMetadata.hasPromptedForTouchIdEnrol = YES;
               [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
           }];
    }
}

- (void)caveatAboutTouchId {
    if(!Settings.sharedInstance.warnedAboutTouchId) { // First Time? Display Touch ID Caveat
        Settings.sharedInstance.warnedAboutTouchId = YES;
        
        NSString* loc = NSLocalizedString(@"mac_touch_id_one_time_warning", @"Touch ID Considerations\n\nWhile this is very convenient, it is not a perfect system for protecting your passwords. It is provided for convenience only. It is within the realm of possibilities that someone with access to your device or your fingerprint, can produce a good enough fake fingerprint to fool Apple’s Touch ID. In addition, on your Mac, your master password will be securely stored in the Keychain. This means it is possible for someone with administrative privileges to search your Keychain for your master password. You should be aware that a strong passphrase held only in your mind provides the most secure experience with StrongBox.\n\nPlease take all of this into account, and make your decision to use Touch ID based on your preferred balance of convenience and security.");
      
        [Alerts info:loc window:self.view.window];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onAutoLock:(NSNotification*)notification {
    if(self.model && !self.model.locked && !self.model.document.isDocumentEdited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLock:nil];
        });
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        if([self.model.document isDocumentEdited]) {
            NSString* loc = NSLocalizedString(@"mac_cant_lock_db_while_changes_pending", @"You cannot lock a database while changes are pending. Save changes and lock now?");
            
            [Alerts yesNo:loc window:self.view.window completion:^(BOOL yesNo) {
                if(yesNo) {
                    NSString* loc = NSLocalizedString(@"generic_locking_ellipsis", @"Locking...");
                    [self showProgressModal:loc];
                    [self.model.document saveDocumentWithDelegate:self didSaveSelector:@selector(lockSafeContinuation:) contextInfo:nil];
                }
                else {
                    return;
                }
            }];
        }
        else {
            // MMcG: Causes Dock Icon to Bounce which isn't great... Just forget about it...
            
            // NSString* loc = NSLocalizedString(@"generic_locking_ellipsis", @"Locking...");
            //[self showProgressModal:loc];

            [self lockSafeContinuation:nil];
        }
    }
}

- (IBAction)lockSafeContinuation:(id)sender {
    NSString* sid = [self selectedItemSerializationId];
    [self closeAllDetailsWindows];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.model lock:sid];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLockDone];
        });
    });
}

- (void)onLockDone {
    [self hideProgressModal];
    
    [self bindToModel];
    
    self.textFieldMasterPassword.stringValue = @"";
    [self setInitialFocus];
    
    [self.view setNeedsDisplay:YES];
    
    // Finally Clear Clipboard if so configured...
    
    if(Settings.sharedInstance.clearClipboardEnabled) {
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate clearClipboardWhereAppropriate];
    }
}

- (void)promptForMasterPassword:(BOOL)new completion:(void (^)(BOOL okCancel))completion {
    if(self.model && !self.model.locked) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.changeMasterPassword = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
            
            NSString* loc = new ? NSLocalizedString(@"mac_please_set_master_credentials", @"Please Enter the Master Credentials for this Database") : NSLocalizedString(@"mac_change_master_credentials", @"Change Master Credentials");
            
            self.changeMasterPassword.titleText = loc;
            self.changeMasterPassword.databaseFormat = self.model.format;
            
            [self.view.window beginSheet:self.changeMasterPassword.window  completionHandler:^(NSModalResponse returnCode) {
                if(returnCode == NSModalResponseOK) {
                    [self.model setCompositeKeyFactors:self.changeMasterPassword.confirmedCompositeKeyFactors];

                    DatabaseMetadata* metadata = self.model.databaseMetadata;
                    
                    if(self.changeMasterPassword.keyFileUrl && !Settings.sharedInstance.doNotRememberKeyFile) {
                        NSError* error;
                        NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:self.changeMasterPassword.keyFileUrl error:&error];
                        if(bookmark) {
                            metadata.keyFileBookmark = bookmark;
                        }
                        else {
                            NSLog(@"Could not set key file bookmark for url... [%@]", error);
                        }
                    }
                    else {
                        metadata.keyFileBookmark = nil;
                    }
                    
                    [DatabasesManager.sharedInstance update:metadata];
                }
                
                if(completion) {
                    completion(returnCode == NSModalResponseOK);
                }
            }];
        });
    }
}

- (IBAction)onChangeMasterPassword:(id)sender {
    [self promptForMasterPassword:NO completion:^(BOOL okCancel) {
        if(okCancel) {
            [[NSApplication sharedApplication] sendAction:@selector(saveDocument:) to:nil from:self];
            
            NSString* loc = NSLocalizedString(@"mac_master_credentials_changed_and_saved", @"Master Credentials Changed and Database Saved");
            [Alerts info:loc window:self.view.window];
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onFind:(id)sender {
    [self.view.window makeFirstResponder:self.searchField];
}

- (IBAction)onSearch:(id)sender {    
    self.itemsCache = nil; // Clear items cache
    
    Node* currentSelection = [self getCurrentSelectedItem];
    
    [self.outlineView reloadData];
    
    if( self.searchField.stringValue.length > 0) {
        // Select first match...
        
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
        // Search cleared - can we maintain the selection?
        
        [self selectItem:currentSelection];
    }
}

- (IBAction)toggleRevealMasterPasswordTextField:(id)sender {
    self.textFieldMasterPassword.showsText = !self.textFieldMasterPassword.showsText;

    [self bindRevealMasterPasswordTextField];
}

- (void)bindRevealMasterPasswordTextField {
    NSString* title = !self.textFieldMasterPassword.showsText ?
        NSLocalizedString(@"mac_button_reveal_master_password_title", @"⌘R to Reveal") :
        NSLocalizedString(@"mac_button_conceal_master_password_title", @"⌘R to Conceal");

    [self.buttonToggleRevealMasterPasswordTip setTitle:title];
    
    self.imageViewShowHidePassword.image = !self.textFieldMasterPassword.showsText ? [NSImage imageNamed:@"show"] : [NSImage imageNamed:@"hide"];
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)dereferenceAndCopyToPasteboard:(NSString*)text item:(Node*)item {
    if(!item || !text.length) {
        [[NSPasteboard generalPasteboard] clearContents];
        return;
    }
    
    NSString* deref = [self.model dereference:text node:item];
    
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
    [ClipboardManager.sharedInstance copyConcealedString:field.value];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, field.key, NSLocalizedString(@"generic_fieldname_custom_field", @"Custom Field")]];
}

- (void)copyTitle:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.title item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_title", @"Title")]];
}

- (void)copyUsername:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.username item:item];
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_username", @"Username")]];
}

- (void)copyEmail:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.email item:item];
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_email", @"Email")]];
}

- (void)copyUrl:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.url item:item];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_url", @"URL")]];
}

- (void)copyNotes:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.notes item:item];

    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_notes", @"Notes")]];
}

- (void)copyPassword:(Node*)item {
    if(!item || item.isGroup) {
        return;
    }

    [self dereferenceAndCopyToPasteboard:item.fields.password item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_password", @"Password")]];
}

- (void)copyTotp:(Node*)item {
    if(!item || !item.fields.otpToken) {
        return;
    }

    NSString *password = item.fields.otpToken.password;
    [ClipboardManager.sharedInstance copyConcealedString:password];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_totp", @"TOTP")]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (Node*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    //NSLog(@"Selected Row: %ld", (long)selectedRow);
    
    return [self.outlineView itemAtRow:selectedRow];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)enableDragDrop {
    [self.outlineView registerForDraggedTypes:@[kDragAndDropInternalUti]];
    [self.outlineView registerForDraggedTypes:@[kDragAndDropExternalUti]];
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

- (id)copy:(id)sender {
    NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    NSArray* selected = [self getSelectedItems];
    
    [self placeItemsOnPasteboard:pasteboard items:selected];
    
    return nil;
}

- (id)paste:(id)sender {
    NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    
    Node* selected = [self getCurrentSelectedItem];
    Node* destinationItem = self.model.rootGroup;
    if(selected) {
        destinationItem = selected.isGroup ? selected : selected.parent;
    }
    
    BOOL ret = [self pasteItemsFromPasteboard:pasteboard destinationItem:destinationItem source:nil clear:NO];
    if(!ret) {
        [Alerts info:@"Could not paste! Unknown Error." window:self.view.window];
    }
    
    return nil;
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
    
    NSArray<Node*> *allSelected = items;
    
    // We need to filter out children that are already included because the group is included,
    // so we're not copying/moving twice
    
    NSArray<Node*>* groups = [allSelected filter:^BOOL(Node * _Nonnull obj) {
        return obj.isGroup;
    }];
    NSArray<Node*>* minimalNodeSet = [allSelected filter:^BOOL(Node * _Nonnull node) {
        BOOL alreadyContained = [groups anyMatch:^BOOL(Node * _Nonnull group) {
            return [group contains:node];
        }];
        return !alreadyContained;
    }];
    
    
    // Internal -> Moves
    
    NSArray<NSString*>* internalSerializationIds = [self getInternalSerializationIds:minimalNodeSet];
    [pasteboard setPropertyList:internalSerializationIds forType:kDragAndDropInternalUti];
    
    // External -> Copies
    
    NSData* json = [self getJsonForNodes:minimalNodeSet];
    [pasteboard setData:json forType:kDragAndDropExternalUti];
    
    return YES;
}

- (NSArray<NSString*>*)getInternalSerializationIds:(NSArray<Node*>*)nodes {
    return [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj getSerializationId:self.model.format != kPasswordSafe];
    }];
}

- (NSData*)getJsonForNodes:(NSArray<Node*>*)nodes {
    SerializationPackage *serializationPackage = [[SerializationPackage alloc] init];
    
    // Node Hierarchy
    
    NSArray<NSDictionary*>* nodeDictionaries = [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj serialize:serializationPackage];
    }];
    
    // Attachments
    
    NSMutableDictionary<NSString*, NSString*> *attachmentsMap = [NSMutableDictionary dictionaryWithCapacity:serializationPackage.usedAttachmentIndices.count];
    
    for (NSNumber* index in serializationPackage.usedAttachmentIndices) {
        DatabaseAttachment* a = self.model.attachments[index.integerValue];
        [attachmentsMap setValue:[a.data base64EncodedStringWithOptions:kNilOptions] forKey:index.stringValue];
    }
    
    // Custom Icons
    
    NSMutableDictionary<NSString*, NSString*> *customIconsMap = [NSMutableDictionary dictionaryWithCapacity:serializationPackage.usedCustomIcons.count];
    
    for(NSUUID* icon in serializationPackage.usedCustomIcons) {
        NSData* iconData = self.model.customIcons[icon];
        NSString* iconB64 = [iconData base64EncodedStringWithOptions:kNilOptions];
        [customIconsMap setValue:iconB64 forKey:icon.UUIDString];
    }
    
    // Package
    
    NSDictionary *serialized = @{ @"sourceFormat" : @(self.model.format),
                                  @"nodes" : nodeDictionaries,
                                  @"attachmentsMap" : attachmentsMap,
                                  @"customIconsMap" : customIconsMap };
    
    // JSON
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:serialized options:kNilOptions error:&error];

    if(!data) {
        [Alerts error:@"Could not serialize these items!" error:error window:self.view.window];
    }
    
    return data;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;

    if ([info draggingSource] == self.outlineView) {
        NSArray<NSString*>* serializationIds = [info.draggingPasteboard propertyListForType:kDragAndDropInternalUti];
        NSArray<Node*>* sourceItems = [serializationIds map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self.model getItemFromSerializationId:obj];
        }];
        
        BOOL notValid = [sourceItems anyMatch:^BOOL(Node * _Nonnull obj) {
            BOOL valid = !destinationItem ||
                        (destinationItem.isGroup && [self.model validateChangeParent:destinationItem node:obj]);

            return !valid;
        }];
        
        //NSLog(@"%@ -> %d", item ? ((Node*)item).title : @"ROOT", !notValid);

        return !notValid ? NSDragOperationMove : NSDragOperationNone;
    }
    else {
        NSData* json = [info.draggingPasteboard dataForType:kDragAndDropExternalUti];
        return json && destinationItem.isGroup ? NSDragOperationCopy : NSDragOperationNone;
    }
}

-(BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info
              item:(id)item
        childIndex:(NSInteger)index {
    
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;

    return [self pasteItemsFromPasteboard:info.draggingPasteboard destinationItem:destinationItem source:info.draggingSource clear:YES];
}

- (BOOL)pasteItemsFromPasteboard:(NSPasteboard*)pasteboard
                 destinationItem:(Node*)destinationItem
                          source:(id)source
                           clear:(BOOL)clear
{
    if(![pasteboard propertyListForType:kDragAndDropExternalUti] &&
       ![pasteboard dataForType:kDragAndDropInternalUti]) {
        return NO;
    }
    
    if (source == self.outlineView) {
        NSArray<NSString*>* serializationIds = [pasteboard propertyListForType:kDragAndDropInternalUti];
        NSArray<Node*>* sourceItems = [serializationIds map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self.model getItemFromSerializationId:obj];
        }];

        for (Node* sourceItem in sourceItems) {
            BOOL result = [self.model changeParent:destinationItem node:sourceItem];
            NSLog(@"move: [%@] - success: [%d]", [sourceItem getSerializationId:self.model.format != kPasswordSafe], result);
        }

        if(clear) {
            [pasteboard clearContents];
        }
        return YES;
    }
    else if(destinationItem.isGroup) {
        NSData* json = [pasteboard dataForType:kDragAndDropExternalUti];
        if(json && destinationItem.isGroup) {
            NSLog(@"copy pasta!");

            BOOL ret = [self pasteFromExternal:json destinationItem:destinationItem];
            if(clear) {
                [pasteboard clearContents];
            }
            return ret;
        }
    }
    
    if(clear) {
        [pasteboard clearContents];
    }
    return NO;
}

- (BOOL)pasteFromExternal:(NSData*)json destinationItem:(Node*)destinationItem {
    NSError* error;
    NSDictionary* serialized = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];

    if(!serialized) {
        [Alerts error:@"Could not deserialize!" error:error window:self.view.window];
        return NO;
    }
    
    NSNumber* sourceFormatNum = serialized[@"sourceFormat"];
    DatabaseFormat sourceFormat = sourceFormatNum.integerValue;
    NSArray<NSDictionary*>* serializedNodes = serialized[@"nodes"];
    
    BOOL allowDuplicateGroupTitles = self.model.format != kPasswordSafe;
    
    // Rebuild Node Hierarchy
    
    NSMutableArray<Node*>* nodes = @[].mutableCopy;
    NSError* err;
    for (NSDictionary* obj in serializedNodes) {
        Node* n = [Node deserialize:obj parent:destinationItem allowDuplicateGroupTitles:allowDuplicateGroupTitles error:&err];
        
        if(!n) {
            [Alerts error:err window:self.view.window];
            return NO;
        }
        
        [nodes addObject:n];
    }
    
    [self processFormatIncompatibilities:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    
    return YES;
}

- (void)processPasswordSafeToKeePass2:(NSDictionary*)serialized
                                nodes:(NSArray<Node*>*)nodes
                      destinationItem:(Node*)destinationItem
                         sourceFormat:(DatabaseFormat)sourceFormat {
    // Password Safe -> KeePass 2 (Emails -> Custom Field)
    
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

        [Alerts yesNo:loc
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
    // Password Safe -> KeePass 1 (Emails -> Appended To End of Notes, No Entries at Root)
   
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
    
    BOOL pastingEntriesToRoot = ((destinationItem == nil || destinationItem == self.model.rootGroup) && rootEntries.count);
    
    if(nodesWithEmails.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries", @"KeePass 1 does not support entries at the root level, these will be discarded. KeePass 1 also does not natively support the 'Email' field. Strongbox will append it instead to the end of the 'Notes' field.\nDo you want to continue?");
        
        [Alerts yesNo:loc
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
    // KeePass 2 -> Password Safe (Loss of Icons, Attachments, Custom Fields?)
    
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
        
        [Alerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.iconId = nil;
                       incompatible.customIconUuid = nil;
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
    // KeePass 2 -> KeePass 1 (Only 1 Attachment! No Entries at Root!)
    
    NSArray<Node*>* allChildNodes = [nodes flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.children;
    }];
    NSMutableArray<Node*>* all = allChildNodes.mutableCopy;
    [all addObjectsFromArray:nodes];
    
    NSArray<Node*>* incompatibles = [all filter:^BOOL(Node * _Nonnull obj) {
        BOOL customIcon = obj.customIconUuid != nil;
        BOOL tooManyAttachments = obj.fields.attachments.count > 1;
        BOOL customFields = obj.fields.customFields.count;
        
        return customIcon || tooManyAttachments || customFields;
    }];
    
    NSArray<Node*>* rootEntries = [nodes filter:^BOOL(Node * _Nonnull obj) {
        return !obj.isGroup;
    }];
    BOOL pastingEntriesToRoot = ((destinationItem == nil || destinationItem == self.model.rootGroup) && rootEntries.count);

    if(incompatibles.count || pastingEntriesToRoot) {
        NSString* loc = NSLocalizedString(@"mac_keepass1_does_not_support_root_entries_or_attachments", @"The KeePass 1 (KDB) does not support entries at the root level, these will be discarded.\n\nThe KeePass 1 (KDB) format also does not support multiple attachments, custom fields or custom icons. If you continue only the first attachment from each item will be copied to this database. Custom Fields and Icons will be discarded.\nDo you want to continue?");

        [Alerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.customIconUuid = nil;
                       NodeFileAttachment* firstAttachment = incompatible.fields.attachments.firstObject;
                       [incompatible.fields.attachments removeAllObjects];
                       if(firstAttachment) {
                           [incompatible.fields.attachments addObject:firstAttachment];
                       }
                       [incompatible.fields removeAllCustomFields];
                   }
                   
                   NSArray* filtered = nodes;
                   if(pastingEntriesToRoot) {
                       filtered = [nodes filter:^BOOL(Node * _Nonnull obj) {
                           return obj.isGroup;
                       }];
                   }
                   
                   [self continuePaste:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
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
    // KeePass 1 -> Password Safe (Loss of Icons & Attachment)
    
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
        
        [Alerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
               if(yesNo) {
                   for (Node* incompatible in incompatibles) {
                       incompatible.iconId = nil;
                       incompatible.customIconUuid = nil;
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
                       destinationItem:(Node*)destinationItem
                          sourceFormat:(DatabaseFormat)sourceFormat {
    if (sourceFormat == kPasswordSafe && (self.model.format == kKeePass || self.model.format == kKeePass4)) {
        [self processPasswordSafeToKeePass2:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if (sourceFormat == kPasswordSafe && self.model.format == kKeePass1) {
        [self processPasswordSafeToKeePass1:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && self.model.format == kPasswordSafe) {
        [self processKeePass2ToPasswordSafe:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if ((sourceFormat == kKeePass || sourceFormat == kKeePass4) && self.model.format == kKeePass1) {
        [self processKeePass2ToKeePass1:serialized nodes:nodes destinationItem:destinationItem sourceFormat:sourceFormat];
    }
    else if (sourceFormat == kKeePass1 && self.model.format == kPasswordSafe) {
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
    NSDictionary<NSString*, NSString*>* attachmentsMap = serialized[@"attachmentsMap"];
    NSMutableDictionary<NSString*, NSString*> *customIconsMap = serialized[@"customIconsMap"];
    
    [self rebuildAttachments:nodes attachmentsMap:attachmentsMap];
    
    // Rebuild Custom Icons

    [self rebuildCustomIcons:nodes customIconsMap:customIconsMap];
    
    // Add Items to our Model...
    
    BOOL allowDuplicateGroupTitles = self.model.format != kPasswordSafe;
    
    BOOL success = [self.model addChildren:nodes parent:destinationItem allowDuplicateGroupTitles:allowDuplicateGroupTitles];
    
    if(!success) {
        [Alerts info:@"Could Not Paste"
     informativeText:@"Could not place these items here. Unknown error."
              window:self.view.window
          completion:nil];
    }
}

- (void)rebuildCustomIcons:(NSArray<Node*>*)nodes customIconsMap:(NSDictionary<NSString*, NSString*>*)customIconsMap {
    for (Node* node in nodes) {
        [self rebuildCustomIconsForSerializedNode:node customIconsMap:customIconsMap];
    }
}

- (void)rebuildCustomIconsForSerializedNode:(Node*)node customIconsMap:(NSDictionary<NSString*, NSString*>*)customIconsMap {
    NSUUID* original = node.customIconUuid;
    node.customIconUuid = nil;

    if(original) {
        NSString* b64Data = customIconsMap[original.UUIDString];
        NSData* data = [[NSData alloc] initWithBase64EncodedString:b64Data options:kNilOptions];
        
        [self.model setItemIcon:node index:nil existingCustom:nil custom:data rationalize:NO batchUpdate:NO]; // Make sure not to rationalize
    }
    
    // Recurse into children
    
    [self rebuildCustomIcons:node.children customIconsMap:customIconsMap];
}

- (void)rebuildAttachments:(NSArray<Node*>*)nodes attachmentsMap:(NSDictionary<NSString*, NSString*>*)attachmentsMap {
    for (Node* node in nodes) {
        [self rebuildAttachmentsForSerializedNode:node attachmentsMap:attachmentsMap];
    }
}

- (void)rebuildAttachmentsForSerializedNode:(Node*)node attachmentsMap:(NSDictionary<NSString*, NSString*>*)attachmentsMap {
    // Make a copy and clear this items attachments - we will re-add below with the right indices etc
    
    NSArray* originalAttachments = node.fields.attachments.copy;
    [node.fields.attachments removeAllObjects];
    
    for (NodeFileAttachment* attachment in originalAttachments) {
        NSString* b64Data = attachmentsMap[@(attachment.index).stringValue];
        NSData* data = [[NSData alloc] initWithBase64EncodedString:b64Data options:kNilOptions];
        UiAttachment* uiAttachment = [UiAttachment attachmentWithFilename:attachment.filename data:data];
    
        [self.model addItemAttachment:node attachment:uiAttachment rationalize:NO]; // DO Not Rationalize since these attachments are not officially linked to the database yet!
    }
    
    // Recurse into children
    
    [self rebuildAttachments:node.children attachmentsMap:attachmentsMap];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onCreateRecord:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    if(![self.model addNewRecord:parent]) {
        NSString* loc = NSLocalizedString(@"mac_alert_cannot_create_item_here", @"You cannot create a new item here. It must be within an existing folder.");
        [Alerts info:loc window:self.view.window];
        return;
    }
}

- (IBAction)onCreateGroup:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);
    
    NSString* loc = NSLocalizedString(@"mac_please_enter_a_title_for_new_group", @"Please enter a Title for your new Group");
    NSString* title = [[[Alerts alloc] init] input:loc defaultValue:kDefaultNewTitle allowEmpty:NO];
    
    if(title.length) {
        [self.model addNewGroup:parent title:title];
    }
}

- (void)onNewItemAdded:(Node*)node newRecord:(BOOL)newRecord {
    self.itemsCache = nil; // Clear items cache
    self.searchField.stringValue = @""; // Clear any ongoing search...
    [self.outlineView reloadData];
    NSInteger row = [self findRowForItemExpandIfNecessary:node];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
    }

    if(newRecord) {
        [self openItemDetails:node newEntry:YES];
        
        [self expressDownloadFavIconIfAppropriateForNewOrUpdatedNode:node];
    }    
}

- (IBAction)onDelete:(id)sender {
    NSIndexSet *rows = [self.outlineView selectedRowIndexes];

    if(rows.count == 1) {
        Node *item = [self getCurrentSelectedItem];
        if(!item) {
            return;
        }
        BOOL willRecycle = [self.model deleteWillRecycle:item];
        
        NSString* loc = willRecycle ? NSLocalizedString(@"mac_are_you_sure_recycle_bin_yes_no_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?") :
                                    NSLocalizedString(@"mac_are_you_sure_delete_yes_no_fmt", @"Are you sure you want to delete '%@'?");
        
        [Alerts yesNo:[NSString stringWithFormat:loc, item.title]
               window:self.view.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                if(![self.model deleteItem:item]) {
                    [Alerts info:@"There was a problem trying to delete this item." window:self.view.window];
                }
            }
        }];
    }
    else {
        BOOL willRecycle = self.model.recycleBinEnabled;
        
        NSString* loc = willRecycle ?
            NSLocalizedString(@"mac_are_you_sure_recycle_bin_multiple_yes_no_fmt", @"Are you sure you want to send %lu items to the Recycle Bin?") :
            NSLocalizedString(@"mac_are_you_sure_delete_multiple_yes_no_fmt", @"Are you sure you want to delete %lu items?");
        
        [Alerts yesNo:[NSString stringWithFormat:loc, (unsigned long)rows.count]
               window:self.view.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                [rows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    Node* node = [self.outlineView itemAtRow:idx];
                    [self.model deleteItem:node];
                }];
            }
        }];
    }
}

- (IBAction)onLaunchUrl:(id)sender {
    Node* item = [self getCurrentSelectedItem];
    
    NSString *urlString = [self.model dereference:item.fields.url node:item];
    
    if (!urlString.length) {
        return;
    }
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];

//    NSLog(@"validating UI Item [%@]", NSStringFromSelector(theAction));

    Node* item = nil;
    
    if(self.model && !self.model.locked) {
        item = [self getCurrentSelectedItem];
    }
    
    if (theAction == @selector(onViewItemDetails:)) {
        return item != nil && !item.isGroup;
    }
    else if (theAction == @selector(copy:)) {
        return item != nil;
    }
    else if (theAction == @selector(paste:)) {
        NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
        NSData* blah = [pasteboard dataForType:kDragAndDropExternalUti];
        NSLog(@"Validate Paste - %d", blah != nil);
        return blah != nil;
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
        return item != nil;
    }
    else if(theAction == @selector(onCreateGroup:) ||
            theAction == @selector(onCreateRecord:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onCopyAsCsv:) ||
             theAction == @selector(onImportFromCsvFile:) ||
             theAction == @selector(onLock:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onShowSafeSummary:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onFind:)) {
        return self.model && !self.model.locked &&
        ([Settings sharedInstance].fullVersion || [Settings sharedInstance].freeTrial);
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
        return item && !item.isGroup && self.model.format == kPasswordSafe;
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
    else if (theAction == @selector(onDatabasePreferences:)) {
        return NO; // TODO:
    }
    else if (theAction == @selector(saveDocument:)) {
        return !self.model.locked;
    }
    else if (theAction == @selector(onSetItemIcon:)) {
        return item != nil && self.model.format != kPasswordSafe;
    }
    else if(theAction == @selector(onSetTotp:)) {
        return item && !item.isGroup;
    }
    else if(theAction == @selector(onClearTotp:)) {
        return item && !item.isGroup && item.fields.otpToken;
    }
    else if (theAction == @selector(onViewItemHistory:)) {
        return
            item != nil &&
            !item.isGroup &&
            item.fields.keePassHistory.count > 0 &&
            (self.model.format == kKeePass || self.model.format == kKeePass4);
    }
    else if(theAction == @selector(onOutlineHeaderColumnsChanged:)) {
        NSMenuItem* menuItem = (NSMenuItem*)anItem;
        menuItem.state = [self isColumnVisible:menuItem.identifier];
        return [self isColumnAvailableForModel:menuItem.identifier];
    }
    else if(theAction == @selector(onPrintDatabase:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onDownloadFavIcons:)) {
        return !self.model.locked && (item == nil || ((self.model.format == kKeePass || self.model.format == kKeePass4) && (item.isGroup || item.fields.url.length)));
    }
    else if (theAction == @selector(onPreviewQuickViewAttachment:)) {
        return !self.model.locked && item != nil && !item.isGroup && self.model.format != kPasswordSafe && self.attachments.count > 0 && self.attachmentsTable.selectedRow != -1;
    }
    else if (theAction == @selector(onSaveQuickViewAttachmentAs:)) {
        return !self.model.locked && item != nil && !item.isGroup && self.model.format != kPasswordSafe && self.attachments.count > 0 && self.attachmentsTable.selectedRow != -1;
    }
    
    return YES;
}

- (void)clearTouchId {
    self.model.databaseMetadata.hasPromptedForTouchIdEnrol = NO; // We can ask again on next open
    self.model.databaseMetadata.touchIdPassword = nil;
    
    [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
    
    [self bindLockScreenUi];
}

- (IBAction)onDatabasePreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToDatabasePreferences" sender:nil];
}

- (IBAction)onCopyAsCsv:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.model.rootGroup] encoding:NSUTF8StringEncoding];
    
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
    
    [Alerts info:loc
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
            //something went wrong; log the error and exit
            NSLog(@"error parsing file: %@", error);
            [Alerts error:error window:self.view.window];
            return;
        }
        else if(rows.count == 0){
            NSString* loc = NSLocalizedString(@"mac_csv_file_contains_zero_rows", @"CSV File Contains Zero Rows. Cannot Import.");
            [Alerts info:loc window:self.view.window];
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
                
                [Alerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                    if(yesNo) {
                        [self.model importRecordsFromCsvRows:rows];

                        NSString* loc = NSLocalizedString(@"mac_csv_file_successfully_imported", @"CSV File Successfully Imported.");
                        [Alerts info:loc window:self.view.window];
                    }
                }];
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_no_valid_csv_rows_found", @"No valid rows found. Ensure CSV file contains a header row and at least one of the required fields.");

                [Alerts info:loc window:self.view.window];
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
    NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");

    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.model == nil || self.model.locked) {
            [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
            [self bindLockScreenUi];
        }
        else {
            Node* currentSelection = [self getCurrentSelectedItem];
                  
            self.itemsCache = nil; // Clear items cache

            [self bindColumnsToSettings];
            [self customizeOutlineView];

            [self.outlineView reloadData];

            [self selectItem:currentSelection];
        }
    });
}

static BasicOrderedDictionary* getSummaryDictionary(ViewModel* model) {
    BasicOrderedDictionary *ret = [[BasicOrderedDictionary alloc] init];
    
    for (NSString* key in [model.metadata kvpForUi].allKeys) {
        NSString *value = [[model.metadata kvpForUi] objectForKey:key];
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
    [self.outlineView deselectAll:nil]; // Funky side effect, no selection -> show safe summary
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.tableViewSummary) {
        BasicOrderedDictionary* dictionary = getSummaryDictionary(self.model);
        return dictionary.count;
    }
    else if (tableView == self.attachmentsTable) {
        return self.attachments.count;
    }
    else {
        return self.customFields.count;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView == self.tableViewSummary) {
        NSTableCellView* cell = [self.tableViewSummary makeViewWithIdentifier:@"KeyCellIdentifier" owner:nil];

        BasicOrderedDictionary *dict = getSummaryDictionary(self.model);
        
        NSString *key = dict.allKeys[row];
        NSString *value = [dict objectForKey:key];
        
        value = value == nil ? @"" : value; // Safety Only
        
        cell.textField.stringValue = [tableColumn.identifier isEqualToString:@"KeyColumn"] ? key : value;
        
        return cell;
    }
    else if (tableView == self.attachmentsTable) {
        NodeFileAttachment* attachment = self.attachments[row];
        DatabaseAttachment* dbAttachment = self.model.attachments[attachment.index];

        BOOL isFileNameColumn = [tableColumn.identifier isEqualToString:@"filename"];
        NSString* cellId = isFileNameColumn ? @"AttachmentFileNameCellIdentifier" : @"AttachmentFileSizeCellIdentifier";
        NSTableCellView* cell = [self.attachmentsTable makeViewWithIdentifier:cellId owner:nil];

        cell.textField.stringValue = isFileNameColumn ? attachment.filename : [NSByteCountFormatter stringFromByteCount:dbAttachment.data.length countStyle:NSByteCountFormatterCountStyleFile];
        
        if(self.attachmentsIconCache == nil) {
            self.attachmentsIconCache = @{};
            [self buildAttachmentsIconCache];
        }
        
        NSImage* cachedIcon = self.attachmentsIconCache[@(attachment.index)];
        if(cachedIcon && Settings.sharedInstance.showAttachmentImagePreviewsOnQuickViewPanel) {
            cell.imageView.image = cachedIcon;
        }
        else {
            NSImage* img = [[NSWorkspace sharedWorkspace] iconForFileType:attachment.filename.pathExtension];
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
            
            cell.value = field.value;
            cell.protected = field.protected && !(field.value.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields);
            cell.valueHidden = field.protected && !(field.value.length == 0 && !Settings.sharedInstance.concealEmptyProtectedFields); // Initially Hide the Value if it is protected
            
            return cell;
        }
    }
}

- (void)buildAttachmentsIconCache {
    NSArray *workingCopy = [self.model.attachments copy];
    NSMutableDictionary *tmp = @{}.mutableCopy;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0;i<workingCopy.count;i++) {
            DatabaseAttachment* dbAttachment = workingCopy[i];
            
            NSImage* img = [[NSImage alloc] initWithData:dbAttachment.data];
            if(img) {
                img = scaleImage(img, CGSizeMake(17, 17));
                tmp[@(i)] = img;
            }
        }
        
        self.attachmentsIconCache = tmp.copy;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.attachmentsTable reloadData];
            [self.view setNeedsDisplay:YES];
        });
    });
}

// Preview Attachments

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

- (IBAction)onPreviewQuickViewAttachment:(id)sender {
    NSInteger selected = self.attachmentsTable.selectedRow;
    if(selected >= 0 && selected < self.attachments.count) {
        [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:self];
    }
}

- (IBAction)onSaveQuickViewAttachmentAs:(id)sender {
    NSInteger selected = self.attachmentsTable.selectedRow;
    if(selected < 0 || selected >= self.attachments.count) {
        return;
    }
    
    NodeFileAttachment* nodeAttachment = self.attachments[selected];
    
    if(nodeAttachment.index < 0 || nodeAttachment.index >= self.model.attachments.count) {
        NSLog(@"Node Attachment out of bounds of Database Attachments. [%d]", nodeAttachment.index);
        return;
    }
    
    // Save As Dialog...
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = nodeAttachment.filename;
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            DatabaseAttachment* dbAttachment = [self.model.attachments objectAtIndex:nodeAttachment.index];
            [dbAttachment.data writeToFile:savePanel.URL.path atomically:YES];
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
    if(self.model.format == kPasswordSafe) {
        return;
    }
    
    __weak ViewController* weakSelf = self;
    self.selectPredefinedIconController = [[SelectPredefinedIconController alloc] initWithWindowNibName:@"SelectPredefinedIconController"];
    self.selectPredefinedIconController.customIcons = self.model.customIcons;
    self.selectPredefinedIconController.hideSelectFile = self.model.format == kKeePass1;
    self.selectPredefinedIconController.onSelectedItem = ^(NSNumber * _Nullable index, NSData * _Nullable data, NSUUID * _Nullable existingCustom, BOOL showFindFavIcons) {
        if(showFindFavIcons) {
            [weakSelf showFindFavIconsForItem:item];
        }
        else {
            onSelectedNewIcon(weakSelf.model, item, index, data, existingCustom, weakSelf.view.window);
        }
    };

    
    [self.view.window beginSheet:self.selectPredefinedIconController.window  completionHandler:nil];
}

void onSelectedNewIcon(ViewModel* model, Node* item, NSNumber* index, NSData* data, NSUUID* existingCustom, NSWindow* window) {
    if(data) {
        NSImage* icon = [[NSImage alloc] initWithData:data];
        if(icon) {
            if(data.length > kMaxRecommendCustomIconSize) {
                NSImage* rescaled = scaleImage(icon, CGSizeMake(kMaxCustomIconDimension, kMaxCustomIconDimension));
                CGImageRef cgRef = [rescaled CGImageForProposedRect:NULL context:nil hints:nil];
                NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
                NSData *compressed = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{ }];
                NSInteger saving = data.length - compressed.length;
                if(saving < 0) {
                    NSLog(@"Not much saving from PNG trying JPG...");
                    compressed = [newRep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{ }];
                    saving = data.length - compressed.length;
                }
                
                if(saving > (32 * 1024)) {
                    NSString* savingStr = [[[NSByteCountFormatter alloc] init] stringFromByteCount:saving];
                    
                    NSString* loc = NSLocalizedString(@"mac_large_image_as_icon_use_scaled_down_version_fmt", @"This is a large image to use as an icon. Would you like to use a scaled down version to save %@?");
                    
                    NSString* message = [NSString stringWithFormat:loc, savingStr];
                    [Alerts yesNo:message window:window completion:^(BOOL yesNo) {
                        if(yesNo) {
                            [model setItemIcon:item index:index existingCustom:existingCustom custom:compressed];
                        }
                        else {
                            [model setItemIcon:item index:index existingCustom:existingCustom custom:data];
                        }
                    }];
                }
                else {
                    [model setItemIcon:item index:index existingCustom:existingCustom custom:data];
                }
            }
            else {
                [model setItemIcon:item index:index existingCustom:existingCustom custom:data];
            }
        }
        else {
            NSString* loc = NSLocalizedString(@"mac_not_a_valid_image_file", @"This is not a valid image file.");
            [Alerts info:loc window:window];
        }
    }
    else {
        [model setItemIcon:item index:index existingCustom:existingCustom custom:nil];
    }
}

- (IBAction)onViewItemHistory:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil ||
       item.isGroup || item.fields.keePassHistory.count == 0 ||
       (!(self.model.format == kKeePass || self.model.format == kKeePass4))) {
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
    
    if(!Settings.sharedInstance.doNotShowTotp && item.fields.otpToken) {
        self.totpRow.hidden = NO;
        
        //NSLog(@"Token: [%@] - Password: %@", item.otpToken, item.otpToken.password);
        
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
    NSString* response = [[Alerts alloc] input:loc defaultValue:@"" allowEmpty:NO];
    
    if(response) {
        NSString* loc = NSLocalizedString(@"mac_is_this_a_stream_token_yes_no", @"Is this a Steam Token? (Say 'No' if you're unsure)");
        [Alerts yesNo:loc
               window:self.view.window
           completion:^(BOOL yesNo) {
            [self.model setTotp:item otp:response steam:yesNo];
        }];
    }
}

- (IBAction)onClearTotp:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil || item.isGroup || !item.fields.otpToken) {
        return;
    }
    
    [self.model clearTotp:item];
}

- (void)showPopupToastNotification:(NSString*)message {
    if(Settings.sharedInstance.doNotShowChangeNotifications) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = message;
    hud.color = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
    hud.mode = MBProgressHUDModeText;
    hud.margin = 10.f;
    hud.yOffset = 150.f;
    hud.removeFromSuperViewOnHide = YES;
    hud.dismissible = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud hide:YES];
    });
}

- (IBAction)onShowHideQuickView:(id)sender {
    Settings.sharedInstance.revealDetailsImmediately = !Settings.sharedInstance.revealDetailsImmediately;
    self.quickViewColumn.hidden = !Settings.sharedInstance.revealDetailsImmediately;
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
    
    NSString* databaseName = [NSString stringWithFormat:loc, self.model.databaseMetadata.nickName];
    NSString* htmlString = [self.model getHtmlPrintString:databaseName];

    //    NSError* error;
    //    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"print.html"];
    //    NSLog(@"Path: %@", path);
    //    if (![htmlString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
    //        NSLog(@"EEEEEEEEEEEEEEEK - %@", error);
    //    }

    // Print not supported:
    // WKWebView *webView = [[WKWebView alloc] init];
    // [webView loadHTMLString:htmlString baseURL:nil];
    
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
    NSArray* items = item ? (item.isGroup ? item.allChildRecords : @[item]) : self.model.rootGroup.allChildRecords;
    
    [FavIconDownloader showUi:self nodes:items viewModel:self.model onDone:^(BOOL go, NSDictionary<NSUUID *,NSImage *> * _Nullable selectedFavIcons) {
        if(go) {
            [self.model batchSetIcons:selectedFavIcons];
        }
    }];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)refreshKeyFileDropdown {
    [self.keyFilePopup.menu removeAllItems];
    
    // None & Browse
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_key_file_none", @"None")
                                      action:@selector(onSelectNoneKeyFile)
                               keyEquivalent:@""];
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_browse_for_key_file", @"Browse...")
                                      action:@selector(onBrowseForKeyFile)
                               keyEquivalent:@""];
    
    // Configured URL

    DatabaseMetadata *database = self.model.databaseMetadata;
    NSURL* configuredUrl;
    if(database && database.keyFileBookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:database.keyFileBookmark updatedBookmark:&updatedBookmark error:&error];
            
        if(!configuredUrl) {
            NSLog(@"getUrlFromBookmark: [%@]", error);
        }
        else {
           // NSLog(@"getUrlFromBookmark: [%@]", configuredUrl);
        }
        
        if(updatedBookmark) {
            database.keyFileBookmark = updatedBookmark;
            [DatabasesManager.sharedInstance update:database];
        }
    }

    // Currently Selected Bookmark...
    
    NSString* bookmark = self.selectedKeyFileBookmark;
    NSURL* currentlySelectedUrl;
    if(bookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        currentlySelectedUrl = [BookmarksHelper getUrlFromBookmark:bookmark updatedBookmark:&updatedBookmark error:&error];
        
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
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:openPanel.URL error:&error];
            
            if(!bookmark) {
                [Alerts error:error window:self.view.window];
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
    self.selectedKeyFileBookmark = self.model.databaseMetadata.keyFileBookmark;
    [self refreshKeyFileDropdown];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)keyFileIsSet {
    return self.selectedKeyFileBookmark != nil;
}

- (DatabaseFormat)getHeuristicFormat {
    BOOL probablyPasswordSafe = [self.model.fileUrl.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; // Not Ideal

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
//    NSLog(@"controlTextDidChange");
    [self bindLockScreenUi];
}

- (void)bindLockScreenUi {
    BOOL enabled = [self manualCredentialsAreValid];

    [self.buttonUnlockWithPassword setEnabled:enabled];
    
    //self.keyFilePopup.hidden = [self getHeuristicFormat] == kPasswordSafe;
    
    [self bindBiometricButtonsOnLockScreen];
    
    DatabaseMetadata* database = self.model.databaseMetadata;
    self.selectedKeyFileBookmark = database.keyFileBookmark ? database.keyFileBookmark : nil;
    
    [self refreshKeyFileDropdown];
}

- (void)bindBiometricButtonsOnLockScreen {
    if(![self biometricOpenIsAvailableForSafe]) {
        self.buttonUnlockWithTouchId.hidden = YES;
            }
    else {
        self.buttonUnlockWithTouchId.hidden = NO;
        [self.buttonUnlockWithTouchId setKeyEquivalent:@"\r"];
    }
}

@end
