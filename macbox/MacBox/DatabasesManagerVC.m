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

NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";

static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";
static NSString* const kDatabaseCellView = @"DatabaseCellView";
static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";

static const CGFloat kAutoRefreshTimeSeconds = 30.0f;

@interface DatabasesManagerVC () <NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate>

@property (nonatomic, strong) NSArray<DatabaseMetadata*>* databases;

@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (weak) IBOutlet NSButton *buttonRemove;
@property (weak) IBOutlet NSButton *buttonRename;
@property (weak) IBOutlet NSButton *buttonSync;

@property NSTimer* timerRefresh;
@property BOOL hasLoaded;

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
    
    self.tableView.headerView = nil;
    [self showHideColumn:@"dummy" show:NO]; 


    self.databases = DatabasesManager.sharedInstance.snapshot;
    [self.tableView reloadData];

    

    if(self.databases.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListViewForceRefreshNotification object:nil];
    [self startRefreshTimer];
}

- (void)bindUi {
    self.buttonRemove.enabled = self.tableView.selectedRowIndexes.count > 0;
    self.buttonRename.enabled = self.tableView.selectedRowIndexes.count == 1;
    self.buttonSync.enabled = self.tableView.selectedRowIndexes.count == 1;
}

- (void)killRefreshTimer {
    if(self.timerRefresh) {
        NSLog(@"Kill Refresh Timer");
        [self.timerRefresh invalidate];
        self.timerRefresh = nil;
    }
}

- (void)startRefreshTimer {
    NSLog(@"Start Refresh Timer");
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

- (IBAction)onRename:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        
        NSString* loc = NSLocalizedString(@"mac_enter_new_name_for_db", @"Enter a new name for this database");
        NSString* response = [[[MacAlerts alloc] init] input:loc defaultValue:safe.nickName allowEmpty:NO];
        
        if(response) {
            NSLog(@"Rename: [%@]", response);
            safe.nickName = response;
            [DatabasesManager.sharedInstance update:safe];
        }
    }
}

- (IBAction)onRemove:(id)sender {
    if (self.tableView.selectedRowIndexes.count == 0) {
        return;
    }
    
    NSString* single = NSLocalizedString(@"are_you_sure_delete_database_single", @"Are you sure you want to remove this database from Strongbox?\n\nNB: The underlying database file will not be deleted. Just Strongbox's settings for this database.");
    
    NSString* multiple = NSLocalizedString(@"are_you_sure_delete_database_multiple", @"Are you sure you want to remove these databases from Strongbox?\n\nNB: The underlying database files will not be deleted. Just Strongbox's settings for these databases.");
    
    NSString *message = self.tableView.selectedRowIndexes.count > 1 ? multiple : single;
    
    [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
  informativeText:message
           window:self.view.window
       completion:^(BOOL yesNo) {
        if (yesNo) {
            NSMutableSet<DatabaseMetadata*>* set = NSMutableSet.set;
        
            [self performActionOnSelected:^(DatabaseMetadata *database) {
                [set addObject:database];
            }];
            
            for (DatabaseMetadata* database in set) {
                [self removeDatabase:database];
            }

            BOOL quickTypeDb = [set.allObjects anyMatch:^BOOL(DatabaseMetadata * _Nonnull obj) {
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
}

- (void)refreshVisibleRows {
    NSIndexSet* set = self.tableView.selectedRowIndexes;
    
    NSMutableSet<NSString*>* selected = NSMutableSet.set;
    [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [selected addObject:self.databases[idx].uuid];
    }];
    
    self.databases = DatabasesManager.sharedInstance.snapshot;

    NSScrollView* scrollView = [self.tableView enclosingScrollView];
    CGPoint originalScrollPos = scrollView.documentVisibleRect.origin;
    





    
    [self.tableView reloadData];
    
    NSMutableIndexSet* selectedSet = NSMutableIndexSet.indexSet;
    [self.databases enumerateObjectsUsingBlock:^(DatabaseMetadata * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([selected containsObject:obj.uuid]) {
            [selectedSet addIndex:idx];
        }
    }];
    
    [self.tableView selectRowIndexes:selectedSet byExtendingSelection:NO];
    
    [scrollView.documentView scrollPoint:originalScrollPos];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databases.count;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    DatabaseMetadata* database = [self.databases objectAtIndex:row];


        DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];

        [result setWithDatabase:database];
        
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
    
    DatabaseMetadata* database = self.databases[row];
    [self openDatabase:database];
}

- (void)openDatabase:(DatabaseMetadata*)database {
    DocumentController* dc = NSDocumentController.sharedDocumentController;
    
    [dc openDatabase:database completion:^(NSError *error) {
        if(error) {
           [DatabasesManager.sharedInstance remove:database.uuid];

           NSString* loc = NSLocalizedString(@"mac_problem_opening_db",
                                             @"There was a problem opening this file. It will be removed from your databases.");

           [MacAlerts error:loc
                   error:error
                  window:self.view.window
              completion:nil];
        }
    }];
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
        DatabaseMetadata* database = [self.databases objectAtIndex:idx];
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

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
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



    if (theAction == @selector(onViewSyncLog:)) {
        if(self.tableView.selectedRow != -1) {
            DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
            return safe.storageProvider != kLocalDevice;
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
    else if (theAction == @selector(onRename:)) {
        return self.tableView.selectedRow != -1;
    }
    else if (theAction == @selector(onToggleLaunchAtStartup:)) {
        if(self.tableView.selectedRow != -1) {
            DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
            NSMenuItem* item = (NSMenuItem*)anItem;
            [item setState:safe.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff];
        }
        
        return self.tableView.selectedRow != -1;
    }

    return NO;
}

- (IBAction)onViewSyncLog:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        if ( safe.storageProvider != kLocalDevice ) {
            SyncLogViewController* vc = [SyncLogViewController showForDatabase:safe];
            [self presentViewControllerAsSheet:vc];
        }
    }
}

- (IBAction)onToggleLaunchAtStartup:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        safe.launchAtStartup = !safe.launchAtStartup;
        [DatabasesManager.sharedInstance update:safe];
    }
}

- (IBAction)onSync:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        if (safe.storageProvider != kLocalDevice ) {
            
            [MacSyncManager.sharedInstance backgroundSyncDatabase:safe
                                                       completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
                if ( error ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [MacAlerts error:error window:self.view.window];
                    });
                }
                else if ( localWasChanged ) {
                    NSLog(@"XXXXX - localWasChanged");
                    
                    Document* doc = [DocumentController.sharedDocumentController documentForURL:safe.fileUrl];
                    [doc onSyncChangedUnderlyingWorkingCopy];
                }
            }];
        }
    }
}

@end
