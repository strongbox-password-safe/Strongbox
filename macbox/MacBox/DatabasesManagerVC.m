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
#import "SFTPStorageProvider.h"
#import "SyncLogViewController.h"
#import "MacSyncManager.h"
#import "Document.h"
#import "WebDAVStorageProvider.h"

#import "MacUrlSchemes.h"
#import "BackupsViewController.h"
#import "BackupsManager.h"
#import "Utils.h"
#import "WorkingCopyManager.h"
#import "SFTPConnectionsManager.h"
#import "WebDAVConnectionsManager.h"
#import "NSDate+Extensions.h"
#import "macOSSpinnerUI.h"
#import "DatabasesManager.h"



NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";
static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";
static NSString* const kDatabaseCellView = @"DatabaseCellView";
static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";
static const CGFloat kAutoRefreshTimeSeconds = 30.0f;



@interface DatabasesManagerVC () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSArray<NSString*>* databaseIds;
@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property NSTimer* timerRefresh;
@property BOOL hasLoaded;
@property (weak) IBOutlet NSTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonProperties;

@end

@implementation DatabasesManagerVC

- (void)close {
    [self.view.window cancelOperation:nil];
}

- (void)killRefreshTimer {
    NSLog(@"Kill Refresh Timer");

    if ( self.timerRefresh ) {
        [self.timerRefresh invalidate];
        self.timerRefresh = nil;
    }
}

- (void)startRefreshTimer {
    [self killRefreshTimer];
    
    NSLog(@"Start Refresh Timer");

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
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kModelUpdateNotificationDatabaseUpdateStatusChanged object:nil];

    NSString* fmt = Settings.sharedInstance.fullVersion ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;

    [self startRefreshTimer];
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
    
    

    DocumentController* dc = DocumentController.sharedDocumentController;

    BOOL atLeastOneUnlocked = [selected.allObjects anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
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
            for (MacDatabasePreferences* database in selected) {
                BOOL isOpen = [dc databaseIsDocumentWindow:database];
                if (isOpen) {
                    [dc closeDocumentWindowForDatabase:database];
                }
                [self removeDatabase:database];
            }
            
            BOOL quickTypeDb = [selected.allObjects anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
                return obj.autoFillEnabled && obj.quickTypeEnabled;
            }];
            
            if ( quickTypeDb ) {
                [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
            }
        }
    }];
}

- (void)removeDatabase:(MacDatabasePreferences*)safe {
    [safe remove];
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
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

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
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

    [self openDatabase:database];
}

- (void)openDatabase:(MacDatabasePreferences*)database {
    [self openDatabase:database offline:database.alwaysOpenOffline];
}

- (void)openDatabase:(MacDatabasePreferences*)database offline:(BOOL)offline {
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

- (void)onAddSFTPDatabase:(id)sender {
    SFTPConnectionsManager* vc = [SFTPConnectionsManager instantiateFromStoryboard];

    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(SFTPSessionConfiguration * _Nonnull connection) {
        SFTPStorageProvider* provider = [[SFTPStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
    
        [weakSelf showStorageBrowserForProvider:provider];
    };
        
    [self presentViewControllerAsSheet:vc];
}

- (IBAction)onAddWebDav:(id)sender {
    WebDAVConnectionsManager* vc = [WebDAVConnectionsManager instantiateFromStoryboard];
    
    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(WebDAVSessionConfiguration * _Nonnull connection) {
        WebDAVStorageProvider* provider = [[WebDAVStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
    
        [weakSelf showStorageBrowserForProvider:provider];
    };
        
    [self presentViewControllerAsSheet:vc];
}

- (void)showStorageBrowserForProvider:(id<SafeStorageProvider>)provider {
    AddDatabaseSelectStorageVC* vc = [AddDatabaseSelectStorageVC newViewController];
    vc.provider = provider;
    
    vc.onDone = ^(BOOL success, StorageBrowserItem * _Nonnull selectedItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"selected: [%@]", selectedItem);
                
                NSString* suggestedName = [selectedItem.name stringByDeletingPathExtension];
                
                MacDatabasePreferences *newDatabase = [provider getDatabasePreferences:suggestedName providerData:selectedItem.providerData];
                    
                if (!newDatabase) {
                    [MacAlerts error:nil window:self.view.window];
                }
                else {
                    NSLog(@"[%@]", newDatabase.fileUrl.absoluteString);
                    
                    [newDatabase add];
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

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];


    MacDatabasePreferences* database;
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
    else if (theAction == @selector(onExportDatabase:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onOpenInOfflineMode:)) {
        if( database != nil ) {
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
        if( database != nil ) {
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
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

        SyncLogViewController* vc = [SyncLogViewController showForDatabase:database];
        [self presentViewControllerAsSheet:vc];
    }
}

- (IBAction)onSync:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

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

- (IBAction)onViewBackups:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

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
    }
}

- (IBAction)onToggleReadOnly:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];

        database.readOnly = !database.readOnly;
    }
}

@end
