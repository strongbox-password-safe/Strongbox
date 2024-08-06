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
#import "AppPreferences.h"

@interface SelectDestinationGroupController ()

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem * buttonSelectThisDestination;
@property NSArray<Node*> *items;
@property BrowseTableViewCellHelper* cellHelper;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddGroup;

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
    
    self.navigationItem.title = NSLocalizedString(@"select_destination_group", @"Select Destination Group");
    self.navigationItem.prompt = [self.viewModel.database getPathDisplayString:self.currentGroup includeRootGroup:YES rootGroupNameInsteadOfSlash:YES includeFolderEmoji:YES joinedBy:@" "];
    
    self.tableView.tableFooterView = [UIView new];
    
    self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.viewModel tableView:self.tableView];
    
    if ( self.hideAddGroupButton ) {
        [self.buttonAddGroup setEnabled:NO];
        [self.buttonAddGroup setTintColor:[UIColor clearColor]];
    }
    
    if ( self.customSelectDestinationButtonTitle.length ) {
        [self.buttonSelectThisDestination setTitle:self.customSelectDestinationButtonTitle];
    }
}

- (IBAction)onCancel:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)refresh {
    BrowseSortConfiguration* sortConfig = [self.viewModel getDefaultSortConfiguration];
    
    self.items = [self.viewModel sortItemsForBrowse:self.currentGroup.childGroups
                                    browseSortField:sortConfig.field
                                         descending:sortConfig.descending
                                  foldersSeparately:sortConfig.foldersOnTop];
        
    self.buttonSelectThisDestination.enabled = [self isValidDestination:self.currentGroup validIfContainsAValidDestination:NO];
    
    [self.tableView reloadData];
}

- (BOOL)isValidDestination:(Node*)group validIfContainsAValidDestination:(BOOL)validIfContainsAValidDestination  {
    BOOL ret;
    if ( self.validateDestination ) {
        ret = self.validateDestination ( group );
    }
    else {
        slog(@"WARNWARN: No Validation block set...");
        ret = NO;
    }

    if ( ret ) {
        return YES;
    }

    if ( validIfContainsAValidDestination ) {
        for ( Node* subgroup in group.childGroups ) {
            if ( [self isValidDestination:subgroup validIfContainsAValidDestination:YES] ) {
                return YES;
            }
        }
    }

    return NO;
}

- (IBAction)onSelectThisGroupAsDestination:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        self.onSelectedDestination(self.currentGroup);
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



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* vm = self.items[indexPath.row];
    BOOL validDestination = [self isValidDestination:vm validIfContainsAValidDestination:YES];

    UITableViewCell* cell = [self.cellHelper getBrowseCellForNode:vm
                                                        indexPath:indexPath
                                                showLargeTotpCell:NO
                                                showGroupLocation:NO
                                            groupLocationOverride:nil
                                                    accessoryType:validDestination ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone
                                                          noFlags:YES
                                              showGroupChildCount:NO];

    cell.selectionStyle = validDestination ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = validDestination;
    cell.contentView.alpha = validDestination ? 1.0f : 0.5f;

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
        vc.validateDestination = self.validateDestination;
        vc.onSelectedDestination = self.onSelectedDestination;
        vc.hideAddGroupButton = self.hideAddGroupButton;
        vc.customSelectDestinationButtonTitle = self.customSelectDestinationButtonTitle;
    }
}

@end
