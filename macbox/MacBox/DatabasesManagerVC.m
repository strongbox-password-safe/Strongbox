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
#import "SelectStorageLocationVC.h"
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
#import "SFTPConfigurationVC.h"
#import "SFTPConnections.h"
#import "WebDAVConnections.h"
#import "WebDAVConfigVC.h"

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
#import "MacFileBasedBookmarkStorageProvider.h"
#import "SBLog.h"



NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";
NSString* const kUpdateNotificationDatabasePreferenceChanged = @"UpdateNotificationDatabasePreferenceChanged";
NSString* const kWifiBrowserResultsUpdatedNotification = @"wifiBrowserResultsUpdated";

static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";

static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";
static const CGFloat kAutoRefreshTimeSeconds = 30.0f;



@interface DatabasesManagerVC () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet ClickableTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonProperties;
@property (weak) IBOutlet CustomBackgroundTableView *tableView;

@property NSArray<NSString*>* databaseIds;
@property NSTimer* timerRefresh;
@property BOOL hasLoaded;

#ifndef NO_NETWORKING
@property CocoaCloudKitSharingHelper* cloudKitSharingHelper;
#endif

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
    
    
    
    self.timerRefresh = [NSTimer timerWithTimeInterval:kAutoRefreshTimeSeconds target:self selector:@selector(refresh) userInfo:nil repeats:YES];
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
    
    [self refresh];
    
    
    
    if(self.databaseIds.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    
    
    [self listenToEvents];
    
    [self bindVersionSubtitle];
    
    [self startRefreshTimer];
}

- (void)listenToEvents {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kDatabasesListChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kDatabasesListViewForceRefreshNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kSyncManagerDatabaseSyncStatusChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kModelUpdateNotificationDatabaseUpdateStatusChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kProStatusChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kDatabasesCollectionLockStateChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:kWifiBrowserResultsUpdatedNotification object:nil];
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
    slog(@"✅ DatabasesManagerVC: Pro Status Changed!");
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindVersionSubtitle];
    });
}

- (void)bindUi {
    self.buttonProperties.enabled = self.tableView.selectedRowIndexes.count > 0;
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
    
    
    
    BOOL willDeleteFromCloudKit = [selected.allObjects anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return obj.storageProvider == kCloudKit && obj.isOwnedByMeCloudKit;
    }];
    
    BOOL deleteAttemptOnUnownedCloudKitDatabase = [selected.allObjects anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return obj.storageProvider == kCloudKit && !obj.isOwnedByMeCloudKit;
    }];
    
    NSString *message;
    
    if ( willDeleteFromCloudKit ) {
        message = NSLocalizedString(@"ays_remove_databases_strongbox_sync_delete", @"Are you sure you want to remove these database(s) from Strongbox?\n\nNB: Strongbox Sync databases will be permanently deleted across all devices.");
    }
    else if ( deleteAttemptOnUnownedCloudKitDatabase && selected.count == 1) {
#ifndef NO_NETWORKING
        [self promptUserToRemoveThemselvesFromCloudKitSharing:selected.anyObject];
#endif
        return;
    }
    else {
        NSString* single = NSLocalizedString(@"are_you_sure_delete_database_single", @"Are you sure you want to remove this database from Strongbox?\n\nNB: The underlying database file will not be deleted. Just Strongbox's settings for this database.");
        
        NSString* multiple = NSLocalizedString(@"are_you_sure_delete_database_multiple", @"Are you sure you want to remove these databases from Strongbox?\n\nNB: The underlying database files will not be deleted. Just Strongbox's settings for these databases.");
        
        message = selected.count > 1 ? multiple : single;
    }
    
    [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
     informativeText:message
              window:self.view.window
          completion:^(BOOL yesNo) {
        if (yesNo) {
            if ( willDeleteFromCloudKit ) {
                [self tripleCheckCloudKitDelete:selected];
            }
            else {
                [self removeDatabases:selected];
            }
        }
    }];
}

- (void)tripleCheckCloudKitDelete:(NSSet<MacDatabasePreferences*>*)selected {
    MacAlerts* ma = [[MacAlerts alloc] init];
    
    NSString* codeword = NSLocalizedString(@"delete_triple_confirm_code_word", @"delete");
    NSString* locFmt = [NSString stringWithFormat:NSLocalizedString(@"delete_triple_confirm_message_fmt", @"Please enter the word '%@' below to confirm."), codeword];
    
    NSString* confirm = [ma input:locFmt
                     defaultValue:@""
                       allowEmpty:NO
                           secure:NO];
    
    if ( confirm != nil && [confirm localizedCaseInsensitiveCompare:codeword] == NSOrderedSame ) {
        [self removeDatabases:selected];
    }
}

- (void)removeDatabases:(NSSet<MacDatabasePreferences*>*)selected {
    for (MacDatabasePreferences* database in selected) {
        if ( [DatabasesCollection.shared isUnlockedWithUuid:database.uuid] ) {
            continue;
        }
        
        [DatabasesCollection.shared closeAnyDocumentWindowsWithUuid:database.uuid];
        
        [self removeDatabase:database];
    }
}

#ifndef NO_NETWORKING
- (void)promptUserToRemoveThemselvesFromCloudKitSharing:(MacDatabasePreferences*)database {
    [MacAlerts yesNo:NSLocalizedString(@"strongbox_sync_shared_database_title", @"Shared Database")
     informativeText:NSLocalizedString(@"strongbox_sync_shared_database_msg", @"This database is shared with you by someone else who owns it. To remove this database from your list, tap OK to manage sharing and remove yourself.")
              window:self.view.window
          completion:^(BOOL yesNo) {
        if ( yesNo ) {
            [self onCreateOrManageCloudKitSharing:database];
        }
    }];
}
#endif

- (void)removeDatabase:(MacDatabasePreferences*)safe {
    
    
    [CrossPlatformDependencies.defaults.spinnerUi show:NSLocalizedString(@"generic_deleting_ellipsis", @"Deleting...")
                                        viewController:self];
    
    [DatabaseNuker nuke:safe deleteUnderlyingIfSupported:YES completion:^(NSError * _Nullable error) {
        [CrossPlatformDependencies.defaults.spinnerUi dismiss];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                slog(@"🔴 Error Nuking Database [%@]", error);
                [MacAlerts error:error window:self.view.window];
            }
        });
    }];
}

- (void)refresh {
    
    
    NSArray<NSString*> *allDatabaseIds = [MacDatabasePreferences.allDatabases map:^id _Nonnull(MacDatabasePreferences * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }];
    
    if ( [allDatabaseIds.set isEqualToSet:self.databaseIds.set] ) {
        self.databaseIds = allDatabaseIds;
        
        NSIndexSet* set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, allDatabaseIds.count)];
        
        [self.tableView reloadDataForRowIndexes:set columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
    else {
        
        
        NSIndexSet* set = self.tableView.selectedRowIndexes;
        NSMutableSet<NSString*>* selectedDatabaseUuids = NSMutableSet.set;
        [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            [selectedDatabaseUuids addObject:self.databaseIds[idx]];
        }];
        
        self.databaseIds = allDatabaseIds;
        
        [self.tableView reloadData];
        
        NSMutableIndexSet* selectedSet = NSMutableIndexSet.indexSet;
        [self.databaseIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([selectedDatabaseUuids containsObject:obj]) {
                [selectedSet addIndex:idx];
            }
        }];
        
        [self.tableView selectRowIndexes:selectedSet byExtendingSelection:NO];
    }
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
    DatabaseCellView *view = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];
    
    
    
    NSString* databaseId = [self.databaseIds objectAtIndex:row];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    BOOL filesOnly = !StrongboxProductBundle.supports3rdPartyStorageProviders && !StrongboxProductBundle.supportsSftpWebDAV && !StrongboxProductBundle.supportsWiFiSync;
    BOOL disabled = database.storageProvider != kLocalDevice && filesOnly;
    
    [view setWithDatabase:database disabled:disabled];
    
    __weak DatabasesManagerVC* weakSelf = self;
    
    view.onUserRenamedDatabase = ^(NSString * _Nonnull name) {
        [weakSelf onUserRenamedDatabase:database name:name];
    };
    
    view.onBeginEditingNickname = ^(DatabaseCellView * _Nonnull cell) {
        NSInteger row = [weakSelf.tableView rowForView:cell];
        if ( row != -1 && weakSelf.tableView.selectedRow != row ) {
            slog(@"Extending Selection after nickname click");
            [weakSelf.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
        
        [weakSelf killRefreshTimer];
    };
    
    view.onEndEditingNickname = ^(DatabaseCellView * _Nonnull cell) {
        [weakSelf refresh];
        [weakSelf startRefreshTimer];
    };
    
    return view;
}

- (IBAction)onRename:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseCellView *view = [self.tableView viewAtColumn:0 row:self.tableView.selectedRow makeIfNecessary:NO];
        
        [view onBeginRenameEdit];
    }
}

- (IBAction)onChangeFilename:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        if ( database.storageProvider == kCloudKit ) {
            MacAlerts* alert = [[MacAlerts alloc] init];
            
            NSString* newFilename = [alert input:NSLocalizedString(@"databases_manager_pls_enter_new_filename", @"Please enter a new filename for this database")
                                    defaultValue:database.fileUrl.lastPathComponent
                                      allowEmpty:NO];
            
            if ( newFilename ) {
                NSString* trimmed = [MacDatabasePreferences trimDatabaseNickName:newFilename];
                
                if ( trimmed.length ) {
                    [self renameCloudKitDatabase:database nick:database.nickName fileName:trimmed];
                }
            }
        }
    }
}

- (void)onUserRenamedDatabase:(MacDatabasePreferences*)database name:(NSString*)name {
    database.nickName = name;
    
    if ( database.storageProvider == kCloudKit ) {
        NSString* fileName = [name stringByAppendingPathExtension:database.fileUrl.pathExtension];
        
        [self renameCloudKitDatabase:database nick:name fileName:fileName];
    }
}

- (void)renameCloudKitDatabase:(MacDatabasePreferences*)database
                          nick:(NSString*)nick
                      fileName:(NSString*)fileName {
#ifndef NO_NETWORKING
    [CrossPlatformDependencies.defaults.spinnerUi show:NSLocalizedString(@"generic_renaming_ellipsis", @"Renaming...")
                                        viewController:self];
    
    [CloudKitDatabasesInteractor.shared renameWithDatabase:database
                                                  nickName:nick
                                                  fileName:fileName
                                         completionHandler:^(NSError * _Nullable error) {
        [CrossPlatformDependencies.defaults.spinnerUi dismiss];
    }];
#endif
}

- (void)showHideColumn:(NSString*)identifier show:(BOOL)show {
    NSInteger colIdx = [self.tableView columnWithIdentifier:identifier];
    if(colIdx == -1) {
        slog(@"WARN WARN WARN: Could not find column: %@", identifier);
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
        slog(@"🔴 Attempt to unlock unsupported Database Storage Provider");
        return;
    }
    
    
    Model* existing = [DatabasesCollection.shared getUnlockedWithUuid:database.uuid];
    if ( !existing ) {
        database.userRequestOfflineOpenEphemeralFlagForDocument = offline;
    }
    else if ( existing.isInOfflineMode != offline ) {
        slog(@"⚠️ Ignoring request to open in different Offline Mode as database is already unlocked...");
    }
    
    [self showProgressModal:NSLocalizedString(@"generic_loading", "Loading...")];
    
    [dc openDatabase:database completion:^(Document * _Nullable document, NSError * _Nullable error) {
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
        slog(@"DatabasesManagerVC::keyDown - OPEN");
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

- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    
    MacDatabasePreferences* singleSelectedDatabase = nil;
    if ( self.tableView.selectedRowIndexes.count == 1 ) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        singleSelectedDatabase = [MacDatabasePreferences fromUuid:databaseId];
    }
    
#ifndef NO_NETWORKING
    
    
    NSMenuItem* item = [menu.itemArray firstOrDefault:^BOOL(NSMenuItem * _Nonnull obj) {
        return obj.action == @selector(onShareCloudKit:);
    }];
    
    if ( item ) {
        [menu removeItem:item];
    }
    
    item = [menu.itemArray firstOrDefault:^BOOL(NSMenuItem * _Nonnull obj) {
        return obj.action == @selector(onChangeFilename:);
    }];
    
    if ( item ) {
        [menu removeItem:item];
    }
    
    item = [menu.itemArray firstOrDefault:^BOOL(NSMenuItem * _Nonnull obj) {
        return obj.action == @selector(onEditSFTPConnection:);
    }];
    
    if ( item ) {
        [menu removeItem:item];
    }
    
    item = [menu.itemArray firstOrDefault:^BOOL(NSMenuItem * _Nonnull obj) {
        return obj.action == @selector(onEditWebDAVConnection:);
    }];
    
    if ( item ) {
        [menu removeItem:item];
    }
    
    
    
    if ( singleSelectedDatabase ) {
        if( singleSelectedDatabase.storageProvider == kCloudKit ) {
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:singleSelectedDatabase.isSharedInCloudKit ?
                                NSLocalizedString(@"generic_manage_sharing_action_ellipsis", @"Manage Sharing...") :
                                NSLocalizedString(@"generic_share_action_ellipsis", @"Share...")
                                                          action:@selector(onShareCloudKit:)
                                                   keyEquivalent:@""];
            
            [menu insertItem:item atIndex:5];
            
            item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"generic_change_filename_ellipsis_action", @"Change Filename...")
                                              action:@selector(onChangeFilename:)
                                       keyEquivalent:@""];
            
            [menu insertItem:item atIndex:7];
        }
        else if( singleSelectedDatabase.storageProvider == kSFTP ) {
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"generic_action_edit_sftp_connection_ellipsis", @"SFTP Connection...")
                                                          action:@selector(onEditSFTPConnection:)
                                                   keyEquivalent:@""];
            
            [menu insertItem:item atIndex:5];
        }
        else if( singleSelectedDatabase.storageProvider == kWebDAV ) {
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"generic_action_edit_webdav_connection_ellipsis", @"WebDAV Connection...")
                                                          action:@selector(onEditWebDAVConnection:)
                                                   keyEquivalent:@""];
            
            [menu insertItem:item atIndex:5];
        }
    }
#endif
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    
    
    SEL theAction = [anItem action];
    
    
    MacDatabasePreferences* singleSelectedDatabase = nil;
    if ( self.tableView.selectedRowIndexes.count == 1 ) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        singleSelectedDatabase = [MacDatabasePreferences fromUuid:databaseId];
    }
    
    if ( singleSelectedDatabase ) {
        if (theAction == @selector(onViewSyncLog:) ||
            theAction == @selector(onViewBackups:) ||
            theAction == @selector(onSaveDatabaseAs:) ||
            theAction == @selector(onCopyTo:) ||
            theAction == @selector(onSync:) ||
            theAction == @selector(onRename:)) {
            return YES;
        }
        else if (theAction == @selector(onChangeFilename:)) {
            if( singleSelectedDatabase.storageProvider == kCloudKit ) {
                return YES;
            }
        }
#ifndef NO_NETWORKING
        else if (theAction == @selector(onEditWebDAVConnection:)) {
            if( singleSelectedDatabase.storageProvider == kWebDAV ) {
                return YES;
            }
        }
        else if (theAction == @selector(onEditSFTPConnection:)) {
            if( singleSelectedDatabase.storageProvider == kSFTP ) {
                return YES;
            }
        }
        else if (theAction == @selector(onShareCloudKit:)) {
            if( singleSelectedDatabase.storageProvider == kCloudKit ) {
                NSMenuItem* item = (NSMenuItem*)anItem;
                
                [item setTitle:singleSelectedDatabase.isSharedInCloudKit ?
                 NSLocalizedString(@"generic_manage_sharing_action_ellipsis", @"Manage Sharing...") :
                 NSLocalizedString(@"generic_share_action_ellipsis", @"Share...")];
                
                return YES;
            }
        }
#endif
        else if (theAction == @selector(onOpenInOfflineMode:)) {
            BOOL isOpen = [DatabasesCollection.shared isUnlockedWithUuid:singleSelectedDatabase.uuid];
            
            return !isOpen;
        }
        else if (theAction == @selector(onToggleAlwaysOpenOffline:)) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:singleSelectedDatabase.alwaysOpenOffline ? NSControlStateValueOn : NSControlStateValueOff];
            return YES;
        }
        else if (theAction == @selector(onToggleReadOnly:)) {
            Model* model = [DatabasesCollection.shared getUnlockedWithUuid:singleSelectedDatabase.uuid];
            BOOL isReadOnly = model ? model.isReadOnly : singleSelectedDatabase.readOnly;
            
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:isReadOnly ? NSControlStateValueOn : NSControlStateValueOff];
            return YES;
        }
        else if ( theAction == @selector(onLock:)) {
            BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:singleSelectedDatabase.uuid];
            
            return isUnlocked;
        }
        else if ( theAction == @selector(onLockOrUnlock:)) {
            BOOL isUnlocked = [DatabasesCollection.shared isUnlockedWithUuid:singleSelectedDatabase.uuid];
            
            NSMenuItem* item = (NSMenuItem*)anItem;
            
            [item setTitle:isUnlocked ? NSLocalizedString(@"generic_verb_lock_action", @"Lock") : NSLocalizedString(@"casg_unlock_action", @"unlock")];
            
            return YES;
        }
        else if (theAction == @selector(onToggleLaunchAtStartup:)) {
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:singleSelectedDatabase.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff];
            
            return YES;
        }
    }
    
    if (theAction == @selector(onRemove:)) { 
        return self.tableView.selectedRowIndexes.count > 0;
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

- (IBAction)onSaveDatabaseAs:(id)sender {
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
                [self saveDatabaseAs:database dest:dest];
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
                [self saveDatabaseAs:database dest:dest];
            }
        });
    }];
}

- (void)saveDatabaseAs:(MacDatabasePreferences *)database
                  dest:(NSURL*)dest {
    NSURL* src = [WorkingCopyManager.sharedInstance getLocalWorkingCache:database.uuid];
    slog(@"Export [%@] => [%@]", src, dest);
    
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

- (void)publishDatabasePreferencesChangedNotification:(NSString*)databaseUuid {
    
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kUpdateNotificationDatabasePreferenceChanged object:databaseUuid userInfo:@{ }];
    });
}

- (IBAction)onSettings:(id)sender {
    [AppSettingsWindowController.sharedInstance showGeneralTab];
}



- (IBAction)onCreateNew:(id)sender {
    
    
    
    DocumentController* dc = DocumentController.sharedDocumentController;
    
    [dc newDocument:nil];
}

- (IBAction)onAddExisting:(id)sender {
    
    
    
    DocumentController* dc = DocumentController.sharedDocumentController;
    
    [dc originalOpenDocument:nil];
}

- (IBAction)onCopyTo:(id)sender {
    if(self.tableView.selectedRow != -1) {
        NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
        
        [self copyDatabaseToStorage:database];
    }
}

- (void)copyDatabaseToStorage:(MacDatabasePreferences*)database {
    [self beginAddDatabaseSequence:YES newModel:nil existingDatabaseToCopy:database];
}



- (void)beginAddDatabaseSequence:(BOOL)createMode
                        newModel:(DatabaseModel* _Nullable)newModel
          existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    if ( Settings.sharedInstance.disableNetworkBasedFeatures ) {
        [self onAddDatabaseUserChoseStorage:kLocalDevice wiFiSyncDevice:nil createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy]; 
        return;
    }
    
    __weak DatabasesManagerVC *weakSelf = self;
    [DBManagerPanel.sharedInstance show];
    
    
    
    for ( NSViewController* vc in self.presentedViewControllers ) {
        [Utils dismissViewControllerCorrectly:vc];
    }
    
    
    
    NSString* cloudKitUnavailableReason = nil;
    
#ifndef NO_NETWORKING
    if ( !CloudKitDatabasesInteractor.shared.fastIsAvailable ) {
        if ( CloudKitDatabasesInteractor.shared.cachedAccountStatusError ) {
            cloudKitUnavailableReason = [NSString stringWithFormat:@"%@", CloudKitDatabasesInteractor.shared.cachedAccountStatusError];
        }
        else {
            cloudKitUnavailableReason = [NSString stringWithFormat:@"%@", [CloudKitDatabasesInteractor getAccountStatusStringWithStatus:CloudKitDatabasesInteractor.shared.cachedAccountStatus]];
        }
    }
#endif
    
    NSViewController* vc = [SwiftUIViewFactory makeStorageSelectorWithCreateMode:createMode
                                                                     isImporting:newModel != nil
                                                                           isPro:Settings.sharedInstance.isPro
                                                       cloudKitUnavailableReason:cloudKitUnavailableReason
                                                                initialSelection:(createMode && cloudKitUnavailableReason == nil) ? kCloudKit : kLocalDevice
                                                                      completion:^(BOOL userCancelled, StorageProvider storageProvider, WiFiSyncServerConfig * selectedWiFiSyncDevice) {
        NSViewController* toDismiss = weakSelf.presentedViewControllers.firstObject;
        
        if ( toDismiss ) {
            NSViewController* sheet = self.presentedViewControllers.firstObject;
            [Utils dismissViewControllerCorrectly:sheet];
            
            if ( !userCancelled ) {
                [weakSelf onAddDatabaseUserChoseStorage:storageProvider
                                         wiFiSyncDevice:selectedWiFiSyncDevice
                                             createMode:createMode
                                               newModel:newModel
                                 existingDatabaseToCopy:existingDatabaseToCopy];
            }
        }
    }];
    
    [self presentViewControllerAsSheet:vc];
}

- (void)onAddDatabaseUserChoseStorage:(StorageProvider)storageProvider
                       wiFiSyncDevice:(WiFiSyncServerConfig*)wiFiSyncDevice
                           createMode:(BOOL)createMode
                             newModel:(DatabaseModel* _Nullable)newModel
               existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    if ( createMode ) {
        if ( storageProvider == kLocalDevice ) {
            [self onSelectedNewDatabaseLocation:MacFileBasedBookmarkStorageProvider.sharedInstance providerLocationParam:nil newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        else if ( storageProvider == kSFTP ) {
            [self createOrAddSFTPDatabase:YES newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        else if ( storageProvider == kWebDAV ) {
            [self createOrAddWebDAVDatabase:YES newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        else if ( storageProvider == kCloudKit ) {
#ifndef NO_NETWORKING
            [self onSelectedNewDatabaseLocation:CloudKitStorageProvider.sharedInstance providerLocationParam:nil newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
#endif
        }
        else if ( storageProvider == kOneDrive ) {
#ifndef NO_NETWORKING
            [self onOneDriveSelected:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
#endif
        }
        else {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:storageProvider];
            [self showStorageBrowserForProvider:provider createMode:YES newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        
    }
    else {
        if ( storageProvider == kLocalDevice ) {
            DocumentController* dc = (DocumentController*)NSDocumentController.sharedDocumentController;
            [dc originalOpenDocumentWithFileSelection];
        }
        else if ( storageProvider == kSFTP ) {
            [self createOrAddSFTPDatabase:NO newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        else if ( storageProvider == kWebDAV ) {
            [self createOrAddWebDAVDatabase:NO newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
        else if ( storageProvider == kWiFiSync ) {
            [self onAddDatabaseSelectedWiFiSyncDevice:wiFiSyncDevice newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy]; 
        }
        else if ( storageProvider == kOneDrive ) {
#ifndef NO_NETWORKING
            [self onOneDriveSelected:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
#endif
        }
        else {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:storageProvider];
            [self showStorageBrowserForProvider:provider createMode:NO newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
    }
}

- (void)onAddDatabaseSelectedWiFiSyncDevice:(WiFiSyncServerConfig*)server
                                   newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    NSViewController* vc = [SwiftUIViewFactory makeWiFiSyncPassCodeEntryViewController:server
                                                                                onDone:^(WiFiSyncServerConfig * server, NSString *passcode) {
        NSViewController* sheet = self.presentedViewControllers.firstObject;
        [Utils dismissViewControllerCorrectly:sheet];
        
        if ( server && passcode && passcode.length ) {
            [self onAddWifiSyncDatabase:server passcode:passcode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
    }];
    
    [self presentViewControllerAsSheet:vc];
}

- (void)onAddWifiSyncDatabase:(WiFiSyncServerConfig*)server
                     passcode:(NSString*)passcode
                     newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    WiFiSyncStorageProvider *sp = [[WiFiSyncStorageProvider alloc] init];
    
    server.passcode = passcode;
    sp.explicitConnectionConfig = server;
    
    [self showStorageBrowserForProvider:sp newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
}

- (void)createOrAddSFTPDatabase:(BOOL)createMode newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
#ifndef NO_NETWORKING
    SFTPConnectionsManager* vc = [SFTPConnectionsManager instantiateFromStoryboard];
    
    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(SFTPSessionConfiguration * _Nonnull connection) {
        SFTPStorageProvider* provider = [[SFTPStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
        
        [weakSelf showStorageBrowserForProvider:provider createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
    };
    
    [self presentViewControllerAsSheet:vc];
#endif
}

- (void)createOrAddWebDAVDatabase:(BOOL)createMode newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
#ifndef NO_NETWORKING
    WebDAVConnectionsManager* vc = [WebDAVConnectionsManager instantiateFromStoryboard];
    
    __weak DatabasesManagerVC* weakSelf = self;
    vc.onSelected = ^(WebDAVSessionConfiguration * _Nonnull connection) {
        WebDAVStorageProvider* provider = [[WebDAVStorageProvider alloc] init];
        provider.explicitConnection = connection;
        provider.maintainSessionForListing = YES;
        
        [weakSelf showStorageBrowserForProvider:provider createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
    };
    
    [self presentViewControllerAsSheet:vc];
#endif
}

- (void)showStorageBrowserForProvider:(id<SafeStorageProvider>)provider newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    [self showStorageBrowserForProvider:provider createMode:NO newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
}

- (void)showStorageBrowserForProvider:(id<SafeStorageProvider>)provider
                           createMode:(BOOL)createMode
                             newModel:(DatabaseModel* _Nullable)newModel
               existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    SelectStorageLocationVC* vc = [SelectStorageLocationVC newViewController];
    vc.provider = provider;
    vc.createMode = createMode;
    
    vc.onDone = ^(BOOL success, StorageBrowserItem * _Nonnull selectedItem) {
        if (success) {
            [self onSelectedStorageLocationSuccess:provider selectedItem:selectedItem createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}

- (void)onSelectedStorageLocationSuccess:(id<SafeStorageProvider>)provider
                            selectedItem:(StorageBrowserItem*)selectedItem
                              createMode:(BOOL)createMode
                                newModel:(DatabaseModel* _Nullable)newModel
                  existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    if ( createMode ) {
        [self onSelectedNewDatabaseLocation:provider
                      providerLocationParam:selectedItem
                                   newModel:newModel
                     existingDatabaseToCopy:existingDatabaseToCopy];
    }
    else {
        [self onSelectedExistingDatabase:provider selectedItem:selectedItem];
    }
}

- (void)onSelectedExistingDatabase:(id<SafeStorageProvider>)provider
                      selectedItem:(StorageBrowserItem*)selectedItem {
    NSString* suggestedName = [selectedItem.name stringByDeletingPathExtension];
    
    suggestedName = [DatabasesManager.sharedInstance getUniqueNameFromSuggestedName:suggestedName];
    
    MacDatabasePreferences *newDatabase = [provider getDatabasePreferences:suggestedName providerData:selectedItem.providerData];
    
    if (!newDatabase) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MacAlerts error:nil window:self.view.window];
        });
    }
    else {
        [newDatabase add];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openDatabase:newDatabase];
        });
    }
}

- (void)onSelectedNewDatabaseLocation:(id<SafeStorageProvider>)provider
                providerLocationParam:(id _Nullable)providerLocationParam
                             newModel:(DatabaseModel* _Nullable)newModel
               existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy
{
    __weak DatabasesManagerVC* weakSelf = self;
    
    __block NewDatabaseSwiftHelper * helper = [[NewDatabaseSwiftHelper alloc] initWithParentViewController:self
                                                                                                  provider:provider
                                                                                     providerLocationParam:providerLocationParam
                                                                                                completion:^(MacDatabasePreferences * _Nullable database, BOOL userCancelled, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf onCreateNewDatabaseDone:database userCancelled:userCancelled error:error];
        });
        
        helper = nil;
    }];
    
    NSError* error = nil;
    
    if ( newModel ) {
        if ( ![helper beginImportNewDatabaseSequenceWithImportedModel:newModel error:&error] ) {
            slog(@"🔴 onSelectedNewDatabaseLocation: [%@]", error);
            [MacAlerts error:error window:self.view.window];
        }
    }
    else if ( existingDatabaseToCopy ) {
        if (! [helper beginCopyToNewDatabaseSequenceWithSourceDatabase:existingDatabaseToCopy error:&error] ) {
            slog(@"🔴 onSelectedNewDatabaseLocation: [%@]", error);
            [MacAlerts error:error window:self.view.window];
        }
    }
    else {
        if ( ![helper beginBrandNewDatabaseSequenceAndReturnError:&error] ) {
            slog(@"🔴 onSelectedNewDatabaseLocation: [%@]", error);
            [MacAlerts error:error window:self.view.window];
        }
    }
}

- (void)onCreateNewDatabaseDone:(MacDatabasePreferences*)database
                  userCancelled:(BOOL)userCancelled
                          error:(NSError*)error {
    if ( userCancelled ) {
        return; 
    }
    
    if ( error || !database ) {
        slog(@"🔴 Error in onNewImportedDatabaseCreatedDone: [%@]", error);
        [MacAlerts error:error window:self.view.window];
        return;
    }
    
    [database add];
    
    [self openDatabase:database];
}



#ifndef NO_NETWORKING

- (IBAction)onShareCloudKit:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    [self onCreateOrManageCloudKitSharing:database];
}

- (IBAction)onEditWebDAVConnection:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    WebDAVConfigVC* configVC = [WebDAVConfigVC newConfigurationVC];
    
    WebDAVSessionConfiguration* existing = [WebDAVStorageProvider.sharedInstance getConnectionFromDatabase:database];
    
    configVC.initialConfiguration = existing;
    
    configVC.onDone = ^(BOOL success, WebDAVSessionConfiguration * _Nonnull configuration) {
        if (success) {
            [WebDAVConnections.sharedInstance addOrUpdate:configuration];
            [self refresh];
        }
    };
    
    [self presentViewControllerAsSheet:configVC];
}

- (IBAction)onEditSFTPConnection:(id)sender {
    if(self.tableView.selectedRow == -1) {
        return;
    }
    
    NSString* databaseId = self.databaseIds[self.tableView.selectedRow];
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:databaseId];
    
    SFTPConfigurationVC* configVC = [SFTPConfigurationVC newConfigurationVC];
    
    SFTPSessionConfiguration* existing = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:database];
    configVC.initialConfiguration = existing;
    
    configVC.onDone = ^(BOOL success, SFTPSessionConfiguration * _Nonnull configuration) {
        if (success) {
            [SFTPConnections.sharedInstance addOrUpdate:configuration];
            [self refresh];
        }
    };
    
    [self presentViewControllerAsSheet:configVC];
}

- (void)onCreateOrManageCloudKitSharing:(MacDatabasePreferences*)database {
    self.cloudKitSharingHelper = [[CocoaCloudKitSharingHelper alloc] initWithDatabase:database
                                                                               window:self.view.window
                                                                           completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [MacAlerts error:error window:self.view.window];
            }
            
            
            
            [CloudKitDatabasesInteractor.shared refreshAndMergeWithCompletionHandler:^(NSError * _Nullable error) {
                if ( error ) {
                    slog(@"🔴 Error refreshing... [%@]", error);
                }
            }];
        });
    }];
    
    [self.cloudKitSharingHelper beginNewShare];
}

- (void)onOneDriveSelected:(BOOL)createMode newModel:(DatabaseModel* _Nullable)newModel existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    if ( createMode ) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"onedrive_explorer_title", @"OneDrive Explorer")
                        informativeText:nil
                      option1AndDefault:NSLocalizedString(@"onedrive_browser_my_drives", @"My Drives")
                                option2:NSLocalizedString(@"onedrive_browser_shared_libraries", @"Shared Libraries")
                                 window:self.view.window
                             completion:^(int option) {
            if ( option == 3 ) {
                return;
            }
            
            OneDriveNavigationContextMode mode;
            if ( option == 0 ) {
                mode = OneDriveNavigationContextModeMyDrives;
            }
            else {
                mode = OneDriveNavigationContextModeSharepointSharedLibraries;
            }
            
            [self launchOneDriveBrowser:mode createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }];
    }
    else {
        [MacAlerts threeOptionsWithCancel:NSLocalizedString(@"onedrive_explorer_title", @"OneDrive Explorer")
                          informativeText:nil
                        option1AndDefault:NSLocalizedString(@"onedrive_browser_my_drives", @"My Drives")
                                  option2:NSLocalizedString(@"onedrive_browser_shared_with_me", @"Shared With Me")
                                  option3:NSLocalizedString(@"onedrive_browser_shared_libraries", @"Shared Libraries")
                                   window:self.view.window
                               completion:^(NSUInteger option) {
            if ( option == 0 ) {
                return;
            }
            
            OneDriveNavigationContextMode mode;
            if ( option == 1 ) {
                mode = OneDriveNavigationContextModeMyDrives;
            }
            else if ( option == 2 ) {
                mode = OneDriveNavigationContextModeSharedWithMe;
            }
            else {
                mode = OneDriveNavigationContextModeSharepointSharedLibraries;
            }
            
            [self launchOneDriveBrowser:mode createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }];
    }
}

- (void)launchOneDriveBrowser:(OneDriveNavigationContextMode)mode
                   createMode:(BOOL)createMode
                     newModel:(DatabaseModel* _Nullable)newModel
       existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy {
    if ( mode == OneDriveNavigationContextModeSharepointSharedLibraries && !Settings.sharedInstance.isPro ) {
        [MacAlerts info:NSLocalizedString(@"mac_autofill_pro_feature_title", @"Pro Feature")
        informativeText:NSLocalizedString(@"sharepoint_pro_feature_message", @"Sharepoint Shared Libraries are a Pro feature. Please upgrade to enjoy full access.")
                 window:self.view.window
             completion:nil];
        
        return;
    }
    
    OneDriveNavigationContext * context = [[OneDriveNavigationContext alloc] initWithMode:mode msalResult:nil driveItem:nil];
    
    SelectStorageLocationVC* vc = [SelectStorageLocationVC newViewController];
    
    id<SafeStorageProvider> provider = OneDriveStorageProvider.sharedInstance;
    vc.provider = provider;
    vc.createMode = createMode;
    vc.disallowCreateAtRoot = YES;
    
    vc.rootBrowserItem = [StorageBrowserItem itemWithName:@"<ROOT>" identifier:@"<ROOT>" folder:YES canNotCreateDatabaseInThisFolder:YES providerData:context];
    
    vc.onDone = ^(BOOL success, StorageBrowserItem * _Nonnull selectedItem) {
        if (success) {
            [self onSelectedStorageLocationSuccess:provider selectedItem:selectedItem createMode:createMode newModel:newModel existingDatabaseToCopy:existingDatabaseToCopy];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}

#endif

- (IBAction)onShowPasswordGenerator:(id)sender {
    [PasswordGenerator.sharedInstance show];
}

@end
