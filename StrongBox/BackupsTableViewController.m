//
//  BackupsTableViewController.m
//  Strongbox
//
//  Created by Mark on 27/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BackupsTableViewController.h"
#import "BackupsManager.h"
#import "DatabasePreferences.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "BackupsBrowserTableViewController.h"
#import "Alerts.h"

@interface BackupsTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchMakeBackups;
@property (weak, nonatomic) IBOutlet UILabel *labelMaxKeepCount;
@property (weak, nonatomic) IBOutlet UILabel *currentCount;
@property (weak, nonatomic) IBOutlet UITableViewCell *currentBackupsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *maxKeepCountCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *deleteAllBackupsCell;

@end

@implementation BackupsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUi];
}

- (IBAction)onSettingChanged:(id)sender {
    self.metadata.makeBackups = self.switchMakeBackups.on;
            
    [self bindUi];
}

- (void)bindUi {
    NSArray *backups = [BackupsManager.sharedInstance getAvailableBackups:self.metadata all:NO];
    
    self.currentCount.text = @(backups.count).stringValue;
    self.labelMaxKeepCount.text = @(self.metadata.maxBackupKeepCount).stringValue;
    self.switchMakeBackups.on = self.metadata.makeBackups;
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.currentBackupsCell) {
        [self performSegueWithIdentifier:@"segueToBackupsBrowser" sender:self.metadata];
    }
    else if (cell == self.maxKeepCountCell) {
        [self promptForInteger:NSLocalizedString(@"backups_vc_set_max_keep_count_title", @"Set Maximum Backup Keep Count")
                       options:@[@(1), @(2), @(3), @(4), @(5), @(10), @(15), @(20), @(30), @(40), @(50), @(75), @(100), @(200)]
                  currentValue:self.metadata.maxBackupKeepCount
                    completion:^(BOOL success, NSInteger selectedValue) {
            if(success) {
                self.metadata.maxBackupKeepCount = selectedValue;
                [self bindUi];
            }
        }];
    }
    else if (cell == self.deleteAllBackupsCell) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"backups_vc_delete_all_backups_prompt_message", @"Are you sure you want to delete all backups?")
               action:^(BOOL response) {
            if (response) {
                [BackupsManager.sharedInstance deleteAllBackups:self.metadata];
                [self bindUi];
            }
        }];
    }
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return obj.stringValue;
    }];
    
    vc.groupItems = @[items];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        NSInteger selectedValue = options[set.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToBackupsBrowser"]) {
        BackupsBrowserTableViewController *bb = (BackupsBrowserTableViewController*)segue.destinationViewController;
        bb.metadata = self.metadata;
    }
}

@end
