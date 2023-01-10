//
//  SortOrderTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 11/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SortOrderTableViewController.h"

@interface SortOrderTableViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellCustom;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellTitle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUsername;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPassword;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUrl;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmail;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNotes;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCreation;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellModified;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAscending;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDescending;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellFolders;

@end

@implementation SortOrderTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    

    if(self.field == kBrowseSortFieldNone && self.format == kPasswordSafe) {
        self.field = kBrowseSortFieldTitle;
    }
    
    [self bindUi:NO];
}

- (void)bindUi:(BOOL)animated {
    self.cellCustom.accessoryType = self.field == kBrowseSortFieldNone ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellTitle.accessoryType = self.field == kBrowseSortFieldTitle ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellUsername.accessoryType = self.field == kBrowseSortFieldUsername ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellPassword.accessoryType = self.field == kBrowseSortFieldPassword ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellUrl.accessoryType = self.field == kBrowseSortFieldUrl ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellEmail.accessoryType = self.field == kBrowseSortFieldEmail ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellNotes.accessoryType = self.field == kBrowseSortFieldNotes ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellCreation.accessoryType = self.field == kBrowseSortFieldCreated ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellModified.accessoryType = self.field == kBrowseSortFieldModified ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellAscending.accessoryType = !self.descending ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellDescending.accessoryType = self.descending ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellFolders.accessoryType = self.foldersSeparately ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    [self cell:self.cellCustom setHidden:self.format == kPasswordSafe];
    
    [self cell:self.cellAscending setHidden:self.field == kBrowseSortFieldNone];
    [self cell:self.cellDescending setHidden:self.field == kBrowseSortFieldNone];
    
    
    [self reloadDataAnimated:animated];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellCustom) {
        self.field = kBrowseSortFieldNone;
    }
    else if(cell == self.cellTitle) {
        self.field = kBrowseSortFieldTitle;
    }
    else if(cell == self.cellUsername) {
        self.field = kBrowseSortFieldUsername;
    }
    else if(cell == self.cellPassword) {
        self.field = kBrowseSortFieldPassword;
    }
    else if(cell == self.cellUrl) {
        self.field = kBrowseSortFieldUrl;
    }
    else if(cell == self.cellEmail) {
        self.field = kBrowseSortFieldEmail;
    }
    else if(cell == self.cellNotes) {
        self.field = kBrowseSortFieldNotes;
    }
    else if(cell == self.cellCreation) {
        self.field = kBrowseSortFieldCreated;
    }
    else if(cell == self.cellModified) {
        self.field = kBrowseSortFieldModified;
    }
    else if(cell == self.cellAscending) {
        self.descending = NO;
    }
    else if(cell == self.cellDescending) {
        self.descending = YES;
    }
    else if(cell == self.cellFolders) {
        self.foldersSeparately = !self.foldersSeparately;
    }
    
    [self bindUi:YES];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    self.onChangedOrder(self.field, self.descending, self.foldersSeparately);
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end

