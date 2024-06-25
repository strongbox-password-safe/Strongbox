//
//  BackupsBrowserTableViewController.m
//  Strongbox
//
//  Created by Mark on 27/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BackupsBrowserTableViewController.h"
#import "BackupsManager.h"
#import "Utils.h"
#import "Alerts.h"
#import "LocalDeviceStorageProvider.h"
#import "NSDate+Extensions.h"
#import "Serializator.h"
#import "DatabasePreferences.h"

@interface BackupsBrowserTableViewController ()

@property NSArray<BackupItem*>* items;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonShowAll;
@property BOOL showAll;

@end

@implementation BackupsBrowserTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = UIView.new;

    self.barButtonShowAll.enabled = self.metadata == nil;
    self.barButtonShowAll.tintColor = self.metadata == nil ? nil : UIColor.clearColor;
    
    [self internalRefresh];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self internalRefresh];
    });
}

- (void)internalRefresh {
    self.items = [BackupsManager.sharedInstance getAvailableBackups:self.metadata all:self.showAll];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"backupItemCell" forIndexPath:indexPath];
    
    BackupItem* item = self.items[indexPath.row];

    cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"backups_backup_modified_title_fmt", @"Modified %@"), item.modDate.friendlyDateTimeString];

    if ( !self.metadata ) {
        NSString* recoveredNickname = [self tryDetermineNickName:item];
        cell.textLabel.text = recoveredNickname;
    }
    
    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"backups_backup_taken_at_subtitle_fmt", @"%@ (Backup taken %@)"), friendlyFileSizeString(item.fileSize.unsignedIntegerValue), item.backupCreatedDate.friendlyDateTimeString];



    cell.imageView.image = [UIImage imageNamed:@"file"];
    
    return cell;
}

- (NSString*)tryDetermineNickName:(BackupItem*)item {
    NSArray *components = item.url.pathComponents;

    if ( components && components.count > 1 ) {
        NSString* secondLast = components[components.count - 2];
        
        
        DatabasePreferences* metadata = [DatabasePreferences fromUuid:secondLast];
        if ( metadata ) {
            return metadata.nickName;
        }
        else {
            return item.url.lastPathComponent;
        }
    }
    else {
        return @"Unknown";
    }
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

    UITableViewRowAction *addLocalAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"backups_add_local", @"Add as Local Database")
                                                                           handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self createAsLocalDatabase:item];
    }];
    
    addLocalAction.backgroundColor = [UIColor systemTealColor];

    
    
    return @[removeAction,
             
             addLocalAction];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
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
    
    NSString* origNickName = self.metadata ? self.metadata.nickName : [self tryDetermineNickName:item];
    NSString* nickName = [NSString stringWithFormat:@"Restored Backup of %@", origNickName];
    
    NSString* extension = [Serializator getLikelyFileExtension:data];
    
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                             fileName:[NSString stringWithFormat:@"%@.%@", origNickName, extension]
                                                 data:data
                                              modDate:modDate
                                           completion:^(DatabasePreferences * _Nonnull metadata, NSError * _Nonnull error) {
        if(error || !metadata) {
            [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
            return;
        }
        
        if ( ![metadata addWithDuplicateCheck:data initialCacheModDate:modDate error:&error] ) {
            [Alerts error:self error:error];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"generic_done", @"Done")
                 message:NSLocalizedString(@"backup_vc_backup_added_to_databases", @"This backup has been added to your databases")
              completion:^{
                [self.navigationController popToRootViewControllerAnimated:YES];
            }];
        }
    }];
}

- (IBAction)onButtonAll:(id)sender {
    
    


}

@end
