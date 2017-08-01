//
//  OpenSafeView.m
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "BrowseSafeView.h"
#import "SafeDatabase.h"
#import "SafeTools.h"
#import "Record.h"
#import "Field.h"
#import "SafeDetailsAndSettingsView.h"
#import "SafeItemViewModel.h"
#import "SelectDestinationGroupController.h"
#import <MessageUI/MessageUI.h>
#import "RecordView.h"
#import "Alerts.h"
#import <ISMessages/ISMessages.h>
#import "Settings.h"

@interface BrowseSafeView () <MFMailComposeViewControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSMutableArray *searchResults;
@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UIBarButtonItem *savedOriginalNavButton;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation BrowseSafeView

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = NO;
    
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                initWithTarget:self
                                action:@selector(handleLongPress:)];
    self.longPressRecognizer.minimumPressDuration = 1;
    self.longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:self.longPressRecognizer];
    
    if (!self.currentGroup || self.currentGroup.isRootGroup) {
        [ISMessages showCardAlertWithTitle:@"Fast Password Copy"
                                   message:@"Touch and hold entry for fast password copy"
                                  duration:2.5f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeInfo
                             alertPosition:ISAlertPositionBottom
                                   didHide:nil];
    }
   
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles = @[@"Title", @"Username", @"Password", @"All Fields"];
    
    if ([[Settings sharedInstance] isProOrFreeTrial]) {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        
        [self.searchController.searchBar sizeToFit];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return !self.viewModel.isUsingOfflineCache && !self.viewModel.isReadOnly;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [Alerts yesNo:self.searchController.isActive ? self.searchController : self
                title:@"Are you sure?"
              message:@"Are you sure you want to delete this item?"
               action:^(BOOL response) {
                   if (response) {
                       SafeItemViewModel *item = [[self getDataSource] objectAtIndex:indexPath.row];
                       
                       [self.viewModel deleteItem:item];
                       
                       [self.viewModel update:^(NSError *error) {
                           if (error) {
                               [Alerts             error:self
                                                   title:@"Error Saving"
                                                   error:error];
                           }
                       }];
                       
                       [self setEditing:NO animated:YES];
                       
                       [self refresh];
                   }
               }];
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeDetailsView"]);
}

- (NSArray<SafeItemViewModel *> *)getDataSource {
    return (self.searchController.isActive ? self.searchResults : self.items);
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    
    [self filterContentForSearchText:searchString scope:searchController.searchBar.selectedScopeButtonIndex];
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText scope:(NSInteger)scope {
    [self.searchResults removeAllObjects];
    
    NSArray *allItems = [self.viewModel getSearchableItems];
    
    NSPredicate *predicate;
    
    if (scope == 0) {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    else if (scope == 1)
    {
        predicate = [NSPredicate predicateWithFormat:@"username contains[c] %@", searchText];
    }
    else if (scope == 2)
    {
        predicate = [NSPredicate predicateWithFormat:@"password contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ OR password contains[c] %@  OR username contains[c] %@  OR url contains[c] %@  OR notes contains[c] %@", searchText, searchText, searchText, searchText, searchText];
    }
    
    self.searchResults = [NSMutableArray arrayWithArray:[allItems filteredArrayUsingPredicate:predicate]];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
    SafeItemViewModel *vm = [self getDataSource][indexPath.row];
    
    cell.textLabel.text = vm.title;
    cell.detailTextLabel.text = vm.isGroup ? (self.searchController.isActive ? [self getGroupPathDisplayString:vm] : @"") : vm.username;
    cell.accessoryType = vm.isGroup ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.imageView.image = vm.isGroup ? [UIImage imageNamed:@"folder-80.png"] : [UIImage imageNamed:@"lock-48.png"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.editing) {
        SafeItemViewModel *item = [self getDataSource][indexPath.row];
        
        if (!item.isGroup) {
            [self performSegueWithIdentifier:@"segueToRecord" sender:item.record];
        }
        else {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item.group];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refresh];
}

- (void)enableDisableToolbarButtons {
    BOOL ro = self.viewModel.isUsingOfflineCache || self.viewModel.isReadOnly;
    
    (self.buttonAddRecord).enabled = !ro && !self.isEditing;
    (self.buttonSafeSettings).enabled = !self.isEditing;
    (self.buttonMove).enabled = !ro && self.isEditing;      // Only move in edit mode
    (self.buttonAddGroup).enabled = !ro && !self.isEditing;
}

- (void)refresh {
    self.navigationItem.title = [NSString stringWithFormat:@"%@%@%@",
                                 (!self.currentGroup || self.currentGroup.isRootGroup) ?
                                 self.viewModel.metadata.nickName : self.currentGroup.suffixDisplayString,
                                 self.viewModel.isUsingOfflineCache ? @" [Offline]" : @"",
                                 self.viewModel.isReadOnly ? @" [Read Only]" : @""];
    
    NSArray *foo = [self.viewModel getItemsForGroup:self.currentGroup];
    self.items = [[NSMutableArray alloc] initWithArray:foo];
    
    // Display
    
    [self updateSearchResultsForSearchController:self.searchController];
    
    [self.tableView reloadData];
    
    self.navigationItem.rightBarButtonItem = (!self.viewModel.isUsingOfflineCache &&
                                              !self.viewModel.isReadOnly &&
                                              [self getDataSource].count > 0) ? self.editButtonItem : nil;
    
    [self enableDisableToolbarButtons];
}

- (NSString *)getGroupPathDisplayString:(SafeItemViewModel *)vm {
    return [vm.groupPathPrefix isEqualToString:@""] ? @"" : [NSString stringWithFormat:@"(in %@)", vm.groupPathPrefix];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToRecord"]) {
        Record *record = (Record *)sender;
        RecordView *vc = segue.destinationViewController;
        vc.record = record;
        vc.currentGroup = self.currentGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"sequeToSubgroup"])
    {
        Group *selectedGroup = (Group *)sender;
        
        BrowseSafeView *vc = segue.destinationViewController;
        
        vc.currentGroup = selectedGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectDestination"])
    {
        NSArray *itemsToMove = (NSArray *)sender;
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = nav.viewControllers.firstObject;
        
        vc.currentGroup = nil;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = itemsToMove;
    }
    else if ([segue.identifier isEqualToString:@"segueToSafeDetailsView"])
    {
        SafeDetailsAndSettingsView *vc = segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onAddGroup:(id)sender {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Group Name"
                            title:@"Enter Group Name"
                          message:@"Please Enter the New Group Name:"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if ([self.viewModel addSubgroupWithUIString:self.currentGroup
                                                                          title:text] != nil) {
                                   [self saveChangesToSafeAndRefreshView];
                               }
                           }
                       }];
}

- (IBAction)onAddRecord:(id)sender {
    [self performSegueWithIdentifier:@"segueToRecord" sender:nil];
}

- (IBAction)onMove:(id)sender {
    NSArray *selectedRows = (self.tableView).indexPathsForSelectedRows;
    
    if (selectedRows.count > 0) {
        NSArray<SafeItemViewModel *> *itemsToMove = [self getSelectedItems:selectedRows];
        
        [self performSegueWithIdentifier:@"segueToSelectDestination" sender:itemsToMove];
        
        [self setEditing:NO animated:YES];
    }
}

- (NSArray<SafeItemViewModel *> *)getSelectedItems:(NSArray<NSIndexPath *> *)selectedRows {
    NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
    
    for (NSIndexPath *selectionIndex in selectedRows) {
        [indicesOfItems addIndex:selectionIndex.row];
    }
    
    NSArray *items = [[self getDataSource] objectsAtIndexes:indicesOfItems];
    return items;
}

- (void)saveChangesToSafeAndRefreshView {
    [self.viewModel update:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error != nil) {
                [Alerts error:self title:@"Problem Saving" error:error];
            }
            
            [self refresh];
        });
    }];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
    [self enableDisableToolbarButtons];
    
    if (!editing) {
        self.navigationItem.leftBarButtonItem = self.savedOriginalNavButton;
    }
    else {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelEditing)];
        
        self.savedOriginalNavButton = self.navigationItem.leftBarButtonItem;
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
}

- (void)cancelEditing {
    [self setEditing:false];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Long Press

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint tapLocation = [self.longPressRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:tapLocation];
    
    if (!indexPath || indexPath.row >= [self getDataSource].count) {
        NSLog(@"Not on a cell");
        return;
    }
    
    SafeItemViewModel *item = [self getDataSource][indexPath.row];
    
    if (item.isGroup) {
        NSLog(@"Item is group, cannot Fast PW Copy...");
        return;
    }
    
    NSLog(@"Fast Password Copy on %@", item.title);
    
    BOOL promptedForCopyPw = [[Settings sharedInstance] isHasPromptedForCopyPasswordGesture];
    BOOL copyPw = [[Settings sharedInstance] isCopyPasswordOnLongPress];
    
    NSLog(@"Long press detected on Record. Copy Featured is [%@]", copyPw ? @"Enabled" : @"Disabled");
    
    if (!copyPw && !promptedForCopyPw) { // If feature is turned off (or never set) and we haven't prompted user about it... prompt
        [Alerts yesNo:self
                title:@"Copy Password?"
              message:@"By Touching and Holding an entry for 2 seconds you can quickly copy the password to the clipboard. Would you like to enable this feature?"
               action:^(BOOL response) {
                   [[Settings sharedInstance] setCopyPasswordOnLongPress:response];
                   
                   if (response) {
                       [self copyPasswordOnLongPress:item withTapLocation:tapLocation];
                   }
               }];
        
        [[Settings sharedInstance] setHasPromptedForCopyPasswordGesture:YES];
    }
    else if (copyPw)
    {
        [self copyPasswordOnLongPress:item withTapLocation:tapLocation];
    }
}

- (void)copyPasswordOnLongPress:(SafeItemViewModel *)item withTapLocation:(CGPoint)tapLocation {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = item.password;
    
    [ISMessages showCardAlertWithTitle:@"Password Copied"
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

@end
