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
#import "NSString+Extensions.h"
#import "BrowsePreferencesTableViewController.h"
#import "CASGTableViewController.h"
#import "YubiManager.h"
#import "OpenSafeSequenceHelper.h"
#import "PreviewItemViewController.h"
#import "LargeTextViewController.h"
#import "UITableView+EmptyDataSet.h"
#import "ItemPropertiesViewController.h"

static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating >

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonAddRecord;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonSafeSettings;
@property (strong, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonMove; 
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonDelete; 
@property UIBarButtonItem* moreiOS14Button;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSortItems;

@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;

@property (strong) SetNodeIconUiHelper* sni; 

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

    if(self.isMovingFromParentViewController) { 
        NSLog(@"isMovingFromParentViewController [%@]", self);

        [self unListenToNotifications];
        
        [self killOtpTimer];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
    
    if (@available(iOS 14.0, *)) {
        self.navigationController.toolbar.hidden = !self.isEditing;
        self.navigationController.toolbarHidden = !self.isEditing;
    }
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
            [self addSearchBarToNav]; 
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
    
    if (@available(iOS 13.0, *)) { 
        [self addSearchBarToNav];
    }
    
    if(self.currentGroup == self.viewModel.database.rootGroup) {
        
        
        
        [self addSearchBarToNav];
        
         
        [self startOtpRefresh];
        
        [self maybePromptToTryProFeatures];        
    }

    if (@available(iOS 13.0, *)) { 
        [self.buttonSafeSettings setImage:[UIImage systemImageNamed:@"gear"]];
    }
    
    
    
    if (@available(iOS 14.0, *)) {
        self.moreiOS14Button =  [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:nil];
        [self refreshiOS14MoreMenu];
        
        if (self.navigationItem.rightBarButtonItems) {
            NSMutableArray* rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
            
            [rightBarButtons insertObject:self.moreiOS14Button atIndex:0];
            
            self.navigationItem.rightBarButtonItems = rightBarButtons;
        }
        else {
            self.navigationItem.rightBarButtonItem = self.moreiOS14Button;
        }
        
        if (@available(iOS 14.0, *)) { 
            
            UIBarButtonItem* flexibleSpace1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem* flexibleSpace2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem* flexibleSpace3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

            NSArray *toolbarButtons = @[flexibleSpace1, self.buttonMove, flexibleSpace2, self.buttonDelete, flexibleSpace3];
            [self setToolbarItems:toolbarButtons animated:NO];
        }
    }
    else {
        

        if (self.navigationItem.rightBarButtonItems) {
            NSMutableArray* rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
            [rightBarButtons insertObject:self.editButtonItem atIndex:0];
            self.navigationItem.rightBarButtonItems = rightBarButtons;
        }
        else {
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
        }
    }
    
    [self refreshItems];
        
    [self listenToNotifications];
}

- (void)refreshiOS14MoreMenu {
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIMenuElement*>* ma0 = [NSMutableArray array];
        
        [ma0 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_new_entry", @"New Entry") systemImage:@"doc.badge.plus" destructive:NO enabled:!self.viewModel.isReadOnly checked:NO handler:^(__kindof UIAction * _Nonnull action) { [self onAddEntry]; }]];
        [ma0 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_new_group", @"New Group") systemImage:@"folder.badge.plus" destructive:NO enabled:!self.viewModel.isReadOnly checked:NO handler:^(__kindof UIAction * _Nonnull action) { [self onAddGroup]; }]];
        [ma0 addObject:[self getContextualMenuItem:NSLocalizedString(@"generic_select", @"Select") systemImage:@"checkmark.circle" destructive:NO enabled:!self.viewModel.isReadOnly checked:NO handler:^(__kindof UIAction * _Nonnull action) { [self setEditing:YES animated:YES]; }]];
        
        UIMenu* menu0 = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:ma0];

        

        NSMutableArray<UIMenuElement*>* ma15 = [NSMutableArray array];

        [ma15 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_prefs_view_as_folders", @"Hierarchy") systemImage:@"list.bullet.indent" destructive:NO enabled:YES checked:self.viewModel.metadata.browseViewType == kBrowseViewTypeHierarchy handler:^(__kindof UIAction * _Nonnull action) {  [self setViewType:kBrowseViewTypeHierarchy]; }]];
        [ma15 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_prefs_view_as_flat_list", @"Flat List") systemImage:@"list.bullet" destructive:NO enabled:YES checked:self.viewModel.metadata.browseViewType == kBrowseViewTypeList handler:^(__kindof UIAction * _Nonnull action) {   [self setViewType:kBrowseViewTypeList]; }]];
        [ma15 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_prefs_view_as_totp_list", @"TOTP View") systemImage:@"clock" destructive:NO enabled:YES checked:self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList handler:^(__kindof UIAction * _Nonnull action) {   [self setViewType:kBrowseViewTypeTotpList]; }]];

        UIMenu* menu15 = [UIMenu menuWithTitle:@""
                                         image:nil
                                    identifier:nil
                                       options:UIMenuOptionsDisplayInline
                                      children:ma15];

        
        
        NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
        
        [ma1 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_start_with_search", @"Start with Search") systemImage:@"magnifyingglass" destructive:NO enabled:YES checked:self.viewModel.metadata.immediateSearchOnBrowse handler:^(__kindof UIAction * _Nonnull action) { [self toggleStartWithSearch]; }]];

        [ma1 addObject:[self getContextualMenuItem:NSLocalizedString(@"generic_sort", @"Sort") systemImage:@"arrow.up.arrow.down" destructive:NO handler:^(__kindof UIAction * _Nonnull action) {
            BOOL ro = self.viewModel.isReadOnly;
            BOOL enabled = !self.isEditing || (!ro && self.isEditing && self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone);
                    
            if (enabled) {
                [self onSortItems:nil];
            }
        }]];

        [ma1 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View") systemImage:@"list.dash" destructive:NO handler:^(__kindof UIAction * _Nonnull action) {  [self performSegueWithIdentifier:@"segueToCustomizeView" sender:nil]; }]];
        
        UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:ma1];

        
        
        NSMutableArray<UIMenuElement*>* ma2 = [NSMutableArray array];

        
        [ma2 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_database_settings", @"Database Settings") systemImage:@"gear" destructive:NO handler:^(__kindof UIAction * _Nonnull action) { [self onDatabasePreferences:nil]; }]];
        
        [ma2 addObject:[self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_set_master_credentials", @"Set Master Credentials") systemImage:@"ellipsis.rectangle" destructive:NO enabled:!self.viewModel.isReadOnly checked:NO handler:^(__kindof UIAction * _Nonnull action) {  [self performSegueWithIdentifier:@"segueToChangeMasterCredentials" sender:nil]; }]];
        
        [ma2 addObject:[self getContextualMenuItem:NSLocalizedString(@"generic_export", @"Export") systemImage:@"square.and.arrow.up" destructive:NO handler:^(__kindof UIAction * _Nonnull action) {  [self onExport:nil]; }]];
        

        UIMenu* menu2 = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:ma2];

        
        UIMenu* menu = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:kNilOptions
                                    children:@[menu0, menu1, menu15, menu2]];

        self.moreiOS14Button.menu = menu;
    }
}

- (void)setViewType:(BrowseViewType)viewType {
    self.viewModel.metadata.browseViewType = viewType;
    
    [SafesList.sharedInstance update:self.viewModel.metadata];
    
    [self refreshItems];
    
    if (@available(iOS 14.0, *)) {
        [self refreshiOS14MoreMenu];
    }
}

- (void)toggleStartWithSearch {
    self.viewModel.metadata.immediateSearchOnBrowse = !self.viewModel.metadata.immediateSearchOnBrowse;
    
    [SafesList.sharedInstance update:self.viewModel.metadata];
    
    if (@available(iOS 14.0, *)) {
        [self refreshiOS14MoreMenu];
    }
}

- (IBAction)onExport:(id)sender {
    [self.viewModel encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled) {
            
        }
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
    
    

    activityViewController.popoverPresentationController.barButtonItem = self.moreiOS14Button ? self.moreiOS14Button : self.exportBarButton;

    
    
    
    
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
    
    if (numNote.boolValue) { 
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
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self showAuditPopup:issueCount.unsignedLongValue lastKnownAuditIssueCount:lastKnownAuditIssueCount];
            });
        }
    }
    
    [self refreshItems]; 
}

- (void)showAuditPopup:(NSUInteger)issueCount lastKnownAuditIssueCount:(NSNumber*)lastKnownAuditIssueCount {
    NSLog(@"showAuditPopup... [%@] = [%ld/%@]", self, (unsigned long)issueCount, lastKnownAuditIssueCount);
    
    if (lastKnownAuditIssueCount == nil) { 
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
    
    
    if(SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
        return;
    }

    

    const NSUInteger kProNudgeIntervalDays = 14;
    NSDate* dueDate = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:kProNudgeIntervalDays toDate:Settings.sharedInstance.lastFreeTrialNudge options:kNilOptions];
    
    BOOL nudgeDue = dueDate.timeIntervalSinceNow < 0; 
    
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

    self.navigationItem.title = [NSString stringWithFormat:@"%@%@",
                                 (self.currentGroup.parent == nil) ?
                                 self.viewModel.metadata.nickName : self.currentGroup.title,
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

- (void)updateToolbarButtonsState {
    [self.closeBarButton setTitle:self.isEditing ? NSLocalizedString(@"generic_cancel", @"Cancel") : self.originalCloseTitle];

    BOOL ro = self.viewModel.isReadOnly;
    BOOL moveAndDeleteEnabled = (!ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0);

    self.buttonMove.enabled = moveAndDeleteEnabled;
    self.buttonDelete.enabled = moveAndDeleteEnabled;

    if (@available(iOS 14.0, *)) { 
        self.navigationController.toolbar.hidden = !self.editing;
        self.navigationController.toolbarHidden = !self.editing;
        self.navigationItem.rightBarButtonItems = self.editing ? @[self.editButtonItem] : @[self.moreiOS14Button];
    }
    else {
        self.buttonAddRecord.enabled = !ro && !self.isEditing;
        self.buttonSafeSettings.enabled = !self.isEditing;
        self.buttonSortItems.enabled = !self.isEditing ||
        (!ro && self.isEditing && self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone);

        UIImage* sortImage = self.isEditing ? [UIImage imageNamed:self.sortOrderForAutomaticSortDuringEditing ? @"sort-desc" : @"sort-asc"] : [UIImage imageNamed:self.viewModel.metadata.browseSortOrderDescending ? @"sort-desc" : @"sort-asc"];
        [self.buttonSortItems setImage:sortImage];
    }
}

-(void)insertToolbarButton:(UIBarButtonItem*)button index:(NSUInteger)index {
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if (![toolbarButtons containsObject:button]) {
        [toolbarButtons insertObject:button atIndex:index];
        [self setToolbarItems:toolbarButtons animated:NO];
    }
}

-(void)addToolbarButton:(UIBarButtonItem*)button {
    NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];

    if (![toolbarButtons containsObject:button]) {
        [toolbarButtons addObject:button];
        [self setToolbarItems:toolbarButtons animated:NO];
    }
}

-(void)removeToolbarButton:(UIBarButtonItem*)button {
    if (button) {
        NSMutableArray *toolbarButtons = [self.toolbarItems mutableCopy];
        [toolbarButtons removeObject:button];
        [self setToolbarItems:toolbarButtons animated:NO];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
    NSLog(@"setEditing: %d", editing);
    
    [self updateToolbarButtonsState];
    
    if (!editing) {
        if(self.reorderItemOperations) {
            
            NSLog(@"Reordering...");
            
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
    else {
        if (![self isUsingLegacyUi]) {
            self.navigationItem.prompt = NSLocalizedString(@"hint_tap_and_hold_to_see_options", @"TIP: Tap and hold item to see options");
        }
        else {
            

            if ((!self.currentGroup || self.currentGroup.parent == nil)) {
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
    }
}

- (BOOL)isUsingLegacyUi {
    if (@available(iOS 13.0, *)) {
        return NO;
    }
    else {
        return YES;
    }
}

- (void)setupTableview {
    self.configuredDataSource = [[ConfiguredBrowseTableDatasource alloc] initWithModel:self.viewModel isDisplayingRootGroup:[self isDisplayingRootGroup] tableView:self.tableView];
    self.searchDataSource = [[SearchResultsBrowseTableDatasource alloc] initWithModel:self.viewModel tableView:self.tableView];
    self.quickViewsDataSource = [[QuickViewsBrowseTableDataSource alloc] initWithModel:self.viewModel tableView:self.tableView];
        
    if ([self isUsingLegacyUi]) {
        self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                    initWithTarget:self
                                    action:@selector(handleLongPress:)];
        self.longPressRecognizer.minimumPressDuration = 1;
        self.longPressRecognizer.cancelsTouchesInView = YES;
        [self.tableView addGestureRecognizer:self.longPressRecognizer];
    }
            
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
    return self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone && self.viewModel.metadata.browseViewType == kBrowseViewTypeHierarchy;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        if(self.reorderItemOperations == nil) {
            self.reorderItemOperations = [NSMutableArray array];
        }
        [self.reorderItemOperations addObject:@[@(sourceIndexPath.row), @(destinationIndexPath.row)]];

        [self updateToolbarButtonsState]; 
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  
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
                self.reorderItemOperations = nil; 
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
        if(response) {
            if ([self.viewModel.database setItemTitle:item title:text]) {
                [self saveChangesToSafeAndRefreshView];
            }
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
                [self.viewModel.database setNodeCustomIconUuid:item uuid:userSelectedExistingCustomIconId rationalize:YES];
            }
            else if(userSelectedNewIconIndex) {
                [self.viewModel.database setNodeIconId:item iconId:userSelectedNewIconIndex rationalize:YES];
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
        
        [self setCustomIcon:item image:selected.allValues.firstObject];
    }
}

- (void)setCustomIcon:(Node*)item image:(UIImage*)image {
    NSData *data = UIImagePNGRepresentation(image);
    
    [self.viewModel.database setNodeCustomIcon:item data:data rationalize:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)){
    return [self isUsingLegacyUi] ? [self getLegacyRightSlideActions:indexPath] : [self getRightSlideActions:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)) {
    return [self isUsingLegacyUi] ? [self getLegacyLeftSlideActions:indexPath] : [self getLeftSlideActions:indexPath];
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

- (UISwipeActionsConfiguration *)getLegacyRightSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    UIContextualAction* pinAction = [self getPinAction:indexPath];
    UIContextualAction* auditAction = [self getAuditAction:indexPath];

    Node *item = [self getNodeFromIndexPath:indexPath];

    return [UISwipeActionsConfiguration configurationWithActions:item.isGroup ? @[pinAction] : @[auditAction, pinAction]];
}

- (UISwipeActionsConfiguration *)getLegacyLeftSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
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

    if(!self.viewModel.isReadOnly) {
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

- (UISwipeActionsConfiguration *)getRightSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    Node *item = [self getNodeFromIndexPath:indexPath];

    UIContextualAction* copyPassword = [self getCopyPasswordSlideAction:indexPath];
    UIContextualAction* copyUsername = [self getCopyUsernameSlideAction:indexPath];

    NSMutableArray* actions = @[copyUsername, copyPassword].mutableCopy;

    NSURL* url = [self getLaunchUrlForItem:item];
    if (url) {
        UIContextualAction* copyAndLaunch = [self getCopyAndLaunchSlideAction:indexPath];
        [actions addObject:copyAndLaunch];
    }
    
    UISwipeActionsConfiguration* ret = item.isGroup ? [self getLegacyRightSlideActions:indexPath] : [UISwipeActionsConfiguration configurationWithActions:actions];
    ret.performsFirstActionWithFullSwipe = YES;
    
    return ret;
}

- (UISwipeActionsConfiguration *)getLeftSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    Node *item = [self getNodeFromIndexPath:indexPath];

    UIContextualAction* copyPassword = [self getCopyPasswordSlideAction:indexPath];
    UIContextualAction* copyUsername = [self getCopyUsernameSlideAction:indexPath];
    
    NSMutableArray* actions = @[copyPassword, copyUsername].mutableCopy;
    
    if (item.fields.otpToken) {
        UIContextualAction* copyTotp = [self getCopyTotpSlideAction:indexPath];
        [actions addObject:copyTotp];
    }
    
    UISwipeActionsConfiguration* ret = item.isGroup ? [self getLegacyLeftSlideActions:indexPath] : [UISwipeActionsConfiguration configurationWithActions:actions];
    ret.performsFirstActionWithFullSwipe = YES;
    
    return ret;
}

- (UIContextualAction*)getCopyAndLaunchSlideAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_prefs_tap_action_copy_and_launch", @"Copy & Launch")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self copyAndLaunch:item];
        completionHandler(YES);
    }];

    action.backgroundColor = UIColor.systemOrangeColor;
    
    return action;
}

- (UIContextualAction*)getCopyTotpSlideAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self copyTotp:item];
        completionHandler(YES);
    }];

    action.backgroundColor = UIColor.systemOrangeColor;
    
    return action;
}

- (UIContextualAction*)getCopyPasswordSlideAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self copyPassword:item];
        completionHandler(YES);
    }];

    action.backgroundColor = UIColor.systemBlueColor;
    
    return action;
}

- (UIContextualAction*)getCopyUsernameSlideAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self copyUsername:item];
        completionHandler(YES);
    }];

    action.backgroundColor = UIColor.systemPurpleColor;
    
    return action;
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
    
    if(!self.viewModel.isReadOnly) {
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

- (void)duplicateItem:(Node*)item {
    [self duplicateItem:item completion:nil];
}

- (void)duplicateItem:(Node*)item completion:(void (^)(BOOL actionPerformed))completion {
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
    
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeSettings"]);
}




- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if (!searchController.searchBar.text.length) {
        [self.quickViewsDataSource refresh]; 
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
        
        self.editButtonItem.enabled = !self.viewModel.isReadOnly;
    }
    
    [self updateToolbarButtonsState];
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
    NSInteger sections = [self getTableDataSource].sections;
    
    return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger sections = [self getTableDataSource].sections;
    NSInteger totalRows = 0;
    for (int i=0; i<sections; i++) {
        totalRows += [[self getTableDataSource] rowsForSection:i];
    }
    
    if (totalRows == 0) {
        [self.tableView setEmptyTitle:[self getTitleForEmptyDataSet]];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }

    NSInteger ret = [[self getTableDataSource] rowsForSection:section];
    
    return ret;
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
    
    
    
    if ( ![self isUsingLegacyUi] ) {
        if (self.editing) {
            [self updateToolbarButtonsState]; 
            return;
        }

        Node *item = [self getNodeFromIndexPath:indexPath];
        
        if (item) {
            if(item.isGroup) {
                [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item];
            }
            else {
                [self performTapAction:item action:self.viewModel.metadata.tapAction];
            }
        }
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else {
        [self handleLegacyDidSelectRowAtIndexPath:indexPath];
    }
}

- (void)openDetails:(Node*)item {
    if (item) {
        if(item.isGroup) {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item];
        }
        else {
            [self openEntryDetails:item];
        }
    }
}

- (void)handleLegacyDidSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.viewModel.metadata.doubleTapAction == kBrowseTapActionNone && self.viewModel.metadata.tripleTapAction == kBrowseTapActionNone) { 
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
        
        self.tapCount = self.tapCount + 1;
        self.tappedIndexPath = indexPath;
        NSLog(@"Got tap... waiting...");
        self.tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
    }
    else if(![self.tappedIndexPath isEqual:indexPath]){
        
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
        vc.readOnly = self.viewModel.isReadOnly;
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
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
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
        vc.readOnly = self.viewModel.isReadOnly;
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
        vc.onDone = ^(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nonnull error) {
            [self onUpdateDone:userCancelled conflictAndLocalWasChanged:conflictAndLocalWasChanged error:error];
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
            [self refreshiOS14MoreMenu];
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
    else if ([segue.identifier isEqualToString:@"segueToCustomizeView"]){
        UINavigationController* nav = segue.destinationViewController;
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)nav.topViewController;
        vc.databaseMetaData = self.viewModel.metadata;
        vc.format = self.viewModel.database.format;
        
        vc.onDone = ^{
            [self refreshiOS14MoreMenu];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToChangeMasterCredentials"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        scVc.mode = kCASGModeSetCredentials;
        scVc.initialFormat = self.viewModel.database.format;
        scVc.initialKeyFileBookmark = self.viewModel.metadata.keyFileBookmark;
        scVc.initialYubiKeyConfig = self.viewModel.metadata.contextAwareYubiKeyConfig;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                        [self setCredentials:creds.password
                             keyFileBookmark:creds.keyFileBookmark
                          oneTimeKeyFileData:creds.oneTimeKeyFileData
                                  yubiConfig:creds.yubiKeyConfig];
                }
            }];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueBrowseToLargeTextView"] ) {
        LargeTextViewController* vc = segue.destinationViewController;
        
        
        NSDictionary* d = sender;
        vc.string = d[@"text"];
        vc.colorize = ((NSNumber*)(d[@"colorize"])).boolValue;
    }
    else if ( [segue.identifier isEqualToString:@"segueToItemProperties"] ) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        ItemPropertiesViewController* vc = (ItemPropertiesViewController*)nav.topViewController;
        vc.model = self.viewModel;
        vc.item = sender;
    }
}



- (void)setCredentials:(NSString*)password
       keyFileBookmark:(NSString*)keyFileBookmark
    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    CompositeKeyFactors *newCkf = [[CompositeKeyFactors alloc] initWithPassword:password];
    
    
    
    if(keyFileBookmark != nil || oneTimeKeyFileData != nil) {
        NSError* error;
        NSData* keyFileDigest = getKeyFileDigest(keyFileBookmark, oneTimeKeyFileData, self.viewModel.database.format, &error);
        
        if(keyFileDigest == nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"db_management_error_title_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
            return;
        }
        
        newCkf.keyFileDigest = keyFileDigest;
    }

    
    
    if (yubiConfig && yubiConfig.mode != kNoYubiKey) {
        newCkf.yubiKeyCR = ^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [YubiManager.sharedInstance getResponse:yubiConfig challenge:challenge completion:completion];
        };
    }

    CompositeKeyFactors *rollbackCkf = [self.viewModel.database.compositeKeyFactors clone];
    self.viewModel.database.compositeKeyFactors.password = newCkf.password;
    self.viewModel.database.compositeKeyFactors.keyFileDigest = newCkf.keyFileDigest;
    self.viewModel.database.compositeKeyFactors.yubiKeyCR = newCkf.yubiKeyCR;
    
    [self.viewModel update:self
                   handler:^(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nullable error) {
        if (userCancelled || error || conflictAndLocalWasChanged) {
            
            self.viewModel.database.compositeKeyFactors.password = rollbackCkf.password;
            self.viewModel.database.compositeKeyFactors.keyFileDigest = rollbackCkf.keyFileDigest;
            self.viewModel.database.compositeKeyFactors.yubiKeyCR = rollbackCkf.yubiKeyCR;
        
            if (error) {
                [Alerts error:self
                        title:NSLocalizedString(@"db_management_couldnt_change_credentials", @"Could not change credentials")
                        error:error];
            }
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onSuccessfulCredentialsChanged:keyFileBookmark oneTimeKeyFileData:oneTimeKeyFileData yubiConfig:yubiConfig];
            });
        }
    }];
}

- (void)onSuccessfulCredentialsChanged:(NSString*)keyFileBookmark
                    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    if (self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForConvenience) {
        if(!oneTimeKeyFileData) {
            self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
            NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
        }
        else {
            
            self.viewModel.metadata.convenienceMasterPassword = nil;
            self.viewModel.metadata.isEnrolledForConvenience = NO;
        }
    }
    
    self.viewModel.metadata.keyFileBookmark = keyFileBookmark;
    self.viewModel.metadata.contextAwareYubiKeyConfig = yubiConfig;
    [SafesList.sharedInstance update:self.viewModel.metadata];

    [ISMessages showCardAlertWithTitle:self.viewModel.database.format == kPasswordSafe ?
     NSLocalizedString(@"db_management_password_changed", @"Master Password Changed") :
     NSLocalizedString(@"db_management_credentials_changed", @"Master Credentials Changed")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}



- (void)showAllAuditIssues { 
    
    [self.searchController.searchBar becomeFirstResponder];
    
    self.searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
    self.searchController.searchBar.text = kSpecialSearchTermAuditEntries;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.searchController.searchBar endEditing:YES]; 
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

- (void)onAddEntry {
    [self showEntry:nil editImmediately:YES];
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
            [self onAddEntry];
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
    if(item) { 
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
    else { 
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
        else { 
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
    
    [self.viewModel update:self
                   handler:^(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nullable error) {
        [self onUpdateDone:userCancelled conflictAndLocalWasChanged:conflictAndLocalWasChanged error:error];
    }];
}

- (void)onUpdateDone:(BOOL)userCancelled conflictAndLocalWasChanged:(BOOL)conflictAndLocalWasChanged error:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if (userCancelled) {
            [self dismissViewControllerAnimated:YES completion:nil]; 
        }
        else if (conflictAndLocalWasChanged) {
            [Alerts info:self
                   title:NSLocalizedString(@"db_management_reopen_required_title", @"Re-Open Required")
                 message:NSLocalizedString(@"db_management_reopen_required_message", @"You must close and reopen this database for changes to take effect.")
              completion:^{
                [self dismissViewControllerAnimated:YES completion:nil]; 
            }];
        }
        else if (error) {
            [Alerts error:self
                    title:NSLocalizedString(@"browse_vc_error_saving", @"Error Saving")
                    error:error
               completion:^{
                [self dismissViewControllerAnimated:YES completion:nil]; 
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
}



- (void)handleSingleTap:(NSIndexPath *)indexPath  {
    if (self.editing) {
        [self updateToolbarButtonsState]; 
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



- (void)performTapAction:(Node*)item action:(BrowseTapAction)action {
    switch (action) {
        case kBrowseTapActionNone:
            
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



- (NSAttributedString *)getTitleForEmptyDataSet {
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

+ (void)updateOtpCodes { 
    [NSNotificationCenter.defaultCenter postNotificationName:kCentralUpdateOtpUiNotification object:nil];
}





- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    if (self.isEditing || [self isShowingQuickViews]) {
        return nil;
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item) {
        return nil;
    }

    return [UIContextMenuConfiguration configurationWithIdentifier:indexPath
                                                   previewProvider:^UIViewController * _Nullable{ return item.isGroup ? nil : [PreviewItemViewController forItem:item andModel:self.viewModel];   }
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:@[
                                [self getContextualMenuNonMutators:indexPath item:item],
                                [self getContextualMenuCopyToClipboard:indexPath item:item],
                                [self getContextualMenuCopyFieldToClipboard:indexPath item:item],
                                [self getContextualMenuMutators:indexPath item:item],
                            ]];
    }];
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    Node *item = [self getNodeFromIndexPath:(NSIndexPath*)configuration.identifier];
    [self openDetails:item];
}

- (UIMenu*)getContextualMenuNonMutators:(NSIndexPath*)indexPath item:(Node*)item  API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    
    
    [ma addObject:[self getContextualMenuTogglePinAction:indexPath item:item]];
    if (!item.isGroup) [ma addObject:[self getContextualMenuAuditSettingsAction:indexPath item:item]];
    if (item.fields.password.length) [ma addObject:[self getContextualMenuShowLargePasswordAction:indexPath item:item]];
    
    [ma addObject:[self getContextualMenuPropertiesAction:indexPath item:item]];
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuPropertiesAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"browse_vc_action_properties", @"Properties")
                           systemImage:@"list.bullet"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToItemProperties" sender:item];
    }];
}

- (UIMenu*)getContextualMenuCopyToClipboard:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    
    
    if ( !item.isGroup && item.fields.username.length ) [ma addObject:[self getContextualMenuCopyUsernameAction:indexPath item:item]];

    

    if ( !item.isGroup ) [ma addObject:[self getContextualMenuCopyPasswordAction:indexPath item:item]];

    

    if (!item.isGroup && item.fields.otpToken) [ma addObject:[self getContextualMenuCopyTotpAction:indexPath item:item]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIMenu*)getContextualMenuCopyFieldToClipboard:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if ( !item.isGroup ) [ma addObject:[self getContextualMenuCopyToClipboardSubmenu:indexPath item:item]];

    return [UIMenu menuWithTitle:NSLocalizedString(@"browse_context_menu_copy_other_field", @"Copy Other Field...")
                           image:nil
                      identifier:nil
                         options:kNilOptions
                        children:ma];
}

- (UIMenuElement*)getContextualMenuCopyToClipboardSubmenu:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if ( !item.isGroup ) {
        
        
        if ( item.fields.username.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_username" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [self copyUsername:item];
            }]];
        }
        
        

        [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_password" item:item handler:^(__kindof UIAction * _Nonnull action) {
            [self copyPassword:item];
        }]];
        
        

        if (item.fields.otpToken) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_totp" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [self copyTotp:item];
            }]];
        }
     
        
        
        NSURL* launchUrl = [self getLaunchUrlForItem:item];
        
        if ( launchUrl ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_url" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [self copyUrl:item];
            }]];
        }
        
        

        if (self.viewModel.database.format == kPasswordSafe && item.fields.email.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_email" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [self copyEmail:item];
            }]];
        }
        
        

        if (item.fields.notes.length) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_notes" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [self copyNotes:item];
            }]];
        }
        
        
        
        if ( launchUrl ) {
            [ma addObject:[UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:nil
                                        options:UIMenuOptionsDisplayInline
                                       children:@[[self getContextualMenuLaunchAndCopyAction:indexPath item:item]]]];
        }

        
        
        NSMutableArray* customFields = [NSMutableArray array];
        NSArray* sortedKeys = [item.fields.customFields.allKeys sortedArrayUsingComparator:finderStringComparator];
        for(NSString* key in sortedKeys) {
            if ( ![NodeFields isTotpCustomFieldKey:key] ) {
                [customFields addObject:[self getContextualMenuGenericCopy:key item:item handler:^(__kindof UIAction * _Nonnull action) {
                    StringValue* sv = item.fields.customFields[key];
                    
                    NSString* value = [self dereference:sv.value node:item];
                    
                    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
                    
                    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), key]
                                               message:nil
                                              duration:3.f
                                           hideOnSwipe:YES
                                             hideOnTap:YES
                                             alertType:ISAlertTypeSuccess
                                         alertPosition:ISAlertPositionTop
                                               didHide:nil];
                }]];
            }
        }
        
        if (customFields.count) {
            [ma addObject:[UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:nil
                                        options:UIMenuOptionsDisplayInline
                                       children:customFields]];
        }
    }

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIMenu*)getContextualMenuMutators:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    if(!self.viewModel.isReadOnly) {
        

        if ( self.viewModel.database.format != kPasswordSafe ) {
            [ma addObject:[self getContextualMenuSetIconAction:indexPath item:item]];
        }
  
        

        if(!item.isGroup) {
            [ma addObject:[self getContextualMenuDuplicateAction:indexPath item:item]];
        }
    
        
        
        [ma addObject:[self getContextualMenuRenameAction:indexPath item:item]];

        
    
        [ma addObject:[self getContextualMenuMoveAction:indexPath item:item]];
    
        
        
        [ma addObject:[self getContextualMenuRemoveAction:indexPath item:item]];
    }
        
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}



- (UIAction*)getContextualMenuTogglePinAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    BOOL pinned = [self.viewModel isPinned:item];
    NSString* title = pinned ? NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") : NSLocalizedString(@"browse_vc_action_pin", @"Pin");

    return [self getContextualMenuItem:title
                           systemImage:pinned ? @"pin.slash" : @"pin"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
         [self togglePinEntry:item];
    }];
}

- (UIAction*)getContextualMenuAuditSettingsAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                           systemImage:@"checkmark.shield"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self showAuditDrillDown:item];
    }];
}

- (UIAction*)getContextualMenuShowLargePasswordAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    return [self getContextualMenuItem:NSLocalizedString(@"browse_context_menu_show_password", @"Show Password")
                           systemImage:@"eye"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        NSString* pw = [self dereference:item.fields.password node:item];
        [self performSegueWithIdentifier:@"segueBrowseToLargeTextView" sender:@{ @"text" : pw, @"colorize" : @(self.viewModel.metadata.colorizePasswords) }];
    }];
}

- (UIAction*)getContextualMenuCopyUsernameAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                           systemImage:@"doc.on.doc"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self copyUsername:item];
    }];
}

- (UIAction*)getContextualMenuCopyPasswordAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                           systemImage:@"doc.on.doc"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self copyPassword:item];
    }];
}

- (UIAction*)getContextualMenuCopyTotpAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                           systemImage:@"doc.on.doc"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self copyTotp:item];
    }];
}

- (UIAction*)getContextualMenuLaunchAndCopyAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(@"browse_action_launch_url_copy_password", @"Launch URL & Copy")
                           systemImage:@"bolt"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self copyAndLaunch:item];
    }];
}

- (UIAction*)getContextualMenuGenericCopy:(NSString*)locKey item:(Node*)item handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:NSLocalizedString(locKey, nil)
                           systemImage:@"doc.on.doc"
                           destructive:NO
                               handler:handler];
}

- (UIAction*)getContextualMenuSetIconAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") : NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon");
    
    return [self getContextualMenuItem:title
                           systemImage:@"photo"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self onSetIconForItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuDuplicateAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate");
        
    return [self getContextualMenuItem:title
                           systemImage:@"plus.square.on.square"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self duplicateItem:item completion:nil];
    }];
}

- (UIAction*)getContextualMenuRenameAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"browse_vc_action_rename", @"Rename");
        
    return [self getContextualMenuItem:title
                           systemImage:@"pencil"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self onRenameItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuMoveAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"generic_move", @"Move");
        
    return [self getContextualMenuItem:title
                           systemImage:@"arrow.up.doc"
                           destructive:NO
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"segueToSelectDestination" sender:@[item]];
    }];
}

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"browse_vc_action_delete", @"Delete");
            
    return [self getContextualMenuItem:title
                           systemImage:@"trash"
                           destructive:YES
                               handler:^(__kindof UIAction * _Nonnull action) {
        [self onDeleteSingleItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0))  {
    return [self getContextualMenuItem:title systemImage:systemImage destructive:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage destructive:(BOOL)destructive handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0))  {
    return [self getContextualMenuItem:title systemImage:systemImage destructive:destructive enabled:YES checked:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage destructive:(BOOL)destructive enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler
  API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:title
                                 image:[UIImage systemImageNamed:systemImage]
                           destructive:destructive
                               enabled:enabled
                               checked:checked
                               handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title image:(UIImage*)image destructive:(BOOL)destructive handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0)) {
    return [self getContextualMenuItem:title image:image destructive:destructive enabled:YES checked:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title image:(UIImage*)image destructive:(BOOL)destructive enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler
  API_AVAILABLE(ios(13.0)) {
    UIAction *ret = [UIAction actionWithTitle:title
                                        image:image
                                   identifier:nil
                                      handler:handler];
    
    if (destructive) {
        ret.attributes = UIMenuElementAttributesDestructive;
    }
        
    if (!enabled) {
        ret.attributes = UIMenuElementAttributesDisabled;
    }
    
    if (checked) {
        ret.state = UIMenuElementStateOn;
    }
    
    return ret;
}



- (NSURL*)getLaunchUrlForItem:(Node*)item {
    NSString* urlString = [self dereference:item.fields.url node:item];

    if (!urlString.length) {
        return nil;
    }
        
    if (![urlString.lowercaseString hasPrefix:@"http:
        ![urlString.lowercaseString hasPrefix:@"https:
        urlString = [NSString stringWithFormat:@"http:
    }
    
    return urlString.urlExtendedParse;
}

- (void)copyAndLaunch:(Node*)item {
    NSURL* url = [self getLaunchUrlForItem:item];
    
    if (url) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self copyPassword:item];

            if (@available (iOS 10.0, *)) {
                [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
            }
            else {
                [UIApplication.sharedApplication openURL:url];
            }
        });
    }
}




- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    if (@available(iOS 13.0, *)) {
        return @[[UIKeyCommand commandWithTitle:NSLocalizedString(@"browse_vc_action_keyboard_shortcut_find", @"Find")
                                          image:nil
                                         action:@selector(onKeyCommandFind:)
                                          input:@"F"
                                  modifierFlags:UIKeyModifierCommand
                                   propertyList:nil]];
    }
    else {
        return @[];
    }
}

- (void)onKeyCommandFind:(id)param {
    [self.searchController.searchBar becomeFirstResponder];
}

@end
