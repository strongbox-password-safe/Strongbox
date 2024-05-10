//
//  SFTPConnectionsViewControllerTableViewController.m
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SFTPConnectionsViewController.h"
#import "UITableView+EmptyDataSet.h"
#import "FontManager.h"
#import "SFTPConnections.h"
#import "SFTPSessionConfigurationViewController.h"
#import "Alerts.h"

#ifndef NO_NETWORKING
#import "SFTPStorageProvider.h"
#endif

#import "NSArray+Extensions.h"
#import "DatabasePreferences.h"

@interface SFTPConnectionsViewController ()

@property NSArray<SFTPSessionConfiguration*> *collection;

@end

@implementation SFTPConnectionsViewController

+ (instancetype)instantiateFromStoryboard {
    UINavigationController* nav  = [[UIStoryboard storyboardWithName:@"SFTPConnections" bundle:nil] instantiateInitialViewController];
    
    return (SFTPConnectionsViewController*)nav.topViewController;
}

- (void)presentFromViewController:(UIViewController *)viewController {
    [viewController presentViewController:self.navigationController animated:YES completion:nil];
}

- (NSAttributedString*)getEmptyDatasetTitle {
    NSString *text = NSLocalizedString(@"empty_connections_list_tableview_title", @"No Connections Yet");

    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString*)getEmptyDatasetDescription {
    NSString *text = NSLocalizedString(@"tap_plus_to_add_a_connection_hint", @"Tap '+' to add a connection.");

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: FontManager.sharedInstance.regularFont,
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
    
    if ( self.selectMode ) {
        self.navigationItem.title = NSLocalizedString(@"select_webdav_or_sftp_connection", @"Select Connection");
        self.navigationItem.prompt = NSLocalizedString(@"slide_left_for_options", @"Slide Left for Options");
    }
    
    [self refresh];
}

- (void)refresh {
    self.collection = SFTPConnections.sharedInstance.snapshot;
    [self.tableView reloadData];
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onAdd:(id)sender {
    [self editConnection:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.collection.count == 0) {
        [self.tableView setEmptyTitle:[self getEmptyDatasetTitle]
                          description:[self getEmptyDatasetDescription]];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }

    return self.collection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"cellIdentifierSftpConnection" forIndexPath:indexPath];
    
    SFTPSessionConfiguration* connection = self.collection[indexPath.row];
    
    cell.textLabel.text = connection.name;
    cell.imageView.image = [UIImage imageNamed:@"C03_Server"];

    if ( self.selectMode && self.initialSelected && [connection.identifier isEqualToString:self.initialSelected] ) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    if ( ( connection.authenticationMode == kPrivateKey && connection.privateKey == nil ) || ( connection.authenticationMode == kUsernamePassword && connection.password == nil ) ) {
        cell.detailTextLabel.text = NSLocalizedString(@"pk_or_password_missing", @"Private Key or Password missing."); 
        cell.detailTextLabel.textColor = UIColor.systemRedColor;
    }
    else {
        cell.detailTextLabel.text = [self getUsedByString:connection];
        cell.detailTextLabel.textColor = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SFTPSessionConfiguration* connection = self.collection[indexPath.row];
    
    if ( self.selectMode ) {
        if ( ( connection.authenticationMode == kPrivateKey && connection.privateKey == nil ) || ( connection.authenticationMode == kUsernamePassword && connection.password == nil ) ) {
            [self editConnection:connection];
        }
        else {
            [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if ( self.onSelected ) {
                    self.onSelected(connection);
                }
            }];
        }
    }
    else {
        [self editConnection:connection];
    }
}

- (void)editConnection:(SFTPSessionConfiguration*)existing {
    SFTPSessionConfigurationViewController *vc = [[SFTPSessionConfigurationViewController alloc] init];
    vc.initialConfiguration = existing;
    
    vc.onDone = ^(BOOL success, SFTPSessionConfiguration * _Nullable configuration) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [SFTPConnections.sharedInstance addOrUpdate:configuration];
                [self refresh];
            }
        }];
    };

    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    SFTPSessionConfiguration* connection = self.collection[indexPath.row];

    NSMutableArray<UITableViewRowAction*>* actions = NSMutableArray.array;

    NSArray* using = [self getDatabasesUsingConnection:connection];
    if ( using.count == 0 ) {
        UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                                title:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                                                              handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            [self deleteConnection:connection];
        }];
        
        [actions addObject:removeAction];
    }
    
    UITableViewRowAction *duplicateItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                                   title:NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate")
                                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self duplicateConnection:connection];
    }];
    duplicateItemAction.backgroundColor = UIColor.systemGreenColor;
    [actions addObject:duplicateItemAction];
    
    UITableViewRowAction *editItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                              title:NSLocalizedString(@"browse_prefs_tap_action_edit", "Edit Item")
                                                                            handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self editConnection:connection];
    }];
    editItemAction.backgroundColor = UIColor.systemBlueColor;

    if ( self.selectMode ) {
        [actions addObject:editItemAction];
    }
    
    return actions;
}

- (void)deleteConnection:(SFTPSessionConfiguration*)connection {
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"mac_are_you_sure_delete_yes_no_fmt", @"Are you sure you want to delete '%@'?"), connection.name];
    
    [Alerts areYouSure:self
               message:fmt
                action:^(BOOL response) {
        if ( response ) {
            [SFTPConnections.sharedInstance deleteConnection:connection.identifier];
            [connection clearKeychainItems];
            [self refresh];
        }
    }];
}

- (void)duplicateConnection:(SFTPSessionConfiguration*)connection {
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

- (NSArray<DatabasePreferences*>*)getDatabasesUsingConnection:(SFTPSessionConfiguration*)connection {
    NSArray<DatabasePreferences*>* possibles = [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return obj.storageProvider == kSFTP;
    }];
    
    NSArray<DatabasePreferences*>* using = [possibles filter:^BOOL(DatabasePreferences * _Nonnull obj) {
#ifndef NO_NETWORKING
        SFTPSessionConfiguration* config = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:obj];
        return ( config && [config.identifier isEqualToString:connection.identifier] );
#else
        return NO;
#endif
    }];
    
    return using;
}

- (NSString*)getUsedByString:(SFTPSessionConfiguration*)connection {
    NSArray<DatabasePreferences*>* using = [self getDatabasesUsingConnection:connection];
    
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

@end
