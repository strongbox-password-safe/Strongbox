//
//  SelectDestinationGroupController.m
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectDestinationGroupController.h"
#import "core-model/SafeItemViewModel.h"
#import "UIAlertView+Blocks.h"
#import "Model.h"
#import "MBProgressHUD.h"

@interface SelectDestinationGroupController ()

@end

@implementation SelectDestinationGroupController
{
    NSArray* _items;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.navigationBar.hidden = NO;
    
    [self refresh];
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)refresh
{
    _items = [self.viewModel getSubgroupsForGroup:self.currentGroup];
    
    self.buttonMove.enabled = [self.viewModel validateMoveItems:self.itemsToMove destination:self.currentGroup];
    
    [self.tableView reloadData];
}

- (IBAction)onCancel:(id)sender {
    [[self navigationController] dismissViewControllerAnimated:YES completion:^{  }];
}

- (IBAction)onMoveHere:(id)sender
{
    [self.viewModel moveItems:self.itemsToMove destination:self.currentGroup];
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];

    [self.viewModel update:self completionHandler:^(NSError *error) {
        if (error) {
            [UIAlertView showWithTitle:@"Error Saving" message:@"An error occured while trying to save changes to this safe." cancelButtonTitle:@"OK" otherButtonTitles:nil
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { }];
        }
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        [self.navigationController dismissViewControllerAnimated:YES completion:^{  }];
    }];
}

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
                 [self refresh];
             }
         }
     }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SafeItemViewModel* vm;
    
    // Check to see whether the normal table or search results table is being displayed and set the Candy object from the appropriate array
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
    vm = [_items objectAtIndex:indexPath.row];
    
    cell.textLabel.text = vm.title;
    
    [self.viewModel getSubgroupsForGroup:vm.group];
    BOOL validMove = [self.viewModel validateMoveItems:self.itemsToMove destination:vm.group checkIfMoveIntoSubgroupOfDestinationOk:YES];
    
    cell.accessoryType = validMove ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = validMove ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = validMove;
    cell.contentView.alpha = validMove ? 1.0f : 0.5f;
    
    cell.imageView.image = [UIImage imageNamed:@"folder-80.png"];
    
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
     if([[segue identifier] isEqualToString:@"segueRecurse"])
     {
         SafeItemViewModel *item = [_items objectAtIndex:[[[self tableView] indexPathForSelectedRow] row]];
         
         SelectDestinationGroupController *vc = [segue destinationViewController];
         
         vc.currentGroup = item.group;
         vc.viewModel = self.viewModel;
         vc.itemsToMove = self.itemsToMove;
     }
}


@end
