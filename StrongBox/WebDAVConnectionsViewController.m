//
//  WebDAVConnectionsViewController.m
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "WebDAVConnectionsViewController.h"
#import "UITableView+EmptyDataSet.h"
#import "FontManager.h"
#import "WebDAVConnections.h"
#import "WebDAVConfigurationViewController.h"
#import "Alerts.h"
#import "DatabasePreferences.h"
#import "NSArray+Extensions.h"

#ifndef NO_NETWORKING
#import "WebDAVStorageProvider.h"
#endif

@interface WebDAVConnectionsViewController ()

@property NSArray<WebDAVSessionConfiguration*> *collection;

@end

@implementation WebDAVConnectionsViewController

+ (instancetype)instantiateFromStoryboard {
    UINavigationController* nav  = [[UIStoryboard storyboardWithName:@"WebDAVConnections" bundle:nil] instantiateInitialViewController];
    
    return (WebDAVConnectionsViewController*)nav.topViewController;
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
    self.collection = WebDAVConnections.sharedInstance.snapshot;
    [self.tableView reloadData];
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"cellIdentifierWebDavConnection" forIndexPath:indexPath];
    
    WebDAVSessionConfiguration* connection = self.collection[indexPath.row];
    
    cell.textLabel.text = connection.name;
    cell.imageView.image = [UIImage imageNamed:@"C03_Server"];
    
    if ( self.selectMode && self.initialSelected && [connection.identifier isEqualToString:self.initialSelected] ) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    if ( connection.password == nil ) {
        cell.detailTextLabel.text = NSLocalizedString(@"password_missing", @"Password missing.");
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
    
    WebDAVSessionConfiguration* connection = self.collection[indexPath.row];

    if ( self.selectMode ) {
        if ( connection.password == nil ) {
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

- (IBAction)onAdd:(id)sender {
    [self editConnection:nil];
}

- (void)editConnection:(WebDAVSessionConfiguration*)existing {
    WebDAVConfigurationViewController *vc = [[WebDAVConfigurationViewController alloc] init];
    vc.initialConfiguration = existing;
    
    vc.onDone = ^(BOOL success, WebDAVSessionConfiguration * _Nullable configuration) {
        [self dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [WebDAVConnections.sharedInstance addOrUpdate:configuration];
                [self refresh];
            }
        }];
    };

    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    WebDAVSessionConfiguration* connection = self.collection[indexPath.row];

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

- (void)deleteConnection:(WebDAVSessionConfiguration*)connection {
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"mac_are_you_sure_delete_yes_no_fmt", @"Are you sure you want to delete '%@'?"), connection.name];
    
    [Alerts areYouSure:self
               message:fmt
                action:^(BOOL response) {
        if ( response ) {
            [WebDAVConnections.sharedInstance deleteConnection:connection.identifier];
            [connection clearKeychainItems];
            [self refresh];
        }
    }];
}

- (void)duplicateConnection:(WebDAVSessionConfiguration*)connection {
    WebDAVSessionConfiguration* dupe = [[WebDAVSessionConfiguration alloc] init];
    
    NSString* newTitle = [connection.name stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")];
    
    dupe.name = newTitle;
    dupe.host = connection.host;
    dupe.username = connection.username;
    dupe.password = connection.password;
    dupe.allowUntrustedCertificate = connection.allowUntrustedCertificate;
    
    [WebDAVConnections.sharedInstance addOrUpdate:dupe];
    [self refresh];
}

- (NSArray<DatabasePreferences*>*)getDatabasesUsingConnection:(WebDAVSessionConfiguration*)connection {
    NSArray<DatabasePreferences*>* possibles = [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return obj.storageProvider == kWebDAV;
    }];
    
    NSArray<DatabasePreferences*>* using = [possibles filter:^BOOL(DatabasePreferences * _Nonnull obj) {
#ifndef NO_NETWORKING
        WebDAVSessionConfiguration* config = [WebDAVStorageProvider.sharedInstance getConnectionFromDatabase:obj];
        return ( config && [config.identifier isEqualToString:connection.identifier] );
#else
        return NO;
#endif
    }];
    
    return using;
}

- (NSString*)getUsedByString:(WebDAVSessionConfiguration*)connection {
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
