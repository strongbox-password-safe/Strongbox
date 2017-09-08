//
//  SelectDestinationGroupController.m
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectDestinationGroupController.h"
#import "Alerts.h"

@implementation SelectDestinationGroupController {
    NSArray<Node*> *_items;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.toolbar.hidden = NO;
    self.navigationController.navigationBar.hidden = NO;

    [self refresh];
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)refresh {
    _items = [self.currentGroup filterChildren:NO predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }];

    self.buttonMove.enabled = [self moveOfItemsIsValid:self.currentGroup subgroupsValid:NO];
    
    [self.tableView reloadData];
}

- (BOOL)moveOfItemsIsValid:(Node*)group subgroupsValid:(BOOL)subgroupsValid  {
    BOOL ret = YES;
    for(Node* itemToMove in self.itemsToMove) {
        if(![itemToMove validateChangeParent:group]) {
            ret = NO;
            break;
        }
    }
    
    if(ret) {
        return YES;
    }
    else if(subgroupsValid) {
        NSArray<Node*> *subgroups = [group filterChildren:NO predicate:^BOOL(Node * _Nonnull node) {
            return group.isGroup;
        }];
        
        for(Node* subgroup in subgroups) {
            if([self moveOfItemsIsValid:subgroup subgroupsValid:YES]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (IBAction)onCancel:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{  }];
}

- (IBAction)onMoveHere:(id)sender {
    for(Node* itemToMove in self.itemsToMove) {
        [itemToMove changeParent:self.currentGroup];
    }

    [self.viewModel update:^(NSError *error) {
        if (error) {
            [Alerts error:self title:@"Error Saving" error:error];
        }

        [self.navigationController dismissViewControllerAnimated:YES completion:^{  }];
    }];
}

- (IBAction)onAddGroup:(id)sender {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Group Name"
                            title:@"Enter Group Name"
                          message:@"Please Enter the New Group Name"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if(![self.viewModel addNewGroup:self.currentGroup title:text]) {
                                   [Alerts warn:self title:@"Could not create group" message:@"Could not create group with that title here."];
                               }
                               else {
                                   [self refresh];
                               }
                           }}];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Check to see whether the normal table or search results table is being displayed and set the Candy object from the appropriate array

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];

    Node* vm = _items[indexPath.row];

    cell.textLabel.text = vm.title;

    BOOL validMove = [self moveOfItemsIsValid:vm subgroupsValid:YES];

    cell.accessoryType = validMove ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = validMove ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = validMove;
    cell.contentView.alpha = validMove ? 1.0f : 0.5f;

    cell.imageView.image = [UIImage imageNamed:@"folder-80.png"];

    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueRecurse"]) {
        Node *item = _items[self.tableView.indexPathForSelectedRow.row];

        SelectDestinationGroupController *vc = segue.destinationViewController;

        vc.currentGroup = item;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = self.itemsToMove;
    }
}

@end
