//
//  SelectAutoFillDatabaseViewController.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SelectAutoFillDatabaseViewController.h"
#import "CustomBackgroundTableView.h"
#import "DatabasesManager.h"
#import "DatabaseCellView.h"
#import "NSArray+Extensions.h"

static NSString* const kDatabaseCellView = @"DatabaseCellView";

@interface SelectAutoFillDatabaseViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (nonatomic, strong) NSArray<DatabaseMetadata*>* databases;
@property (weak) IBOutlet NSButton *buttonSelect;

@end

@implementation SelectAutoFillDatabaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.headerView = nil;
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kDatabaseCellView bundle:nil]
                  forIdentifier:kDatabaseCellView];

    self.tableView.emptyString = NSLocalizedString(@"mac_no_autofill_enabled_databases_initial_message", @"No AutoFill Enabled Databases");
    
    self.tableView.doubleAction = @selector(onSelect:);
    
    [self refresh];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    self.view.window.frameAutosaveName = @"SelectAutoFillDatabase-AutoSave";
}

- (void)refresh {
    self.databases = [DatabasesManager.sharedInstance.snapshot filter:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return obj.autoFillEnabled;
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
        DatabaseMetadata* database = self.databases[row];
        
        [self dismissViewController:self];
        
        self.onDone(NO, database);
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.databases.count;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    DatabaseMetadata* database = [self.databases objectAtIndex:row];

    DatabaseCellView *result = [tableView makeViewWithIdentifier:kDatabaseCellView owner:self];
    [result setWithDatabase:database autoFill:YES];
    
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
