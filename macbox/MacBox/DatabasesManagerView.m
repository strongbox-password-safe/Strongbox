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

static NSString* const kColumnIdUuid = @"uuid";
static NSString* const kColumnIdNickName = @"nickName";
static NSString* const kColumnIdTouchIdPassword = @"touchIdPassword";
static NSString* const kColumnIdTouchIdKeyFileDigest = @"touchIdKeyFileDigest";
static NSString* const kColumnIdStorageId = @"storageProvider";
static NSString* const kColumnIdTouchIdEnabled = @"isTouchIdEnabled";
static NSString* const kColumnIdStorageInfo = @"storageInfo";
static NSString* const kColumnIdFileUrl = @"fileUrl";
static NSString* const kColumnIdFilePath = @"filePath";
static NSString* const kColumnIdFileName = @"fileName";


@interface DatabasesManagerView () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSArray<DatabaseMetadata*>* databases;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSButton *buttonOpen;
@property (weak) IBOutlet NSButton *checkboxAutoOpenPrimary;

@property BOOL debug;

@end

@implementation DatabasesManagerView

static DatabasesManagerView* sharedInstance;

+ (void)show:(BOOL)debug
{
    if (!sharedInstance) {
        sharedInstance = [[DatabasesManagerView alloc] initWithWindowNibName:@"SafesMetaDataViewer"];
    }
    
    sharedInstance.debug = debug;
    [sharedInstance showWindow:nil];
}

- (void)cancel:(id)sender { // Pick up escape key
    [self close];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == [self window] && self == sharedInstance) {
        sharedInstance = nil;
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    [self.window setLevel:NSFloatingWindowLevel];
    [self.window setHidesOnDeactivate:YES];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onDoubleClick:);

    [self bindAutoOpenPrimary];
    [self showHideColumns];
    
    [self refresh];

    // Select the first one... ready for open
    
    if(self.databases.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (void)bindAutoOpenPrimary {
    self.checkboxAutoOpenPrimary.state = Settings.sharedInstance.autoOpenFirstDatabaseOnEmptyLaunch ? NSOnState : NSOffState;
}

- (IBAction)onChangeAutoOpen:(id)sender {
    Settings.sharedInstance.autoOpenFirstDatabaseOnEmptyLaunch = self.checkboxAutoOpenPrimary.state == NSOnState;
    
    [self bindAutoOpenPrimary];
}

- (void)showHideColumns {
    [self showHideColumn:kColumnIdUuid show:self.debug];
    [self showHideColumn:kColumnIdTouchIdPassword show:self.debug];
    [self showHideColumn:kColumnIdTouchIdKeyFileDigest show:self.debug];
    [self showHideColumn:kColumnIdTouchIdEnabled show:self.debug];
    [self showHideColumn:kColumnIdFileUrl show:self.debug];
    [self showHideColumn:kColumnIdStorageInfo show:self.debug];
    [self showHideColumn:kColumnIdStorageId show:self.debug];
}

- (IBAction)onOk:(id)sender {
    [self.window close];
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
            [self refresh];
        }
    }
}

- (IBAction)onRemove:(id)sender {
    if(self.tableView.selectedRow != -1) {
        DatabaseMetadata *safe = [self.databases objectAtIndex:self.tableView.selectedRow];
        [self removeDatabase:safe];
    }
}

- (void)removeDatabase:(DatabaseMetadata*)safe {
    [DatabasesManager.sharedInstance remove:safe.uuid];
    [safe resetConveniencePasswordWithCurrentConfiguration:nil];
    safe.keyFileBookmark = nil;
    [self refresh];
}

- (void)refresh {
    self.databases = DatabasesManager.sharedInstance.snapshot;
    [self.tableView reloadData];
    [self validateUi];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databases.count;
}

-(id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];
    
    DatabaseMetadata* database = [self.databases objectAtIndex:row];

    if([tableColumn.identifier isEqualToString:kColumnIdFileName]) {
        NSURL* url = [database valueForKey:kColumnIdFileUrl];
        result.textField.stringValue = url.lastPathComponent;
    }
    else if([tableColumn.identifier isEqualToString:kColumnIdFilePath]) {
        NSURL* url = [database valueForKey:kColumnIdFileUrl];
        result.textField.stringValue = url.URLByDeletingLastPathComponent.path;
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

- (IBAction)onDoubleClick:(id)sender {
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

           NSString* loc = NSLocalizedString(@"mac_problem_opening_db", @"There was a problem opening this file. It will be removed from your databases.");

           [Alerts error:loc error:error window:self.window completion:^{
                [self refresh];
           }];
        }
        else {
           [self close];
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
    [self close];
    
    DocumentController* dc = (DocumentController*)NSDocumentController.sharedDocumentController;
    
    [dc originalOpenDocument:nil];
}

- (IBAction)onNewDatabase:(id)sender {
    [self close];
    [NSDocumentController.sharedDocumentController newDocument:nil];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self validateUi];
}

- (void)validateUi {
    NSInteger row = self.tableView.selectedRow;
    
    self.buttonOpen.enabled = (row != -1);
}

@end
