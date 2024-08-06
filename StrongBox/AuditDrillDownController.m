//
//  AuditDrillDownController.m
//  Strongbox
//
//  Created by Strongbox on 01/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AuditDrillDownController.h"
#import "NSArray+Extensions.h"
#import "BrowseTableViewCellHelper.h"
#import "ItemDetailsViewController.h"
#import "SwitchTableViewCell.h"
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "AuditConfigurationVcTableViewController.h"
#import "AppPreferences.h"
#import "DatabasePreferences.h"

const NSUInteger kSectionSettingsIdx = 0;
const NSUInteger kSectionBasicIdx = 1;
const NSUInteger kSectionDuplicatedIdx = 2;
const NSUInteger kSectionSimalarIdx = 3;
const NSUInteger kSectionActionsIdx = 4;
const NSUInteger kSectionsCount = kSectionActionsIdx + 1;

static NSString* const kSwitchTableCellId = @"SwitchTableCell";

@interface AuditDrillDownController ()

@property NSSet<NSNumber*>* flags;
@property NSArray<NSString*> *basicRows;
@property NSArray<Node*>* duplicates;
@property NSArray<Node*>* similars;
@property BrowseTableViewCellHelper* browseCellHelper;
@property NSArray<NSString*> *actions;

@end

@implementation AuditDrillDownController

+ (UINavigationController*)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"AuditDrillDown" bundle:nil];
    
    return [sb instantiateInitialViewController];
}

- (void)dealloc {
    slog(@"DEALLOC [%@]", self);
    [self unListenToNotifications];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView registerNib:[UINib nibWithNibName:kSwitchTableCellId bundle:nil] forCellReuseIdentifier:kSwitchTableCellId];

    self.browseCellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.model tableView:self.tableView];

    [self refreshItems];

    [self listenToNotifications];
}

- (void)refreshItems {
    
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshItemsDoIt) object:nil];
    [self performSelector:@selector(refreshItemsDoIt) withObject:nil afterDelay:0.1f];
}

- (void)refreshItemsDoIt {
    NSSet<Node*>* dupes = [self.model getDuplicatedPasswordNodeSet:self.itemId];
    NSMutableSet<Node*>* mute = dupes.mutableCopy;
         
    NSSet* sims = [self.model getSimilarPasswordNodeSet:self.itemId];
    NSMutableSet<Node*>* muteSims = sims.mutableCopy;
    
    self.flags = [self.model getQuickAuditFlagsForNode:self.itemId];
    self.basicRows = [self getBasicRows:self.flags];
    self.actions = ([self.flags containsObject:@(kAuditFlagPwned)] || !AppPreferences.sharedInstance.isPro || AppPreferences.sharedInstance.disableNetworkBasedFeatures) ? @[] : @[NSLocalizedString(@"audit_drill_down_action_check_hibp", @"Check HIBP for this Password...")];
    
    self.duplicates = [[mute.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return ![obj.uuid isEqual:self.itemId];
    }] sortedArrayUsingComparator:finderStyleNodeComparator];

    self.similars = [[muteSims.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return ![obj.uuid isEqual:self.itemId];
    }] sortedArrayUsingComparator:finderStyleNodeComparator];
       

    [self.tableView reloadData];
}

- (void)listenToNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshItems)
                                               name:kModelEditedNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshItems)
                                               name:kAuditNodesChangedNotificationKey
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshItems)
                                               name:kAuditCompletedNotification
                                             object:nil];

}

- (void)unListenToNotifications {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionsCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kSectionSettingsIdx) {
        return 2;
    }
    else if (section == kSectionBasicIdx) {
        return self.flags.count == 0 ? 1 : self.basicRows.count;
    }
    else if (section == kSectionDuplicatedIdx) {
        return self.duplicates.count;
    }
    else if (section == kSectionSimalarIdx) {
        return self.similars.count;
    }
    else if (section == kSectionActionsIdx) {
        return self.actions.count;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSectionSettingsIdx) {
        if (indexPath.row == 0) {
            SwitchTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kSwitchTableCellId];

            BOOL excluded = [self.model isExcludedFromAudit:self.itemId];
            
            [cell set:NSLocalizedString(@"audit_drill_down_audit_this_item_preference_title", @"Audit this Item") on:!excluded
             enabled:!self.model.isReadOnly
            onChanged:^(BOOL on) {
                [self onAuditOnOff:on];
            }];
            
            return cell;
        }
        else {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"auditDrillDownBasicCellId" forIndexPath:indexPath];
            cell.imageView.image = nil;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.text = NSLocalizedString(@"audit_drill_down_go_to_database_audit_preferences", @"Database Audit Settings");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
            return cell;
        }
    }
    else if (indexPath.section == kSectionBasicIdx) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"auditDrillDownBasicCellId" forIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.shield"];
        
        if (self.flags.count == 0) {
            if ([self.model isExcludedFromAudit:self.itemId]) {
                cell.textLabel.text = NSLocalizedString(@"audit_status_item_is_exluded", @"This item is exluded from Audits");
                cell.imageView.tintColor = UIColor.systemGrayColor;
            }
            else {
                cell.textLabel.text = NSLocalizedString(@"audit_status_no_issues_found", @"No issues found");
                cell.imageView.tintColor = nil;
            }
             
            return cell;
        }
        else {
            cell.textLabel.text = self.basicRows[indexPath.row];
            cell.imageView.tintColor = UIColor.systemOrangeColor;
            return cell;
        }
    }
    else if (indexPath.section == kSectionDuplicatedIdx) {
        Node* node = self.duplicates[indexPath.row];
        return [self.browseCellHelper getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryDisclosureIndicator noFlags:YES];
    }
    else if (indexPath.section == kSectionSimalarIdx) {
        Node* node = self.similars[indexPath.row];
        return [self.browseCellHelper getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryDisclosureIndicator noFlags:YES];
    }
    else {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"auditDrillDownBasicCellId" forIndexPath:indexPath];
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = self.actions[indexPath.row];
        cell.imageView.image = nil;
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSectionSimalarIdx || indexPath.section == kSectionDuplicatedIdx) {
        Node* node = indexPath.section == kSectionDuplicatedIdx ? self.duplicates[indexPath.row] : self.similars[indexPath.row];
        
        [self performSegueWithIdentifier:@"segueToItemDetails" sender:node];
    }
    else if (indexPath.section == kSectionSettingsIdx) {
        if ( indexPath.row == 1) {
            [self performSegueWithIdentifier:@"segueToDatabaseAuditPreferences" sender:nil];
        }
    }
    else if (indexPath.section == kSectionActionsIdx) {
        if (!self.model.metadata.auditConfig.hibpCaveatAccepted) {
            [self hibpWarning];
        }
        else {
            [self checkHibp];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSectionSettingsIdx) {
        return NSLocalizedString(@"audit_drill_down_section_header_preferences", @"Settings");
    }
    else if (section == kSectionBasicIdx) {
        return NSLocalizedString(@"audit_drill_down_section_header_summary", @"Summary");
    }
    else if (section == kSectionDuplicatedIdx) {
        if (self.duplicates.count) {
            return NSLocalizedString(@"audit_drill_down_section_header_duplicates", @"Duplicate Passwords");
        }
        else {
            return nil;
        }
    }
    else if (section == kSectionSimalarIdx) {
        if (self.similars.count) {
            return NSLocalizedString(@"audit_drill_down_section_header_similar", @"Similar Passwords");
        }
        else {
            return nil;
        }
    }
    else if (section == kSectionActionsIdx) {
        return self.actions.count ? NSLocalizedString(@"audit_drill_down_section_header_actions", @"Actions") : nil;
    }

    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == kSectionDuplicatedIdx) {
        if (self.duplicates.count) {
            return NSLocalizedString(@"audit_drill_down_section_footer_duplicates", @"The items above use exactly the same password as this item, this is generally considered a weakness. You should try not to havve any duplicated passwords.");
        }
        else {
            return nil;
        }
    }
    else if (section == kSectionSimalarIdx) {
        if (self.similars.count) {
            return NSLocalizedString(@"audit_drill_down_section_footer_similar", @"The items above have a similar password to this item. This might indicate a weakness or use of a common component and could be there be weak.");
        }
        else {
            return nil;
        }
    }

    return [super tableView:tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == kSectionDuplicatedIdx && !self.duplicates.count) {
        return 0.1;
    }
    else if (section == kSectionSimalarIdx && !self.similars.count) {
        return 0.1;
    }

    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == kSectionDuplicatedIdx && !self.duplicates.count) {
        return 0.1;
    }
    else if (section == kSectionSimalarIdx && !self.similars.count) {
        return 0.1;
    }




    return UITableViewAutomaticDimension;
}

- (UIView *)sectionFiller {
    static UILabel *emptyLabel = nil;
    if (!emptyLabel) {
        emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        emptyLabel.backgroundColor = [UIColor clearColor];
    }
    return emptyLabel;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == kSectionDuplicatedIdx && !self.duplicates.count) {
        return [self sectionFiller];
    }
    else if (section == kSectionSimalarIdx && !self.similars.count) {
        return [self sectionFiller];
    }
    
    return [super tableView:tableView viewForHeaderInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == kSectionDuplicatedIdx && !self.duplicates.count) {
        return [self sectionFiller];
    }
    else if (section == kSectionSimalarIdx && !self.similars.count) {
        return [self sectionFiller];
    }




    return [super tableView:tableView viewForFooterInSection:section];
}



- (void)onAuditOnOff:(BOOL)on {
    if ( self.model.isReadOnly ) {
        [self refreshItems];
        return;
    }
    
    Node* item = [self.model.database getItemById:self.itemId];
    if ( !item ) {
        slog(@"WARNWARN: Could not find item to check for HIBP");
        return;
    }

    [self.model excludeFromAudit:item exclude:!on];

    self.updateDatabase();
    
    [self.model restartBackgroundAudit];
    
    [self refreshItems];
}

- (NSArray<NSString*>*)getBasicRows:(NSSet<NSNumber*>*)flags {
    NSArray<NSNumber*>* sorted = [flags.allObjects sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];

    return [sorted map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getBasicFlagDescription:obj];
    }];
}

- (NSString*)getBasicFlagDescription:(NSNumber*)flag {
    if (flag.intValue == kAuditFlagNoPassword) {
        return NSLocalizedString(@"audit_summary_flag_no_password_set", @"No password set");
    }
    else if (flag.intValue == kAuditFlagCommonPassword) {
        return NSLocalizedString(@"audit_summary_flag_very_common_password", @"Password is very common");
    }
    else if (flag.intValue == kAuditFlagPwned) {
        return NSLocalizedString(@"audit_summary_flag_pwned", @"Password is Pwned (HIBP)");
    }
    else if (flag.intValue == kAuditFlagTooShort) {
        return NSLocalizedString(@"audit_summary_flag_password_is_too_short", @"Password is too short.");
    }
    else if (flag.intValue == kAuditFlagDuplicatePassword) {
        return NSLocalizedString(@"audit_quick_summary_duplicated_password", @"Password is duplicated in another entry");
    }
    else if (flag.intValue == kAuditFlagSimilarPassword) {
        return NSLocalizedString(@"audit_quick_summary_password_is_similar_to_another", @"Password is similar to one in another entry.");
    }
    else if (flag.intValue == kAuditFlagLowEntropy) {
        return NSLocalizedString(@"audit_quick_summary_password_low_entropy", @"Password is weak (low entropy)");
    }
    else if (flag.intValue == kAuditFlagTwoFactorAvailable) {
        return NSLocalizedString(@"audit_quick_summary_two_factor_available", @"2 Factor Authentication is available for this domain.");
    }
    
    return NSLocalizedString(@"generic_unknown", @"Unknown");
}



- (void)hibpWarning {
    NSString* loc1 = NSLocalizedString(@"audit_hibp_warning_title", @"HIBP Disclaimer");
    NSString* loc2 = NSLocalizedString(@"audit_hibp_warning_message", @"I understand that my passwords will be sent over the web (HTTPS) to the 'Have I Been Pwned?' password checking service (using k-anonymity) and that I fully consent to this functionality. I also absolve Strongbox, Mark McGuill and Phoebe Code Limited of all liabilty for using this feature.");
    NSString* locNo = NSLocalizedString(@"audit_hibp_warning_no", @"No, I don't want to use this feature");
    NSString* locYes = NSLocalizedString(@"audit_hibp_warning_yes", @"Yes, I understand and agree");
    
    [Alerts twoOptionsWithCancel:self title:loc1 message:loc2 defaultButtonText:locNo secondButtonText:locYes action:^(int response) {
        if (response == 1) { 
            DatabaseAuditorConfiguration* config = self.model.metadata.auditConfig;
            config.hibpCaveatAccepted = YES;
            self.model.metadata.auditConfig = config;
            
            [self checkHibp];
        }
    }];
}

- (void)checkHibp {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"audit_manual_pwn_progress_message", @"Checking HIBP")];
    
    Node* item = [self.model.database getItemById:self.itemId];
    if ( !item ) {
        slog(@"WARNWARN: Could not find item to check for HIBP");
        return;
    }
    
    NSString* password = item.fields.password;
    
    [self.model oneTimeHibpCheck:password completion:^(BOOL pwned, NSError * _Nonnull error) {
        slog(@"HIBP: %hhd - %@", pwned, error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];

            if (error) {
                [Alerts error:self error:error];
            }
            else {
                if (!pwned) {
                    [Alerts info:self
                           title:NSLocalizedString(@"audit_manual_pwn_check_result_title", @"Manual HIBP Result")
                         message:NSLocalizedString(@"audit_manual_pwn_check_result_not_pwned", @"Your password has NOT been pwned as is likely secure.") completion:nil];
                }
                else {
                    [Alerts warn:self
                           title:NSLocalizedString(@"audit_manual_pwn_check_result_title", @"Manual HIBP Result")
                         message:NSLocalizedString(@"audit_manual_pwn_check_result_pwned", @"This password is pwned and is vulnerable") completion:nil];

                    [self.model restartBackgroundAudit]; 
                }
            }
        });
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToItemDetails"]) {
        ItemDetailsViewController *vc = segue.destinationViewController;
    
        Node* node = (Node*)sender;
        
        vc.createNewItem = NO;
        
        vc.itemId = node.uuid;
        vc.parentGroupId = node.parent.uuid;
        vc.forcedReadOnly = NO;
        vc.databaseModel = self.model;
    }
    else if ([segue.identifier isEqualToString:@"segueToDatabaseAuditPreferences"]) {
        AuditConfigurationVcTableViewController *vc = segue.destinationViewController;
        vc.model = self.model;
        vc.updateDatabase = self.updateDatabase;
    }
}

@end
