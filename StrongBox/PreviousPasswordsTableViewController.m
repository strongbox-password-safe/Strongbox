//
//  PreviousPasswordsTableViewController.m
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "PreviousPasswordsTableViewController.h"

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

    //NSLocale* currentLocale = [NSLocale currentLocale];
    //NSString *dateString = [entry.timestamp descriptionWithLocale:currentLocale];

//    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"beginDate" ascending:TRUE];
//    [myMutableArray sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
//    [sortDescriptor release];
//
    NSString *dateString = [_dateFormatter stringFromDate:entry.timestamp];

    cell.textLabel.text = entry.password;
    cell.detailTextLabel.text = dateString; //entry.password;

    return cell;
}

@end
