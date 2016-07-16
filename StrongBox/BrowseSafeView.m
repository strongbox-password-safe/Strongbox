//
//  OpenSafeView.m
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "BrowseSafeView.h"
#import "core-model/SafeDatabase.h"
#import "core-model/SafeTools.h"
#import "core-model/Record.h"
#import "core-model/Field.h"
#import "RecordViewController.h"
#import "SafeDetailsAndSettingsView.h"
#import "MBProgressHUD.h"
#import "core-model/SafeItemViewModel.h"
#import "UIAlertView+Blocks.h"
#import "SelectDestinationGroupController.h"
#import <MessageUI/MessageUI.h>

@interface BrowseSafeView () <MFMailComposeViewControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate>
@end

@implementation BrowseSafeView
{
    NSMutableArray* _items;
    NSMutableArray *_titleSearchResults;
    NSMutableArray *_deepSearchResults;

    UIBarButtonItem *savedOriginalNavButton;
    UILongPressGestureRecognizer *longPressRecognizer;
    BOOL searchResultsTableViewIsVisible;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                           initWithTarget:self
                           action:@selector(handleLongPress:)];
    longPressRecognizer.minimumPressDuration = 1.5;
    longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    if(!self.currentGroup || self.currentGroup.isRootGroup)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
        
        // Configure for text only and offset down
        
        hud.mode = MBProgressHUDModeText;
        hud.labelText = @"Fast Password Copy";
        hud.detailsLabelText = @"Touch and hold entry for fast password copy";
        hud.yOffset += 100;
        hud.margin = 10.0f;
        hud.removeFromSuperViewOnHide = YES;
        hud.userInteractionEnabled = NO;
        
        [hud hide:YES afterDelay:3];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.navigationBar.hidden = NO;
    
    [self refresh];
}

- (void)enableDisableToolbarButtons
{
    [self.buttonAddRecord setEnabled:!self.viewModel.isUsingOfflineCache && !self.isEditing];
    [self.buttonSafeSettings setEnabled:!self.viewModel.isUsingOfflineCache && !self.isEditing];
    [self.buttonDelete setEnabled:!self.viewModel.isUsingOfflineCache && self.isEditing];
    [self.buttonMove setEnabled:!self.viewModel.isUsingOfflineCache && self.isEditing];
    [self.buttonAddGroup setEnabled:!self.viewModel.isUsingOfflineCache && !self.isEditing];
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)refresh
{
    self.navigationItem.title = [NSString stringWithFormat:@"%@%@",
                                 (!self.currentGroup || self.currentGroup.isRootGroup) ?
                                    self.viewModel.metadata.nickName : self.currentGroup.suffixDisplayString,
                                 self.viewModel.isUsingOfflineCache ?
                                    @" [Offline]" : @""];
    
    NSArray* foo = [self.viewModel getItemsForGroup:self.currentGroup];
    _items = [[NSMutableArray alloc] initWithArray:foo];
    
    // Display
    
    [self.tableView reloadData];
    
    self.navigationItem.rightBarButtonItem = (!self.viewModel.isUsingOfflineCache && _items.count > 0) ? self.editButtonItem : nil;

    [self enableDisableToolbarButtons];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Display and normal select logic

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return (tableView == self.searchDisplayController.searchResultsTableView) ? (section == 0 ? @"Title Matches" : @"Deep Search Matches") : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (tableView == self.searchDisplayController.searchResultsTableView) ? 2 : 1;

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        return section == 0 ? [_titleSearchResults count] : [_deepSearchResults count];
    }
    else
    {
        return [_items count];
    }
}

- (NSString *)getGroupPathDisplayString:(SafeItemViewModel *)vm
{
    return [vm.groupPathPrefix isEqualToString:@""] ? @"" : [NSString stringWithFormat:@"(in %@)", vm.groupPathPrefix];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    SafeItemViewModel* vm;
    
    // Check to see whether the normal table or search results table is being displayed and set the Candy object from the appropriate array
    
    BOOL isSearchResults = tableView == self.searchDisplayController.searchResultsTableView;
    if (isSearchResults)
    {
        static NSString *CellIdentifier = @"Cell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if ( cell == nil ) {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        NSUInteger section = [indexPath section];
       
        if(section == 0)
        {
            vm = [_titleSearchResults objectAtIndex:indexPath.row];
        }
        else if(section == 1)
        {
            vm = [_deepSearchResults objectAtIndex:indexPath.row];
        }
        
        [cell detailTextLabel].textColor =( vm.isGroup ? [UIColor blackColor] : [UIColor blueColor]);
    }
    else
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
        vm = [_items objectAtIndex:indexPath.row];
    }
    
    cell.textLabel.text = vm.title;
    cell.detailTextLabel.text = vm.isGroup ?
                (isSearchResults ? [self getGroupPathDisplayString: vm] : @"") :
             vm.username;

    cell.accessoryType = vm.isGroup ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.imageView.image = vm.isGroup ? [UIImage imageNamed:@"folder-80.png"] : [UIImage imageNamed:@"lock-48.png"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(![self isEditing])
    {
        SafeItemViewModel* item;
        if (tableView == self.searchDisplayController.searchResultsTableView)
        {
            if([indexPath section] == 0)
            {
                item = [_titleSearchResults objectAtIndex:indexPath.row];
            }
            else
            {
                item = [_deepSearchResults objectAtIndex:indexPath.row];
            }
           }
        else
        {
            item = [_items objectAtIndex:indexPath.row];
        }
        
        
        if(!item.isGroup)
        {
            [self performSegueWithIdentifier:@"segueToRecordView" sender:item.record];
        }
        else
        {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item.group];
        }
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return (sender == self || [identifier isEqualToString:@"segueToSafeDetailsView"]);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"segueToRecordView"])
    {
        Record* record = (Record*)sender;
        
        RecordViewController *vc = [segue destinationViewController];
        vc.record = record;
        vc.currentGroup = self.currentGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([[segue identifier] isEqualToString:@"sequeToSubgroup"])
    {
        Group *selectedGroup = (Group*)sender;
        
        BrowseSafeView *vc = [segue destinationViewController];
        
        vc.currentGroup = selectedGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([[segue identifier] isEqualToString:@"segueToSelectDestination"])
    {
        NSArray *itemsToMove = (NSArray*)sender;
        
        UINavigationController *nav = [segue destinationViewController];
        SelectDestinationGroupController *vc = [[nav viewControllers] firstObject];
        
        vc.currentGroup = nil;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = itemsToMove;
    }
    else if ([[segue identifier] isEqualToString:@"segueToSafeDetailsView"])
    {
        SafeDetailsAndSettingsView *vc = [segue destinationViewController];
        vc.viewModel = self.viewModel;
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onAddGroup:(id)sender
{
    [UIAlertView showWithTitle:@"Enter Group Name" message:@"Please Enter the New Group Name:" style:UIAlertViewStylePlainTextInput cancelButtonTitle:@"Cancel" otherButtonTitles:@[@"Ok"]
       tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
       {
          if (buttonIndex == 1)
          {
              UITextField *groupTextField = [alertView textFieldAtIndex:0];
              
              // TODO: What happens if we have a duplicate or it already exists
              
              if([self.viewModel.safe addSubgroupWithUIString:self.currentGroup title:groupTextField.text] != nil)
              {
                  [self saveChangesToSafeAndRefreshView];
              }
          }
       }];
}

- (IBAction)onAddRecord:(id)sender
{
    [self performSegueWithIdentifier:@"segueToRecordView" sender:nil];
}

- (IBAction)onMove:(id)sender
{
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if(selectedRows.count > 0)
    {
        // We need to segue the root view and ask for selection of destination
        
        NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
        for (NSIndexPath *selectionIndex in selectedRows)
        {
            [indicesOfItems addIndex:selectionIndex.row];
        }

        NSArray *itemsToMove = [_items objectsAtIndexes:indicesOfItems];
        
        [self performSegueWithIdentifier:@"segueToSelectDestination" sender:itemsToMove];
        
        [self setEditing:NO animated:YES]; 
    }
}

- (IBAction)onDelete:(id)sender
{
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    
    if(selectedRows.count > 0)
    {
        NSString* message = [NSString stringWithFormat:@"Would you like to delete %@", selectedRows.count > 1 ? @"these Items?" : @"this Item"];
        
        [UIAlertView showWithTitle:@"Are you sure?" message:message cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if(buttonIndex == 1)
            {
            NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
            for (NSIndexPath *selectionIndex in selectedRows)
            {
                [indicesOfItems addIndex:selectionIndex.row];
            }
            
            NSArray *itemsToDelete = [_items objectsAtIndexes:indicesOfItems];
            
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            [self.viewModel deleteItems:itemsToDelete];
            
            [self.viewModel update:self completionHandler:^(NSError *error) {
                if (error) {
                    [UIAlertView showWithTitle:@"Error Saving" message:@"An error occured while trying to save changes to this safe." cancelButtonTitle:@"OK" otherButtonTitles:nil
                                      tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { }];
                }
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            }];
            
            [self setEditing:NO animated:YES];
            
            [self refresh];
            }
        }];
    }
}

-(void)saveChangesToSafeAndRefreshView
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    [self.viewModel update:self completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            
            if(error != nil)
            {
                NSLog(@"%@", error);
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Problem Saving"  message:@"There was a problem saving the safe." delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles: nil  ];
                [alertView show];
            }
            
            [self refresh];
        });
    }];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    
    [self enableDisableToolbarButtons];
    
    if(!editing)
    {
        self.navigationItem.leftBarButtonItem = savedOriginalNavButton;
    }
    else
    {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self
                                                                                      action:@selector(cancelEditing)];
        
        savedOriginalNavButton = self.navigationItem.leftBarButtonItem;
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
}

-(void)cancelEditing
{
    [self setEditing:false];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Search

-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    [_titleSearchResults removeAllObjects];
    
    // Filter the array using NSPredicate
    
    NSArray* allItems = [self.viewModel getSearchableItems];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    
    _titleSearchResults = [NSMutableArray arrayWithArray:[allItems filteredArrayUsingPredicate:predicate]];
    
    NSPredicate *deepPredicate = [NSPredicate predicateWithFormat:@"isGroup == NO AND (password contains[c] %@  OR username contains[c] %@  OR url contains[c] %@  OR notes contains[c] %@) AND NOT (title contains %@)" , searchText, searchText, searchText, searchText, searchText];
    
    _deepSearchResults = [NSMutableArray arrayWithArray:[allItems filteredArrayUsingPredicate:deepPredicate]];
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    // Tells the table data source to reload when scope bar selection changes
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

-(void)searchDisplayController:(UISearchDisplayController *)controller didShowSearchResultsTableView:(UITableView *)tableView
{
    searchResultsTableViewIsVisible = YES;
}

-(void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView
{
    searchResultsTableViewIsVisible = NO;
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Long Press

- (void)handleLongPress:(UILongPressGestureRecognizer*)sender
{
    if (sender.state != UIGestureRecognizerStateBegan)
    {
        return;
    }
    
    SafeItemViewModel *item;
    CGPoint tapLocation;
    
    if(searchResultsTableViewIsVisible)
    {
        NSLog(@"Long Press on Search Results...");
        
        tapLocation = [longPressRecognizer locationInView:self.searchDisplayController.searchResultsTableView];
        NSIndexPath *indexPath = [self.searchDisplayController.searchResultsTableView indexPathForRowAtPoint:tapLocation];
        
        if(!indexPath)
        {
            NSLog(@"Not on a cell");
            return;
        }
        
        if(indexPath.section == 0) // Title
        {
            if ([indexPath row] < [_titleSearchResults count])
            {
                item = [_titleSearchResults objectAtIndex:[indexPath row]];
            }
            else
            {
                NSLog(@"Not on a cell");
                return;
            }
        }
        else // Deep Search
        {
            if ([indexPath row] < [_deepSearchResults count])
            {
                item = [_deepSearchResults objectAtIndex:[indexPath row]];
            }
            else
            {
                NSLog(@"Not on a cell");
            }
        }
    }
    else
    {
        tapLocation = [longPressRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:tapLocation];
        
        if (indexPath && [indexPath row] < [_items count])
        {
            item = [_items objectAtIndex:[indexPath row]];
        }
        else
        {
            NSLog(@"Not on a cell");
            return;
        }
    }
    
    if(item.isGroup)
    {
        NSLog(@"Item is group, cannot Fast PW Copy...");
        return;
    }
    
    NSLog(@"Fast Password Copy on %@", item.title);
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    BOOL promptedForCopyPw = [userDefaults boolForKey:@"promptedForCopyPasswordGesture"];
    BOOL copyPw = [userDefaults boolForKey:@"copyPasswordOnLongPress"];
    
    NSLog(@"Long press detected on Record. Copy Featured is [%@]", copyPw ? @"Enabled" : @"Disabled");
    
    if(!copyPw && !promptedForCopyPw) // If feature is turned off (or never set) and we haven't prompted user about it... prompt
    {
        [UIAlertView     showWithTitle:@"Copy Password?"
                            message:@"By Touching and Holding an entry for 2 seconds you can quickly copy the password to the clipboard. Would you like to enable this feature?" cancelButtonTitle:@"No" otherButtonTitles:@[@"Yes"]
        tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex)
        {
            if (buttonIndex == 1)
            {
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                
                [userDefaults setBool:YES forKey:@"copyPasswordOnLongPress"];
                [self copyPasswordOnLongPress:item withTapLocation:tapLocation];
            }
            else
            {
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                
                [userDefaults setBool:NO forKey:@"copyPasswordOnLongPress"];
            }
        }];
        
        [userDefaults setBool:YES forKey:@"promptedForCopyPasswordGesture"];
    }
    else if(copyPw)
    {
        [self copyPasswordOnLongPress: item withTapLocation:tapLocation];
    }
}

-(void)copyPasswordOnLongPress:(SafeItemViewModel*)item withTapLocation:(CGPoint)tapLocation
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = item.password;
    
    NSLog(@"Password copied");
        
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    // Configure for text only and offset down
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Password Copied";
    hud.margin = 10.0f;
    hud.yOffset = -self.tableView.frame.size.height / 2 + tapLocation.y - 30; // Slightly above users touch
    hud.removeFromSuperViewOnHide = YES;
    hud.userInteractionEnabled = NO;
    
    [hud hide:YES afterDelay:3];
}

- (void)showMessage:(NSString*)message rect:(CGRect)rect {
    UILabel* label = [[UILabel alloc] initWithFrame:rect];
    label.backgroundColor = [UIColor whiteColor];
    label.font = [UIFont fontWithName:@"Helvetica-Bold" size:24];  // Or whatever.
    label.text = message;
    label.textColor = [UIColor blueColor];  // Or whatever.
    label.textAlignment = NSTextAlignmentCenter;
    
    UITableView *theTableView = searchResultsTableViewIsVisible ? self.searchDisplayController.searchResultsTableView : self.tableView;
    
    [theTableView addSubview:label];
    
    [UIView animateWithDuration:2.0 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         label.alpha=0.2f;
                     } completion:^(BOOL finished){
                         label.alpha=1.0f;
                         label.hidden = YES;
                         [label removeFromSuperview];
                     }];
}

@end
