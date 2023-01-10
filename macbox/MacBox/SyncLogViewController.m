//
//  SyncLogViewController.m
//  MacBox
//
//  Created by Strongbox on 16/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SyncLogViewController.h"
#import "MacSyncManager.h"
#import "NSDate+Extensions.h"
#import "NSArray+Extensions.h"
#import "ClipboardManager.h"

static NSString* const kColumnTimeStamp = @"timestamp";
static NSString* const kColumnLog = @"log";

@interface TableRow : NSObject

@property BOOL isGroupRow;
@property NSString* groupHeaderTitle;
@property SyncStatusLogEntry* entry;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@end

@implementation TableRow

@end

@interface SyncLogViewController () <NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate>

@property BOOL hasLoaded;
@property (weak) IBOutlet NSTableView *tableView;

@property NSArray<TableRow*> *syncs;
@property MacDatabasePreferences* database;

@end

@implementation SyncLogViewController

+ (instancetype)showForDatabase:(MacDatabasePreferences*)database {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"SyncLogViewController" bundle:nil];
    NSWindowController* wc = [storyboard instantiateInitialController];
    SyncLogViewController* ret = (SyncLogViewController*)wc.contentViewController;
    ret.database = database;
    
    return ret;
}

- (void)cancel:(id)sender { 
    if ( self.view.window.sheetParent ) {
        [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.view.window orderOut:self];
    }
}

- (IBAction)onClose:(id)sender {
    [self cancel:nil];
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
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
        
    [self refresh];
}

- (void)refresh {
    SyncStatus *syncStatus = [MacSyncManager.sharedInstance getSyncStatus:self.database];

    NSMutableArray<NSArray*>* mutableSyncs = NSMutableArray.array;

    NSMutableSet<NSUUID*>* set = NSMutableSet.set;
    
    NSMutableArray *currentSync;
    for (SyncStatusLogEntry* entry in syncStatus.changeLog) {
        if (![set containsObject:entry.syncId]) {
            currentSync = NSMutableArray.array;
            [mutableSyncs addObject:currentSync];
            [set addObject:entry.syncId];
        }
        
        [currentSync addObject:entry];
    }
    
    NSMutableArray<TableRow*>* ret = NSMutableArray.array;
    NSInteger i = set.count;
    for (NSArray<SyncStatusLogEntry*> *entries in mutableSyncs.reverseObjectEnumerator) {
        TableRow* row = [[TableRow alloc] init];
        row.isGroupRow = YES;
        
        SyncStatusLogEntry* entry = entries.firstObject;
        NSString* loc = NSLocalizedString(@"sync_log_sync_header_fmt", @"%@ - Sync No. %@");
        row.groupHeaderTitle =  [NSString stringWithFormat:loc, entry ? entry.timestamp.friendlyDateStringVeryShort : @"", @(i--)];
        
        
        [ret addObject:row];
    
        for (SyncStatusLogEntry* entry in entries) {
            TableRow* row = [[TableRow alloc] init];
            
            row.entry = entry;
            row.isGroupRow = NO;
            row.groupHeaderTitle = @"";
            
            [ret addObject:row];
        }
    }
    
    self.syncs = ret.copy;
    
    [self.tableView reloadData];
}



- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.syncs.count;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    TableRow* tableRow = [self.syncs objectAtIndex:row];
    return tableRow.isGroupRow;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    TableRow* tableRow = [self.syncs objectAtIndex:row];

    if (tableRow.isGroupRow) {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"SyncLogLogCellId" owner:self];
        
        result.textField.stringValue = tableRow.groupHeaderTitle;
        
        
        return result;
    }
    else {
        SyncStatusLogEntry* entry = tableRow.entry;
        
        if([tableColumn.identifier isEqualToString:kColumnTimeStamp]) {
            NSString* timestamp = entry.timestamp.friendlyTimeStringPrecise;

            NSTableCellView *result = [tableView makeViewWithIdentifier:@"SyncLogTimeStampCellId" owner:self];
            
            result.textField.stringValue = timestamp;

            [self setImageBasedOnState:entry.state stateImage:result.imageView];
            
            return result;
        }
        else {
            NSString* log = entry.error ? entry.error.description : (entry.message ? entry.message : @"");
        
            NSTableCellView *result = [tableView makeViewWithIdentifier:@"SyncLogLogCellId" owner:self];

            if([tableColumn.identifier isEqualToString:kColumnLog]) {
                if (entry.state == kSyncOperationStateDone ) {
                    result.textField.stringValue = NSLocalizedString(@"sync_log_status_done", @"Done. ✅");
                }
                else {
                    result.textField.stringValue = log;
                }
            }
            
            return result;
        }
    }
}

- (void)setImageBasedOnState:(SyncOperationState)state stateImage:(NSImageView*)stateImage {
    switch(state) {
        case kSyncOperationStateInProgress:
            stateImage.image = [NSImage imageNamed:@"syncronize"];
            stateImage.contentTintColor = NSColor.systemBlueColor;
            break;
        case kSyncOperationStateUserCancelled:
        case kSyncOperationStateBackgroundButUserInteractionRequired:
            stateImage.image = [NSImage imageNamed:@"syncronize"];
            stateImage.contentTintColor = NSColor.systemYellowColor;
            break;
        case kSyncOperationStateError:
            stateImage.image = [NSImage imageNamed:@"error"];
            stateImage.contentTintColor = NSColor.systemRedColor;
            break;
        case kSyncOperationStateInitial:
            stateImage.image = [NSImage imageNamed:@"ok"];
            stateImage.contentTintColor = NSColor.systemBlueColor;
        case kSyncOperationStateDone:
        default:
            stateImage.image = [NSImage imageNamed:@"ok"];
            stateImage.contentTintColor = NSColor.systemGreenColor;
            break;
    }
}

- (IBAction)onCopySyncLog:(id)sender {
    SyncStatus *syncStatus = [MacSyncManager.sharedInstance getSyncStatus:self.database];

    NSArray* logs = [syncStatus.changeLog map:^id _Nonnull(SyncStatusLogEntry * _Nonnull entry, NSUInteger idx) {
        NSString* log = entry.error ? entry.error.description : (entry.message ? entry.message : @"");
        NSString* timestamp = entry.timestamp.friendlyTimeStringPrecise;

        return [NSString stringWithFormat:@"%@ [%@] - %@", timestamp, syncOperationStateToString(entry.state), log];
    }];
    
    NSString* log = [logs componentsJoinedByString:@"\n"];
    
    [ClipboardManager.sharedInstance copyConcealedString:log];
}

@end
