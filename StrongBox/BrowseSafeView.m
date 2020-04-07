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
#import <ISMessages/ISMessages.h>
#import "Settings.h"
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

const NSUInteger kSectionIdxPinned = 0;
const NSUInteger kSectionIdxNearlyExpired = 1;
const NSUInteger kSectionIdxExpired = 2;
const NSUInteger kSectionIdxLast = 3;

static NSString* const kBrowseItemCell = @"BrowseItemCell";
static NSString* const kBrowseItemTotpCell = @"BrowseItemTotpCell";
static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, DZNEmptyDataSetSource>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *standardItemsCache;
@property (strong, nonatomic) NSArray<Node*> *pinnedItemsCache;
@property (strong, nonatomic) NSArray<Node*> *expiredItemsCache;
@property (strong, nonatomic) NSArray<Node*> *nearlyExpiredItemsCache;

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
@property NSTimer* timerRefreshOtp;

@end

@implementation BrowseSafeView

- (void)dealloc {
    [self killOtpTimer];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if(self.isMovingFromParentViewController) { // Kill
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
        
        [self maybeShowNagScreen];
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

- (void)listenToNotifications {
    if(self.splitViewController) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showDetailTargetDidChange:) name:UIViewControllerShowDetailTargetDidChangeNotification object:self.splitViewController];
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseViewPreferencesChanged:)
                                               name:kDatabaseViewPreferencesChangedNotificationKey
                                             object:nil];
}

- (void)onDatabaseViewPreferencesChanged:(id)param {
    [self refreshItems];
}

- (void)maybeShowNagScreen {
    if([Settings.sharedInstance isPro]) {
        return;
    }

    NSInteger percentageChanceOfShowing;
    NSInteger freeTrialDays = Settings.sharedInstance.freeTrialDaysLeft; // TODO: What if user has not opted in? If install date > 60 -> nag

    if(freeTrialDays > 40) {
        NSLog(@"More than 40 days left in free trial... not showing Nag Screen");
        return;
    }
    else if(Settings.sharedInstance.isFreeTrial) {
        percentageChanceOfShowing = 10;
    }
    else {
        percentageChanceOfShowing = 20;
    }

    NSInteger random = arc4random_uniform(100);

    //NSLog(@"Random: %ld", (long)random);

    if(random < percentageChanceOfShowing) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
        });
    }
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
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    
    if (!Settings.sharedInstance.hideTips && (!self.currentGroup || self.currentGroup.parent == nil)) {
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
    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];
    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemTotpCell bundle:nil] forCellReuseIdentifier:kBrowseItemTotpCell];

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
    MasterDetailViewController* master = (MasterDetailViewController*)self.splitViewController;
    [master onClose];
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

            [item touch:YES touchParents:YES];

            [self saveChangesToSafeAndRefreshView];
        }
        
        if(completion) {
            completion(response);
        }
    }];
}

- (void)onDeleteSingleItem:(NSIndexPath * _Nonnull)indexPath {
    [self onDeleteSingleItem:indexPath completion:nil];
}

- (void)onDeleteSingleItem:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    Node *item = [self getNodeFromIndexPath:indexPath];
    BOOL willRecycle = [self.viewModel deleteWillRecycle:item];

    [Alerts yesNo:self.searchController.isActive ? self.searchController : self
            title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
          message:[NSString stringWithFormat:willRecycle ?
                   NSLocalizedString(@"browse_vc_are_you_sure_recycle_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?") :
                   NSLocalizedString(@"browse_vc_are_you_sure_delete_fmt", @"Are you sure you want to permanently delete '%@'?"), [self dereference:item.title node:item]]
           action:^(BOOL response) {
                if (response) {
                    if(![self.viewModel deleteItem:item]) {
                        [Alerts warn:self
                               title:NSLocalizedString(@"browse_vc_delete_failed", @"Delete Failed")
                             message:NSLocalizedString(@"browse_vc_delete_error_message", @"There was an error trying to delete this item.")];
                    }
                    else {
                        if([self.viewModel isPinned:item]) {
                            // Also Unpin
                            [self togglePinEntry:item];
                        }

                        [self saveChangesToSafeAndRefreshView];
                    }
                }
                
                if (completion) {
                    completion(response);
                }
           }];
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
                [item touch:YES touchParents:YES];
                item.customIconUuid = userSelectedExistingCustomIconId;
            }
            else if(userSelectedNewIconIndex) {
                if(!item.isGroup) {
                    Node* originalNodeForHistory = [item cloneForHistory];
                    [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
                }
                [item touch:YES touchParents:YES];

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
    
    [item touch:YES touchParents:YES];

    NSData *data = UIImagePNGRepresentation(image);
    [self.viewModel.database setNodeCustomIcon:item data:data rationalize:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)){
    return [self getModernSlideActions:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)) {
    return [self getModernSlideActions:indexPath];
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
    renameAction.backgroundColor = UIColor.systemBlueColor;
    
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

    setIconAction.backgroundColor = UIColor.systemOrangeColor;

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

- (UISwipeActionsConfiguration *)getModernSlideActions:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    UIContextualAction* removeAction = [self getRemoveAction:indexPath];
    UIContextualAction* renameAction = [self getRenameAction:indexPath];
    UIContextualAction* setIconAction = [self getSetIconAction:indexPath];
    UIContextualAction* duplicateItemAction = [self getDuplicateItemAction:indexPath];
    UIContextualAction* pinAction = [self getPinAction:indexPath];
        
    if(!self.viewModel.isUsingOfflineCache && !self.viewModel.isReadOnly) {
        Node *item = [self getNodeFromIndexPath:indexPath];
        if(item.isGroup) {
            return self.viewModel.database.format != kPasswordSafe ?    [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, setIconAction, pinAction]] :
                                                                        [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, pinAction]];
        }
        else {
            return [UISwipeActionsConfiguration configurationWithActions:@[removeAction, duplicateItemAction, setIconAction, pinAction]];
        }
    }
    else {
        return [UISwipeActionsConfiguration configurationWithActions:@[pinAction]];
    }

    return [UISwipeActionsConfiguration configurationWithActions:@[removeAction]];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
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
    renameAction.backgroundColor = UIColor.systemBlueColor;
    
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
            return @[removeAction, duplicateItemAction, setIconAction, pinAction];
        }
    }
    else {
        return @[pinAction];
    }
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

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    self.searchResults = [searcher search:searchController.searchBar.text
                                    scope:(SearchScope)searchController.searchBar.selectedScopeButtonIndex
                              dereference:self.viewModel.metadata.searchDereferencedFields
                    includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                        includeRecycleBin:self.viewModel.metadata.showRecycleBinInSearchResults
                           includeExpired:self.viewModel.metadata.showExpiredInSearch
                            includeGroups:YES];
    
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

////////////////////////////////
// Data Sources

- (NSArray<Node*>*)loadPinnedItems {
    if(!self.viewModel.metadata.showQuickViewFavourites || !self.viewModel.pinnedSet.count) {
        return @[];
    }
    
    NSSet<NSString*> *set = self.viewModel.pinnedSet;
    
    NSArray<Node*>* pinned = [self.viewModel.database.rootGroup filterChildren:YES
                                                                     predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [node getSerializationId:self.viewModel.database.format != kPasswordSafe];
        return [set containsObject:sid];
    }];
    
    DatabaseSearchAndSorter *searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    return [searcher filterAndSortForBrowse:pinned.mutableCopy
                      includeKeePass1Backup:YES
                          includeRecycleBin:YES
                             includeExpired:YES
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadNearlyExpiredItems {
    if(!self.viewModel.metadata.showQuickViewNearlyExpired) {
        return @[];
    }
    
    NSArray<Node*>* ne = [self.viewModel.database.rootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.nearlyExpired;
    }];

    DatabaseSearchAndSorter *searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    return [searcher filterAndSortForBrowse:ne.mutableCopy
                      includeKeePass1Backup:NO
                          includeRecycleBin:NO
                             includeExpired:NO
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadExpiredItems {
    if(!self.viewModel.metadata.showQuickViewExpired) {
        return @[];
    }
    
    NSArray<Node*>* exp = [self.viewModel.database.rootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.expired;
    }];
    
    DatabaseSearchAndSorter *searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    return [searcher filterAndSortForBrowse:exp.mutableCopy
                      includeKeePass1Backup:NO
                          includeRecycleBin:NO
                             includeExpired:YES
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadStandardItems {
    NSArray<Node*>* ret;
    
    switch (self.viewModel.metadata.browseViewType) {
        case kBrowseViewTypeHierarchy:
            ret = self.currentGroup.children;
            break;
        case kBrowseViewTypeList:
            ret = self.currentGroup.allChildRecords;
            break;
        case kBrowseViewTypeTotpList:
            ret = [self.viewModel.database.rootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
                return obj.fields.otpToken != nil;
            }];
            break;
        default:
            break;
    }
    
    DatabaseSearchAndSorter *searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];
    
    return [searcher filterAndSortForBrowse:ret.mutableCopy
                      includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                          includeRecycleBin:!self.viewModel.metadata.doNotShowRecycleBinInBrowse
                             includeExpired:self.viewModel.metadata.showExpiredInBrowse
                              includeGroups:YES];
}

- (NSUInteger)getQuickViewRowCount {
    return [self getDataSourceForSection:kSectionIdxPinned].count +
    [self getDataSourceForSection:kSectionIdxNearlyExpired].count +
    [self getDataSourceForSection:kSectionIdxExpired].count;
}

- (NSArray<Node*>*)getDataSourceForSection:(NSUInteger)section {
    if(section == kSectionIdxPinned) {
        return self.pinnedItemsCache;
    }
    else if (section == kSectionIdxNearlyExpired) {
        return self.nearlyExpiredItemsCache;
    }
    else if (section == kSectionIdxExpired) {
        return self.expiredItemsCache;
    }
    else if(section == kSectionIdxLast) {
        return (self.searchController.isActive ? self.searchResults : self.standardItemsCache);
    }
    
    NSLog(@"EEEEEEK: WARNWARN: DataSource not found for section");
    return nil;
}

- (Node*)getNodeFromIndexPath:(NSIndexPath*)indexPath {
    NSArray<Node*>* dataSource = [self getDataSourceForSection:indexPath.section];
    
    if(!dataSource || indexPath.row >= dataSource.count) {
        NSLog(@"EEEEEK: WARNWARN - Should never happen but unknown node for indexpath: [%@]", indexPath);
        return nil;
    }
    
    return dataSource[indexPath.row];
}

- (void)refreshItems {
    self.standardItemsCache = [self loadStandardItems];
    
    // PERF: These can only appear in Root Group...
    
    self.pinnedItemsCache = [self isDisplayingRootGroup] ? [self loadPinnedItems] : @[];
    self.nearlyExpiredItemsCache = [self isDisplayingRootGroup] ? [self loadNearlyExpiredItems] : @[];
    self.expiredItemsCache = [self isDisplayingRootGroup] ? [self loadExpiredItems] : @[];
    
    // Display
    
    if(self.searchController.isActive) {
        [self updateSearchResultsForSearchController:self.searchController];
    }
    else {
        [self.tableView reloadData];
    }
    
    self.editButtonItem.enabled = (!self.viewModel.isUsingOfflineCache &&
                                   !self.viewModel.isReadOnly);
    
    [self enableDisableToolbarButtons];
}

////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionIdxLast + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if((![self isDisplayingRootGroup] || self.searchController.isActive) && section != kSectionIdxLast) {
        return 0;
    }
    else {
        return [self getDataSourceForSection:section].count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(self.searchController.isActive) {
        return nil;
    }
    
    if(section == kSectionIdxPinned && [self isDisplayingRootGroup] && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_pinned", @"Section Header Title for Pinned Items");
    }
    else if (section == kSectionIdxNearlyExpired && [self isDisplayingRootGroup] && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_nearly_expired", @"Section Header Title for Nearly Expired Items");
    }
    else if (section == kSectionIdxExpired && [self isDisplayingRootGroup] && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_expired", @"Section Header Title for Expired Items");
    }
    else if (section == kSectionIdxLast && [self isDisplayingRootGroup]){
        if (self.viewModel.metadata.showQuickViewFavourites ||
            self.viewModel.metadata.showQuickViewNearlyExpired ||
            self.viewModel.metadata.showQuickViewExpired) {
            NSUInteger countRows = [self getQuickViewRowCount];
            return countRows ? NSLocalizedString(@"browse_vc_section_title_standard_view", @"Standard View Sections Header") : nil;
        }
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = [self getNodeFromIndexPath:indexPath];
    return [self getTableViewCellFromNode:node indexPath:indexPath];
}

- (UITableViewCell*)getTableViewCellFromNode:(Node*)node indexPath:(NSIndexPath*)indexPath {
    NSString* title = self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node model:self.viewModel];

    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    if(!self.searchController.isActive && self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList) {
        BrowseItemTotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemTotpCell forIndexPath:indexPath];
        NSString* subtitle = [searcher getBrowseItemSubtitle:node];
        
        [cell setItem:title subtitle:subtitle icon:icon expired:node.expired otpToken:node.fields.otpToken];
        
        return cell;
    }
    else {
        BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

        NSString *groupLocation = self.searchController.isActive ? [self getGroupPathDisplayString:node] : @""; // [node.fields.tags.allObjects componentsJoinedByString:@", "];

        if(node.isGroup) {
            BOOL italic = (self.viewModel.database.recycleBinEnabled && node == self.viewModel.database.recycleBinNode);

            NSString* childCount = self.viewModel.metadata.showChildCountOnFolderInBrowse ? [NSString stringWithFormat:@"(%lu)", (unsigned long)node.children.count] : @"";
            
            [cell setGroup:title
                      icon:icon
                childCount:childCount
                    italic:italic
             groupLocation:groupLocation
                 tintColor:self.viewModel.database.format == kPasswordSafe ? [NodeIconHelper folderTintColor] : nil
                    pinned:self.viewModel.metadata.showFlagsInBrowse ? [self.viewModel isPinned:node] : NO
                  hideIcon:self.viewModel.metadata.hideIconInBrowse];
        }
        else {
            NSString* subtitle = [searcher getBrowseItemSubtitle:node];
            
            [cell setRecord:title
                   subtitle:subtitle
                       icon:icon
              groupLocation:groupLocation
                     pinned:self.viewModel.metadata.showFlagsInBrowse ? [self.viewModel isPinned:node] : NO
             hasAttachments:self.viewModel.metadata.showFlagsInBrowse ? node.fields.attachments.count : NO
                    expired:node.expired
                   otpToken:self.viewModel.metadata.hideTotpInBrowse ? nil : node.fields.otpToken
                   hideIcon:self.viewModel.metadata.hideIconInBrowse];
        }
        
        return cell;
    }
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    return [NSString stringWithFormat:NSLocalizedString(@"browse_vc_group_path_string_fmt", @"(in %@)"),
            [self.viewModel.database getSearchParentGroupPathDisplayString:vm]];
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
        vc.onChanged = ^{
            [self refreshItems];
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
        vc.onChanged = ^{
            [self refreshItems];
        };
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
    }
    else if([segue.identifier isEqualToString:@"segueToSortOrder"]){
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
            if (!Settings.sharedInstance.isFreeTrial) {
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.modalInPresentation = YES;
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
                  title:@"Would you like to add an entry or a group?"
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

- (IBAction)onDeleteToolbarButton:(id)sender {
    NSArray *selectedRows = (self.tableView).indexPathsForSelectedRows;
    
    if (selectedRows.count > 0) {
        NSArray<Node *> *items = [self getSelectedItems:selectedRows];
        Node* item = [items firstObject];
        BOOL willRecycle = [self.viewModel deleteWillRecycle:item];
        
        [Alerts yesNo:self.searchController.isActive ? self.searchController : self
                title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
              message:willRecycle ?
         NSLocalizedString(@"browse_vc_are_you_sure_recycle", @"Are you sure you want to send these item(s) to the Recycle Bin?") :
         NSLocalizedString(@"browse_vc_are_you_sure_delete", @"Are you sure you want to permanently delete these item(s)?")
               action:^(BOOL response) {
                   if (response) {
                       NSArray<Node *> *items = [self getSelectedItems:selectedRows];
                       
                       BOOL fail = NO;
                       for (Node* item in items) {
                           if(![self.viewModel deleteItem:item]) {
                               fail = YES;
                           }
                           
                            // Also Unpin
                           
                           if([self.viewModel isPinned:item]) {
                               [self togglePinEntry:item];
                           }
                       }
                       
                       if(fail) {
                           [Alerts warn:self
                                  title:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                                message:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")];
                       }
                       
                       [self saveChangesToSafeAndRefreshView];
                   }
               }];
    }
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
