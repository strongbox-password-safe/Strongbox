//
//  SFTPConnectionsManager.m
//  MacBox
//
//  Created by Strongbox on 05/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SFTPConnectionsManager.h"
#import "SFTPConnections.h"
#import "MacDatabasePreferences.h"
#import "NSArray+Extensions.h"
#import "SFTPStorageProvider.h"
#import "MacAlerts.h"
#import "SFTPConfigurationVC.h"
#import "ConnectionCellView.h"
#import "CustomBackgroundTableView.h"

static NSString* const kConnectionCellView = @"ConnectionCellView";

@interface SFTPConnectionsManager () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property BOOL hasLoaded;
@property (weak) IBOutlet NSTableView *tableView;
@property NSArray<SFTPSessionConfiguration*>* collection;
@property (weak) IBOutlet NSButton *buttonRemove;
@property (weak) IBOutlet NSButton *buttonDuplicate;
@property (weak) IBOutlet NSButton *buttonEdit;
@property (weak) IBOutlet NSButton *buttonSelect;

@end

@implementation SFTPConnectionsManager

+ (instancetype)instantiateFromStoryboard {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"SFTPConnectionsManager" bundle:nil];
    SFTPConnectionsManager* ret = [storyboard instantiateInitialController];
    return ret;
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

    self.tableView.headerView = nil;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onDoubleClick:);

    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kConnectionCellView bundle:nil]
                  forIdentifier:kConnectionCellView];
        


    if ( self.manageMode ) {
        [self.buttonSelect setTitle:NSLocalizedString(@"generic_done", @"Done")];
    }
    
    [self refresh];
    
    if ( self.collection.count ) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (void)cancel:(id)sender { 
    [self onDismiss:nil];
}

- (IBAction)onDismiss:(id)sender {
    if ( self.presentingViewController ) {
        [self.presentingViewController dismissViewController:self];
    }
    else {
        [self.view.window close];
    }
}

- (void)refresh {
    self.collection = SFTPConnections.sharedInstance.snapshot;
    [self.tableView reloadData];
    
    [self bindUi];
}

- (void)onDoubleClick:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if(row == -1) {
        return;
    }
    
    [self selectConnection:row];
}

- (IBAction)onSelect:(id)sender {
    if ( self.manageMode ) {
        [self onDismiss:nil];
    }
    else {
        NSInteger row = self.tableView.selectedRow;
        if(row == -1) {
            return;
        }
        
        [self selectConnection:self.tableView.selectedRow];
    }
}

- (void)selectConnection:(NSUInteger)row {
    if ( !self.manageMode ){
        [self onDismiss:nil];
        
        SFTPSessionConfiguration* connection = self.collection[row];
        self.onSelected(connection);
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.collection.count;
}

- (id)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    SFTPSessionConfiguration* connection = self.collection[row];
    
    ConnectionCellView* ret = [self.tableView makeViewWithIdentifier:kConnectionCellView owner:nil];
    
    ret.textFieldName.stringValue = connection.name;
    ret.textFieldHost.stringValue = connection.host;
    ret.textFieldUsedBy.stringValue = [self getUsedByString:connection];
    ret.textFieldUser.stringValue = connection.username;

    return ret;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (NSArray<MacDatabasePreferences*>*)getDatabasesUsingConnection:(SFTPSessionConfiguration*)connection {
    NSArray<MacDatabasePreferences*>* possibles = [MacDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
        return database.storageProvider == kSFTP;
    }];
    
    NSArray<MacDatabasePreferences*>* using = [possibles filter:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        SFTPSessionConfiguration* config = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:obj];
        return ( config && [config.identifier isEqualToString:connection.identifier] );
    }];
    
    return using;
}

- (NSString*)getUsedByString:(SFTPSessionConfiguration*)connection {
    NSArray<MacDatabasePreferences*>* using = [self getDatabasesUsingConnection:connection];
    
    if ( using.count == 0 ) {
        return NSLocalizedString(@"not_used_by_any_databases", @"Not used by any databases.");
    }
    else if (using.count == 1 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"used_by_database_name_fmt", @"Used by '%@'"), using.firstObject.nickName];
    }
    else {
        return [NSString stringWithFormat:NSLocalizedString(@"used_by_database_name_and_n_more_fmt", @"Used by '%@' and %@ more"), using.firstObject.nickName, @(using.count - 1)];
    }
}

- (void)bindUi {
    SFTPSessionConfiguration* connection = nil;
    
    if ( self.tableView.selectedRow != -1 ) {
        connection = self.collection[self.tableView.selectedRow];
    }
    
    NSArray* using = [self getDatabasesUsingConnection:connection];

    self.buttonRemove.enabled = connection != nil && using.count == 0;
    self.buttonEdit.enabled = connection != nil;
    self.buttonDuplicate.enabled = connection != nil;
    self.buttonSelect.enabled = self.manageMode || connection != nil;
}

- (IBAction)onDuplicate:(id)sender {
    SFTPSessionConfiguration* connection = nil;
    
    if ( self.tableView.selectedRow != -1 ) {
        connection = self.collection[self.tableView.selectedRow];
    }
    else {
        return;
    }
    
    SFTPSessionConfiguration* dupe = [[SFTPSessionConfiguration alloc] init];
    
    NSString* newTitle = [connection.name stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")];
    dupe.name = newTitle;

    dupe.host = connection.host;
    dupe.username = connection.username;
    dupe.password = connection.password;
    dupe.authenticationMode = connection.authenticationMode;
    dupe.privateKey = connection.privateKey;
    dupe.initialDirectory = connection.initialDirectory;
    
    [SFTPConnections.sharedInstance addOrUpdate:dupe];
    [self refresh];
}

- (IBAction)onRemove:(id)sender {
    SFTPSessionConfiguration* connection = nil;
    
    if ( self.tableView.selectedRow != -1 ) {
        connection = self.collection[self.tableView.selectedRow];
    }
    else {
        return;
    }
    
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"mac_are_you_sure_delete_yes_no_fmt", @"Are you sure you want to delete '%@'?"), connection.name];
    
    [MacAlerts areYouSure:fmt
                   window:self.view.window
               completion:^(BOOL response) {
        if ( response ) {
            [SFTPConnections.sharedInstance deleteConnection:connection.identifier];
            [connection clearKeychainItems];
            [self refresh];
        }
    }];
}

- (IBAction)onAdd:(id)sender {
    [self editConnection:nil];
}

- (IBAction)onEdit:(id)sender {
    SFTPSessionConfiguration* connection = nil;
    
    if ( self.tableView.selectedRow != -1 ) {
        connection = self.collection[self.tableView.selectedRow];
    }
    else {
        return;
    }
    
    [self editConnection:connection];
}

- (void)editConnection:(SFTPSessionConfiguration*)existing {
    SFTPConfigurationVC* configVC = [SFTPConfigurationVC newConfigurationVC];

    configVC.initialConfiguration = existing;

    configVC.onDone = ^(BOOL success, SFTPSessionConfiguration * _Nonnull configuration) {
        if (success) {


            [SFTPConnections.sharedInstance addOrUpdate:configuration];
            [self refresh];
        }
    };

    [self presentViewControllerAsSheet:configVC];
}

@end
