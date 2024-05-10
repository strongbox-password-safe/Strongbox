//
//  DatabasesManagerVC.m
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabasesManagerVC.h"
#import "MacAlerts.h"
#import "DocumentController.h"
#import "Settings.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"
#import "CustomBackgroundTableView.h"
#import "AutoFillManager.h"
#import "SafeStorageProviderFactory.h"
#import "AddDatabaseSelectStorageVC.h"
#import "SyncLogViewController.h"
#import "MacSyncManager.h"
#import "Document.h"
#import "MacUrlSchemes.h"
#import "BackupsViewController.h"
#import "BackupsManager.h"
#import "Utils.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "macOSSpinnerUI.h"
#import "DatabasesManager.h"
#import "AboutViewController.h"

#ifndef NO_NETWORKING
    #import "SFTPStorageProvider.h"
    #import "SFTPConnectionsManager.h"
    #import "WebDAVConnectionsManager.h"
    #import "WebDAVStorageProvider.h"
#endif

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    #import "GoogleDriveStorageProvider.h"
    #import "DropboxV2StorageProvider.h"
#endif

#import "Strongbox-Swift.h"
#import "DatabaseNuker.h"



NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";
NSString* const kUpdateNotificationDatabasePreferenceChanged = @"UpdateNotificationDatabasePreferenceChanged";
NSString* const kWifiBrowserResultsUpdatedNotification = @"wifiBrowserResultsUpdated";

static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";
static NSString* const kDatabaseCellView = @"DatabaseCellView";
static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";
static const CGFloat kAutoRefreshTimeSeconds = 30.0f;



@interface DatabasesManagerVC () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSArray<NSString*>* databaseIds;
@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property NSTimer* timerRefresh;
@property BOOL hasLoaded;
@property (weak) IBOutlet ClickableTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonProperties;
@property (strong) IBOutlet NSMenu *dummyStrongReferenceToMenuToPreventCrash;
@property (weak) IBOutlet NSPopUpButton *buttonAdd;

@end

@implementation DatabasesManagerVC

- (void)close {
    [self.view.window cancelOperation:nil];
}

- (void)killRefreshTimer {
    
    
    if ( self.timerRefresh ) {
        [self.timerRefresh invalidate];
        self.timerRefresh = nil;
    }
}

- (void)startRefreshTimer {
    [self killRefreshTimer];
    
    
    
    self.timerRefresh = [NSTimer timerWithTimeInterval:kAutoRefreshTimeSeconds target:self selector:@selector(refreshVisibleRows) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefresh forMode:NSRunLoopCommonModes];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
}

- (void)doInitialSetup {
    
    
    
    
    
    NSButton *zoomButton = [self.view.window standardWindowButton:NSWindowZoomButton];
    NSButton *minButton = [self.view.window standardWindowButton:NSWindowMiniaturizeButton];
    
    [zoomButton setEnabled:NO];
    [minButton setEnabled:NO];
    
    [self.view.window makeKeyAndOrderFront:nil];
    [self.view.window center];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onDoubleClick:);
    self.tableView.rightClickSelectsItem = YES;
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kDatabaseCellView bundle:nil]
                  forIdentifier:kDatabaseCellView];
    
    [self.tableView registerForDraggedTypes:@[kDragAndDropId]];
    self.tableView.emptyString = NSLocalizedString(@"mac_no_databases_initial_message", @"No Databases Here Yet.\n\nClick 'Add Database...' below to get started...");
    
    self.tableView.headerView = nil;
    [self.tableView sizeLastColumnToFit];
    
    [self loadDatabases];
    [self.tableView reloadData];
    
    
    
    if(self.databaseIds.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    [self customizeAddDatabaseSubMenu];
    
    [self listenToEvents];
    
    [self bindVersionSubtitle];
    
    [self startRefreshTimer];
}

- (void)listenToEvents {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListViewForceRefreshNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kSyncManagerDatabaseSyncStatusChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kModelUpdateNotificationDatabaseUpdateStatusChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onProStatusChanged:) name:kProStatusChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesCollectionLockStateChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kWifiBrowserResultsUpdatedNotification object:nil];
}

- (void)bindVersionSubtitle {
    NSString* fmt = Settings.sharedInstance.isPro ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;
    self.textFieldVersion.onClick = ^{
        [AboutViewController show];
    };
}

- (void)onProStatusChanged:(id)param {
    NSLog(@"✅ DatabasesManagerVC: Pro Status Changed!");
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindVersionSubtitle];
    });
}

- (void)loadDatabases {
    self.databaseIds = [MacDatabasePreferences.allDatabases map:^id _Nonnull(MacDatabasePreferences * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }];
}

- (void)bindUi {
    self.buttonProperties.enabled = self.tableView.selectedRowIndexes.count == 1;
}

- (IBAction)onRemove:(id)sender {
    if (self.tableView.selectedRowIndexes.count == 0) {
        return;
    }
    
    NSMutableSet<MacDatabasePreferences*>* selected = NSMutableSet.set;
    
    [self performActionOnSelected:^(MacDatabasePreferences *database) {
        [selected addObject:database];
    }];
    
    
    
    BOOL atLeastOneUnlocked = [selected.allObjects anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return [DatabasesCollection.shared isUnlockedWithUuid:obj.uuid];
    }];
    
    if ( atLeastOneUnlocked ) {
        [MacAlerts info:NSLocalizedString(@"mac_at_least_one_db_unlocked_cannot_remove", @"At least one of these databases is unlocked. You must lock this database before you can remove it.")
                 window:self.view.window];
        return;
    }
    
    
    
    NSString* single = NSLocalizedString(@"are_you_sure_delete_database_single", @"Are you sure you want to remove this database from Strongbox?\n\nNB: The underlying database file will not be deleted. Just Strongbox's settings for this database.");
    
    NSString* multiple = NSLocalizedString(@"are_you_sure_delete_database_multiple", @"Are you sure you want to remove these databases from Strongbox?\n\nNB: The underlying database files will not be deleted. Just Strongbox's settings for these databases.");
    
    NSString *message = selected.count > 1 ? multiple : single;
    
    [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
     informativeText:message
              window:self.view.window
          completion:^(BOOL yesNo) {
        if (yesNo) {
            for (MacDatabasePreferences* database in selected) {
                if ( [DatabasesCollection.shared isUnlockedWithUuid:database.uuid] ) {
                    continue;
                }
                
                [DatabasesCollection.shared closeAnyDocumentWindowsWithUuid:database.uuid];
                
                [self removeDatabase:database];
            }            
        }
    }];
}

- (void)removeDatabase:(MacDatabasePreferences*)safe {
    [DatabaseNuker nuke:safe];
}

- (void)refreshVisibleRows {
    
    
    NSIndexSet* set = self.tableView.selectedRowIndexes;
    
    NSMutableSet<NSString*>* selected = NSMutableSet.set;
    [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [selected addObject:self.databaseIds[idx]];
    }];
    
    [self loadDatabases];
    
    NSScrollView* scrollView = [self.tableView enclosingScrollView];
    CGPoint originalScrollPos = scrollView.documentVisibleRect.origin;
    
    
    
    
    
    
    
    [self.tableView reloadData];
    
    NSMutableIndexSet* selectedSet = NSMutableIndexSet.indexSet;
    [self.databaseIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([selected containsObject:obj]) {
            [selectedSet addIndex:idx];
        }
    }];
    
    [self.tableView selectRowIndexes:selectedSet byExtendingSelection:NO];
    
    [scrollView.documentView scrollPoint:originalScrollPos];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databaseIds.count;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    NSString* databaseId = [self.databaseIds objectAtIndex:row];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    BOOL filesOnly = !StrongboxProductBundle.supports3rdPartyStorageProviders && !StrongboxProductBundle.supportsSftpWebDAV && !StrongboxProductBundle.supportsWiFiSync;
    BOOL disabled = database.storageProvider != kLocalDevice && filesOnly;
    
    return !disabled;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];
    
    
    
    NSString* databaseId = [self.databaseIds objectAtIndex:row];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    BOOL filesOnly = !StrongboxProductBundle.supports3rdPartyStorageProviders && !StrongboxProductBundle.supportsSftpWebDAV && !StrongboxProductBundle.supportsWiFiSync;
    BOOL disabled = database.storageProvider != kLocalDevice && filesOnly;
    
    [result setWithDatabase:database disabled:disabled];
    
    __weak DatabasesManagerVC* weakSelf = self;
    
    result.onBeginEditingNickname = ^(DatabaseCellView * _Nonnull cell) {
        NSInteger row = [weakSelf.tableView rowForView:cell];
        if ( row != -1 && weakSelf.tableView.selectedRow != row ) {
            NSLog(@"Extending Selection after nickname click");
            [weakSelf.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
        
        [weakSelf killRefreshTimer];
    };
    
    result.onEndEditingNickname = ^(DatabaseCellView * _Nonnull cell) {
        [weakSelf refreshVisibleRows];
        [weakSelf startRefreshTimer];
    };
    
    return result;
}

- (void)showHideColumn:(NSString*)identifier show:(BOOL)show {
    NSInteger colIdx = [self.tableView columnWithIdentifier:identifier];
    if(colIdx == -1) {
        NSLog(@"WARN WARN WARN: Could not find column: %@", identifier);
        return;
    }
    
    NSTableColumn *col = [self.tableView.tableColumns objectAtIndex:colIdx];
    
    if(col.hidden != !show) {
        col.hidden = !show;
    }
}

- (void)onDoubleClick:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if(row == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[row];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    [self openDatabase:database];
}

- (void)openDatabase:(MacDatabasePreferences*)database {
    [self openDatabase:database offline:database.alwaysOpenOffline];
}

- (void)openDatabase:(MacDatabasePreferences*)database offline:(BOOL)offline {
    DocumentController* dc = DocumentController.sharedDocumentController;
    
    BOOL filesOnly = !StrongboxProductBundle.supports3rdPartyStorageProviders && !StrongboxProductBundle.supportsSftpWebDAV && !StrongboxProductBundle.supportsWiFiSync;
    BOOL disabled = database.storageProvider != kLocalDevice && filesOnly;
    
    if ( disabled ) {
        NSLog(@"🔴 Attempt to unlock unsupported Database Storage Provider");
        return;
    }
    
    
    Model* existing = [DatabasesCollection.shared getUnlockedWithUuid:database.uuid];
    if ( !existing ) {
        database.userRequestOfflineOpenEphemeralFlagForDocument = offline;
    }
    else if ( existing.isInOfflineMode != offline ) {
        NSLog(@"⚠️ Ignoring request to open in different Offline Mode as database is already unlocked...");
    }
    
    [self showProgressModal:NSLocalizedString(@"generic_loading", "Loading...")];
    
    [dc openDatabase:database completion:^(NSError *error) {
        [self hideProgressModal];
        
        if(error) {
            NSString* loc = NSLocalizedString(@"mac_problem_opening_db",
                                              @"There was a problem opening this file.");
            
            [MacAlerts error:loc
                       error:error
                      window:self.view.window
                  completion:nil];
        }
        else {
            if ( Settings.sharedInstance.closeManagerOnLaunch ) {
                [self close];
            }
        }
    }];
}

- (void)showProgressModal:(NSString*)operationDescription {
    [macOSSpinnerUI.sharedInstance show:operationDescription viewController:self];
}

- (void)hideProgressModal {
    [macOSSpinnerUI.sharedInstance dismiss];
}

- (void)onOpenFromFiles:(id)sender {
    DocumentController* dc = (DocumentController*)NSDocumentController.sharedDocumentController;
    [dc originalOpenDocument:nil];
}

- (void)onNewDatabase:(id)sender {
    [NSDocumentController.sharedDocumentController newDocument:nil];
}

- (IBAction)onAddGoogleDriveDatabase:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    GoogleDriveStorageProvider* storageProvider = GoogleDriveStorageProvider.sharedInstance;
    [self showStorageBrowserForProvider:storageProvider];
#endif
}

- (IBAction)onAddDropboxDatabase:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    DropboxV2StorageProvider* storageProvider = DropboxV2StorageProvider.sharedInstance;
    
    [self showStorageBrowserForProvider:storageProvider];
#endif
}

- (IBAction)onAddOneDriveDatabase:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    TwoDriveStorageProvider* storageProvider = TwoDriveStorageProvider.sharedInstance;
    [self showStorageBrowserForProvider:storageProvider];
#endif
}

- (void)onAddSFTPDatabase:(id)sender {
#ifndef NO_NETWORKING
    SFTPConnectionsManager* vc = [SFTPConnectionsManager instantiateFromStoryboard];
    
    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(SFTPSessionConfiguration * _Nonnull connection) {
        SFTPStorageProvider* provider = [[SFTPStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
        
        [weakSelf showStorageBrowserForProvider:provider];
    };
    
    [self presentViewControllerAsSheet:vc];
#endif
}

- (IBAction)onAddWebDav:(id)sender {
#ifndef NO_NETWORKING
    WebDAVConnectionsManager* vc = [WebDAVConnectionsManager instantiateFromStoryboard];
    
    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(WebDAVSessionConfiguration * _Nonnull connection) {
        WebDAVStorageProvider* provider = [[WebDAVStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
        
        [weakSelf showStorageBrowserForProvider:provider];
    };
    
    [self presentViewControllerAsSheet:vc];
#endif
}

- (void)onAddWifiSyncDatabase:(WiFiSyncServerConfig*)server
                     passcode:(NSString*)passcode {
    WiFiSyncStorageProvider *sp = [[WiFiSyncStorageProvider alloc] init];
    
    server.passcode = passcode;
    sp.explicitConnectionConfig = server;
    
    [self showStorageBrowserForProvider:sp];
}



- (void)showStorageBrowserForProvider:(id<SafeStorageProvider>)provider {
    AddDatabaseSelectStorageVC* vc = [AddDatabaseSelectStorageVC newViewController];
    vc.provider = provider;
    
    vc.onDone = ^(BOOL success, StorageBrowserItem * _Nonnull selectedItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                
                
                NSString* suggestedName = [selectedItem.name stringByDeletingPathExtension];
                
                suggestedName = [DatabasesManager.sharedInstance getUniqueNameFromSuggestedName:suggestedName];
                
                MacDatabasePreferences *newDatabase = [provider getDatabasePreferences:suggestedName providerData:selectedItem.providerData];
                
                if (!newDatabase) {
                    [MacAlerts error:nil window:self.view.window];
                }
                else {
                    
                    
                    [newDatabase add];
                    [self openDatabase:newDatabase];
                }
            }
        });
    };
    
    [self presentViewControllerAsSheet:vc];
}

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
#endif

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = theEvent.charactersIgnoringModifiers;
    unichar aChar = [chars characterAtIndex:0];
    
    if( aChar == NSDeleteCharacter || aChar == NSBackspaceCharacter || aChar == 63272 ) {
        [self onRemove:nil];
    }
    else if ( (aChar == NSEnterCharacter) || (aChar == NSCarriageReturnCharacter) ) {
        NSLog(@"DatabasesManagerVC::keyDown - OPEN");
        [self performActionOnSelected:^(MacDatabasePreferences* database) {
            [self openDatabase:database];
        }];
    }
    else {
        
        [super keyDown:theEvent];
    }
}

- (void)performActionOnSelected:(void(^)(MacDatabasePreferences* database))action {
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* databaseId = self.databaseIds[idx];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        if (action) {
            action(database);
        }
    }];
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    NSPasteboardItem* item = [[NSPasteboardItem alloc] init];
    
    [item setString:@(row).stringValue forType:kDragAndDropId];
    
    return item;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
    NSMutableArray<NSNumber*>* oldIndices = NSMutableArray.array;
    
    [info enumerateDraggingItemsWithOptions:kNilOptions forView:self.tableView classes:@[NSPasteboardItem.class] searchOptions:@{  } usingBlock:^(NSDraggingItem * _Nonnull draggingItem, NSInteger idx, BOOL * _Nonnull stop) {
        NSPasteboardItem* rowItem = draggingItem.item;
        NSString* strRow = [rowItem stringForType:kDragAndDropId];
        [oldIndices addObject:@(strRow.integerValue)];
    }];
    
    NSInteger oldIndexOffset = 0;
    NSInteger newIndexOffset = 0;
    
    for (NSNumber* num in oldIndices) {
        NSInteger oldIndex = num.integerValue;
        
        if (oldIndex < row) {
            [MacDatabasePreferences move:oldIndex + oldIndexOffset to:row-1];
            oldIndexOffset -= 1;
        }
        else {
            [MacDatabasePreferences move:oldIndex to:row + newIndexOffset];
            newIndexOffset += 1;
        }
    }
    
    return YES;
}

- (NSMenuItem*)createHeaderMenuItem:(NSString*)title {
    NSMenuItem* item = [[NSMenuItem alloc] init];
    
    item.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                           attributes:@{
        NSFontAttributeName : FontManager.shared.boldCaption1Font,
        NSForegroundColorAttributeName : NSColor.secondaryLabelColor
    }];
    item.enabled = NO;
    return item;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {

    
    [self populateWifiSyncMenu];
}

- (void)customizeAddDatabaseSubMenu {
    NSMenu* menu = self.buttonAdd.menu;
    
    
    
    NSMenuItem* itemFilesHeader = [self createHeaderMenuItem:NSLocalizedString(@"add_database_on_my_mac", @"On My Mac")];
    [menu insertItem:itemFilesHeader atIndex:1];
    
    
    
    NSUInteger currentIdxForSection = 4;
    
    if ( StrongboxProductBundle.supportsWiFiSync && !Settings.sharedInstance.disableWiFiSyncClientMode ) {
        NSMenuItem* itemWiFiSyncHeader = [self createHeaderMenuItem:NSLocalizedString(@"storage_provider_name_wifi_sync", @"Wi-Fi Sync")];
        itemWiFiSyncHeader.action = @selector(onDummyWiFiSyncParentMenuAction:);
    
        [menu insertItem:NSMenuItem.separatorItem atIndex:currentIdxForSection++];
        [menu insertItem:itemWiFiSyncHeader atIndex:currentIdxForSection++];

        currentIdxForSection += 2; 
    }
    else {
        [menu removeItemAtIndex:currentIdxForSection];
    }
    
    
    
    if ( !StrongboxProductBundle.supports3rdPartyStorageProviders ) {
        [self removeMenuItemFromAddButtonMenu:@selector(onAddGoogleDriveDatabase:)];
        [self removeMenuItemFromAddButtonMenu:@selector(onAddDropboxDatabase:)];
        [self removeMenuItemFromAddButtonMenu:@selector(onAddOneDriveDatabase:)];
    }
    else {
        NSMenuItem* itemThirdPartyHeader = [self createHeaderMenuItem:NSLocalizedString(@"select_storage_header_third_party", @"Third Party Integrations")];
        [menu insertItem:itemThirdPartyHeader atIndex:currentIdxForSection];
        
        currentIdxForSection += 5;
    }
    
    
    
    if ( !StrongboxProductBundle.supports3rdPartyStorageProviders ) {
        [self removeMenuItemFromAddButtonMenu:@selector(onAddSFTPDatabase:)];
        [self removeMenuItemFromAddButtonMenu:@selector(onAddWebDav:)];
    }
    else {
        NSMenuItem* itemServersHeader = [self createHeaderMenuItem:NSLocalizedString(@"select_storage_header_servers", @"Servers")];
        [menu insertItem:itemServersHeader atIndex:currentIdxForSection];
        
        currentIdxForSection++;
        
        if ( !Settings.sharedInstance.isPro ) {
            NSMenuItem* menuItem = [menu itemAtIndex:currentIdxForSection];
            
            menuItem.enabled = NO;
            if (@available(macOS 14.0, *)) {
                menuItem.badge = [[NSMenuItemBadge alloc] initWithString:NSLocalizedString(@"pro_badge_text_all_caps", @"PRO")];
            }
            else {
                menuItem.title = NSLocalizedString(@"mac_add_sftp_pro_only", @"Add SFTP Database... (Pro)");
            }
            currentIdxForSection++;
            
            menuItem = [menu itemAtIndex:currentIdxForSection];
            
            if (@available(macOS 14.0, *)) {
                menuItem.badge = [[NSMenuItemBadge alloc] initWithString:NSLocalizedString(@"pro_badge_text_all_caps", @"PRO")];
            }
            else {
                menuItem.title = NSLocalizedString(@"mac_add_webdav_pro_only",  @"Add WebDAV Database... (Pro)");
            }
            
            menuItem.enabled = NO;
        }
    }
}

- (void)populateWifiSyncMenu {
    NSMenu* menu = self.buttonAdd.menu;
    
    if ( !StrongboxProductBundle.supportsWiFiSync || Settings.sharedInstance.disableWiFiSyncClientMode ) {
        return;
    }
    
    
    
    [self removeAllMenuItemFromAddButtonMenu:@selector(onSelectWiFiSyncDatabase:)];
    
    
    
    NSArray<NSMenuItem*>* subItems;
    NSArray<WiFiSyncServerConfig*>* wiFiSyncDevices = [self getWiFiSyncDevices];
    if ( wiFiSyncDevices.count > 0 ) {
        subItems = [wiFiSyncDevices map:^id _Nonnull(WiFiSyncServerConfig * _Nonnull obj, NSUInteger idx) {
            NSMenuItem* server = [[NSMenuItem alloc] initWithTitle:obj.name action:@selector(onSelectWiFiSyncDatabase:) keyEquivalent:@""];
            server.image = [self getWiFiSyncMenuItemImage:Settings.sharedInstance.isPro];
            return server;
        }];
    }
    else {
        NSMenuItem* server = [[NSMenuItem alloc] initWithTitle:@"No Devices Found" action:@selector(onSelectWiFiSyncDatabase:)  keyEquivalent:@""]; 
        server.enabled = NO;
        server.image = [self getWiFiSyncMenuItemImage:NO];
        subItems = @[server];
    }
    
    NSUInteger idx = [self getAddButtonItemIndex:@selector(onDummyWiFiSyncParentMenuAction:)] + 1;
    
    for ( NSMenuItem* item in subItems ) {
        if ( !Settings.sharedInstance.isPro ) {
            item.enabled = NO;
            if (@available(macOS 14.0, *)) {
                item.badge = [[NSMenuItemBadge alloc] initWithString:NSLocalizedString(@"pro_badge_text_all_caps", @"PRO")];
            }
            else {
                item.title = [NSString stringWithFormat:@"%@ (%@)", item.title, NSLocalizedString(@"pro_badge_text", @"Pro")];
            }
        }
        
        [menu insertItem:item atIndex:idx++];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    NSLog(@"🚀 validateUserInterfaceItem: [%@]", anItem);
    
    SEL theAction = [anItem action];
    
    
    MacDatabasePreferences* database = nil;
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        database = [MacDatabasePreferences fromUuid:databaseId];
    }
    
    if (theAction == @selector(onViewSyncLog:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onViewBackups:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onChangeNickname:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onExportDatabase:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onOpenInOfflineMode:)) {
        if( database != nil ) {
            BOOL isOpen = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid];
            return !isOpen;
        }
    }
    else if (theAction == @selector(onToggleAlwaysOpenOffline:)) {
        if(self.tableView.selectedRow != -1) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:database.alwaysOpenOffline ? NSControlStateValueOn : NSControlStateValueOff];
            return YES;
        }
    }
    else if (theAction == @selector(onToggleReadOnly:)) {
        if( database != nil ) {
            Model* model = [DatabasesCollection.shared getUnlockedWithUuid:database.uuid];
            BOOL isReadOnly = model ? model.isReadOnly : database.readOnly;
            
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:isReadOnly ? NSControlStateValueOn : NSControlStateValueOff];
            return YES;
        }
    }
    else if (theAction == @selector(onSync:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onRemove:)) {
        return self.tableView.selectedRowIndexes.count;
    }
    else if ( theAction == @selector(onLock:)) {
        BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid];
        
        return self.tableView.selectedRowIndexes.count == 1 && database && isUnlocked;
    }
    else if ( theAction == @selector(onLockOrUnlock:)) {
        BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid];
        
        NSMenuItem* item = (NSMenuItem*)anItem;
        
        [item setTitle:isUnlocked ? NSLocalizedString(@"generic_verb_lock_action", @"Lock") : NSLocalizedString(@"casg_unlock_action", @"unlock")];
        
        return self.tableView.selectedRowIndexes.count == 1 && database;
    }
    else if (theAction == @selector(onToggleLaunchAtStartup:)) {
        if(self.tableView.selectedRow != -1) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:database.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff];
        }
        
        return self.tableView.selectedRow != -1;
    }
    
    return NO;
}

- (NSArray<WiFiSyncServerConfig*>*)getWiFiSyncDevices {
    NSMutableArray<WiFiSyncServerConfig*>* allWiFiSyncDevices = [WiFiSyncBrowser.shared.availableServers mutableCopy];
    NSArray<WiFiSyncServerConfig*>* wiFiSyncDevices = allWiFiSyncDevices;
    
    if ( WiFiSyncServer.shared.isRunning ) { 
        NSString* myName = WiFiSyncServer.shared.lastRegisteredServiceName;

        if ( myName.length ) {
            wiFiSyncDevices = [allWiFiSyncDevices filter:^BOOL(WiFiSyncServerConfig * _Nonnull obj) {
                return ![obj.name isEqualToString:myName];
            }];
        }
    }
    
    return wiFiSyncDevices;
}

- (NSImage*)getWiFiSyncMenuItemImage:(BOOL)live {
    NSImage* image = [NSImage imageWithSystemSymbolName:@"externaldrive.fill.badge.wifi" accessibilityDescription:nil];
    
    if (@available(macOS 12.0, *)) {
        NSImageSymbolConfiguration* config = [NSImageSymbolConfiguration configurationWithPaletteColors:live ? @[NSColor.systemGreenColor, NSColor.systemBlueColor] : @[NSColor.systemGrayColor]];
        
        image = [image imageWithSymbolConfiguration:config];
    }
    
    return image;
}

- (IBAction)onDummyWiFiSyncParentMenuAction:(id)sender {
    
}

- (IBAction)onSelectWiFiSyncDatabase:(id)sender {
    NSMenuItem* item = sender;
        
    WiFiSyncServerConfig* server = [WiFiSyncBrowser.shared getServerConfig:item.title];
    
    if ( server ) {
        NSViewController* vc = [SwiftUIViewFactory makeWiFiSyncPassCodeEntryViewControllerWithServer:server
                                                                                              onDone:^(WiFiSyncServerConfig * server, NSString *passcode) {
            NSViewController* sheet = self.presentedViewControllers.firstObject;
            [Utils dismissViewControllerCorrectly:sheet];
            
            if ( server && passcode && passcode.length ) {
                [self onAddWifiSyncDatabase:server passcode:passcode];
            }
        }];
        
        [self presentViewControllerAsSheet:vc];
    }
    else {
        [MacAlerts error:nil window:self.view.window];
    }
}

- (IBAction)onViewSyncLog:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        SyncLogViewController* vc = [SyncLogViewController showForDatabase:database];
        [self presentViewControllerAsSheet:vc];
    }
}

- (IBAction)onSync:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        Model* unlocked = [DatabasesCollection.shared getUnlockedWithUuid:databaseId];
        BOOL isInOfflineMode = unlocked ? unlocked.isInOfflineMode : (database.alwaysOpenOffline || database.userRequestOfflineOpenEphemeralFlagForDocument);
        
        if ( isInOfflineMode ) {
            [MacAlerts info:NSLocalizedString(@"browse_vc_pulldown_refresh_offline_title", @"Offline Mode")
            informativeText:NSLocalizedString(@"database_is_in_offline_mode_cannot_be_synced", @"This database is in Offline Mode and cannot be synced.")
                     window:self.view.window
                 completion:nil];
        }
        else {
            
            
            [DatabasesCollection.shared syncWithUuid:databaseId allowInteractive:YES suppressErrorAlerts:NO ckfsForConflict:nil completion:nil];
        }
    }
}

- (IBAction)onViewBackups:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        [self performSegueWithIdentifier:@"segueToBackups" sender:database.uuid];
    }
}

- (IBAction)onLock:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid];
        if ( isUnlocked ) {
            [DatabasesCollection.shared initiateLockRequestWithUuid:database.uuid];
        }
    }
}

- (IBAction)onLockOrUnlock:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid];
        if ( isUnlocked ) {
            [DatabasesCollection.shared initiateLockRequestWithUuid:database.uuid];
        }
        else {
            [self openDatabase:database];
        }
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"segueToBackups"] ) {
        BackupsViewController* vc = segue.destinationController;
        vc.databaseUuid = sender;
    }
}

- (IBAction)onProperties:(id)sender {
    [NSMenu popUpContextMenu:self.tableView.menu withEvent:NSApp.currentEvent forView:self.tableView];
}

- (IBAction)onExportDatabase:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    NSSavePanel* panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = database.exportFileName;
    
    if ( [panel runModal] != NSModalResponseOK ) {
        return;
    }
    
    NSURL* dest = panel.URL;
    
    if ( !database.isLocalDeviceDatabase ) {
        [MacAlerts yesNo:NSLocalizedString(@"sync_before_export_question_yes_no", @"Would you like to sync before exporting to ensure you have the latest version of your database?")
                  window:self.view.window
              completion:^(BOOL yesNo) {
            if ( yesNo ) {
                [self syncBeforeExport:database dest:dest showSpinner:YES];
            }
            else {
                [self export:database dest:dest];
            }
        }];
    }
    else {
        [self syncBeforeExport:database dest:dest showSpinner:NO];
    }
}

- (void)syncBeforeExport:(MacDatabasePreferences *)database dest:(NSURL*)dest showSpinner:(BOOL)showSpinner {
    if ( showSpinner ) {
        [self showProgressModal:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
    }
    
    [MacSyncManager.sharedInstance backgroundSyncDatabase:database
                                                      key:nil
                                               completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( showSpinner ) {
            [self hideProgressModal];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( result != kSyncAndMergeSuccess ) {
                [MacAlerts error:error window:self.view.window];
            }
            else {
                [self export:database dest:dest];
            }
        });
    }];
}

- (void)export:(MacDatabasePreferences *)database
          dest:(NSURL*)dest {
    NSURL* src = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    NSLog(@"Export [%@] => [%@]", src, dest);
    
    if ( !src ) {
        [MacAlerts info:NSLocalizedString(@"open_sequence_couldnt_open_local_message", "Could not open Strongbox's local copy of this database. A online sync is required.")
                 window:self.view.window];
    }
    else {
        NSError* errr;
        BOOL copy;
        
        if ( [NSFileManager.defaultManager fileExistsAtPath:dest.path] ) {
            NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:src.path error:nil];
            NSData* data = [NSData dataWithContentsOfFile:src.path];
            copy = [NSFileManager.defaultManager createFileAtPath:dest.path contents:data attributes:attr];
        }
        else {
            copy = [NSFileManager.defaultManager copyItemAtURL:src toURL:dest error:&errr];
        }
        
        if ( !copy ) {
            [MacAlerts error:errr window:self.view.window];
        }
        else {
            [MacAlerts info:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
                     window:self.view.window];
        }
    }
}

- (IBAction)onOpenInOfflineMode:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    [self openDatabase:database offline:YES];
}

- (IBAction)onToggleLaunchAtStartup:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        database.launchAtStartup = !database.launchAtStartup;
    }
}

- (IBAction)onToggleAlwaysOpenOffline:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        database.alwaysOpenOffline = !database.alwaysOpenOffline;
        
        [self publishDatabasePreferencesChangedNotification:databaseId];
    }
}

- (IBAction)onToggleReadOnly:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        Model* model = [DatabasesCollection.shared getUnlockedWithUuid:database.uuid];
        BOOL isReadOnly = model ? model.isReadOnly : database.readOnly;
        
        if ( !isReadOnly ) {
            if ( [DatabasesCollection.shared databaseHasEditsOrIsBeingEditedWithUuid:databaseId] ) {
                [MacAlerts info:NSLocalizedString(@"read_only_unavailable_title", @"Read Only Unavailable")
                informativeText:NSLocalizedString(@"read_only_unavailable_pending_changes_message", @"You currently have changes pending and so you cannot switch to Read Only mode. You must save or discard your current changes first.")
                         window:self.view.window
                     completion:nil];
                return;
            }
        }
        
        database.readOnly = !database.readOnly;
        
        [self publishDatabasePreferencesChangedNotification:databaseId];
    }
}

- (IBAction)onChangeNickname:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseCellView *view = [self.tableView viewAtColumn:0 row:self.tableView.selectedRow makeIfNecessary:NO];
        
        [view onChangeNickname];
    }
}

- (void)publishDatabasePreferencesChangedNotification:(NSString*)databaseUuid {
    
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kUpdateNotificationDatabasePreferenceChanged object:databaseUuid userInfo:@{ }];
    });
}

- (NSUInteger)getAddButtonItemIndex:(SEL)action {
    NSMenu* topLevelMenuItem = self.buttonAdd.menu;
    
    NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.action == action;
    }];
    
    return index;
}

- (void)removeAllMenuItemFromAddButtonMenu:(SEL)action {
    while ( [self removeMenuItemFromAddButtonMenu:action] ) ;
}

- (BOOL)removeMenuItemFromAddButtonMenu:(SEL)action {
    NSMenu* topLevelMenuItem = self.buttonAdd.menu;
    
    NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.action == action;
    }];
    
    if( topLevelMenuItem &&  index != NSNotFound) {
        
        [topLevelMenuItem removeItemAtIndex:index];
        return YES;
    }
    else {
        return NO;
        
    }
}

@end
