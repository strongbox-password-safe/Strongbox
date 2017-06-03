//
//  SelectDestinationGroupController.m
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectDestinationGroupController.h"
#import "SafeItemViewModel.h"
#import "Model.h"
#import "Alerts.h"

@implementation SelectDestinationGroupController {
    NSArray *_items;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.toolbar.hidden = NO;
    self.navigationController.navigationBar.hidden = NO;

    [self refresh];
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)refresh {
    _items = [self.viewModel getSubgroupsForGroup:self.currentGroup];

    self.buttonMove.enabled = [self.viewModel validateMoveItems:self.itemsToMove destination:self.currentGroup];

    [self.tableView reloadData];
}

- (IBAction)onCancel:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{  }];
}

- (IBAction)onMoveHere:(id)sender {
    [self.viewModel moveItems:self.itemsToMove destination:self.currentGroup];

    [self.viewModel update:^(NSError *error) {
                        if (error) {
                        [Alerts             error:self
                                title:@"Error Saving"
                                error:error];
                        }

                        [self.navigationController                 dismissViewControllerAnimated:YES
                                                                      completion:^{  }];
                    }];
}

- (IBAction)onAddGroup:(id)sender {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Group Name"
                            title:@"Enter Group Name"
                          message:@"Please Enter the New Group Name"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               [self.viewModel.safe addSubgroupWithUIString:self.currentGroup
                                                                  title:text];
                               [self refresh];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeItemViewModel *vm;

    // Check to see whether the normal table or search results table is being displayed and set the Candy object from the appropriate array

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];

    vm = _items[indexPath.row];

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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueRecurse"]) {
        SafeItemViewModel *item = _items[self.tableView.indexPathForSelectedRow.row];

        SelectDestinationGroupController *vc = segue.destinationViewController;

        vc.currentGroup = item.group;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = self.itemsToMove;
    }
}

@end
