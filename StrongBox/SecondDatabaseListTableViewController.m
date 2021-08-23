//
//  SecondDatabaseListTableViewController.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SecondDatabaseListTableViewController.h"
#import "SafesList.h"
#import "DatabaseCell.h"

@interface SecondDatabaseListTableViewController ()

@property NSArray<SafeMetaData*> *list;

@end

@implementation SecondDatabaseListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.list = SafesList.sharedInstance.snapshot;

    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    self.tableView.tableFooterView = UIView.new;
    
    if ( self.customTitle.length ) {
        [self.navigationItem setTitle:self.customTitle];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];
    
    SafeMetaData* database = self.list[indexPath.row];
    
    BOOL isFirstDatabase = [database.uuid isEqualToString:self.firstDatabase.metadata.uuid];
    BOOL isReadOnly = database.readOnly;
    
    [cell populateCell:database disabled:isFirstDatabase || (self.disableReadOnlyDatabases && isReadOnly)];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SafeMetaData* database = self.list[indexPath.row];
    
    self.onSelectedDatabase(database, self);
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
