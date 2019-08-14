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
#import "SafeDetailsView.h"
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

static NSString* const kBrowseItemCell = @"BrowseItemCell";
static NSString* const kBrowseItemTotpCell = @"BrowseItemTotpCell";

static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, DZNEmptyDataSetSource>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UIBarButtonItem *savedOriginalNavButton;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;

@property (strong) SetNodeIconUiHelper* sni; // Required: Or Delegate does not work!

@property NSMutableArray<NSArray<NSNumber*>*>* reorderItemOperations;
@property BOOL sortOrderForAutomaticSortDuringEditing;

@property BOOL hasAlreadyAppeared;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonViewPreferences;

@property NSTimer* timerRefreshOtp;

@end

@implementation BrowseSafeView

- (void)dealloc {
    [self killOtpTimer];
}

-(void)viewDidDisappear:(BOOL)animated {
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
    
    if(!self.hasAlreadyAppeared && self.viewModel.metadata.immediateSearchOnBrowse && self.currentGroup == self.viewModel.database.rootGroup) {
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTableview];
    
    [self setupTips];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;

    [self setupNavBar];
    [self setupSearchBar];
    
    if(self.currentGroup == self.viewModel.database.rootGroup) {
        // Only do this for the root group - We should delay adding this because we get a weird
        // UI Artifact / Delay on segues to subgroups if we add here :(
        
        [self addSearchBarToNav];
        
         // This coordinates all TOTP UI updates for this database
        [self startOtpRefresh];
    }
    
    NSMutableArray* rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
    [rightBarButtons insertObject:self.editButtonItem atIndex:0];
    self.navigationItem.rightBarButtonItems = rightBarButtons;
    
    [self refreshItems];
    
    if(self.splitViewController) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showDetailTargetDidChange:) name:UIViewControllerShowDetailTargetDidChangeNotification object:self.splitViewController];
    }
}

- (void)showDetailTargetDidChange:(NSNotification *)notification{
    NSLog(@"showDetailTargetDidChange");
    if(!self.splitViewController.isCollapsed) {
        NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
        if(ip) {
            Node* item = [self getDataSource][ip.row];
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
        if(self.currentGroup != self.viewModel.database.rootGroup) {
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
                                                          NSLocalizedString(@"browse_vc_search_scope_all", @"All Fields")];
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
    return !self.viewModel.isUsingOfflineCache && !self.viewModel.isReadOnly;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    Node *item = [[self getDataSource] objectAtIndex:indexPath.row];
    
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
                               
                               item.fields.accessed = [NSDate date];
                               item.fields.modified = [NSDate date];
                               
                               [item setTitle:text allowDuplicateGroupTitles:self.viewModel.database.format != kPasswordSafe];
                               
                               [self saveChangesToSafeAndRefreshView];
                           }
                       }];
}

- (void)onDeleteSingleItem:(NSIndexPath * _Nonnull)indexPath {
    Node *item = [[self getDataSource] objectAtIndex:indexPath.row];
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
                       [self saveChangesToSafeAndRefreshView];
                   }
               }
           }];
}

- (void)onSetIconForItem:(NSIndexPath * _Nonnull)indexPath {
    Node *item = [[self getDataSource] objectAtIndex:indexPath.row];

    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.viewModel.database.customIcons;
    
    NSString* urlHint;
    if(!item.isGroup) {
        urlHint = item.fields.url;
        if(!urlHint.length) {
            urlHint = item.title;
        }
    }    
    
    [self.sni changeIcon:self
                 urlHint:urlHint
                  format:self.viewModel.database.format
              completion:^(BOOL goNoGo, NSNumber * userSelectedNewIconIndex, NSUUID * userSelectedExistingCustomIconId, UIImage * userSelectedNewCustomIcon) {
        NSLog(@"completion: %d - %@-%@-%@", goNoGo, userSelectedNewIconIndex, userSelectedExistingCustomIconId, userSelectedNewCustomIcon);
        if(goNoGo) {
            if(!item.isGroup) {
                Node* originalNodeForHistory = [item cloneForHistory];
                [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
            }
            
            item.fields.accessed = [NSDate date];
            item.fields.modified = [NSDate date];
            
            if(userSelectedNewCustomIcon) {
                NSData *data = UIImagePNGRepresentation(userSelectedNewCustomIcon);
                [self.viewModel.database setNodeCustomIcon:item data:data];
            }
            else if(userSelectedExistingCustomIconId) {
                item.customIconUuid = userSelectedExistingCustomIconId;
            }
            else if(userSelectedNewIconIndex) {
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
    }];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Node *item = [[self getDataSource] objectAtIndex:indexPath.row];

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
    renameAction.backgroundColor = UIColor.blueColor;
    
    UITableViewRowAction *setIconAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onSetIconForItem:indexPath];
    }];
    setIconAction.backgroundColor = UIColor.purpleColor;

    UITableViewRowAction *duplicateItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                                   title:NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate")
                                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self duplicateItem:item];
    }];
    duplicateItemAction.backgroundColor = UIColor.purpleColor;
    
    UITableViewRowAction *editItemAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                                   title:NSLocalizedString(@"browse_vc_action_edit", @"Edit")
                                                                                 handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                                                                                     [self editEntry:item];
                                                                                 }];
    editItemAction.backgroundColor = UIColor.magentaColor;
    
    if(item.isGroup) {
        return self.viewModel.database.format != kPasswordSafe ? @[removeAction, renameAction, setIconAction] : @[removeAction, renameAction];
    }
    else {
        return @[removeAction, renameAction, duplicateItemAction, editItemAction];
    }
}

-(void)duplicateItem:(Node*)item {
    Node* dupe = [item duplicate:[item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")]];
    
    item.fields.accessed = [NSDate date];
    [item.parent addChild:dupe allowDuplicateGroupTitles:NO];

    [self saveChangesToSafeAndRefreshView];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    //ignore segue from cell since we we are calling manually in didSelectRowAtIndexPath
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeSettings"]);
}

- (NSArray<Node *> *)getDataSource {
    return (self.searchController.isActive ? self.searchResults : self.items);
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    self.searchResults = [searcher search:searchController.searchBar.text
                                    scope:(SearchScope)searchController.searchBar.selectedScopeButtonIndex
                              dereference:self.viewModel.metadata.searchDereferencedFields
                    includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                        includeRecycleBin:self.viewModel.metadata.showRecycleBinInSearchResults
                           includeExpired:self.viewModel.metadata.showExpiredInSearch];
    
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node *node = [self getDataSource][indexPath.row];
    NSString* title = self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node database:self.viewModel.database];

    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];

    if(!self.searchController.isActive && self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList) {
        BrowseItemTotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemTotpCell forIndexPath:indexPath];
        NSString* subtitle = [searcher getBrowseItemSubtitle:node];
        
        [cell setItem:title subtitle:subtitle icon:icon expired:node.expired otpToken:node.fields.otpToken];
        
        return cell;
    }
    else {
        BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

        NSString *groupLocation = self.searchController.isActive ? [self getGroupPathDisplayString:node] : @"";

        if(node.isGroup) {
            BOOL italic = (self.viewModel.database.recycleBinEnabled && node == self.viewModel.database.recycleBinNode);

            NSString* childCount = self.viewModel.metadata.showChildCountOnFolderInBrowse ? [NSString stringWithFormat:@"(%lu)", (unsigned long)node.children.count] : @"";
            
            [cell setGroup:title icon:icon childCount:childCount italic:italic groupLocation:groupLocation tintColor:self.viewModel.database.format == kPasswordSafe ? [NodeIconHelper folderTintColor] : nil];
        }
        else {
            NSString* subtitle = [searcher getBrowseItemSubtitle:node];
            NSString* flags = node.fields.attachments.count > 0 ? @"📎" : @"";
            flags = self.viewModel.metadata.showFlagsInBrowse ? flags : @"";
            
            [cell setRecord:title
                   subtitle:subtitle
                       icon:icon
              groupLocation:groupLocation
                      flags:flags
                    expired:node.expired
                   otpToken:self.viewModel.metadata.hideTotpInBrowse ? nil : node.fields.otpToken];
        }
        
        return cell;
    }
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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
        //This is the first tap. If there is no tap till tapTimer is fired, it is a single tap
        self.tapCount = self.tapCount + 1;
        self.tappedIndexPath = indexPath;
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

- (void)enableDisableToolbarButtons {
    BOOL ro = self.viewModel.isUsingOfflineCache || self.viewModel.isReadOnly;
    
    self.buttonAddRecord.enabled = !ro && !self.isEditing && self.currentGroup.childRecordsAllowed;
    self.buttonSafeSettings.enabled = !self.isEditing;
    self.buttonViewPreferences.enabled = !self.isEditing;
    
    self.buttonMove.enabled = (!ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0);
    self.buttonDelete.enabled = !ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0;
    
    self.buttonSortItems.enabled = !self.isEditing ||
        (!ro && self.isEditing && self.viewModel.database.format != kPasswordSafe && self.viewModel.metadata.browseSortField == kBrowseSortFieldNone);
    
    UIImage* sortImage = self.isEditing ? [UIImage imageNamed:self.sortOrderForAutomaticSortDuringEditing ? @"sort-desc" : @"sort-asc"] : [UIImage imageNamed:self.viewModel.metadata.browseSortOrderDescending ? @"sort-desc" : @"sort-asc"];
    
    [self.buttonSortItems setImage:sortImage];
        
    self.buttonAddGroup.enabled = !ro && !self.isEditing;
}

- (NSArray<Node*>*)getItems {
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
    
    // Filter KeePass 1 Backup Group
    
    if(self.viewModel.database.format == kKeePass1 && !self.viewModel.metadata.showKeePass1BackupGroup) {
        Node* backupGroup = self.viewModel.database.keePass1BackupNode;
        
        if(backupGroup) {
                ret = [ret filter:^BOOL(Node * _Nonnull obj) {
                    return obj != backupGroup;
                }];
        }
    }
    // Filter KeePass 2 Recycle Bin?
    else if(self.viewModel.database.format == kKeePass || self.viewModel.database.format == kKeePass4) {
        Node* recycleBin = self.viewModel.database.recycleBinNode;
        
        if(self.viewModel.metadata.doNotShowRecycleBinInBrowse && recycleBin) {
            ret = [ret filter:^BOOL(Node * _Nonnull obj) {
                return obj != recycleBin;
            }];
        }
    }
    
    if(!self.viewModel.metadata.showExpiredInBrowse) {
        ret = [ret filter:^BOOL(Node * _Nonnull obj) {
            return !obj.expired;
        }];
    }
    
    DatabaseSearchAndSorter *searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];
    
    return [searcher sortItemsForBrowse:ret];
}

- (void)refreshItems {
    self.items = [self getItems];
    
    // Display
    
    if(self.searchController.isActive) {
        [self updateSearchResultsForSearchController:self.searchController];
    }
    else {
        [self.tableView reloadData];
    }
    
    self.editButtonItem.enabled = (!self.viewModel.isUsingOfflineCache &&
                                   !self.viewModel.isReadOnly &&
                                   [self getDataSource].count > 0);
    
    [self enableDisableToolbarButtons];
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
    else if ([segue.identifier isEqualToString:@"segueToSelectDestination"])
    {
        NSArray *itemsToMove = (NSArray *)sender;
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = (SelectDestinationGroupController*)nav.topViewController;
        
        vc.currentGroup = self.viewModel.database.rootGroup;
        vc.viewModel = self.viewModel;
        vc.itemsToMove = itemsToMove;
        vc.onDone = ^{
            [self dismissViewControllerAnimated:YES completion:^{
                [self refreshItems];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToSafeSettings"])
    {
        UINavigationController* nav = segue.destinationViewController;
        SafeDetailsView *vc = (SafeDetailsView *)nav.topViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToViewSettings"]) {
        UINavigationController* nav = segue.destinationViewController;
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)nav.topViewController;
        vc.format = self.viewModel.database.format;
        vc.databaseMetaData = self.viewModel.metadata;
        
        vc.onPreferencesChanged = ^{
            [self refreshItems];
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
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onAddGroup:(id)sender {
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

- (IBAction)onAddRecord:(id)sender {
    [self showEntry:nil editImmediately:YES];
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
        NSArray *selectedRows = (self.tableView).indexPathsForSelectedRows;
        
        if (selectedRows.count > 0) {
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
    NSMutableIndexSet *indicesOfItems = [NSMutableIndexSet new];
    
    for (NSIndexPath *selectionIndex in selectedRows) {
        [indicesOfItems addIndex:selectionIndex.row];
    }
    
    NSArray *items = [[self getDataSource] objectsAtIndexes:indicesOfItems];
    return items;
}

- (void)saveChangesToSafeAndRefreshView {
    [self refreshItems];
    
    [self.viewModel update:NO handler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self setEditing:NO animated:YES];
            
            [self refreshItems];
            
            [self updateSplitViewDetailsView:nil editMode:NO];
            
            if (error) {
                [Alerts error:self
                        title:NSLocalizedString(@"browse_vc_error_saving", @"Error Saving")
                        error:error];
            }
        });
    }];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
    NSLog(@"setEditing: %d", editing);
    
    [self enableDisableToolbarButtons];
    
    //NSLog(@"setEditing: %hhd", editing);
    
    if (!editing) {
        self.navigationItem.leftBarButtonItem = self.savedOriginalNavButton;
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
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelEditing)];
        
        self.savedOriginalNavButton = self.navigationItem.leftBarButtonItem;
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
}

- (void)cancelEditing {
    self.reorderItemOperations = nil;
    [self setEditing:false];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (Node*)getTappedItem:(NSIndexPath*)indexPath {
    NSArray* arr = [self getDataSource];
    if(indexPath.row >= arr.count) { // This can happen in a race condition
        return nil;
    }
    
    return arr[indexPath.row];
}

- (void)handleSingleTap:(NSIndexPath *)indexPath  {
    if (self.editing) {
        [self enableDisableToolbarButtons]; // Buttons can be enabled disabled based on selection?
        return;
    }
    
    Node* item = [self getTappedItem:indexPath];
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

    Node* item = [self getTappedItem:indexPath];
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
    Node* item = [self getTappedItem:indexPath];
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
    Node* item = [self getTappedItem:indexPath];
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.title node:item];
    
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.fields.url node:item];
    
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.fields.email node:item];
    
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.fields.notes node:item];
    
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.fields.username node:item];
    
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
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = item.fields.otpToken.password;
    
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
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
    pasteboard.string = copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item];
    
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

- (IBAction)onViewPreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToViewSettings" sender:nil];
}

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
