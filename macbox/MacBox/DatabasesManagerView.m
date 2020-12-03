//
//  SafesMetaDataViewer.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "DatabasesManagerView.h"
#import "DatabasesManager.h"
#import "Alerts.h"
#import "DocumentController.h"
#import "Settings.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"
#import "CustomBackgroundTableView.h"
#import "AutoFillManager.h"

static NSString* const kColumnIdUuid = @"uuid";
static NSString* const kColumnIdFriendlyTitleAndSubtitles = @"nickName";
static NSString* const kColumnIdTouchIdPassword = @"conveniencePassword";
static NSString* const kColumnIdStorageId = @"storageProvider";
static NSString* const kColumnIdTouchIdEnabled = @"isTouchIdEnabled";
static NSString* const kColumnIdStorageInfo = @"storageInfo";
static NSString* const kColumnIdFileUrl = @"fileUrl";
static NSString* const kColumnIdFilePath = @"filePath";
static NSString* const kColumnIdFileName = @"fileName";

static NSString* const kDatabaseCellView = @"DatabaseCellView";
static NSString* const kDragAndDropId = @"com.markmcguill.strongbox.mac.databases.list";

static const CGFloat kAutoRefreshTimeSeconds = 30.0f;

NSString* const kDatabasesListViewForceRefreshNotification = @"databasesListViewForceRefreshNotification";

@interface DatabasesManagerView () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSArray<DatabaseMetadata*>* databases;
@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (weak) IBOutlet NSButton *checkboxAutoOpenPrimary;
@property (weak) IBOutlet NSButton *buttonRemove;
@property (weak) IBOutlet NSButton *buttonRename;
@property NSTimer* timerRefresh;
@property BOOL debug;

@end

@implementation DatabasesManagerView

static DatabasesManagerView* sharedInstance;

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

+ (void)show:(BOOL)debug {
    if (!sharedInstance) {
        sharedInstance = [[DatabasesManagerView alloc] initWithWindowNibName:@"SafesMetaDataViewer"];
    }
    
    sharedInstance.debug = debug;
    [sharedInstance showWindow:nil];
}

- (void)cancel:(id)sender { 
    [self.window orderBack:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == [self window] && self == sharedInstance) {
        [self killRefreshTimer];
        sharedInstance = nil;
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSButton *zoomButton = [self.window standardWindowButton:NSWindowZoomButton];
    NSButton *minButton = [self.window standardWindowButton:NSWindowMiniaturizeButton];
    
    [zoomButton setEnabled:NO];
    [minButton setEnabled:NO];
    
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];

    
    
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onDoubleClick:);
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kDatabaseCellView bundle:nil]
                  forIdentifier:kDatabaseCellView];

    [self.tableView registerForDraggedTypes:@[kDragAndDropId]];
    self.tableView.emptyString = NSLocalizedString(@"mac_no_databases_initial_message", @"No Databases Here Yet\n\nClick 'New Database...' or 'Add Existing...' below to get started.");

    [self bindAutoOpenPrimary];
    [self showHideColumns];
    
    self.databases = DatabasesManager.sharedInstance.snapshot;
    [self.tableView reloadData];

    
    
    if(self.databases.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVisibleRows) name:kDatabasesListViewForceRefreshNotification object:nil];
    
    [self startRefreshTimer];
}

- (void)bindAutoOpenPrimary {
    self.checkboxAutoOpenPrimary.state = Settings.sharedInstance.autoOpenFirstDatabaseOnEmptyLaunch ? NSOnState : NSOffState;
}

- (IBAction)onChangeAutoOpen:(id)sender {
    Settings.sharedInstance.autoOpenFirstDatabaseOnEmptyLaunch = self.checkboxAutoOpenPrimary.state == NSOnState;
    
    [self bindAutoOpenPrimary];
}

- (void)showHideColumns {
    if (!self.debug) {
        self.tableView.headerView = nil;
    }
    
    [self showHideColumn:kColumnIdUuid show:self.debug];
    [self showHideColumn:kColumnIdFileName show:self.debug];
    [self showHideColumn:kColumnIdFilePath show:self.debug];
    [self showHideColumn:kColumnIdTouchIdPassword show:self.debug];
    [self showHideColumn:kColumnIdTouchIdEnabled show:self.debug];
    [self showHideColumn:kColumnIdFileUrl show:self.debug];
    [self showHideColumn:kColumnIdStorageInfo show:self.debug];
    [self showHideColumn:kColumnIdStorageId show:self.debug];
}

- (IBAction)onRename:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        
        NSString* loc = NSLocalizedString(@"mac_enter_new_name_for_db", @"Enter a new name for this database");
        NSString* response = [[[Alerts alloc] init] input:loc defaultValue:safe.nickName allowEmpty:NO];
        
        if(response) {
            NSLog(@"Rename: [%@]", response);
            safe.nickName = response;
            [DatabasesManager.sharedInstance update:safe];
        }
    }
}

- (IBAction)onRemove:(id)sender {
    NSString* single = NSLocalizedString(@"are_you_sure_delete_database_single", @"Are you sure you want to remove this database from Strongbox?\n\nNB: The underlying database file will not be deleted. Just Strongbox's settings for this database.");
    
    NSString* multiple = NSLocalizedString(@"are_you_sure_delete_database_multiple", @"Are you sure you want to remove these databases from Strongbox?\n\nNB: The underlying database files will not be deleted. Just Strongbox's settings for these databases.");
    
    NSString *message = self.tableView.selectedRowIndexes.count > 1 ? multiple : single;
    
    [Alerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
  informativeText:message
           window:self.window
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

    if([tableColumn.identifier isEqualToString:kColumnIdFriendlyTitleAndSubtitles]) {
        DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];

        [result setWithDatabase:database];
        
        return result;
    }
    else {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];

        if([tableColumn.identifier isEqualToString:kColumnIdFileName]) {
            NSURL* url = [database valueForKey:kColumnIdFileUrl];
            NSString* loc = NSLocalizedString(@"generic_unknown", @"Unknown");
            result.textField.stringValue = url && url.lastPathComponent ? url.lastPathComponent : loc;
        }
        else if([tableColumn.identifier isEqualToString:kColumnIdFilePath]) {
            NSURL* url = [database valueForKey:kColumnIdFileUrl];
            NSString* loc = NSLocalizedString(@"generic_unknown", @"Unknown");
            
            result.textField.stringValue = url && url.URLByDeletingLastPathComponent.path ? url.URLByDeletingLastPathComponent.path : loc;
        }
        else if([tableColumn.identifier isEqualToString:kColumnIdStorageId]) {
            NSObject *obj = [database valueForKey:tableColumn.identifier];
            NSNumber* num = (NSNumber*)obj;
            result.textField.stringValue = getStorageProviderName((StorageProvider)num.integerValue);
        }
        else {
            NSObject *obj = [database valueForKey:tableColumn.identifier];
            result.textField.stringValue = obj == nil ? @"(nil)" : [obj description];
        }
        
        return result;
    }
}

NSString* getStorageProviderName(StorageProvider sp) {
    switch (sp) {
        case kLocalDevice:
            {
                NSString* loc = NSLocalizedString(@"mac_storage_provider_name_file", @"File Based");
                return loc;
            }
            break;
        case kSFTP:
            {
                return @"SFTP";
            }
            break;
        case kWebDAV:
            {
                return @"WebDAV";
            }
            break;
        default:
            return @"Unknown";
            break;
    }
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

           [Alerts error:loc
                   error:error
                  window:self.window
              completion:nil];
        }
        else {

        }
    }];
}

- (IBAction)onOpen:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if(row == -1) {
        return;
    }
    
    DatabaseMetadata* database = self.databases[row];
    [self openDatabase:database];
}

- (IBAction)onOpenFiles:(id)sender {

    
    DocumentController* dc = (DocumentController*)NSDocumentController.sharedDocumentController;
    
    [dc originalOpenDocument:nil];
}

- (IBAction)onNewDatabase:(id)sender {

    [NSDocumentController.sharedDocumentController newDocument:nil];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.buttonRemove.enabled = self.tableView.selectedRowIndexes.count > 0;
    self.buttonRename.enabled = self.tableView.selectedRowIndexes.count == 1;
    









}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = theEvent.charactersIgnoringModifiers;
    unichar aChar = [chars characterAtIndex:0];

    if(aChar == NSDeleteCharacter) {
        [self onRemove:nil];
    }
    else if ((aChar == NSEnterCharacter) || (aChar == NSCarriageReturnCharacter)) {
        NSLog(@"OPEN");
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

@end
