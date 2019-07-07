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
#import "Node+OTPToken.h"
#import "OTPToken+Generation.h"
#import "SetNodeIconUiHelper.h"
#import "ItemDetailsViewController.h"
#import "BrowseItemCell.h"
#import "MasterDetailViewController.h"
#import "BrowsePreferencesTableViewController.h"
#import "SortOrderTableViewController.h"
#import "BrowseItemTotpCell.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>
#import "DatabaseSearchAndSorter.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";
static NSString* const kBrowseItemTotpCell = @"BrowseItemTotpCell";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, DZNEmptyDataSetSource>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UIBarButtonItem *savedOriginalNavButton;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;

@property NSTimer* timerRefreshOtp;
@property (strong) SetNodeIconUiHelper* sni; // Required: Or Delegate does not work!

@property NSMutableArray<NSArray<NSNumber*>*>* reorderItemOperations;
@property BOOL sortOrderForAutomaticSortDuringEditing;

@property BOOL hasAlreadyAppeared;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonViewPreferences;

@end

@implementation BrowseSafeView

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    if(!self.hasAlreadyAppeared && self.viewModel.metadata.immediateSearchOnBrowse && self.currentGroup == self.viewModel.database.rootGroup) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if ([[Settings sharedInstance] isProOrFreeTrial]) {
                [self.searchController.searchBar becomeFirstResponder];
            }
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (IBAction)updateOtpCodes:(id)sender {
    if(![self.tableView isEditing]) { // DO not update during edit, cancels left swipe menu and edit selections!
        NSArray<NSIndexPath*>* visible = [self.tableView indexPathsForVisibleRows];
        
        NSArray<Node*> *nodes = [self getDataSource];
        NSArray* visibleOtpRows = [visible filter:^BOOL(NSIndexPath * _Nonnull obj) {
            return nodes[obj.row].fields.otpToken != nil;
        }];
        
        if(visibleOtpRows.count) {
            [self.tableView reloadRowsAtIndexPaths:visibleOtpRows withRowAnimation:UITableViewRowAnimationNone];
        }
    }
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
                                 self.viewModel.isUsingOfflineCache ? @" (Offline)" : @"",
                                 self.viewModel.isReadOnly ? @" (Read Only)" : @""];
    
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
    self.searchController.searchBar.scopeButtonTitles = @[@"Title", @"Username", @"Password", @"URL", @"All Fields"];
    self.searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
}

- (void)addSearchBarToNav {
    if ([[Settings sharedInstance] isProOrFreeTrial]) {
        if (@available(iOS 11.0, *)) {
            self.navigationItem.searchController = self.searchController;
            
            // We want the search bar visible immediately for Root
            
            self.navigationItem.hidesSearchBarWhenScrolling = self.currentGroup != self.viewModel.database.rootGroup;
        } else {
            self.tableView.tableHeaderView = self.searchController.searchBar;
            [self.searchController.searchBar sizeToFit];
        }
    }
    else {
        if (@available(iOS 11.0, *)) {
            self.navigationItem.searchController = nil;
        }
    }
}

- (void)setupTips {
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    
    if (!Settings.sharedInstance.hideTips && (!self.currentGroup || self.currentGroup.parent == nil)) {
        [ISMessages showCardAlertWithTitle:@"Fast Tap Actions"
                                   message:@"You can long press, or double/triple tap to quickly copy fields... Give it a try!"
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
    // Super important for this to be pixel perfect - otherwise get very jumpy scrolling
    return self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList ? 99.0 : 46.5;
    //TODO: UITableViewAutomaticDimension;
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
                title:@"Sort Items By Title?"
              message:@"Do you want to sort all the items in this folder by Title? This will set the order in which they are stored in your database." action:^(BOOL response) {
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
                            title:@"Rename Item"
                          message:@"Please enter a new title for this item"
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
            title:@"Are you sure?"
          message:[NSString stringWithFormat:willRecycle ? @"Are you sure you want to send '%@' to the Recycle Bin?" : @"Are you sure you want to permanently delete '%@'?", [self dereference:item.title node:item]]
           action:^(BOOL response) {
               if (response) {
                   if(![self.viewModel deleteItem:item]) {
                       [Alerts warn:self title:@"Delete Failed" message:@"There was an error trying to delete this item."];
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
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onDeleteSingleItem:indexPath];
    }];
    
    UITableViewRowAction *renameAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Rename" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onRenameItem:indexPath];
    }];
    renameAction.backgroundColor = UIColor.blueColor;
    
    UITableViewRowAction *setIconAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Set Icon" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self onSetIconForItem:indexPath];
    }];
    
    setIconAction.backgroundColor = UIColor.purpleColor;

    return self.viewModel.database.format != kPasswordSafe ? @[removeAction, renameAction, setIconAction] : @[removeAction, renameAction];
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

    if(self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList) {
        NSArray<Node*>* otps = [self.viewModel.database.rootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.otpToken != nil;
        }];
        
        self.searchResults = [searcher searchNodes:otps
                                        searchText:searchController.searchBar.text
                                             scope:(SearchScope)searchController.searchBar.selectedScopeButtonIndex
                                       dereference:self.viewModel.metadata.searchDereferencedFields
                             includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                                 includeRecycleBin:self.viewModel.metadata.showRecycleBinInSearchResults];
    }
    else {
        self.searchResults = [searcher search:searchController.searchBar.text
                                        scope:(SearchScope)searchController.searchBar.selectedScopeButtonIndex
                                  dereference:self.viewModel.metadata.searchDereferencedFields
                        includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                            includeRecycleBin:self.viewModel.metadata.showRecycleBinInSearchResults];
    }
    
    [self.tableView reloadData];
    [self startOtpRefreshTimerIfAppropriate];
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

    if(self.searchController.isActive || self.viewModel.metadata.browseViewType != kBrowseViewTypeTotpList) {
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
            
            [cell setRecord:title subtitle:subtitle icon:icon groupLocation:groupLocation flags:flags];

            [self setOtpCellProperties:cell node:node];
        }
        
        return cell;
    }
    else {
        BrowseItemTotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemTotpCell forIndexPath:indexPath];
        
        NSString* subtitle = [searcher getBrowseItemSubtitle:node];

        cell.labelTitle.text = title;
        cell.labelUsername.text = subtitle;
        cell.icon.image = icon;
        
        [self setOtpCellLabelProperties:cell.labelOtp node:node];

        return cell;
    }
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (void)setOtpCellProperties:(BrowseItemCell*)cell node:(Node*)node {
    [self setOtpCellLabelProperties:cell.otpLabel node:node];
}

- (void)setOtpCellLabelProperties:(UILabel*)otpLabel node:(Node*)node {
    if(!self.viewModel.metadata.hideTotpInBrowse && node.fields.otpToken) {
        uint64_t remainingSeconds = node.fields.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)node.fields.otpToken.period);
        
        otpLabel.text = [NSString stringWithFormat:@"%@", node.fields.otpToken.password];
        otpLabel.textColor = (remainingSeconds < 5) ? [UIColor redColor] : (remainingSeconds < 9) ? [UIColor orangeColor] : [UIColor blueColor];
        otpLabel.alpha = 1;
        
        if(remainingSeconds < 16) {
            [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
                otpLabel.alpha = 0.5;
            } completion:nil];
        }
    }
    else {
        otpLabel.text = @"";
    }
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
    
    // Any OTPs we should start a refresh timer if so...
    
    [self startOtpRefreshTimerIfAppropriate];
}

- (void)startOtpRefreshTimerIfAppropriate {
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
    
    BOOL hasOtpToken = [[self getDataSource] anyMatch:^BOOL(Node * _Nonnull obj) {
        return obj.fields.otpToken != nil;
    }];
    
    if(!self.viewModel.metadata.hideTotpInBrowse && hasOtpToken) {
        NSLog(@"Starting OTP Refresh Timer");
        
        self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(updateOtpCodes:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
    }
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    return [NSString stringWithFormat:@"(in %@)", [self.viewModel.database getSearchParentGroupPathDisplayString:vm]];
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
        Node *record = (Node *)sender;

        ItemDetailsViewController *vc = segue.destinationViewController;
        
        vc.createNewItem = record == nil;
        vc.item = record;
        vc.parentGroup = self.currentGroup;
        vc.readOnly = self.viewModel.isReadOnly || self.viewModel.isUsingOfflineCache;
        vc.databaseModel = self.viewModel;
        vc.onChanged = ^{
            [self refreshItems];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueMasterDetailToDetail"]) {
        Node *record = (Node *)sender;
        
        UINavigationController* nav = segue.destinationViewController;
        ItemDetailsViewController *vc = (ItemDetailsViewController*)nav.topViewController;
        
        vc.createNewItem = record == nil;
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
             textFieldPlaceHolder:@"Group Name"
                            title:@"Enter Group Name"
                          message:@"Please Enter the New Group Name:"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               if ([self.viewModel addNewGroup:self.currentGroup title:text] != nil) {
                                   [self saveChangesToSafeAndRefreshView];
                               }
                               else {
                                   [Alerts warn:self title:@"Cannot create group" message:@"Could not create a group with this name here, possibly because one with this name already exists."];
                               }
                           }
                       }];
}

- (IBAction)onAddRecord:(id)sender {
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
                title:@"Are you sure?"
              message:willRecycle ? @"Are you sure you want to send these item(s) to the Recycle Bin?" : @"Are you sure you want to permanently delete these item(s)?"
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
                           [Alerts warn:self title:@"Error Deleting" message:@"There was a problem deleting a least one of these items."];
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
    
    [self.viewModel update:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self setEditing:NO animated:YES];
            
            [self refreshItems];
            
            [self updateSplitViewDetailsView:nil];
            
            if (error) {
                [Alerts error:self title:@"Error Saving" error:error];
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
       default:
            break;
    }
}

- (void)copyTitle:(Node*)item {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    pasteboard.string = [self dereference:item.title node:item];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' Title Copied", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' URL Copied", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' Email Copied", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' Notes Copied", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' Username Copied", [self dereference:item.title node:item]]
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
        [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@': No TOTP setup to Copy!", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' TOTP Copied", [self dereference:item.title node:item]]
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
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:copyTotp ? @"'%@' OTP Code Copied" : @"'%@' Password Copied", [self dereference:item.title node:item]]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)openEntryDetails:(Node*)item {
    if(item.isGroup) {
        return;
    }
    
    if(self.splitViewController) {
        [self updateSplitViewDetailsView:item];
    }
    else {
        if (@available(iOS 11.0, *)) {
            [self performSegueWithIdentifier:@"segueToItemDetails" sender:item];
        }
        else {
            [self performSegueWithIdentifier:@"segueToRecord" sender:item];
        }
    }
}

- (void)updateSplitViewDetailsView:(Node*)item {
    if(self.splitViewController) {
        if(item) {
            [self performSegueWithIdentifier:@"segueMasterDetailToDetail" sender:item];
        }
        else if(!self.splitViewController.isCollapsed) {
            [self performSegueWithIdentifier:@"segueMasterDetailToEmptyDetail" sender:nil];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onViewPreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToViewSettings" sender:nil];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text = @"";
    
    if(self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList) {
        text = @"View As: TOTP List (No TOTP Entries)";
    }
    else if(self.searchController.isActive) {
        text = @"No matching entries found";
    }
    else {
        text = @"No Entries";
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

@end
