//
//  SelectAutoFillDatabaseViewController.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SelectDatabaseViewController.h"
#import "CustomBackgroundTableView.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"
#import "Settings.h"

//static NSString* const kDatabaseCellView = @"DatabaseCellView";

@interface SelectDatabaseViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (nonatomic, strong) NSArray<MacDatabasePreferences*>* databases;
@property (weak) IBOutlet NSButton *buttonSelect;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@property BOOL viewWillAppearFirstTimeDone;
@property BOOL firstAppearanceDone;
@end

@implementation SelectDatabaseViewController

+ (instancetype)fromStoryboard {
    return [[SelectDatabaseViewController alloc] initWithNibName:@"SelectAutoFillDatabaseViewController" bundle:nil];
}

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
        
        self.tableView.doubleAction = @selector(onDoubleClick:);
        
        if ( self.customTitle != nil ) {
            self.textFieldTitle.stringValue = self.customTitle;
        }
        
        [self refresh];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    if ( !self.firstAppearanceDone ) {
        self.firstAppearanceDone = YES;
        self.view.window.frameAutosaveName = @"SelectAutoFillDatabase-AutoSave";
        
        NSUInteger count = [self.databases filter:^BOOL(MacDatabasePreferences * _Nonnull obj) {
            return obj.autoFillEnabled;
        }].count;
        
        if ( self.autoFillMode && count == 1 ) {
            slog(@"Single Database Launching...");
            
            MacDatabasePreferences* database = self.databases.firstObject;
            
            __weak SelectDatabaseViewController* weakSelf = self;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf dismissAndComplete:NO database:database];
            });
        }
    }
}

- (void)refresh {
    self.databases = MacDatabasePreferences.allDatabases;
    
    [self.tableView reloadData];
    
    if ( self.autoFillMode ) {
        NSUInteger idx = [self.databases indexOfFirstMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
            return obj.autoFillEnabled;
        }];
        
        if ( idx != NSNotFound ) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
        }
    }
    
    [self bindSelectedButton];
}

- (IBAction)onCancel:(id)sender {
    [self dismissAndComplete:YES database:nil];
}

- (void)onDoubleClick:(id)sender {
    [self openDatabaseAtRow:self.tableView.clickedRow];
}

- (IBAction)onSelect:(id)sender {
    [self openDatabaseAtRow:self.tableView.selectedRow];
}

- (void)openDatabaseAtRow:(NSUInteger)row {
    if (row != NSNotFound) {
        MacDatabasePreferences* database = self.databases[row];
        
        if ( [self isDisabled:database] ) {
            slog(@"🔴 Database is disabled! Cannot select");
            return;
        }
        
        [self dismissAndComplete:NO database:database];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databases.count;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    MacDatabasePreferences* database = [self.databases objectAtIndex:row];

    DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];
    
    BOOL wormholeDetectedUnlocked = [self.unlockedDatabases containsObject:database.uuid];
    BOOL disabled = [self isDisabled:database];
    
    [result setWithDatabase:database
   nickNameEditClickEnabled:NO
              showSyncState:NO
   indicateAutoFillDisabled:self.autoFillMode
           wormholeUnlocked:wormholeDetectedUnlocked
                   disabled:disabled];
    
    return result;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    MacDatabasePreferences* database = [self.databases objectAtIndex:row];

    if ( [self isDisabled:database] ) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isDisabled:(MacDatabasePreferences*)database {
    BOOL isReadOnly = database.readOnly;
    if (self.disableReadOnlyDatabases && isReadOnly) {
        return YES;
    }
    
    BOOL disabled = ( ( self.disabledDatabases && [self.disabledDatabases containsObject:database.uuid] ) || ( self.autoFillMode && !database.autoFillEnabled ) );
    
    return disabled;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self bindSelectedButton];
}

- (void)bindSelectedButton {
    NSUInteger row = self.tableView.selectedRowIndexes.firstIndex;

    if ( row == NSNotFound ){
        self.buttonSelect.enabled = NO;
        return;
    }
    
    MacDatabasePreferences* database = [self.databases objectAtIndex:row];

    self.buttonSelect.enabled = ![self isDisabled:database];
}

- (void)dismissAndComplete:(BOOL)userCancelled database:(MacDatabasePreferences*)database {
    if ( self.presentingViewController ) {
        [self.presentingViewController dismissViewController:self];
    }
    else if ( self.view.window.sheetParent ) {
        [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.view.window close];
    }
    
    self.onDone(userCancelled, database);
}

@end
