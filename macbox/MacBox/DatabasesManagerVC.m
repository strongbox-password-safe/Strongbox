//
//  DatabasesManagerVC.m
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabasesManagerVC.h"
#import "DatabasesManager.h"
#import "MacAlerts.h"
#import "DocumentController.h"
#import "Settings.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"
#import "CustomBackgroundTableView.h"
#import "AutoFillManager.h"
#import "SafeStorageProviderFactory.h"
#import "AddDatabaseSelectStorageVC.h"
#import "SFTPStorageProvider.h"
#import "SyncLogViewController.h"
#import "MacSyncManager.h"
#import "Document.h"
#import "WebDAVStorageProvider.h"
#import "ProgressWindow.h"
#import "MacUrlSchemes.h"
#import "BackupsViewController.h"
#import "BackupsManager.h"
#import "Utils.h"
#import "WorkingCopyManager.h"

NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";

static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";

static NSString* const kDatabaseCellView = @"DatabaseCellView";

static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";

static const CGFloat kAutoRefreshTimeSeconds = 30.0f;

@interface DatabasesManagerVC () <NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate>

@property (nonatomic, strong) NSArray<NSString*>* databaseIds;

@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property NSTimer* timerRefresh;
@property BOOL hasLoaded;
@property ProgressWindow* progressWindow;
@property (weak) IBOutlet NSTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonProperties;

@end

static DatabasesManagerVC* sharedInstance;

@implementation DatabasesManagerVC

+ (void)show {
    if ( sharedInstance == nil ) {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"DatabasesManager" bundle:nil];
        NSWindowController* wc = [storyboard instantiateInitialController];
        sharedInstance = (DatabasesManagerVC*)wc.contentViewController;
    }
 
    [sharedInstance.view.window.windowController showWindow:self];
    [sharedInstance.view.window makeKeyAndOrderFront:self];
    [sharedInstance.view.window center];
}

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
}

- (void)doInitialSetup {
    self.view.window.delegate = self;

    
    
    
    


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
    
    [self.tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    NSTableColumn *col = [self.tableView.tableColumns objectAtIndex:0];
    [col setResizingMask:NSTableColumnAutoresizingMask];
    self.tableView.headerView = nil;
    
    

    [self loadDatabases];
    [self.tableView reloadData];



    

    if(self.databaseIds.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListViewForceRefreshNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kSyncManagerDatabaseSyncStatusChanged object:nil];
    
    [self startRefreshTimer];
}

- (void)loadDatabases {
    self.databaseIds = [DatabasesManager.sharedInstance.snapshot map:^id _Nonnull(DatabaseMetadata * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }];
}

- (void)bindUi {
    self.buttonProperties.enabled = self.tableView.selectedRowIndexes.count == 1;
    
    NSString* fmt = Settings.sharedInstance.fullVersion ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;
}

- (void)killRefreshTimer {
    if(self.timerRefresh) {

        [self.timerRefresh invalidate];
        self.timerRefresh = nil;
    }
}

- (void)startRefreshTimer {

    self.timerRefresh = [NSTimer timerWithTimeInterval:kAutoRefreshTimeSeconds target:self selector:@selector(refreshVisibleRows) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefresh forMode:NSRunLoopCommonModes];
}

- (void)cancel:(id)sender { 
    [self.view.window orderBack:self];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ( notification.object == self.view.window && self == sharedInstance) {
        [self.view.window orderOut:self];
        [self killRefreshTimer];
        sharedInstance = nil;
    }
}

- (IBAction)onRemove:(id)sender {
    if (self.tableView.selectedRowIndexes.count == 0) {
        return;
    }
    
    NSMutableSet<DatabaseMetadata*>* selected = NSMutableSet.set;

    [self performActionOnSelected:^(DatabaseMetadata *database) {
        [selected addObject:database];
    }];
    
    

    DocumentController* dc = DocumentController.sharedDocumentController;

    BOOL atLeastOneUnlocked = [selected.allObjects anyMatch:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return [dc databaseIsUnlockedInDocumentWindow:obj];
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
            for (DatabaseMetadata* database in selected) {
                BOOL isOpen = [dc databaseIsDocumentWindow:database];
                if (isOpen) {
                    [dc closeDocumentWindowForDatabase:database];
                }
                [self removeDatabase:database];
            }
            
            BOOL quickTypeDb = [selected.allObjects anyMatch:^BOOL(DatabaseMetadata * _Nonnull obj) {
                return obj.autoFillEnabled && obj.quickTypeEnabled;
            }];
            
            if ( quickTypeDb ) {
                [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
            }
        }
    }];
}

- (void)removeDatabase:(DatabaseMetadata*)safe {
    [DatabasesManager.sharedInstance remove:safe.uuid];
    [safe clearSecureItems];
    [BackupsManager.sharedInstance deleteAllBackups:safe];
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

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];

    NSString* databaseId = [self.databaseIds objectAtIndex:row];
    DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

    [result setWithDatabase:database];

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
    DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

    [self openDatabase:database];
}

- (void)openDatabase:(DatabaseMetadata*)database {
    [self openDatabase:database offline:database.alwaysOpenOffline];
}

- (void)openDatabase:(DatabaseMetadata*)database offline:(BOOL)offline {
    DocumentController* dc = DocumentController.sharedDocumentController;

    

    NSLog(@"%hhd-%hhd", offline, database.offlineMode);
    if ( offline != database.offlineMode ) {
        if ( [dc databaseIsDocumentWindow:database] ) {
            [MacAlerts info:NSLocalizedString(@"database_already_open_please_close", @"This database is already open. Please close it first if you would like to open it in a different mode.")
                     window:self.view.window];
            return;
        }
        else {
            database.offlineMode = offline;
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                                    touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.offlineMode = offline;
            }];
        }
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
    }];
}

- (void)showProgressModal:(NSString*)operationDescription {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.progressWindow ) {
            [self.progressWindow hide];
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

- (void)onOpenFromFiles:(id)sender {
    DocumentController* dc = (DocumentController*)NSDocumentController.sharedDocumentController;
    [dc originalOpenDocument:nil];
}

- (void)onNewDatabase:(id)sender {
    [NSDocumentController.sharedDocumentController newDocument:nil];
}

- (void)onAddSFTPDatabase:(id)sender {
    SFTPStorageProvider* provider = [[SFTPStorageProvider alloc] init];
    provider.maintainSessionForListing = YES;
    
    [self showStorageBrowserForProvider:provider];
}

- (IBAction)onAddWebDav:(id)sender {
    WebDAVStorageProvider* provider = [[WebDAVStorageProvider alloc] init];
    provider.maintainSessionForListings = YES;
    
    [self showStorageBrowserForProvider:provider];
}

- (void)showStorageBrowserForProvider:(id<SafeStorageProvider>)provider {
    AddDatabaseSelectStorageVC* vc = [AddDatabaseSelectStorageVC newViewController];
    vc.provider = provider;
    
    vc.onDone = ^(BOOL success, StorageBrowserItem * _Nonnull selectedItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"selected: [%@]", selectedItem);
                
                NSString* suggestedName = [selectedItem.name stringByDeletingPathExtension];
                
                DatabaseMetadata *newDatabase = [provider getSafeMetaData:suggestedName
                                                             providerData:selectedItem.providerData];
                
                if (!newDatabase) {
                    [MacAlerts error:nil window:self.view.window];
                }
                else {
                    NSLog(@"[%@]", newDatabase.fileUrl.absoluteString);
                    
                    [DatabasesManager.sharedInstance add:newDatabase];
                    [self openDatabase:newDatabase];
                }
            }
        });
    };
    
    [self presentViewControllerAsSheet:vc];
}

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
        [self performActionOnSelected:^(DatabaseMetadata* database) {
            [self openDatabase:database];
        }];
    }
    else {

        [super keyDown:theEvent];
    }
}

- (void)performActionOnSelected:(void(^)(DatabaseMetadata* database))action {
    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* databaseId = self.databaseIds[idx];
        DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

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
            [DatabasesManager.sharedInstance move:oldIndex + oldIndexOffset to:row-1];
            oldIndexOffset -= 1;
        }
        else {
            [DatabasesManager.sharedInstance move:oldIndex to:row + newIndexOffset];
            newIndexOffset += 1;
        }
    }
    
    return YES;
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];


    DatabaseMetadata* database;
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];
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
    else if (theAction == @selector(onExport:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onOpenInOfflineMode:)) {
        if(self.tableView.selectedRow != -1) {
            DocumentController* dc = DocumentController.sharedDocumentController;
            BOOL isOpen = [dc databaseIsDocumentWindow:database];
            return !isOpen && !database.isLocalDeviceDatabase;
        }
    }
    else if (theAction == @selector(onToggleAlwaysOpenOffline:)) {
        if(self.tableView.selectedRow != -1) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:database.alwaysOpenOffline ? NSControlStateValueOn : NSControlStateValueOff];

            return !database.isLocalDeviceDatabase;
        }
    }
    else if (theAction == @selector(onToggleReadOnly:)) {
        if(self.tableView.selectedRow != -1) {
            DocumentController* dc = DocumentController.sharedDocumentController;
            BOOL isOpen = [dc databaseIsDocumentWindow:database];

            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:database.readOnly ? NSControlStateValueOn : NSControlStateValueOff];
            return !isOpen;
        }
    }
    else if (theAction == @selector(onSync:)) {
        if(self.tableView.selectedRow != -1) {
            return !database.isLocalDeviceDatabase;
        }
    }
    else if ( theAction == @selector(onAddSFTPDatabase:)) {
        if ( !Settings.sharedInstance.isPro ) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            item.title = NSLocalizedString(@"mac_add_sftp_pro_only", @"Add SFTP Database... (Pro)");
        }
        return Settings.sharedInstance.isProOrFreeTrial;
    }
    else if ( theAction == @selector(onAddWebDav:)) {
        if ( !Settings.sharedInstance.isPro ) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            item.title = NSLocalizedString(@"mac_add_webdav_pro_only",  @"Add WebDAV Database... (Pro)");
        }

        return Settings.sharedInstance.isProOrFreeTrial;
    }
    else if ( theAction == @selector(onOpenFromFiles:)) {
        return YES;
    }
    else if ( theAction == @selector(onNewDatabase:)) {
        return YES;
    }
    else if (theAction == @selector(onRemove:)) {
        return self.tableView.selectedRowIndexes.count;
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

- (IBAction)onViewSyncLog:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

        SyncLogViewController* vc = [SyncLogViewController showForDatabase:database];
        [self presentViewControllerAsSheet:vc];
    }
}

- (BOOL)isLegacyFileUrl:(NSURL*)url {
    return ( url && url.scheme.length && [url.scheme isEqualToString:kStrongboxFileUrlScheme] );
}

- (IBAction)onSync:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

        if ( ![self isLegacyFileUrl:database.fileUrl] ) {
            Document* doc = [DocumentController.sharedDocumentController documentForURL:database.fileUrl];
            if ( doc && !doc.isModelLocked ) {
                NSLog(@"Document is already open ");
                [doc checkForRemoteChanges];
            }
            else {
                
                [MacSyncManager.sharedInstance backgroundSyncDatabase:database
                                                           completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
                    if ( error ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [MacAlerts error:error window:self.view.window];
                        });
                    }
                    else if ( localWasChanged ) {
                        NSLog(@"ManagerVC - Background Sync - localWasChanged");
                    }
                }];
            }
        }
    }
}

- (IBAction)onViewBackups:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

        [self performSegueWithIdentifier:@"segueToBackups" sender:database.uuid];
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

- (IBAction)onExport:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }

    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

    NSSavePanel* panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = database.fileUrl.lastPathComponent;
    
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

- (void)syncBeforeExport:(DatabaseMetadata *)database dest:(NSURL*)dest showSpinner:(BOOL)showSpinner {
    if ( showSpinner ) {
        [self showProgressModal:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
    }
    [MacSyncManager.sharedInstance backgroundSyncDatabase:database
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

- (void)export:(DatabaseMetadata *)database
          dest:(NSURL*)dest {
    NSURL* src = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:database.uuid];
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
    DatabaseMetadata* database = [DatabasesManager.sharedInstance getDatabaseById:databaseId];

    [self openDatabase:database offline:YES];
}

- (IBAction)onToggleLaunchAtStartup:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];

        [DatabasesManager.sharedInstance atomicUpdate:databaseId touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.launchAtStartup = !metadata.launchAtStartup;
        }];
    }
}

- (IBAction)onToggleAlwaysOpenOffline:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];

        [DatabasesManager.sharedInstance atomicUpdate:databaseId touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.alwaysOpenOffline = !metadata.alwaysOpenOffline;
        }];
    }
}

- (IBAction)onToggleReadOnly:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];

        [DatabasesManager.sharedInstance atomicUpdate:databaseId touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.readOnly = !metadata.readOnly;
        }];
    }
}

@end
