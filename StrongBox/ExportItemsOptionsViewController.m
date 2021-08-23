//
//  ExportOptionsViewController.m
//  Strongbox
//
//  Created by Strongbox on 29/07/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ExportItemsOptionsViewController.h"
#import "NSArray+Extensions.h"
#import "AppPreferences.h"
#import "Alerts.h"

@interface ExportItemsOptionsViewController ()

@property (weak, nonatomic) IBOutlet UILabel *summary;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReplaceExisting;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPreserveUUIDs;
@property (weak, nonatomic) IBOutlet UISwitch *switchReplaceExisting;
@property (weak, nonatomic) IBOutlet UISwitch *switchPreserveUUIDs;

@property (weak, nonatomic) IBOutlet UISwitch *switchPreserveTimestamps;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPreserveTimestamp;

@end

@implementation ExportItemsOptionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (IBAction)onTogglePreserveTimestamps:(id)sender {
    AppPreferences.sharedInstance.exportItemsPreserveTimestamps = !AppPreferences.sharedInstance.exportItemsPreserveTimestamps;
    
    [self bindUI];
}

- (IBAction)onToggleReplaceExistingItems:(id)sender {
    AppPreferences.sharedInstance.exportItemsReplaceExisting = !AppPreferences.sharedInstance.exportItemsReplaceExisting;
    
    [self bindUI];
}

- (IBAction)onTogglePreserveUUIDs:(id)sender {
    AppPreferences.sharedInstance.exportItemsPreserveUUIDs = !AppPreferences.sharedInstance.exportItemsPreserveUUIDs;
    
    [self bindUI];
}

- (void)bindUI {
    self.switchPreserveUUIDs.on = AppPreferences.sharedInstance.exportItemsPreserveUUIDs;
    self.switchReplaceExisting.on = AppPreferences.sharedInstance.exportItemsReplaceExisting;
    self.switchPreserveTimestamps.on = AppPreferences.sharedInstance.exportItemsPreserveTimestamps;
    
    [self cell:self.cellReplaceExisting setHidden:self.itemsIntersection.anyObject == nil];
    [self cell:self.cellPreserveUUIDs setHidden:self.itemsIntersection.anyObject != nil];
    
    BOOL showPreserveTimestamps;
    if ( self.itemsIntersection.anyObject ) {
        showPreserveTimestamps = !AppPreferences.sharedInstance.exportItemsReplaceExisting;
    }
    else {
        showPreserveTimestamps = !AppPreferences.sharedInstance.exportItemsPreserveUUIDs;
    }
    
    [self cell:self.cellPreserveTimestamp setHidden:!showPreserveTimestamps];
        
    if ( self.itemsIntersection.anyObject && AppPreferences.sharedInstance.exportItemsReplaceExisting ) {
        if ( self.items.count == 1 ) {
            self.summary.text = [NSString stringWithFormat:NSLocalizedString(@"export_options_1_replaced_fmt", @"1 item will be replaced in destination database '%@'."), self.destinationModel.metadata.nickName];
        }
        else {
            if ( self.itemsIntersection.count == 1 ) {
                self.summary.text = [NSString stringWithFormat:NSLocalizedString(@"export_options_n_items_1_replaced_fmt", @"%@ items will be exported with 1 item being replaced in destination database '%@'."), @(self.items.count), self.destinationModel.metadata.nickName];
            }
            else {
                self.summary.text = [NSString stringWithFormat:NSLocalizedString(@"export_options_n_items_n_replaced_fmt", @"%@ items will be exported with %@ items being replaced in destination database '%@'."), @(self.items.count), @(self.itemsIntersection.count), self.destinationModel.metadata.nickName];
            }
        }
    }
    else {
        if ( self.items.count == 1 ) {
            self.summary.text = [NSString stringWithFormat:NSLocalizedString(@"export_options_1_added_fmt", @"1 item will be added to destination database '%@'."), self.destinationModel.metadata.nickName];
        }
        else {
            self.summary.text = [NSString stringWithFormat:NSLocalizedString(@"export_options_n_added_fmt", @"%@ items will be added to destination database '%@'."), @(self.items.count), self.destinationModel.metadata.nickName];
        }
    }
    
    [self reloadDataAnimated:YES];
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onExport:(id)sender {









    
    BOOL makeBrandNewCopies;

    if ( self.itemsIntersection.anyObject ) {
        makeBrandNewCopies = !AppPreferences.sharedInstance.exportItemsReplaceExisting;
        
        if ( !makeBrandNewCopies ) {
            [Alerts areYouSure:self
                       message:NSLocalizedString(@"export_are_you_sure_replace", @"Are you sure you want to replace the existing matching item(s) in the destination database?")
                        action:^(BOOL response) {
                if ( response ) {
                    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                        self.completion(makeBrandNewCopies, YES);
                    }];
                }
            }];
        }
        else {
            [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                self.completion(YES, AppPreferences.sharedInstance.exportItemsPreserveTimestamps);
            }];
        }
    }
    else {
        makeBrandNewCopies = !AppPreferences.sharedInstance.exportItemsPreserveUUIDs;
        BOOL preserveTimestamps = !makeBrandNewCopies && AppPreferences.sharedInstance.exportItemsPreserveTimestamps;
        
        [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
            self.completion(makeBrandNewCopies, preserveTimestamps);
        }];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ( section == 2 && self.itemsIntersection.anyObject && !AppPreferences.sharedInstance.exportItemsReplaceExisting) {
        return @"";
    }
    
    return [super tableView:self.tableView titleForFooterInSection:section];
}

@end
