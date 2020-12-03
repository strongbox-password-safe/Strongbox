//
//  SelectDestinationGroupController.m
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SelectDestinationGroupController.h"
#import "Alerts.h"
#import "Utils.h"
#import "BrowseTableViewCellHelper.h"

@interface SelectDestinationGroupController ()

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem * buttonMove;
@property NSArray<Node*> *items;
@property BrowseTableViewCellHelper* cellHelper;

@end

@implementation SelectDestinationGroupController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.toolbar.hidden = NO;
    self.navigationController.toolbarHidden = NO;
    self.navigationController.navigationBar.hidden = NO;

    [self refresh];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = [UIView new];
    
    self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.viewModel tableView:self.tableView];
}


- (void)refresh {
    self.items = [self.currentGroup filterChildren:NO predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }];

    self.buttonMove.enabled = [self moveOfItemsIsValid:self.currentGroup subgroupsValid:NO];
    
    [self.tableView reloadData];
}

- (BOOL)moveOfItemsIsValid:(Node*)group subgroupsValid:(BOOL)subgroupsValid  {
    BOOL ret = [self.viewModel.database validateMoveItems:self.itemsToMove destination:group];

    if(ret) {
        return YES;
    }
    
    if(subgroupsValid) {
        for(Node* subgroup in group.childGroups) {
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
    BOOL ret = [self.viewModel.database moveItems:self.itemsToMove destination:self.currentGroup];
    
    if (!ret) {
        NSLog(@"Error Moving");
        NSError* error = [Utils createNSError:NSLocalizedString(@"moveentry_vc_error_moving", @"Error Moving") errorCode:-1];
        self.onDone(NO, NO, error);
        return;
    }

    
    
    [self.viewModel update:self handler:^(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{ 
            [self dismissViewControllerAnimated:YES completion:^{
                self.onDone(userCancelled, conflictAndLocalWasChanged, error);
            }];
        });
    }];
}

- (IBAction)onAddGroup:(id)sender {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:NSLocalizedString(@"moveentry_vc_add_group_prompt_placeholder", @"Group Name")
                            title:NSLocalizedString(@"moveentry_vc_add_group_prompt_title", @"Enter Group Name")
                          message:NSLocalizedString(@"moveentry_vc_add_group_prompt_message", @"Please Enter the New Group Name")
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if(![self.viewModel addNewGroup:self.currentGroup title:text]) {
                                   [Alerts warn:self
                                          title:NSLocalizedString(@"moveentry_vc_warn_creating_group_title", @"Could not create group")
                                        message:NSLocalizedString(@"moveentry_vc_warn_creating_group_message", @"Could not create group with that title here.")];
                               }
                               else {
                                   [self refresh];
                               }
                           }}];
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* vm = self.items[indexPath.row];
    BOOL validMove = [self moveOfItemsIsValid:vm subgroupsValid:YES];

    UITableViewCell* cell = [self.cellHelper getBrowseCellForNode:vm
                                                        indexPath:indexPath
                                                showLargeTotpCell:NO
                                                showGroupLocation:NO
                                            groupLocationOverride:nil
                                                    accessoryType:validMove ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone          noFlags:YES
                                              showGroupChildCount:NO];

    cell.selectionStyle = validMove ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = validMove;
    cell.contentView.alpha = validMove ? 1.0f : 0.5f;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* vm = self.items[indexPath.row];

    [self performSegueWithIdentifier:@"segueRecurse" sender:vm];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueRecurse"]) {
        Node *item = (Node*)sender;

        SelectDestinationGroupController *vc = segue.destinationViewController;

        vc.currentGroup = item;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = self.itemsToMove;
        vc.onDone = self.onDone;
    }
}

@end
