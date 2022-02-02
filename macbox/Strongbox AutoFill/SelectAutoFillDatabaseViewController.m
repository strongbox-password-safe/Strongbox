//
//  SelectAutoFillDatabaseViewController.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SelectAutoFillDatabaseViewController.h"
#import "CustomBackgroundTableView.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"
#import "Settings.h"
#import "MMWormhole.h"
#import "AutoFillWormhole.h"

static NSString* const kDatabaseCellView = @"DatabaseCellView";

@interface SelectAutoFillDatabaseViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (nonatomic, strong) NSArray<MacDatabasePreferences*>* databases;
@property (weak) IBOutlet NSButton *buttonSelect;

@property BOOL viewWillAppearFirstTimeDone;
@property BOOL firstAppearanceDone;
@property NSSet<NSString*> *unlockedDatabases;

@end

@implementation SelectAutoFillDatabaseViewController

- (void)viewWillAppear {
    [super viewWillAppear];
    
    if ( !self.viewWillAppearFirstTimeDone ) {
        self.viewWillAppearFirstTimeDone = YES;
        
        self.tableView.headerView = nil;
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        
        [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kDatabaseCellView bundle:nil]
                      forIdentifier:kDatabaseCellView];

        self.tableView.emptyString = NSLocalizedString(@"mac_no_autofill_enabled_databases_initial_message", @"No AutoFill Enabled Databases");
        
        self.tableView.doubleAction = @selector(onSelect:);
        
        self.unlockedDatabases = NSSet.set;

        [self refresh];
        
        [self checkWormholeForUnlockedDatabases];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
        
    if ( !self.firstAppearanceDone ) {
        self.firstAppearanceDone = YES;
        self.view.window.frameAutosaveName = @"SelectAutoFillDatabase-AutoSave";
    
        if ( self.databases.count == 1 && Settings.sharedInstance.autoFillAutoLaunchSingleDatabase ) {
            NSLog(@"Single Database Launching...");
        
            MacDatabasePreferences* database = self.databases.firstObject;
            
            [self dismissViewController:self];
            
            self.onDone(NO, database);
        }
    }
}

- (void)checkWormholeForUnlockedDatabases {
    [self.wormhole clearAllMessageContents];
    
    __block BOOL gotResponse = NO;
    __block NSMutableSet<NSString*> *unlocked = NSMutableSet.set;
        
    for (MacDatabasePreferences* database in self.databases) {
        NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusRequestId, database.uuid];

        [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(), @"database-id" : database.uuid }
                              identifier:requestId];

        NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusResponseId, database.uuid];

        [self.wormhole listenForMessageWithIdentifier:responseId
                                             listener:^(id messageObject) {

            
            NSDictionary* dict = messageObject;
            NSString* userSession = dict[@"user-session-id"];

            if ( [userSession isEqualToString:NSUserName()] ) { 
                NSString* databaseId = dict[@"unlocked"];

                NSLog(@"AutoFill-Wormhole: Got Database Status Response Message [%@] is unlocked", databaseId);

                gotResponse = YES;
                [unlocked addObject:databaseId];
                
                self.unlockedDatabases = unlocked;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self refresh];
                });
            }
        }];
    }
    
    CGFloat timeout = 0.5f;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!gotResponse) {
            NSLog(@"No wormhole response after %f seconds...", timeout);
            
            for (MacDatabasePreferences* database in self.databases) {
                NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusResponseId, database.uuid];
                [self.wormhole stopListeningForMessageWithIdentifier:responseId];
            }
            
            [self.wormhole clearAllMessageContents];
        }
    });
}

- (void)refresh {
    self.databases = [MacDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
        return database.autoFillEnabled;
    }];
    
    [self.tableView reloadData];
    
    if (self.tableView.numberOfRows > 0) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    [self bindSelectedButton];
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewController:self];
    
    self.onDone(YES, nil);
}

- (IBAction)onSelect:(id)sender {
    NSUInteger row = self.tableView.selectedRowIndexes.firstIndex;
    
    if (row != NSNotFound) {
        MacDatabasePreferences* database = self.databases[row];
        
        [self dismissViewController:self];
        
        self.onDone(NO, database);
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databases.count;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    MacDatabasePreferences* database = [self.databases objectAtIndex:row];

    DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];
    
    BOOL wormholeDetectedUnlocked = [self.unlockedDatabases containsObject:database.uuid];
    [result setWithDatabase:database autoFill:YES wormholeUnlocked:wormholeDetectedUnlocked];
    
    return result;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self bindSelectedButton];
}

- (void)bindSelectedButton {
    NSUInteger row = self.tableView.selectedRowIndexes.firstIndex;
    self.buttonSelect.enabled = (row != NSNotFound);
}

@end
