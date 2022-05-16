//
//  DiffDrilldownTableViewController.m
//  Strongbox
//
//  Created by Strongbox on 15/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DiffDrilldownTableViewController.h"
#import "NSDate+Extensions.h"
#import "MutableOrderedDictionary.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "NSUUID+Zero.h"
#import "DiffDrillDownDetailer.h"

@interface DiffDrilldownTableViewController ()

@property MutableOrderedDictionary<NSString*, NSString*> *diffs;

@end

@implementation DiffDrilldownTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
 
    self.navigationItem.title = self.diffPair.a.title;
    
    [self initializeDiffs];
}

- (void)initializeDiffs {
    if (self.diffPair) {
        self.diffs = [DiffDrillDownDetailer initializePairWiseDiffs:self.firstDatabase.database
                                                    secondDatabase:self.secondDatabase.database
                                                            diffPair:self.diffPair
                                                        isMergeDiff:self.isMergeDiff];
        
    }
    else {
        self.diffs = [DiffDrillDownDetailer initializePropertiesDiff:self.firstDatabase.database secondDatabase:self.secondDatabase.database isMergeDiff:self.isMergeDiff];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.diffs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* title = self.diffs.allKeys[indexPath.row];
    NSString* subtitle = self.diffs[title];
    
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"diffDrillDownCellIdentifer" forIndexPath:indexPath];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = subtitle;
    
    return cell;
}

@end
