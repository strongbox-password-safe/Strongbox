//
//  VersionConflictController.m
//  Strongbox
//
//  Created by Mark on 25/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "VersionConflictController.h"
#import "Utils.h"

@interface VersionConflictController ()

@property NSMutableArray<NSFileVersion*> *versions;

@end

@implementation VersionConflictController

NSDateFormatter* _dateFormatter;

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController.toolbar setHidden:YES];
    self.navigationController.toolbarHidden = YES;
    
    NSMutableArray * fileVersions = [NSMutableArray array];
    
    NSURL* theUrl = [NSURL URLWithString:self.url];
    NSFileVersion * currentVersion = [NSFileVersion currentVersionOfItemAtURL:theUrl];
    [fileVersions addObject:currentVersion];
    
    NSArray * otherVersions = [NSFileVersion otherVersionsOfItemAtURL:theUrl];
    [fileVersions addObjectsFromArray:otherVersions];
    
    for (NSFileVersion * fileVersion in fileVersions) {
        [self.versions addObject:fileVersion];
    }
    
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    
    self.versions = [NSMutableArray array];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.versions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"versionCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    
    
    
    NSFileVersion * fileVersion = [self.versions objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [NSString stringWithFormat:@"Modified on %@", fileVersion.localizedNameOfSavingComputer];
    
    cell.detailTextLabel.text = [_dateFormatter stringFromDate:fileVersion.modificationDate];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSFileVersion *version = [self.versions objectAtIndex:indexPath.row];
    
    NSURL* fileURL = [NSURL URLWithString:self.url];
    
    if (![version isEqual:[NSFileVersion currentVersionOfItemAtURL:fileURL]]) {
        [version replaceItemAtURL:fileURL options:0 error:nil];
    }
    
    [NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:nil];
    NSArray* conflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
    
    for (NSFileVersion* fileVersion in conflictVersions) {
        fileVersion.resolved = YES;
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
