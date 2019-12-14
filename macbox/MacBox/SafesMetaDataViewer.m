//
//  SafesMetaDataViewer.m
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafesMetaDataViewer.h"
#import "SafesList.h"
#import "Alerts.h"
#import "DocumentController.h"
#import "Settings.h"

static NSString* const kColumnIdUuid = @"uuid";
static NSString* const kColumnIdNickName = @"nickName";
static NSString* const kColumnIdTouchIdPassword = @"touchIdPassword";
static NSString* const kColumnIdTouchIdKeyFileDigest = @"touchIdKeyFileDigest";
static NSString* const kColumnIdFilename = @"fileName";
static NSString* const kColumnIdStorageId = @"storageProvider";
static NSString* const kColumnIdTouchIdEnabled = @"isTouchIdEnabled";
static NSString* const kColumnIdFileIdentifier = @"fileIdentifier";

@interface SafesMetaDataViewer () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSArray<SafeMetaData*>* safes;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSButton *buttonOpen;
@property (weak) IBOutlet NSButton *checkboxAutoOpenPrimary;

@property BOOL debug;

@end

@implementation SafesMetaDataViewer

static SafesMetaDataViewer* sharedInstance;

+ (void)show:(BOOL)debug
{
    if (!sharedInstance) {
        sharedInstance = [[SafesMetaDataViewer alloc] initWithWindowNibName:@"SafesMetaDataViewer"];
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
    
    if(self.safes.count) {
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
//    [self showHideColumn:kColumnIdFilename show:self.debug];
    [self showHideColumn:kColumnIdFileIdentifier show:self.debug];
    [self showHideColumn:kColumnIdStorageId show:self.debug];
}

- (IBAction)onOk:(id)sender {
    [self.window close];
}

- (IBAction)onRename:(id)sender {
    if(self.tableView.selectedRow != -1) {
        SafeMetaData *safe = [self.safes objectAtIndex:self.tableView.selectedRow];
        
        NSString* loc = NSLocalizedString(@"mac_enter_new_name_for_db", @"Enter a new name for this database");
        NSString* response = [[[Alerts alloc] init] input:loc defaultValue:safe.nickName allowEmpty:NO];
        
        if(response) {
            NSLog(@"Rename: [%@]", response);
            safe.nickName = response;
            [SafesList.sharedInstance update:safe];
            [self refresh];
        }
    }
}

- (IBAction)onRemove:(id)sender {
    if(self.tableView.selectedRow != -1) {
        SafeMetaData *safe = [self.safes objectAtIndex:self.tableView.selectedRow];
        [self removeDatabase:safe];
    }
}

- (void)removeDatabase:(SafeMetaData*)safe {
    [SafesList.sharedInstance remove:safe.uuid];
    safe.touchIdPassword = nil;
    safe.touchIdKeyFileDigest = nil;
    [self refresh];
}

- (void)refresh {
    self.safes = SafesList.sharedInstance.snapshot;
    [self.tableView reloadData];
    [self validateUi];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.safes.count;
}

-(id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"MyView" owner:self];
    
    SafeMetaData* safe = [self.safes objectAtIndex:row];
    
    NSObject *obj = [safe valueForKey:tableColumn.identifier];
    
    if([tableColumn.identifier isEqualToString:kColumnIdStorageId]) {
        NSNumber* num = (NSNumber*)obj;
        result.textField.stringValue = getStorageProviderName((StorageProvider)num.integerValue);
    }
    else {
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
    
    SafeMetaData* database = self.safes[row];
    [self openDatabase:database];
}

- (void)openDatabase:(SafeMetaData*)database {
    NSLog(@"Open: %@", database.nickName);
    
    if(database.storageProvider == kLocalDevice) {
        NSURL* url = [NSURL URLWithString:database.fileIdentifier];
        
        [NSDocumentController.sharedDocumentController
         openDocumentWithContentsOfURL:url
                                display:YES
                    completionHandler:^(NSDocument * _Nullable document,
                                        BOOL documentWasAlreadyOpen,
                NSError * _Nullable error) {
            NSLog(@"Done! = %@", error);
                
                        
           if(error) {
               [SafesList.sharedInstance remove:database.uuid];

               NSString* loc = NSLocalizedString(@"mac_problem_opening_db", @"There was a problem opening this file. It will be removed from your databases.");
                       
               [Alerts error:loc
                       error:error
                      window:self.window
                  completion:^{
                    [self refresh];
               }];
           }
           else {
               [self close];
           }
        }];
    }
}

- (IBAction)onOpen:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if(row == -1) {
        return;
    }
    
    SafeMetaData* database = self.safes[row];
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
