//
//  OpenSafeView.m
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "BrowseSafeView.h"
#import "PwSafeSerialization.h"
#import "SelectDestinationGroupController.h"
#import "RecordView.h"
#import "Alerts.h"
#import "Settings.h"
#import "SharedAppAndAutoFillSettings.h"
#import "DatabaseOperations.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "NodeIconHelper.h"
#import "SetNodeIconUiHelper.h"
#import "ItemDetailsViewController.h"
#import "BrowseItemCell.h"
#import "MasterDetailViewController.h"
#import "BrowsePreferencesTableViewController.h"
#import "SortOrderTableViewController.h"
#import "BrowseItemTotpCell.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>
#import "DatabaseSearchAndSorter.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "DatabasePreferencesController.h"

#import "BrowseTableDatasource.h"
#import "ConfiguredBrowseTableDatasource.h"
#import "SearchResultsBrowseTableDatasource.h"
#import "BrowseTableViewCellHelper.h"
#import "QuickViewsBrowseTableDataSource.h"
#import <ISMessages/ISMessages.h>
#import "BiometricsManager.h"
#import "AuditDrillDownController.h"

static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, DZNEmptyDataSetSource >

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonAddRecord;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonSafeSettings;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonMove;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDelete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSortItems;

@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;

@property (strong) SetNodeIconUiHelper* sni; // Required: Or Delegate does not work!

@property NSMutableArray<NSArray<NSNumber*>*>* reorderItemOperations;
@property BOOL sortOrderForAutomaticSortDuringEditing;

@property BOOL hasAlreadyAppeared;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeBarButton;
@property NSString* originalCloseTitle;

@property NSTimer* timerRefreshOtp;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *exportBarButton;

@property ConfiguredBrowseTableDatasource* configuredDataSource;
@property SearchResultsBrowseTableDatasource* searchDataSource;
@property QuickViewsBrowseTableDataSource* quickViewsDataSource;

@end

@implementation BrowseSafeView

- (void)dealloc {
    NSLog(@"DEALLOC [%@]", self);
    
    [self unListenToNotifications];
    
    [self killOtpTimer];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if(self.isMovingFromParentViewController) { // Kill
        NSLog(@"isMovingFromParentViewController [%@]", self);

        [self unListenToNotifications];
        
        [self killOtpTimer];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    if(!self.hasAlreadyAppeared && self.viewModel.metadata.immediateSearchOnBrowse && [self isDisplayingRootGroup]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.searchController.searchBar becomeFirstResponder];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self addSearchBarToNav]; // Required to avoid weird UI artifact on subgroup segues
        });
    }
    
    self.hasAlreadyAppeared = YES;
    
    [self refreshItems];
    [self updateSplitViewDetailsView:nil];
}

- (BOOL)isDisplayingRootGroup {
    return self.currentGroup == self.viewModel.database.rootGroup;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTableview];
    
    [self setupTips];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;

    [self setupNavBar];
    [self setupSearchBar];

    if (@available(iOS 13.0, *)) { // iOS 13 Appears to require this to show search bad - Doing so from ViewDidAppear doesn't work?
        [self addSearchBarToNav];
    }
    
    if(self.currentGroup == self.viewModel.database.rootGroup) {
        // Only do this for the root group - We should delay adding this because we get a weird
        // UI Artifact / Delay on segues to subgroups if we add here :(
        
        [self addSearchBarToNav];
        
         // This coordinates all TOTP UI updates for this database
        [self startOtpRefresh];
        
        [self maybePromptToTryProFeatures];        
    }
    
    // Add an edit button to the top right
    
    if (self.navigationItem.rightBarButtonItems) {
        NSMutableArray* rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
        [rightBarButtons insertObject:self.editButtonItem atIndex:0];
        self.navigationItem.rightBarButtonItems = rightBarButtons;
    }
    else {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    
    [self refreshItems];
        
    [self listenToNotifications];
}

- (IBAction)onExport:(id)sender {
    [self.viewModel encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled) { }
        else if (!data) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_error_encrypting", @"Could not get database data")
                    error:error];
        }
        else {
            [self onShareWithData:data];
        }
    }];
}

- (void)onShareWithData:(NSData*)data {
    NSString* filename = self.viewModel.metadata.fileName;
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSError* err;
    [data writeToFile:f options:kNilOptions error:&err];
    
    if (err) {
        [Alerts error:self error:err];
        return;
    }
    
    NSURL* url = [NSURL fileURLWithPath:f];
    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    // Required for iPad...

    activityViewController.popoverPresentationController.barButtonItem = self.exportBarButton;

    //    activityViewController.popoverPresentationController.sourceView = self.view;
    //    activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds),0,0);
    //    activityViewController.popoverPresentationController.permittedArrowDirections = 0L; // Don't show the arrow as it's not really anchored
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError *errorBlock;
        if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
            NSLog(@"error deleting file %@", errorBlock);
            return;
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)listenToNotifications {
    if(self.splitViewController) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showDetailTargetDidChange:) name:UIViewControllerShowDetailTargetDidChangeNotification object:self.splitViewController];
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseViewPreferencesChanged:)
                                               name:kDatabaseViewPreferencesChangedNotificationKey
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAuditNodesChanged:)
                                               name:kAuditNodesChangedNotificationKey
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshItems)
                                               name:kNotificationNameItemDetailsEditDone
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAuditCompleted:)
                                               name:kAuditCompletedNotificationKey
                                             object:nil];
}

- (void)unListenToNotifications {
//    [NSNotificationCenter.defaultCenter removeObserver:self name:UIViewControllerShowDetailTargetDidChangeNotification object:self.splitViewController]; // TODO: Call this?!
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:kDatabaseViewPreferencesChangedNotificationKey object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kAuditNodesChangedNotificationKey object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kNotificationNameItemDetailsEditDone object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:kAuditCompletedNotificationKey object:nil];
}

- (void)onAuditNodesChanged:(id)param {
    [self refreshItems];
}

- (void)onAuditCompleted:(id)param {
    NSNotification* note = param;
    NSNumber* numNote = note.object;
    
    NSLog(@"Audit Completed... [%@]-[%@]", self, numNote);
    
    if (numNote.boolValue) { // User Cancelled/Stopped or Restarted the Audit - Just ignore
        return;
    }
    
    if ([self isDisplayingRootGroup]) {
        NSNumber* issueCount = self.viewModel.auditIssueCount;
        if (issueCount == nil) {
            NSLog(@"WARNWARN: Invalid Audit Issue Count but Audit Completed Notification Received. Stale BrowseView... ignore");
            return;
        }
        
        
        NSNumber* lastKnownAuditIssueCount = self.viewModel.metadata.auditConfig.lastKnownAuditIssueCount;
        
        NSLog(@"Audit Complete: Issues = %lu - Last Known = %@", issueCount.unsignedLongValue, lastKnownAuditIssueCount);
        
        self.viewModel.metadata.auditConfig.lastKnownAuditIssueCount = issueCount;
        [SafesList.sharedInstance update:self.viewModel.metadata];

        if ( self.viewModel.metadata.auditConfig.showAuditPopupNotifications) {
            [self showAuditPopup:issueCount.unsignedLongValue lastKnownAuditIssueCount:lastKnownAuditIssueCount];
        }
    }
    
    [self refreshItems]; // Item may have been cleared of an audit issue, remove the audit badge
}

- (void)showAuditPopup:(NSUInteger)issueCount lastKnownAuditIssueCount:(NSNumber*)lastKnownAuditIssueCount {
    NSLog(@"showAuditPopup... [%@] = [%ld/%@]", self, (unsigned long)issueCount, lastKnownAuditIssueCount);
    
    if (lastKnownAuditIssueCount == nil) { // First time
        if (issueCount == 0) {
            [ISMessages showCardAlertWithTitle:NSLocalizedString(@"browse_vc_audit_complete_title", @"Security Audit Complete")
                                       message:NSLocalizedString(@"browse_vc_audit_complete_message", @"No issues found")
                                      duration:1.5f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeSuccess
                                 alertPosition:ISAlertPositionTop
                                       didHide:nil];
        }
        else {
            [ISMessages showCardAlertWithTitle:NSLocalizedString(@"browse_vc_audit_complete_title", @"Security Audit Complete")
                                       message:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_audit_complete_message_issues_found_fmt", @"%ld issues found"), issueCount]
                                      duration:1.5f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeWarning
                                 alertPosition:ISAlertPositionTop
                                       didHide:nil];
        }
    }
    else if (issueCount > lastKnownAuditIssueCount.unsignedIntegerValue) {
        [ISMessages showCardAlertWithTitle:NSLocalizedString(@"browse_vc_audit_complete_title", @"Security Audit Complete")
                                   message:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_audit_complete_message_new_issues_found_fmt",@"%ld New Issues Found!"), issueCount - lastKnownAuditIssueCount.unsignedIntegerValue]
                                  duration:2.5f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeError
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    }
}

- (void)onDatabaseViewPreferencesChanged:(id)param {
    [self refreshItems];
}

- (void)maybePromptToTryProFeatures {
    // Free or Pro? Definitely no
    
    if(SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
        return;
    }

    // Has the user ever given Pro a try? Maybe the just need a nudge...

    const NSUInteger kProNudgeIntervalDays = 14;
    NSDate* dueDate = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:kProNudgeIntervalDays toDate:Settings.sharedInstance.lastFreeTrialNudge options:kNilOptions];
    //NSLog(@"Nudge Due: [%@]", dueDate);
    BOOL nudgeDue = dueDate.timeIntervalSinceNow < 0; // Due date is in past
    
    if (!SharedAppAndAutoFillSettings.sharedInstance.freeTrialHasBeenOptedInAndExpired && nudgeDue) {
        Settings.sharedInstance.lastFreeTrialNudge = NSDate.date;
        
        NSString* locMsg = NSLocalizedString(@"browse_pro_nudge_message_fmt", @"Strongbox Pro is full of handy features like %@ Unlock.\n\nYou have a Free Trial available to use, would you like to try Strongbox Pro?");
        NSString* locMsgFmt = [NSString stringWithFormat:locMsg, BiometricsManager.sharedInstance.biometricIdName];
        
        [Alerts yesNo:self
                title:NSLocalizedString(@"browse_pro_nudge_title", @"Try Strongbox Pro?")
              message:locMsgFmt
               action:^(BOOL response) {
            if (response) {
                [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
            }
        }];
    }
    else {
        // User has already tried for more than 90 days... Nag :(
        if ([self userHasAlreadyTriedAppForMoreThan90Days]) {
            const NSUInteger percentageChanceOfShowing = 4;
            NSInteger random = arc4random_uniform(100);

            if(random < percentageChanceOfShowing) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
                });
            }
        }
    }
}

- (BOOL)userHasAlreadyTriedAppForMoreThan90Days {
    return (SharedAppAndAutoFillSettings.sharedInstance.freeTrialHasBeenOptedInAndExpired || Settings.sharedInstance.daysInstalled > 90);
}
    
- (void)showDetailTargetDidChange:(NSNotification *)notification{
    NSLog(@"showDetailTargetDidChange");
    if(!self.splitViewController.isCollapsed) {
        NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
        if(ip) {
            Node* item = [self getNodeFromIndexPath:ip];
            [self updateSplitViewDetailsView:item];
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateSplitViewDetailsView:nil];
            });
        }
    }
}

- (void)setupNavBar {
    self.originalCloseTitle = self.closeBarButton.title;
    
    if(self.splitViewController) {
        if(![self isDisplayingRootGroup]) {
            self.closeBarButton.enabled = NO;
            [self.closeBarButton setTintColor:UIColor.clearColor];
        }
    }
    else {
        self.closeBarButton.enabled = NO;
        [self.closeBarButton setTintColor:UIColor.clearColor];
    }
    self.navigationItem.leftItemsSupplementBackButton = YES;

    self.navigationItem.title = [NSString stringWithFormat:@"%@%@%@",
                                 (self.currentGroup.parent == nil) ?
                                 self.viewModel.metadata.nickName : self.currentGroup.title,
                                 self.viewModel.isUsingOfflineCache ? NSLocalizedString(@"browse_vc_offline_suffix", @" (Offline)") : @"",
                                 self.viewModel.isReadOnly ? NSLocalizedString(@"browse_vc_read_only_suffix", @" (Read Only)") : @""];
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.navigationBarHidden = NO;
}

- (void)enableDisableToolbarButtons {
    BOOL ro = self.viewModel.isUsingOfflineCache || self.viewModel.isReadOnly;
    
    self.buttonAddRecord.enabled = !ro && !self.isEditing;
    self.buttonSafeSettings.enabled = !self.isEditing;
    
    self.buttonMove.enabled = (!ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0);
    self.buttonDelete.enabled = !ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0;
    
    self.buttonSortItems.enabled = !self.isEditing ||
    (!ro && self.isEditing && self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone);
    
    UIImage* sortImage = self.isEditing ? [UIImage imageNamed:self.sortOrderForAutomaticSortDuringEditing ? @"sort-desc" : @"sort-asc"] : [UIImage imageNamed:self.viewModel.metadata.browseSortOrderDescending ? @"sort-desc" : @"sort-asc"];
    
    [self.buttonSortItems setImage:sortImage];
    
    [self.closeBarButton setTitle:self.isEditing ? NSLocalizedString(@"generic_cancel", @"Cancel") : self.originalCloseTitle];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
//    NSLog(@"setEditing: %d", editing);
    
    [self enableDisableToolbarButtons];
    
    if (!editing) {
        if(self.reorderItemOperations) {
            // Do the reordering
            NSLog(@"Reordering");
            
            for (NSArray<NSNumber*>* moveOp in self.reorderItemOperations) {
                NSUInteger src = moveOp[0].unsignedIntegerValue;
                NSUInteger dest = moveOp[1].unsignedIntegerValue;
                NSLog(@"Move: %lu -> %lu", (unsigned long)src, (unsigned long)dest);
                [self.currentGroup moveChild:src to:dest];
            }
            
            self.reorderItemOperations = nil;
            [self saveChangesToSafeAndRefreshView];
        }
    }
    else {
        self.reorderItemOperations = nil;
    }
}

- (void)cancelEditing {
    self.reorderItemOperations = nil;
    [self setEditing:NO];
}

- (void)setupSearchBar {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles = @[
                                                          NSLocalizedString(@"browse_vc_search_scope_title", @"Title"),
                                                          NSLocalizedString(@"browse_vc_search_scope_username", @"Username"),
                                                          NSLocalizedString(@"browse_vc_search_scope_password", @"Password"),
                                                          NSLocalizedString(@"browse_vc_search_scope_url", @"URL"),
                                                          NSLocalizedString(@"browse_vc_search_scope_tags", @"Tags"),
                                                          NSLocalizedString(@"browse_vc_search_scope_all", @"All")];
    self.searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
}

- (void)addSearchBarToNav {
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        
        // We want the search bar visible immediately for Root
        
        self.navigationItem.hidesSearchBarWhenScrolling = self.currentGroup != self.viewModel.database.rootGroup;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        [self.searchController.searchBar sizeToFit];
    }
}

- (void)setupTips {
    if(SharedAppAndAutoFillSettings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    
    if (!SharedAppAndAutoFillSettings.sharedInstance.hideTips && (!self.currentGroup || self.currentGroup.parent == nil)) {
        [ISMessages showCardAlertWithTitle:NSLocalizedString(@"browse_vc_tip_fast_tap_title", @"Fast Tap Actions")
                                   message:NSLocalizedString(@"browse_vc_tip_fast_tap_message", @"You can long press, or double/triple tap to quickly copy fields... Give it a try!")
                                  duration:2.5f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionBottom
                                   didHide:nil];
    }
}

- (void)setupTableview {
    self.configuredDataSource = [[ConfiguredBrowseTableDatasource alloc] initWithModel:self.viewModel isDisplayingRootGroup:[self isDisplayingRootGroup] tableView:self.tableView];
    self.searchDataSource = [[SearchResultsBrowseTableDatasource alloc] initWithModel:self.viewModel tableView:self.tableView];
    self.quickViewsDataSource = [[QuickViewsBrowseTableDataSource alloc] initWithModel:self.viewModel tableView:self.tableView];
    
    self.tableView.emptyDataSetSource = self;
    
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                initWithTarget:self
                                action:@selector(handleLongPress:)];
    self.longPressRecognizer.minimumPressDuration = 1;
    self.longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:self.longPressRecognizer];
    
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    
    self.tableView.estimatedRowHeight = self.cellHeight;
    self.tableView.rowHeight = self.cellHeight;
    self.tableView.tableFooterView = [UIView new];
    
    self.clearsSelectionOnViewWillAppear = YES;
}

- (CGFloat)cellHeight {
    return self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList ? 99.0 : 46.5;
}

- (IBAction)onClose:(id)sender {
    if (self.isEditing) {
        [self cancelEditing];
    }
    else {
        MasterDetailViewController* master = (MasterDetailViewController*)self.splitViewController;
        [master onClose];
        
        if (self.viewModel) {
            [self.viewModel closeAndCleanup];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        if(self.reorderItemOperations == nil) {
            self.reorderItemOperations = [NSMutableArray array];
        }
        [self.reorderItemOperations addObject:@[@(sourceIndexPath.row), @(destinationIndexPath.row)]];

        [self enableDisableToolbarButtons]; // Disable moving/deletion if there's been a move
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  // Required for iOS 9 and 10
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.cellHeight;
}

- (IBAction)onSortItems:(id)sender {
    if(self.isEditing) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"browse_vc_sort_by_title", @"Sort Items By Title?")
              message:NSLocalizedString(@"browse_vc_sort_by_title_message", @"Do you want to sort all the items in this folder by Title? This will set the order in which they are stored in your database.")
               action:^(BOOL response) {
            if(response) {
                self.reorderItemOperations = nil; // Discard existing reordering ops...
                self.sortOrderForAutomaticSortDuringEditing = !self.sortOrderForAutomaticSortDuringEditing;
                [self.currentGroup sortChildren:self.sortOrderForAutomaticSortDuringEditing];
                [self saveChangesToSafeAndRefreshView];
            }
        }];
    }
    else {
        [self performSegueWithIdentifier:@"segueToSortOrder" sender:nil];
    }
}

- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory {
    BOOL shouldAddHistory = YES; // FUTURE: Config on/off? only valid for KeePass 2+ also...
    if(shouldAddHistory && originalNodeForHistory != nil) {
        [item.fields.keePassHistory addObject:originalNodeForHistory];
    }
}

- (void)onRenameItem:(NSIndexPath * _Nonnull)indexPath {
    [self onRenameItem:indexPath completion:nil];
}

- (void)onRenameItem:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    [Alerts OkCancelWithTextField:self
                    textFieldText:item.title
                            title:NSLocalizedString(@"browse_vc_rename_item", @"Rename Item")
                          message:NSLocalizedString(@"browse_vc_rename_item_enter_title", @"Please enter a new title for this item")
                       completion:^(NSString *text, BOOL response) {
        if(response && [text length]) {
            if(!item.isGroup) {
                Node* originalNodeForHistory = [item cloneForHistory];
                [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
            }

            [item setTitle:text keePassGroupTitleRules:self.viewModel.database.format != kPasswordSafe];

            [item touch:YES touchParents:NO];

            [self saveChangesToSafeAndRefreshView];
        }
        
        if(completion) {
            completion(response);
        }
    }];
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (void)onSetIconForItem:(NSIndexPath * _Nonnull)indexPath {
    [self onSetIconForItem:indexPath completion:nil];
}

- (void)onSetIconForItem:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.viewModel.database.customIcons;
    
    [self.sni changeIcon:self
                    node:item
             urlOverride:nil
                  format:self.viewModel.database.format
          keePassIconSet:self.viewModel.metadata.keePassIconSet
              completion:^(BOOL goNoGo, NSNumber * _Nullable userSelectedNewIconIndex, NSUUID * _Nullable userSelectedExistingCustomIconId, BOOL isRecursiveGroupFavIconResult, NSDictionary<NSUUID *,UIImage *> * _Nonnull selected) {
        if(goNoGo) {
            if (selected) {
                [self setCustomIcons:item selected:selected isRecursiveGroupFavIconResult:isRecursiveGroupFavIconResult];
            }
            else if (userSelectedExistingCustomIconId) {
                if(!item.isGroup) {
                    Node* originalNodeForHistory = [item cloneForHistory];
                    [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
                }
                [item touch:YES touchParents:NO];
                item.customIconUuid = userSelectedExistingCustomIconId;
            }
            else if(userSelectedNewIconIndex) {
                if(!item.isGroup) {
                    Node* originalNodeForHistory = [item cloneForHistory];
                    [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
                }
                [item touch:YES touchParents:NO];

                if(userSelectedNewIconIndex.intValue == -1) {
                    item.iconId = !item.isGroup ? @(0) : @(48); // Default
                }
                else {
                    item.iconId = userSelectedNewIconIndex;
                }
                item.customIconUuid = nil;
            }
            
            [self saveChangesToSafeAndRefreshView];
        }
        
        if(completion) {
            completion(goNoGo);
        }
    }];
}
    
- (void)setCustomIcons:(Node*)item
              selected:(NSDictionary<NSUUID *,UIImage *>*)selected
isRecursiveGroupFavIconResult:(BOOL)isRecursiveGroupFavIconResult {
    if(isRecursiveGroupFavIconResult) {
        for(Node* node in item.allChildRecords) {
            UIImage* img = selected[node.uuid];
            if(img) {
                [self setCustomIcon:node image:img];
            }
        }
    }
    else {
        // Direct set for item/group
        [self setCustomIcon:item image:selected.allValues.firstObject];
    }
}

- (void)setCustomIcon:(Node*)item image:(UIImage*)image {
    if(!item.isGroup) {
        Node* originalNodeForHistory = [item cloneForHistory];
        [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
    }
    
    [item touch:YES touchParents:NO];

    NSData *data = UIImagePNGRepresentation(image);
    [self.viewModel.database setNodeCustomIcon:item data:data rationalize:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)){
    return [self getRightSlideActions:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)) {
    return [self getLeftSlideActions:indexPath];
}

- (UIContextualAction*)getRemoveAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onDeleteSingleItem:indexPath completion:completionHandler];
    }];

    if (@available(iOS 13.0, *)) {
        removeAction.image = [UIImage systemImageNamed:@"trash"];
    }
    else {
        removeAction.image = [UIImage imageNamed:@"trash"];
    }
    removeAction.backgroundColor = UIColor.systemRedColor;
    
    return removeAction;
}

- (UIContextualAction*)getRenameAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_vc_action_rename", @"Rename")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onRenameItem:indexPath completion:completionHandler];
    }];

    if (@available(iOS 13.0, *)) {
        renameAction.image = [UIImage systemImageNamed:@"pencil"];
    }
    else {
        renameAction.image = [UIImage imageNamed:@"pencil"];
    }
    renameAction.backgroundColor = UIColor.systemGreenColor;
    
    return renameAction;
}

- (UIContextualAction*)getSetIconAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *setIconAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") :
                                                                                                    NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onSetIconForItem:indexPath completion:completionHandler];
    }];

    if (@available(iOS 13.0, *)) {
        setIconAction.image = [UIImage systemImageNamed:@"photo"];
    }
    else {
        setIconAction.image = [UIImage imageNamed:@"picture"];
    }

    setIconAction.backgroundColor = UIColor.systemBlueColor;

    return setIconAction;
}

- (UIContextualAction*)getDuplicateItemAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *duplicateItemAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self duplicateItem:item completion:completionHandler];
    }];

    if (@available(iOS 13.0, *)) {
        duplicateItemAction.image = [UIImage systemImageNamed:@"plus.square.on.square"];
    }
    else {
        duplicateItemAction.image = [UIImage imageNamed:@"duplicate"];
    }

    duplicateItemAction.backgroundColor = UIColor.systemPurpleColor;

    return duplicateItemAction;
}

- (UIContextualAction*)getPinAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    BOOL pinned = [self.viewModel isPinned:item];
    
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:pinned ?
                                                                                                           NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") :
                                                                                                           NSLocalizedString(@"browse_vc_action_pin", @"Pin")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self togglePinEntry:item];
        completionHandler(YES);
    }];

    if (@available(iOS 13.0, *)) {
        pinAction.image = [UIImage systemImageNamed:pinned ? @"pin.slash" : @"pin"];
    }
    else {
        pinAction.image = [UIImage imageNamed:pinned ? @"pin-un" : @"pin"];
    }

    pinAction.backgroundColor = UIColor.magentaColor;

    return pinAction;
}

- (UIContextualAction*)getAuditAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self showAuditDrillDown:item];
        completionHandler(YES);
    }];

    pinAction.image = [UIImage imageNamed:@"security_checked"];
    pinAction.backgroundColor = UIColor.systemOrangeColor;

    return pinAction;
}

- (UISwipeActionsConfiguration *)getRightSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    UIContextualAction* pinAction = [self getPinAction:indexPath];
    UIContextualAction* auditAction = [self getAuditAction:indexPath];

    Node *item = [self getNodeFromIndexPath:indexPath];

    return [UISwipeActionsConfiguration configurationWithActions:item.isGroup ? @[pinAction] : @[auditAction, pinAction]];
}

- (UISwipeActionsConfiguration *)getLeftSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    UIContextualAction* removeAction = [self getRemoveAction:indexPath];
    UIContextualAction* renameAction = [self getRenameAction:indexPath];
    UIContextualAction* setIconAction = [self getSetIconAction:indexPath];
    UIContextualAction* duplicateItemAction = [self getDuplicateItemAction:indexPath];
    UIContextualAction* pinAction = [self getPinAction:indexPath];
    UIContextualAction* auditAction = [self getAuditAction:indexPath];

    Node *item = [self getNodeFromIndexPath:indexPath];

    if(!self.viewModel.isUsingOfflineCache && !self.viewModel.isReadOnly) {
        if(item.isGroup) {
            return self.viewModel.database.format != kPasswordSafe ?    [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, setIconAction, pinAction]] :
                                                                        [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, pinAction]];
        }
        else {
            return [UISwipeActionsConfiguration configurationWithActions:@[removeAction, duplicateItemAction, setIconAction, pinAction]];
        }
    }
    else {
        return [UISwipeActionsConfiguration configurationWithActions:item.isGroup ? @[pinAction] : @[auditAction, pinAction]];
    }
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (![self getTableDataSource].supportsSlideActions) {
        return nil;
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item) {
        return nil;
    }
    
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onDeleteSingleItem:indexPath];
    }];
    
    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                            title:NSLocalizedString(@"browse_vc_action_rename", @"Rename")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onRenameItem:indexPath];
    }];
    renameAction.backgroundColor = UIColor.systemGreenColor;
    
    UITableViewRowAction *setIconAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") :
                                                                                                  NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon")
                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onSetIconForItem:indexPath];
    }];
    setIconAction.backgroundColor = UIColor.systemOrangeColor;

    UITableViewRowAction *duplicateItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                                   title:NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate")
                                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self duplicateItem:item];
    }];
    duplicateItemAction.backgroundColor = UIColor.systemPurpleColor;

    UITableViewRowAction *auditItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                                                                             handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self showAuditDrillDown:item];
    }];

    UITableViewRowAction *pinAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                         title:[self.viewModel isPinned:item] ?
                                       NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") :
                                       NSLocalizedString(@"browse_vc_action_pin", @"Pin")
                                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                                                                                     [self togglePinEntry:item];
                                                                                 }];
    pinAction.backgroundColor = UIColor.magentaColor;
    
    if(!self.viewModel.isUsingOfflineCache && !self.viewModel.isReadOnly) {
        if(item.isGroup) {
            return self.viewModel.database.format != kPasswordSafe ? @[removeAction, renameAction, setIconAction, pinAction] : @[removeAction, renameAction, pinAction];
        }
        else {
            return @[removeAction, duplicateItemAction, auditItemAction, pinAction];
        }
    }
    else {
        return item.isGroup ? @[pinAction] : @[auditItemAction, pinAction];
    }
}

- (void)showAuditDrillDown:(Node*)item {
    [self performSegueWithIdentifier:@"segueToAuditDrillDown" sender:item];
}

- (void)togglePinEntry:(Node*)item {
    [self.viewModel togglePin:item];
    [self refreshItems];
}

-(void)duplicateItem:(Node*)item {
    [self duplicateItem:item completion:nil];
}

-(void)duplicateItem:(Node*)item completion:(void (^)(BOOL actionPerformed))completion {
    [Alerts yesNo:self
            title:NSLocalizedString(@"browse_vc_duplicate_prompt_title", @"Duplicate Item?")
          message:NSLocalizedString(@"browse_vc_duplicate_prompt_message", @"Are you sure you want to duplicate this item?")
           action:^(BOOL response) {
        if(response) {
            Node* dupe = [item duplicate:[item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")]];
            
            [item touch:NO touchParents:YES];

            [item.parent addChild:dupe keePassGroupTitleRules:NO];

            [self saveChangesToSafeAndRefreshView];
            
            if(completion) {
                completion(response);
            }
        }
        else {
            if(completion) {
                completion(response);
            }
        }
    }];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeSettings"]);
}

//////////////////////////////////////////////////////////////////////////////////////
// Data Source Control

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if (!searchController.searchBar.text.length) {
        [self.quickViewsDataSource refresh]; // Refresh Tags / Audit Count
    }
    
    [self.searchDataSource updateSearchResults:searchController];
    
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (void)refreshItems {
    if(self.searchController.isActive) {
        [self updateSearchResultsForSearchController:self.searchController];
    }
    else {
        [self.configuredDataSource refreshItems:self.currentGroup];
        [self.tableView reloadData];
        
        self.editButtonItem.enabled = (!self.viewModel.isUsingOfflineCache &&
        !self.viewModel.isReadOnly);
    }
    
    [self enableDisableToolbarButtons];
}

- (id<BrowseTableDatasource>)getTableDataSource {
    if (self.searchController.isActive) {
        if (self.searchController.searchBar.text.length) {
            return self.searchDataSource;
        }
        else {
            return self.quickViewsDataSource;
        }
    }
    else {
        return self.configuredDataSource;
    }
}

- (Node*)getNodeFromIndexPath:(NSIndexPath*)indexPath {
    return [[self getTableDataSource] getNodeFromIndexPath:indexPath];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self getTableDataSource].sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self getTableDataSource] rowsForSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[self getTableDataSource] titleForSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self getTableDataSource] cellForRowAtIndexPath:indexPath];
}

- (BOOL)isShowingQuickViews {
    return self.searchController.isActive && self.searchController.searchBar.text.length == 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isShowingQuickViews]) {
        
        [self.quickViewsDataSource performTapAction:indexPath searchController:self.searchController];

        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if(self.viewModel.metadata.doubleTapAction == kBrowseTapActionNone && self.viewModel.metadata.tripleTapAction == kBrowseTapActionNone) { // No need for timer or delay if no double/triple tap actions...
        NSLog(@"Expediting Single Tap action as no double/triple tap actions set");
        [self handleSingleTap:indexPath];
        return;
    }
    
    if(self.tapCount == 2 && self.tapTimer != nil && [self.tappedIndexPath isEqual:indexPath]) {
        [self.tapTimer invalidate];
        self.tapTimer = nil;
        self.tapCount = 0;
        self.tappedIndexPath = nil;
        
        [self handleTripleTap:indexPath];
    }
    else if(self.tapCount == 1 && self.tapTimer != nil && [self.tappedIndexPath isEqual:indexPath]){
        [self.tapTimer invalidate];
        self.tapCount = self.tapCount + 1;
        self.tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
    }
    else if(self.tapCount == 0) {
        // This is the first tap. If there is no tap till tapTimer is fired, it is a single tap
        self.tapCount = self.tapCount + 1;
        self.tappedIndexPath = indexPath;
        NSLog(@"Got tap... waiting...");
        self.tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
    }
    else if(![self.tappedIndexPath isEqual:indexPath]){
        //tap on new row
        self.tapCount = 0;
        self.tappedIndexPath = indexPath;
        if(self.tapTimer != nil){
            [self.tapTimer invalidate];
            self.tapTimer = nil;
        }
    }
}

- (void)tapTimerFired:(NSTimer *)aTimer{
    if(self.tapCount == 1) {
        [self handleSingleTap:self.tappedIndexPath];
    }
    else if(self.tapCount == 2) {
        [self handleDoubleTap:self.tappedIndexPath];
    }
    
    self.tapCount = 0;
    self.tappedIndexPath = nil;
    self.tapTimer = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToRecord"]) {
        Node *record = (Node *)sender;
        RecordView *vc = segue.destinationViewController;
        vc.record = record;
        vc.parentGroup = self.currentGroup;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToItemDetails"]) {
        ItemDetailsViewController *vc = segue.destinationViewController;
        
        NSDictionary* params = (NSDictionary*)sender;
        Node* record = params[kItemToEditParam];
        NSNumber* editImmediately = params[kEditImmediatelyParam];
        vc.createNewItem = record == nil;
        vc.editImmediately = editImmediately.boolValue;
        
        vc.item = record;
        vc.parentGroup = self.currentGroup;
        vc.readOnly = self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache;
        vc.databaseModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToAuditDrillDown"]) {
        UINavigationController* nav = segue.destinationViewController;
        AuditDrillDownController *vc = (AuditDrillDownController*)nav.topViewController;

        __weak BrowseSafeView* weakSelf = self;
        
        vc.model = self.viewModel;
        vc.item = sender;
        vc.onDone =  ^(BOOL showAllAuditIssues) {
            NSLog(@"onDone: [%hhd]", showAllAuditIssues);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // Getting a weird glitch every now and then in this dismissal... attempt to fix y postponing briefly
                [self dismissViewControllerAnimated:YES completion:^{
                    if (showAllAuditIssues) {
                        [weakSelf showAllAuditIssues];
                    }
                }];
            });
        };
    }
    else if ([segue.identifier isEqualToString:@"segueMasterDetailToDetail"]) {
        UINavigationController* nav = segue.destinationViewController;
        ItemDetailsViewController *vc = (ItemDetailsViewController*)nav.topViewController;
        
        NSDictionary* params = (NSDictionary*)sender;
        Node* record = params[kItemToEditParam];
        NSNumber* editImmediately = params[kEditImmediatelyParam];
        vc.createNewItem = record == nil;
        vc.editImmediately = editImmediately.boolValue;
        
        vc.item = record;
        vc.parentGroup = self.currentGroup;
        vc.readOnly = self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache;
        vc.databaseModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"sequeToSubgroup"]){
        BrowseSafeView *vc = segue.destinationViewController;
        vc.currentGroup = (Node *)sender;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectDestination"]) {
        NSArray *itemsToMove = (NSArray *)sender;
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = (SelectDestinationGroupController*)nav.topViewController;
        
        vc.currentGroup = self.viewModel.database.rootGroup;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = itemsToMove;
        vc.onDone = ^(BOOL userCancelled, NSError *error) {
            [self dismissViewControllerAnimated:YES completion:^{
                if (userCancelled) {
                    [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE: Be more graceful and revert nicely
                }
                else if (error) {
                    NSString* title = NSLocalizedString(@"moveentry_vc_error_moving", @"Error Moving");
                    [Alerts error:self title:title error:error];
                }
                else {
                    [self refreshItems];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToPreferencesAndManagement"]) {
        UINavigationController* nav = segue.destinationViewController;
        
        DatabasePreferencesController *vc = (DatabasePreferencesController*)nav.topViewController;
        vc.viewModel = self.viewModel;
        vc.onDatabaseBulkIconUpdate = ^(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
            for(Node* node in self.viewModel.database.activeRecords) {
                UIImage* img = selectedFavIcons[node.uuid];
                if(img) {
                    [self setCustomIcon:node image:img];
                }
            }
            [self saveChangesToSafeAndRefreshView];
        };
        vc.onDone =  ^(BOOL showAllAuditIssues) {
            [self dismissViewControllerAnimated:YES completion:^{
                if (showAllAuditIssues) {
                    [self showAllAuditIssues];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToSortOrder"]){
        UINavigationController* nav = segue.destinationViewController;
        SortOrderTableViewController* vc = (SortOrderTableViewController*)nav.topViewController;
        vc.format = self.viewModel.database.format;
        vc.field = self.viewModel.metadata.browseSortField;
        vc.descending = self.viewModel.metadata.browseSortOrderDescending;
        vc.foldersSeparately = self.viewModel.metadata.browseSortFoldersSeparately;
        
        vc.onChangedOrder = ^(BrowseSortField field, BOOL descending, BOOL foldersSeparately) {
            self.viewModel.metadata.browseSortField = field;
            self.viewModel.metadata.browseSortOrderDescending = descending;
            self.viewModel.metadata.browseSortFoldersSeparately = foldersSeparately;
            [self refreshItems];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToUpgrade"]) {
        UIViewController* vc = segue.destinationViewController;
        if (@available(iOS 13.0, *)) {
            if ([self userHasAlreadyTriedAppForMoreThan90Days]) {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.modalInPresentation = YES;
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showAllAuditIssues { // We should probably not do this via search...
    
    [self.searchController.searchBar becomeFirstResponder];
    
    self.searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
    self.searchController.searchBar.text = kSpecialSearchTermAuditEntries;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.searchController.searchBar endEditing:YES]; // Hide Keyboard after search
    });
}

- (IBAction)onDatabasePreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToPreferencesAndManagement" sender:nil];
}

- (void)onAddGroup {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:NSLocalizedString(@"browse_vc_group_name", @"Group Name")
                            title:NSLocalizedString(@"browse_vc_enter_group_name", @"Enter Group Name")
                          message:NSLocalizedString(@"browse_vc_enter_group_name_message", @"Please Enter the New Group Name:")
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if ([self.viewModel addNewGroup:self.currentGroup title:text] != nil) {
                                   [self saveChangesToSafeAndRefreshView];
                               }
                               else {
                                   [Alerts warn:self
                                          title:NSLocalizedString(@"browse_vc_cannot_create_group", @"Cannot create group")
                                        message:NSLocalizedString(@"browse_vc_cannot_create_group_message", @"Could not create a group with this name here, possibly because one with this name already exists.")];
                               }
                           }
                       }];
}

- (IBAction)onAddItem:(id)sender {
    NSString* locEntry = NSLocalizedString(@"browse_add_entry_button_title", @"Add Entry...");
    NSString* locGroup = NSLocalizedString(@"browse_add_group_button_title", @"Add Group...");
    
    NSArray* options = self.currentGroup.childRecordsAllowed ? @[locGroup, locEntry] : @[locGroup];
    
    [Alerts actionSheet:self
              barButton:self.buttonAddRecord
                  title:NSLocalizedString(@"browse_add_group_or_entry_question", @"Would you like to add an entry or a group?")
           buttonTitles:options
             completion:^(int response) {
        if (response == 1) {
            [self onAddGroup];
        }
        else if (response == 2) {
            [self showEntry:nil editImmediately:YES];
        }
    }];
}

- (void)editEntry:(Node*)item {
    if(item.isGroup) {
        return;
    }
    
    [self showEntry:item editImmediately:YES];
}

- (void)openEntryDetails:(Node*)item {
    if(item.isGroup) {
        return;
    }
    
    [self showEntry:item editImmediately:NO];
}

- (void)updateSplitViewDetailsView:(Node*)item {
    [self updateSplitViewDetailsView:item editMode:NO];
}

- (void)updateSplitViewDetailsView:(Node*)item editMode:(BOOL)editMode {
    if(self.splitViewController) {
        if(item) {
            [self performSegueWithIdentifier:@"segueMasterDetailToDetail" sender:@{ kItemToEditParam : item, kEditImmediatelyParam : @(editMode) } ];
        }
        else if(!self.splitViewController.isCollapsed) {
            [self performSegueWithIdentifier:@"segueMasterDetailToEmptyDetail" sender:nil];
        }
    }
}

- (void)showEntry:(Node*)item editImmediately:(BOOL)editImmediately {
    if(item) { // TODO: Why the difference? Can't we unify?
        if(self.splitViewController) {
            [self updateSplitViewDetailsView:item editMode:editImmediately];
        }
        else {
            if (@available(iOS 11.0, *)) {
                [self performSegueWithIdentifier:@"segueToItemDetails" sender:@{ kItemToEditParam : item, kEditImmediatelyParam : @(editImmediately) } ];
            }
            else {
                [self performSegueWithIdentifier:@"segueToRecord" sender:item];
            }
        }
    }
    else { // Only via Add New Entry -> Which is why different from above - Does not segueMasterDetailToEmptyDetail
        if (@available(iOS 11.0, *)) {
            if(self.splitViewController) {
                [self performSegueWithIdentifier:@"segueMasterDetailToDetail" sender:nil];
            }
            else {
                [self performSegueWithIdentifier:@"segueToItemDetails" sender:nil];
            }
        }
        else {
            [self performSegueWithIdentifier:@"segueToRecord" sender:nil];
        }
    }
}

- (IBAction)onMove:(id)sender {
    if(self.editing) {
        NSArray<NSIndexPath*> *selectedRows = self.tableView.indexPathsForSelectedRows;
        
        if (selectedRows && selectedRows.count > 0) {
            NSArray<Node *> *itemsToMove = [self getSelectedItems:selectedRows];
            
            [self performSegueWithIdentifier:@"segueToSelectDestination" sender:itemsToMove];
            
            [self setEditing:NO animated:YES];
        }
    }
}

////////////////////////////////////////////////////////////////////////
// Deletes

- (IBAction)onDeleteToolbarButton:(id)sender {
    NSArray<NSIndexPath*> *selectedRows = (self.tableView).indexPathsForSelectedRows;
    
    if (selectedRows.count > 0) {
        if (selectedRows.count > 1) {
            [self onDeleteMultipleSelected:selectedRows];
        }
        else {
            [self onDeleteSingleItem:selectedRows.firstObject];
        }
    }
}

- (void)onDeleteSingleItem:(NSIndexPath * _Nonnull)indexPath {
    [self onDeleteSingleItem:indexPath completion:nil];
}

- (void)onDeleteSingleItem:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    Node *item = [self getNodeFromIndexPath:indexPath];
    BOOL willRecycle = [self.viewModel canRecycle:item];

    [Alerts yesNo:self.searchController.isActive ? self.searchController : self
            title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
          message:[NSString stringWithFormat:willRecycle ?
                   NSLocalizedString(@"browse_vc_are_you_sure_recycle_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?") :
                   NSLocalizedString(@"browse_vc_are_you_sure_delete_fmt", @"Are you sure you want to permanently delete '%@'?"), [self dereference:item.title node:item]]
           action:^(BOOL response) {
                if (response) {
                    BOOL failed = NO;
                    if (willRecycle) {
                        failed = ![self.viewModel recycleItems:@[item]];
                    }
                    else {
                        [self.viewModel deleteItems:@[item]];
                    }

                    if (failed) {
                        [Alerts warn:self
                               title:NSLocalizedString(@"browse_vc_delete_failed", @"Delete Failed")
                             message:NSLocalizedString(@"browse_vc_delete_error_message", @"There was an error trying to delete this item.")];
                    }
                    else {
                        [self saveChangesToSafeAndRefreshView];
                    }
                }
        
                if (completion) {
                    completion(response);
                }
           }];
}

- (void)onDeleteMultipleSelected:(NSArray<NSIndexPath*>*)selected {
    NSArray<Node *> *items = [self getSelectedItems:selected];
    
    NSDictionary* grouped = [items groupBy:^id _Nonnull(Node * _Nonnull obj) {
        BOOL delete = [self.viewModel canRecycle:obj];
        return @(delete);
    }];

    const NSArray<Node*> *toBeDeleted = grouped[@(NO)];
    const NSArray<Node*> *toBeRecycled = grouped[@(YES)];

    if ( toBeDeleted == nil ) {
        [self postValidationRecycleAllItemsWithConfirmPrompt:toBeRecycled];
    }
    else {
        if ( toBeRecycled == nil ) {
            [self postValidationDeleteAllItemsWithConfirmPrompt:toBeDeleted];
        }
        else { // Mixed delete and recycle
            [self postValidationPartialDeleteAndRecycleItemsWithConfirmPrompt:toBeDeleted toBeRecycled:toBeRecycled];
        }
    }
}

- (void)postValidationPartialDeleteAndRecycleItemsWithConfirmPrompt:(const NSArray<Node*>*)toBeDeleted toBeRecycled:(const NSArray<Node*>*)toBeRecycled {
    [Alerts yesNo:self.searchController.isActive ? self.searchController : self
            title:NSLocalizedString(@"browse_vc_partial_recycle_alert_title", @"Partial Recycle")
          message:NSLocalizedString(@"browse_vc_partial_recycle_alert_message", @"Some of the items you have selected cannot be recycled and will be permanently deleted. Is that ok?")
           action:^(BOOL response) {
        if (response) {
            // Delete first, then recycly because the item to be deleted could be the recycle bin, and if we recycle first then we will actually
            // permanently delete the items we wanted to recycle! This is more conservative and a better outcome.
            
            [self.viewModel deleteItems:toBeDeleted];
            
            BOOL fail = ![self.viewModel recycleItems:toBeRecycled];
            
            if(fail) {
                [Alerts warn:self
                       title:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                     message:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")];
            }
            
            [self saveChangesToSafeAndRefreshView];
        }
    }];
}

- (void)postValidationDeleteAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items {
    [Alerts yesNo:self.searchController.isActive ? self.searchController : self
            title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
          message:NSLocalizedString(@"browse_vc_are_you_sure_delete", @"Are you sure you want to permanently delete these item(s)?")
           action:^(BOOL response) {
               if (response) {
                   [self.viewModel deleteItems:items];
                   [self saveChangesToSafeAndRefreshView];
               }
           }];
}

- (void)postValidationRecycleAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items {
    [Alerts yesNo:self.searchController.isActive ? self.searchController : self
            title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
          message:NSLocalizedString(@"browse_vc_are_you_sure_recycle", @"Are you sure you want to send these item(s) to the Recycle Bin?")
           action:^(BOOL response) {
               if (response) {
                   BOOL fail = ![self.viewModel recycleItems:items];
                   
                   if(fail) {
                       [Alerts warn:self
                              title:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                            message:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")];
                       
                       [self refreshItems];
                   }
                   else {
                       [self saveChangesToSafeAndRefreshView];
                   }
               }
           }];
}

///

- (NSArray<Node*> *)getSelectedItems:(NSArray<NSIndexPath *> *)selectedRows {
    NSMutableArray<Node*>* ret = [NSMutableArray array];

    for (NSIndexPath *selectionIndex in selectedRows) {
        Node* node = [self getNodeFromIndexPath:selectionIndex];
        
        if(node) {
            [ret addObject:node];
        }
    }
    
    return ret;
}

- (void)saveChangesToSafeAndRefreshView {
    [self refreshItems];
    
    [self.viewModel update:NO handler:^(BOOL userCancelled, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (userCancelled) {
                [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert more gracefully
            }
            else if (error) {
                [Alerts error:self
                        title:NSLocalizedString(@"browse_vc_error_saving", @"Error Saving")
                        error:error
                   completion:^{
                    [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert more gracefully
                }];
            }
            else {
                if(self.isEditing) {
                    [self setEditing:NO animated:YES];
                }
                
                [self refreshItems];
                
                [self updateSplitViewDetailsView:nil editMode:NO];
            }
        });
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleSingleTap:(NSIndexPath *)indexPath  {
    if (self.editing) {
        [self enableDisableToolbarButtons]; // Buttons can be enabled disabled based on selection?
        return;
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if(!item) {
        return;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if(item.isGroup) {
        [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item];
    }
    else {
        NSLog(@"Single Tap on %@", item.title);
        [self performTapAction:item action:self.viewModel.metadata.tapAction];
    }
}

- (void)handleDoubleTap:(NSIndexPath *)indexPath {
    if(self.editing) {
        return;
    }

    Node *item = [self getNodeFromIndexPath:indexPath];
    if(!item || item.isGroup) {
        if(item) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        return;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"Double Tap on %@", item.title);

    [self performTapAction:item action:self.viewModel.metadata.doubleTapAction];
}

- (void)handleTripleTap:(NSIndexPath *)indexPath {
    if(self.editing) {
        return;
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if(!item || item.isGroup) {
        if(item) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        return;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"Triple Tap on %@", item.title);

    [self performTapAction:item action:self.viewModel.metadata.tripleTapAction];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if(self.editing) {
        return;
    }
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    CGPoint tapLocation = [self.longPressRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:tapLocation];
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item || item.isGroup) {
        if(item) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        return;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"Long Press on %@", item.title);
    
    [self performTapAction:item action:self.viewModel.metadata.longPressTapAction];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)performTapAction:(Node*)item action:(BrowseTapAction)action {
    switch (action) {
        case kBrowseTapActionNone:
            // NOOP
            break;
        case kBrowseTapActionOpenDetails:
            [self openEntryDetails:item];
            break;
        case kBrowseTapActionCopyTitle:
            [self copyTitle:item];
            break;
        case kBrowseTapActionCopyUsername:
            [self copyUsername:item];
            break;
        case kBrowseTapActionCopyPassword:
            [self copyPassword:item];
            break;
        case kBrowseTapActionCopyUrl:
            [self copyUrl:item];
            break;
        case kBrowseTapActionCopyEmail:
            [self copyEmail:item];
            break;
        case kBrowseTapActionCopyNotes:
            [self copyNotes:item];
            break;
        case kBrowseTapActionCopyTotp:
            [self copyTotp:item];
            break;
        case kBrowseTapActionEdit:
            [self editEntry:item];
       default:
            break;
    }
}

- (void)copyTitle:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.title node:item]];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_title_copied_fmt", @"'%@' Title Copied"), [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)copyUrl:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.url node:item]];

    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_url_copied_fmt", @"'%@' URL Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)copyEmail:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.email node:item]];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_email_copied_fmt", @"'%@' Email Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)copyNotes:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.notes node:item]];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_notes_copied_fmt", @"'%@' Notes Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)copyUsername:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.username node:item]];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_username_copied_fmt", @"'%@' Username Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
    
    NSLog(@"Fast Username Copy on %@", item.title);
}

- (void)copyTotp:(Node*)item {
    if(!item.fields.otpToken) {
        [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_no_totp_to_copy_fmt", @"'%@': No TOTP setup to Copy!"),
                                            [self dereference:item.title node:item]]
                                   message:nil
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeWarning
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];

        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:item.fields.otpToken.password];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_totp_copied_fmt", @"'%@' TOTP Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
    
    NSLog(@"Fast TOTP Copy on %@", item.title);
    
}

- (void)copyPassword:(Node *)item {
    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item]];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:copyTotp ?
                                        NSLocalizedString(@"browse_vc_totp_copied_fmt", @"'%@' OTP Code Copied") :
                                        NSLocalizedString(@"browse_vc_password_copied_fmt", @"'%@' Password Copied"),
                                        [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text = @"";
    
    if(self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList) {
        text = NSLocalizedString(@"browse_vc_view_as_totp_no_totps", @"View As: TOTP List (No TOTP Entries)");
    }
    else if(self.searchController.isActive) {
        text = NSLocalizedString(@"browse_vc_view_search_no_matches", @"No matching entries found");
    }
    else {
        text = NSLocalizedString(@"browse_vc_view_as_database_empty", @"No Entries");
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (void)killOtpTimer {
    if(self.timerRefreshOtp) {
        NSLog(@"Kill Central OTP Timer");
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (void)startOtpRefresh {
    NSLog(@"Start Central OTP Timer");
    
    self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:[BrowseSafeView class] selector:@selector(updateOtpCodes) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
}

+ (void)updateOtpCodes { // Keep Static to avoid retain cycle
    [NSNotificationCenter.defaultCenter postNotificationName:kCentralUpdateOtpUiNotification object:nil];
}

@end
