//
//  PreviousPasswordsTableViewController.m
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PreviousPasswordsTableViewController.h"
#import "ClipboardManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface PreviousPasswordsTableViewController ()

@end

@implementation PreviousPasswordsTableViewController {
    NSDateFormatter *_dateFormatter;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    _dateFormatter.locale = [NSLocale currentLocale];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.model.entries).count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PasswordHistoryEntryCell" forIndexPath:indexPath];

    PasswordHistoryEntry *entry = (self.model.entries)[indexPath.row];

    NSString *dateString = [_dateFormatter stringFromDate:entry.timestamp];

    cell.textLabel.text = entry.password;
    cell.detailTextLabel.text = dateString; 

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PasswordHistoryEntry *entry = (self.model.entries)[indexPath.row];

    if (entry.password.length) {
        [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:entry.password];
        
        NSString* message = NSLocalizedString(@"item_details_password_copied", @"Password Copied");
    
#ifndef IS_APP_EXTENSION
        [StrongboxToastMessages showSlimWithTitle:message];
#endif
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
