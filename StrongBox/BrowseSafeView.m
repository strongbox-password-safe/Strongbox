//
//  OpenSafeView.m
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "BrowseSafeView.h"
#import "SafeTools.h"
#import "SelectDestinationGroupController.h"
#import <MessageUI/MessageUI.h>
#import "RecordView.h"
#import "Alerts.h"
#import <ISMessages/ISMessages.h>
#import "Settings.h"
#import "SafeDetailsView.h"

@interface BrowseSafeView () <MFMailComposeViewControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UIBarButtonItem *savedOriginalNavButton;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation BrowseSafeView

static NSComparator searchResultsComparator = ^(id obj1, id obj2) {
    Node* n1 = (Node*)obj1;
    Node* n2 = (Node*)obj2;
    
    if(n1.isGroup && !n2.isGroup) {
        return NSOrderedDescending;
    }
    else if(!n1.isGroup && n2.isGroup) {
        return NSOrderedAscending;
    }
    
    NSComparisonResult result = [n1.title compare:n2.title options:NSCaseInsensitiveSearch];
    
    if(result == NSOrderedSame) {
        return [n1.title compare:n2.title];
    }
    
    return result;
};

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = NO;

    [self refresh];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                initWithTarget:self
                                action:@selector(handleLongPress:)];
    self.longPressRecognizer.minimumPressDuration = 1;
    self.longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:self.longPressRecognizer];
    
    if (!self.currentGroup || self.currentGroup.parent == nil) {
        [ISMessages showCardAlertWithTitle:@"Fast Password Copy"
                                   message:@"Tap and hold entry for fast password copy"
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
    
    self.navigationController.toolbar.hidden = NO;
}

// BUGBUG: TODO: Apple iOS 11 Bug:
// https://www.raywenderlich.com/157864/uisearchcontroller-tutorial-getting-started
// https://openradar.appspot.com/radar?id=4941731439050752

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.searchController.active) {
        return 44; // with scope
    } else {
        return 0; // no scope
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
                       Node *item = [[self getDataSource] objectAtIndex:indexPath.row];
                       
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
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeSettings"]);
}

- (NSArray<Node *> *)getDataSource {
    return (self.searchController.isActive ? self.searchResults : self.items);
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    
    [self filterContentForSearchText:searchString scope:searchController.searchBar.selectedScopeButtonIndex];
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText scope:(NSInteger)scope {
    NSPredicate *predicate;
    
    if (scope == 0) {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    else if (scope == 1)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.username contains[c] %@", searchText];
    }
    else if (scope == 2)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.password contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ OR fields.password contains[c] %@  OR fields.username contains[c] %@  OR fields.url contains[c] %@  OR fields.notes contains[c] %@", searchText, searchText, searchText, searchText, searchText];
    }
    
    NSArray<Node*> *foo = [self.viewModel.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return [predicate evaluateWithObject:node];
    }];
    
    self.searchResults = [foo sortedArrayUsingComparator:searchResultsComparator];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
    Node *vm = [self getDataSource][indexPath.row];
    
    NSString *groupLocation = (self.searchController.isActive ? [self getGroupPathDisplayString:vm] : vm.isGroup ? @"" : vm.fields.username);
    
    cell.textLabel.text = vm.isGroup ? vm.title :
        (self.searchController.isActive ? [NSString stringWithFormat:@"%@ [%@]", vm.title, vm.fields.username] :
         vm.title);
    
    cell.detailTextLabel.text = groupLocation;
    cell.accessoryType = vm.isGroup ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.imageView.image = vm.isGroup ? [UIImage imageNamed:@"folder-80.png"] : [UIImage imageNamed:@"lock-48.png"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.editing) {
        Node *item = [self getDataSource][indexPath.row];
        
        if (!item.isGroup) {
            [self performSegueWithIdentifier:@"segueToRecord" sender:item];
        }
        else {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item];
        }
    }
    else {
        [self enableDisableToolbarButtons];
    }
}

- (void)enableDisableToolbarButtons {
    BOOL ro = self.viewModel.isUsingOfflineCache || self.viewModel.isReadOnly;
    
    (self.buttonAddRecord).enabled = !ro && !self.isEditing;
    (self.buttonSafeSettings).enabled = !self.isEditing;
    (self.buttonMove).enabled = !ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0;
    (self.buttonAddGroup).enabled = !ro && !self.isEditing;
}

- (void)refresh {
    self.navigationItem.title = [NSString stringWithFormat:@"%@%@%@",
                                 (self.currentGroup.parent == nil) ?
                                 self.viewModel.metadata.nickName : self.currentGroup.title,
                                 self.viewModel.isUsingOfflineCache ? @" [Offline]" : @"",
                                 self.viewModel.isReadOnly ? @" [Read Only]" : @""];
    
    self.items = [[NSMutableArray alloc] initWithArray:self.currentGroup.children];
    
    // Display
    
    [self updateSearchResultsForSearchController:self.searchController];
    
    [self.tableView reloadData];
    
    self.navigationItem.rightBarButtonItem = (!self.viewModel.isUsingOfflineCache &&
                                              !self.viewModel.isReadOnly &&
                                              [self getDataSource].count > 0) ? self.editButtonItem : nil;
    
    [self enableDisableToolbarButtons];
    
    self.navigationController.toolbar.hidden = NO;
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSArray<NSString*> *hierarchy = [vm getTitleHierarchy];
    
    NSString *path = [[hierarchy subarrayWithRange:NSMakeRange(0, hierarchy.count - 1)] componentsJoinedByString:@"/"];
    
    return hierarchy.count == 1 ? @"(in /)" : [NSString stringWithFormat:@"(in /%@)", path];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToRecord"]) {
        Node *record = (Node *)sender;
        RecordView *vc = segue.destinationViewController;
        vc.record = record;
        vc.parentGroup = self.currentGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"sequeToSubgroup"])
    {
        BrowseSafeView *vc = segue.destinationViewController;
        
        vc.currentGroup = (Node *)sender;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectDestination"])
    {
        NSArray *itemsToMove = (NSArray *)sender;
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = nav.viewControllers.firstObject;
        
        vc.currentGroup = self.viewModel.rootGroup;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = itemsToMove;
    }
    else if ([segue.identifier isEqualToString:@"segueToSafeSettings"])
    {
        SafeDetailsView *vc = segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onAddGroup:(id)sender {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Group Name"
                            title:@"Enter Group Name"
                          message:@"Please Enter the New Group Name:"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if ([self.viewModel addNewGroup:self.currentGroup title:text] != nil) {
                                   [self saveChangesToSafeAndRefreshView];
                               }
                               else {
                                   [Alerts warn:self title:@"Cannot create group" message:@"Could not create a group with this name here, possibly because one with this name already exists."];
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
        NSArray<Node *> *itemsToMove = [self getSelectedItems:selectedRows];
        
        [self performSegueWithIdentifier:@"segueToSelectDestination" sender:itemsToMove];
        
        [self setEditing:NO animated:YES];
    }
}

- (NSArray<Node*> *)getSelectedItems:(NSArray<NSIndexPath *> *)selectedRows {
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
    
    Node *item = [self getDataSource][indexPath.row];
    
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

- (void)copyPasswordOnLongPress:(Node *)item withTapLocation:(CGPoint)tapLocation {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = item.fields.password;
    
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
