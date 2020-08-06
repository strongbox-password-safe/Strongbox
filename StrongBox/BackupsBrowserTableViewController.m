//
//  BackupsBrowserTableViewController.m
//  Strongbox
//
//  Created by Mark on 27/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BackupsBrowserTableViewController.h"
#import "BackupsManager.h"
#import "Utils.h"
#import "Alerts.h"
#import "ExportOptionsTableViewController.h"
#import "LocalDeviceStorageProvider.h"

@interface BackupsBrowserTableViewController ()

@property NSArray<BackupItem*>* items;

@end

@implementation BackupsBrowserTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = UIView.new;

    [self internalRefresh];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self internalRefresh];
    });
}

- (void)internalRefresh {
    self.items = [BackupsManager.sharedInstance getAvailableBackups:self.metadata];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"backupItemCell" forIndexPath:indexPath];
    
    BackupItem* item = self.items[indexPath.row];
    
    cell.textLabel.text = friendlyDateString(item.date);
    cell.detailTextLabel.text = friendlyFileSizeString(item.fileSize.unsignedIntegerValue);
    
    return cell;
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    BackupItem* item = self.items[indexPath.row];
    
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"generic_remove", @"Remove")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"backup_vc_are_you_sure_remove", @"Are you sure you want to remove this backup?")
               action:^(BOOL response) {
            if(response) {
                [BackupsManager.sharedInstance deleteBackup:item];
                [self refresh];
            }
        }];
    }];

    UITableViewRowAction *exportAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"generic_export", @"Export")
                                                                           handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self performSegueWithIdentifier:@"segueToExport" sender:item];
    }];
    
    exportAction.backgroundColor = [UIColor systemBlueColor];

    UITableViewRowAction *addLocalAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"backups_add_local", @"Add as Local Database")
                                                                           handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self createAsLocalDatabase:item];
    }];
    
    addLocalAction.backgroundColor = [UIColor systemTealColor];

    // Other Options
    
    return @[removeAction, exportAction, addLocalAction];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToExport"]) {
        ExportOptionsTableViewController *vc = (ExportOptionsTableViewController *)segue.destinationViewController;
    
        BackupItem* item = sender;
           
        NSError* error;
        NSData* data = [NSData dataWithContentsOfURL:item.url options:kNilOptions error:&error];
        if (!data) {
            [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
            return;
        }
        
        vc.backupMode = YES;
        vc.encrypted = data;
        vc.metadata = self.metadata;
        vc.backupItem = item;
        vc.viewModel = nil;
    }
}

- (void)createAsLocalDatabase:(BackupItem*)item {
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:item.url options:kNilOptions error:&error];
    if (!data) {
        [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
        return;
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:item.url.path error:&error];
    if (!attr || error) {
        [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
        return;
    }
    
    NSDate* modDate = attr.fileModificationDate;
    
    NSString* nickName = [NSString stringWithFormat:@"Restored Backup of %@", self.metadata.nickName];
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                              modDate:modDate
                                    suggestedFilename:nickName
                                           completion:^(SafeMetaData * _Nonnull metadata, NSError * _Nonnull error) {
        if(error || !metadata) {
            NSError* error;
            NSData* data = [NSData dataWithContentsOfURL:item.url options:kNilOptions error:&error];
            if (!data) {
                [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
                return;
            }

        }
        
        [SafesList.sharedInstance addWithDuplicateCheck:metadata initialCache:data initialCacheModDate:modDate];

        [Alerts info:self
               title:NSLocalizedString(@"generic_done", @"Done")
             message:NSLocalizedString(@"backup_vc_backup_added_to_databases", @"This backup has been added to your databases")
          completion:^{
            [self.navigationController popToRootViewControllerAnimated:YES];
        }];
    }];
}

@end
