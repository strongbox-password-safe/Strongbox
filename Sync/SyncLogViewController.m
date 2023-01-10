//
//  SyncLogViewController.m
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncLogViewController.h"
#import "SyncManager.h"
#import "Utils.h"
#import "SyncLogEntryTableViewCell.h"
#import "NSArray+Extensions.h"
#import "ClipboardManager.h"
#import "NSDate+Extensions.h"
 
static NSString* const kSyncLogCellCellId = @"SyncLogCell";

@interface SyncLogViewController ()

@property NSArray<NSArray<SyncStatusLogEntry*>*> *syncs;

@end

@implementation SyncLogViewController

+ (UINavigationController*)createWithDatabase:(DatabasePreferences*)database {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"SyncLog" bundle:nil];
    UINavigationController* nav = [sb instantiateInitialViewController];
    SyncLogViewController* vc = (SyncLogViewController*) nav.childViewControllers.firstObject;
    vc.database = database;
    
    return nav;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:kSyncLogCellCellId bundle:nil] forCellReuseIdentifier:kSyncLogCellCellId];

    self.tableView.tableFooterView = UIView.new;
    
    [self refresh];
}

- (void)refresh {
    SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:self.database];

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
    
    self.syncs = [[mutableSyncs reverseObjectEnumerator] allObjects];
    
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.syncs.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.syncs[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray* sync = self.syncs[section];
    SyncStatusLogEntry* entry = sync.firstObject;
    
    NSString* loc = NSLocalizedString(@"sync_log_sync_header_fmt", @"%@ - Sync No. %@");
    
    return [NSString stringWithFormat:loc, entry ? entry.timestamp.friendlyDateStringVeryShort : @"", @(self.syncs.count - section)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SyncLogEntryTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kSyncLogCellCellId forIndexPath:indexPath];

    NSArray *entries = self.syncs[indexPath.section];
    SyncStatusLogEntry *entry = entries[indexPath.row];
    
    NSString* log = entry.error ? entry.error.description : (entry.message ? entry.message : @"");
    NSString* timestamp = entry.timestamp.friendlyTimeStringPrecise;

    [cell setState:entry.state log:log timestamp:timestamp];
    
    return cell;
}
    
- (IBAction)onCopyLog:(id)sender {
    SyncStatus *syncStatus = [SyncManager.sharedInstance getSyncStatus:self.database];

    NSArray* logs = [syncStatus.changeLog map:^id _Nonnull(SyncStatusLogEntry * _Nonnull entry, NSUInteger idx) {
        NSString* log = entry.error ? entry.error.description : (entry.message ? entry.message : @"");
        NSString* timestamp = entry.timestamp.friendlyTimeStringPrecise;

        return [NSString stringWithFormat:@"%@ [%@] - %@", timestamp, syncOperationStateToString(entry.state), log];
    }];
    
    NSString* log = [logs componentsJoinedByString:@"\n"];
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:log];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
