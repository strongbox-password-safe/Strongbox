//
//  StatisticsPropertiesViewController.m
//  Strongbox
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "StatisticsPropertiesViewController.h"

@interface StatisticsPropertiesViewController ()

@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfGroups;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfRecords;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniqueUsernames;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniquePasswords;
@property (weak, nonatomic) IBOutlet UILabel * labelMostPopularUsername;

@end

@implementation StatisticsPropertiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.labelMostPopularUsername.text = self.viewModel.database.mostPopularUsername ? self.viewModel.database.mostPopularUsername : NSLocalizedString(@"db_management_statistics_none", @"<None>");
    self.labelNumberOfUniqueUsernames.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.usernameSet count]];
    self.labelNumberOfUniquePasswords.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.viewModel.database.passwordSet count]];
    self.labelNumberOfGroups.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfGroups];
    self.labelNumberOfRecords.text =  [NSString stringWithFormat:@"%lu", (unsigned long)self.viewModel.database.numberOfRecords];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if(indexPath.section == 1) {
        BasicOrderedDictionary<NSString*, NSString*> *metadataKvps = [self.viewModel.database.metadata kvpForUi];

        if(indexPath.row < metadataKvps.allKeys.count) // Hide extra metadata pairs beyond actual metadata
        {
            NSString* key = [metadataKvps.allKeys objectAtIndex:indexPath.row];
            cell.textLabel.text = key;
            cell.detailTextLabel.text = [metadataKvps objectForKey:key];
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BasicOrderedDictionary<NSString*, NSString*> *metadataKvps = [self.viewModel.database.metadata kvpForUi];
    if(indexPath.section == 1 && indexPath.row >= metadataKvps.allKeys.count) // Hide extra metadata pairs beyond actual metadata
    {
        return 0;
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

@end
