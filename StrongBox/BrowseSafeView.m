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
#import "Alerts.h"
#import "AppPreferences.h"
#import "DatabaseOperations.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "NodeIconHelper.h"
#import "SetNodeIconUiHelper.h"
#import "ItemDetailsViewController.h"
#import "BrowseItemCell.h"
#import "BrowsePreferencesTableViewController.h"
#import "SortOrderTableViewController.h"
#import "BrowseItemTotpCell.h"
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
#import "PreviewItemViewController.h"
#import "LargeTextViewController.h"
#import "UITableView+EmptyDataSet.h"
#import "ItemPropertiesViewController.h"
#import "SyncManager.h"
#import "Platform.h"
#import "MMcGPair.h"
#import "ConvenienceUnlockPreferences.h"
#import "KeyFileParser.h"
#import "SecondDatabaseListTableViewController.h"
#import "DatabaseUnlocker.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DuressActionHelper.h"
#import "DatabaseFormatIncompatibilityHelper.h"
#import "ExportItemsOptionsViewController.h"
#import "SVProgressHUD.h"
#import "DuplicateOptionsViewController.h"
#import "ContextMenuHelper.h"
#import "DatabasePreferences.h"
#import "EncryptionSettingsViewModel.h"
#import "NavBarSyncButtonHelper.h"
#import "Constants.h"

#import "Strongbox-Swift.h"

static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, UIAdaptivePresentationControllerDelegate, UIPopoverPresentationControllerDelegate, UISearchControllerDelegate >

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonAddRecord;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonSafeSettings;

@property (strong, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonMove; 
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonDelete; 
@property (strong, nonatomic) IBOutlet UIBarButtonItem *exportItemsBarButton;  

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSortItems;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *exportDatabaseBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *closeBarButton;

@property UIBarButtonItem* moreiOS14Button;
@property UIBarButtonItem* sortiOS14Button;
@property UIBarButtonItem* syncBarButton;
@property UIButton* syncButton;
@property NSString* originalCloseTitle;

@property (strong, nonatomic) UISearchController *searchController;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;
@property (strong) SetNodeIconUiHelper* sni; 
@property NSMutableArray<MMcGPair<NSIndexPath*, NSIndexPath*>*> * reorderItemOperations;
@property BOOL sortOrderForAutomaticSortDuringEditing;
@property BOOL hasAlreadyAppeared;

@property ConfiguredBrowseTableDatasource* configuredDataSource;
@property SearchResultsBrowseTableDatasource* searchDataSource;
@property QuickViewsBrowseTableDataSource* quickViewsDataSource;

@property NSString *pwSafeRefreshSerializationId;
@property (readonly) BOOL isItemsCanBeExported;

@property (readonly) BOOL isDisplayingRootGroup;

@property (readonly) MainSplitViewController* parentSplitViewController;
@property BrowseSortConfiguration* sortConfiguration;

@end

@implementation BrowseSafeView

+ (instancetype)fromStoryboard:(BrowseViewType)viewType model:(Model*)model {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Browse" bundle:nil];
    BrowseSafeView* vc = (BrowseSafeView*)[sb instantiateInitialViewController];
    
    vc.viewModel = model;
    vc.currentGroupId = viewType == kBrowseViewTypeTags ? nil : model.database.effectiveRootGroup.uuid;
    vc.currentTag = nil;
    vc.viewType = viewType;
    
    return vc;
}

- (void)dealloc {
    NSLog(@"DEALLOC [%@]", self);
    
    [self onClosed];
}

- (void)onClosed {
    
    
    [self unListenToNotifications];
}

- (void)listenToNotifications {
    [self unListenToNotifications];
    
    __weak BrowseSafeView* weakSelf = self;
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onDatabaseViewPreferencesChanged:)
                                               name:kDatabaseViewPreferencesChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onAuditNodesChanged:)
                                               name:kAuditNodesChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(refresh)
                                               name:kNotificationNameItemDetailsEditDone
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onAuditCompleted:)
                                               name:kAuditCompletedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onClosed)
                                               name:kMasterDetailViewCloseNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onDatabaseReloaded:)
                                               name:kDatabaseReloadedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateStarting
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateDone
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kSyncManagerDatabaseSyncStatusChanged
                                             object:nil];
}

- (void)unListenToNotifications {
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}



- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    
    
    if(self.isMovingFromParentViewController) { 
                                                
        [self onClosed];
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
    
    [self refresh];
}

- (void)didPresentSearchController:(UISearchController *)searchController {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.searchController.searchBar becomeFirstResponder];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    
    
    if(!self.hasAlreadyAppeared && [self isDisplayingRootGroup]) {
        if ( self.viewModel.metadata.immediateSearchOnBrowse ) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                self.searchController.active = YES;
            });
        }
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self addSearchBarToNav]; 
        });
    }
    
    self.hasAlreadyAppeared = YES;
    
    
    
    if ( self.splitViewController.isCollapsed ) {
        
        self.viewModel.metadata.lastViewedEntry = nil;
    }
}

- (void)displayLastViewedEntryIfAppropriate {
    if ( [self isDisplayingRootGroup] && self.viewModel.metadata.showLastViewedEntryOnUnlock && self.viewModel.metadata.lastViewedEntry ) {
        if ( self.viewModel.metadata.immediateSearchOnBrowse && self.splitViewController.isCollapsed ) {
            NSLog(@"Not showing last viewed entry because Start with Search and Split View collapsed");
        }
        else {
            Node* item = [self.viewModel getItemById:self.viewModel.metadata.lastViewedEntry];
            
            if ( item ) {
                [self showEntry:item animated:NO];
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ( self.viewModel.originalFormat == kPasswordSafe && self.currentGroupId ) {
        self.pwSafeRefreshSerializationId = [self.viewModel.database getCrossSerializationFriendlyIdId:self.currentGroupId]; 
    }
    
    [self setupDatasources];
    
    [self customizeUi];
    
    [self refresh];
    
    [self listenToNotifications];
    
    [self displayLastViewedEntryIfAppropriate];
    
    [self performOnboardingDatabaseChangeRequests];
}

- (void)performOnboardingDatabaseChangeRequests {
    if ( self.viewModel.onboardingDatabaseChangeRequests && self.isDisplayingRootGroup ) {
        BOOL changed = NO;
        EncryptionSettingsViewModel* enc = [EncryptionSettingsViewModel fromDatabaseModel:self.viewModel.database];
        
        if ( enc ) {
            if ( self.viewModel.onboardingDatabaseChangeRequests.updateDatabaseToV4OnLoad ) {
                NSLog(@"Updating Database to V4 after Onboard Request...");
                enc.format = kKeePass4;
                changed = YES;
            }
            
            if ( self.viewModel.onboardingDatabaseChangeRequests.reduceArgon2MemoryOnLoad ) {
                NSLog(@"Reducing Argon2 Memory after Onboard Request...");
                const int kReducedArgonMemory = 32 * 1024 * 1024;
                enc.argonMemory = kReducedArgonMemory;
                changed = YES;
            }
            
            if ( changed ) {
                [enc applyToDatabaseModel:self.viewModel.database];
                [self updateAndRefresh];
            }
        }
    }
}

- (void)setupDatasources {
    self.configuredDataSource = [[ConfiguredBrowseTableDatasource alloc] initWithModel:self.viewModel
                                                                 isDisplayingRootGroup:[self isDisplayingRootGroup]
                                                                             tableView:self.tableView
                                                                              viewType:self.viewType
                                                                        currentGroupId:self.currentGroupId
                                                                            currentTag:self.currentTag];
    
    self.searchDataSource = [[SearchResultsBrowseTableDatasource alloc] initWithModel:self.viewModel tableView:self.tableView];
    self.quickViewsDataSource = [[QuickViewsBrowseTableDataSource alloc] initWithModel:self.viewModel tableView:self.tableView];
}

- (void)customizeUi {
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeTop | UIRectEdgeBottom;
    self.definesPresentationContext = YES;
    
    [self setupTableview];
    [self setupTips];
    [self setupNavBar];
    [self setupSearchBar];
    
    if (@available(iOS 13.0, *) ) { 
        [self addSearchBarToNav];
        [self.buttonSafeSettings setImage:[UIImage systemImageNamed:@"gear"]]; 
    }
    else if( [self isDisplayingRootGroup] ) {
        
        
        [self addSearchBarToNav];
    }
    
    
    
    [self customizeRightBarButtons];
    [self customizeBottomToolbar];
}

- (void)setupNavBar {
    self.originalCloseTitle = self.closeBarButton.title;
    
    if (![self isDisplayingRootGroup]) {
        self.closeBarButton.enabled = NO;
        [self.closeBarButton setTintColor:UIColor.clearColor];
    }
    
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    [self refreshNavBarTitle];
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.navigationBarHidden = NO;
}

- (void)customizeRightBarButtons {
    self.syncButton = [NavBarSyncButtonHelper createSyncButton:self action:@selector(onSyncButtonClicked:)];
    self.syncBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.syncButton];
    
    NSMutableArray* rightBarButtons = @[].mutableCopy;
    
    if ( self.navigationItem.rightBarButtonItems ) {
        rightBarButtons = self.navigationItem.rightBarButtonItems.mutableCopy;
    }
    else if ( self.navigationItem.rightBarButtonItem ) {
        rightBarButtons = @[self.navigationItem.rightBarButtonItem].mutableCopy;
    }
    
    if (@available(iOS 14.0, *)) {
        self.moreiOS14Button =  [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:nil];
        [rightBarButtons insertObject:self.moreiOS14Button atIndex:0];
        [self refreshiOS14MoreMenu];
        
        self.sortiOS14Button = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleSmall]] menu:nil];
        [rightBarButtons insertObject:self.sortiOS14Button atIndex:1];
        [self refreshiOS14SortMenu];
        
    }
    else {
        [rightBarButtons insertObject:self.editButtonItem atIndex:0];
    }
    
    [rightBarButtons addObject:self.syncBarButton];
    
    self.navigationItem.rightBarButtonItems = rightBarButtons;
}

- (void)updateRightNavBarButtons {
    NSMutableArray *copy = self.navigationItem.rightBarButtonItems.mutableCopy;
    
    
    
    [copy replaceObjectAtIndex:0 withObject:self.isEditing ? self.editButtonItem : self.moreiOS14Button]; 
    
    
    
        
    
    
    
    BOOL showSyncButton = [NavBarSyncButtonHelper bindSyncToobarButton:self.viewModel button:self.syncButton];
    
    if ( !showSyncButton ) {
        if ( [copy containsObject:self.syncBarButton] ) {
            [copy removeObject:self.syncBarButton];
        }
    }
    else {
        if ( ![copy containsObject:self.syncBarButton] ) { 
            [copy addObject:self.syncBarButton];
        }
    }
    
    self.navigationItem.rightBarButtonItems = copy;
}

- (void)onSyncOrUpdateStatusChanged:(id)object {
    [self updateNavAndToolbarButtonsState];
    
    SyncStatus* status = [SyncManager.sharedInstance getSyncStatus:self.viewModel.metadata];
    
    if ( status.state != kSyncOperationStateInProgress ) {
        [self.tableView.refreshControl endRefreshing];
    }
}

- (void)updateNavAndToolbarButtonsState {
    [self.closeBarButton setTitle:self.isEditing ? NSLocalizedString(@"generic_cancel", @"Cancel") : self.originalCloseTitle];
    
    BOOL ro = self.viewModel.isReadOnly;
    BOOL moveAndDeleteEnabled = (!ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0);
    BOOL exportEnabled = self.isItemsCanBeExported && self.tableView.indexPathsForSelectedRows.count > 0;
    
    self.navigationController.toolbar.hidden = !(exportEnabled || moveAndDeleteEnabled); 
    self.navigationController.toolbarHidden = !(exportEnabled || moveAndDeleteEnabled); 

    self.buttonMove.enabled = moveAndDeleteEnabled;
    self.buttonDelete.enabled = moveAndDeleteEnabled;
    self.exportItemsBarButton.enabled = exportEnabled;
    
    if (@available(iOS 14.0, *)) { 
        [self updateRightNavBarButtons];
    }
    else {
        self.buttonAddRecord.enabled = !ro && !self.isEditing;
        self.buttonSafeSettings.enabled = !self.isEditing;
        self.buttonSortItems.enabled = !self.isEditing || (!ro && self.isEditing && self.viewModel.database.originalFormat != kPasswordSafe && self.sortConfiguration.field == kBrowseSortFieldNone);
        self.exportDatabaseBarButton.enabled = !self.isEditing;
        
        UIImage* sortImage = self.isEditing ? [UIImage imageNamed:self.sortOrderForAutomaticSortDuringEditing ? @"sort-desc" : @"sort-asc"] : [UIImage imageNamed:self.sortConfiguration.descending ? @"sort-desc" : @"sort-asc"];
        [self.buttonSortItems setImage:sortImage];
        
        
        
        if ( self.isEditing ) {
            if ( ![self.toolbarItems containsObject:self.buttonMove] ) {
                NSMutableArray* copy = self.toolbarItems.mutableCopy;
                
                [copy insertObject:self.buttonMove atIndex:2];
                [copy insertObject:self.exportItemsBarButton atIndex:3];
                [copy insertObject:self.buttonDelete atIndex:4];
                
                self.toolbarItems = copy;
            }
        }
        else {
            if ( [self.toolbarItems containsObject:self.buttonMove] ) {
                NSMutableArray* copy = self.toolbarItems.mutableCopy;
                
                [copy removeObject:self.buttonMove];
                [copy removeObject:self.exportItemsBarButton];
                [copy removeObject:self.buttonDelete];
                
                self.toolbarItems = copy;
            }
        }
    }
}

- (void)customizeBottomToolbar {
    if (@available(iOS 14.0, *)) { 
        
        
        
        UIBarButtonItem* flexibleSpace1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem* flexibleSpace2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem* flexibleSpace3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem* flexibleSpace4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        NSArray *toolbarButtons = @[flexibleSpace1, self.buttonMove, flexibleSpace2, self.exportItemsBarButton, flexibleSpace3, self.buttonDelete, flexibleSpace4];
        
        [self setToolbarItems:toolbarButtons animated:NO];
    }
}

- (void)onSyncButtonClicked:(id)sender {
    SyncStatus* syncStatus = [SyncManager.sharedInstance getSyncStatus:self.viewModel.metadata];
    
    if ( self.viewModel.isRunningAsyncUpdate || syncStatus.state == kSyncOperationStateInProgress ) {
        return;
    }
    
    [self updateAndRefresh];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

- (BOOL)isDisplayingRootGroup {
    BOOL ret = self.navigationController.viewControllers.firstObject == self;
    
    
    
    
    
    return ret;
}

- (void)refreshiOS14ButtonMenus {
    if (@available(iOS 14.0, *)) {
        [self refreshiOS14MoreMenu];
        [self refreshiOS14SortMenu];
    }
}

- (void)refreshiOS14MoreMenu API_AVAILABLE(ios(14.0)) {
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIMenuElement*>* ma0 = [NSMutableArray array];
        __weak BrowseSafeView* weakSelf = self;
        
        BOOL newEntryPossible = self.viewType != kBrowseViewTypeHierarchy || ( [self.viewModel.database getItemById:self.currentGroupId].childRecordsAllowed );
        
        if ( newEntryPossible ) {
            [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_new_entry", @"New Entry")
                                          systemImage:@"doc.badge.plus"
                                              enabled:!self.viewModel.isReadOnly
                                              handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf onAddEntry];
            }]];
        }
        
        if ( self.viewType == kBrowseViewTypeHierarchy ) {
            [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_new_group", @"New Group") systemImage:@"folder.badge.plus" enabled:!self.viewModel.isReadOnly handler:^(__kindof UIAction * _Nonnull action) { [weakSelf onAddGroup]; }]];
        }
        
        [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_select", @"Select") systemImage:@"checkmark.circle"
                                          enabled:(!self.viewModel.isReadOnly || self.isItemsCanBeExported)
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf setEditing:YES animated:YES];
        }]];
        
        UIMenu* menu0 = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:ma0];
        
        
        
        NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
        
        [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_start_with_search", @"Start with Search") systemImage:@"magnifyingglass" enabled:YES checked:self.viewModel.metadata.immediateSearchOnBrowse handler:^(__kindof UIAction * _Nonnull action) { [weakSelf toggleStartWithSearch]; }]];

        BOOL ro = weakSelf.viewModel.isReadOnly;
                
        if (@available(iOS 14.0, *)) {
        }
        else {
            BOOL sortingEnabled = !weakSelf.isEditing && weakSelf.viewModel.database.originalFormat != kPasswordSafe;
            [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_sort", @"Sort") systemImage:@"arrow.up.arrow.down" enabled:sortingEnabled handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf onSortItems:nil];
            }]];
        }
        
        BOOL rearrangingEnabled = (!ro && self.viewType == kBrowseViewTypeHierarchy && weakSelf.viewModel.database.originalFormat != kPasswordSafe && self.sortConfiguration.field == kBrowseSortFieldNone);

        if ( rearrangingEnabled ) {
            [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_rearrange", @"Rearrange")
                                          systemImage:@"arrow.up.arrow.down.square.fill"
                                              enabled:!self.viewModel.isReadOnly
                                              handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf setEditing:YES animated:YES];
            }]];
        }
        
        [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View") systemImage:@"list.dash" handler:^(__kindof UIAction * _Nonnull action) {  [weakSelf performSegueWithIdentifier:@"segueToCustomizeView" sender:nil]; }]];

        





        UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:ma1];
        
        
        
        NSMutableArray<UIMenuElement*>* ma2 = [NSMutableArray array];
        
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_export_database", @"Export Database") systemImage:@"square.and.arrow.up" handler:^(__kindof UIAction * _Nonnull action) {  [weakSelf onExportDatabase:nil]; }]];
        
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_set_master_credentials", @"Set Master Credentials") systemImage:@"ellipsis.rectangle" enabled:!self.viewModel.isReadOnly handler:^(__kindof UIAction * _Nonnull action) {  [weakSelf performSegueWithIdentifier:@"segueToChangeMasterCredentials" sender:nil]; }]];
        
        NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"convenience_unlock_preferences_title_fmt", @"%@ & PIN Codes"), BiometricsManager.sharedInstance.biometricIdName];
        UIImage *bioImage = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];
        
        [ma2 addObject:[ContextMenuHelper getItem:fmt
                                            image:bioImage
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf performSegueWithIdentifier:@"segueToConvenienceUnlock" sender:nil];
        }]];
        
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_database_settings", @"Database Settings") systemImage:@"gear" handler:^(__kindof UIAction * _Nonnull action) { [weakSelf onDatabasePreferences:nil]; }]];
        
        
        
        UIMenu* menu2 = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:ma2];
        
        UIMenu* menu = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:kNilOptions
                                    children:@[menu0, menu1, menu2]];
        
        self.moreiOS14Button.menu = menu;
    }
}

- (void)toggleStartWithSearch {
    self.viewModel.metadata.immediateSearchOnBrowse = !self.viewModel.metadata.immediateSearchOnBrowse;
    
    if (@available(iOS 14.0, *)) {
        [self refreshiOS14ButtonMenus];
    }
}

- (IBAction)onExportDatabase:(id)sender {
    [self.viewModel encrypt:self completion:^(BOOL userCancelled, NSString * _Nullable file, NSString * _Nullable debugXml, NSError * _Nullable error) {
        if (userCancelled) {
            
        }
        else if ( !file || error ) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_error_encrypting", @"Could not get database data")
                    error:error];
        }
        else {
            NSData* data = [NSData dataWithContentsOfFile:file];
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
    
    
    
    activityViewController.popoverPresentationController.barButtonItem = self.moreiOS14Button ? self.moreiOS14Button : self.exportDatabaseBarButton;
    
    
    
    
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError *errorBlock;
        if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
            NSLog(@"error deleting file %@", errorBlock);
            return;
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)onAuditNodesChanged:(id)param {
    [self refresh];
}

- (void)onAuditCompleted:(id)param {
    NSNotification* note = param;
    NSDictionary* dict = note.object;
    
    Model* model = dict[@"model"];
    if ( model != self.viewModel ) {
        return;
    }
    
    NSNumber* numNote = dict[@"userStopped"];
    NSLog(@"✅ Audit Completed... [%@]- userStopped = [%@]", self, numNote);
    
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
        
        DatabaseAuditorConfiguration* config = self.viewModel.metadata.auditConfig;
        config.lastKnownAuditIssueCount = issueCount;
        self.viewModel.metadata.auditConfig = config;
        
        if ( self.viewModel.metadata.auditConfig.showAuditPopupNotifications) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self showAuditPopup:issueCount.unsignedLongValue lastKnownAuditIssueCount:lastKnownAuditIssueCount];
            });
        }
    }
    
    [self refresh]; 
}

- (void)showAuditPopup:(NSUInteger)issueCount lastKnownAuditIssueCount:(NSNumber*)lastKnownAuditIssueCount {
    
    
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
    [self refresh];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate {
    [super setEditing:editing animated:animate];
    
    NSLog(@"setEditing: %d", editing);
    
    [self updateNavAndToolbarButtonsState];
    
    if ( !editing ) {
        if( self.reorderItemOperations ) {
            [self reorderPendingItems];
        }
    }
    else {
        self.reorderItemOperations = nil;
    }
}



- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self getTableDataSource] canMoveRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(![sourceIndexPath isEqual:destinationIndexPath]) {
        NSLog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        if(self.reorderItemOperations == nil) {
            self.reorderItemOperations = [NSMutableArray array];
        }
        
        [self.reorderItemOperations addObject:[MMcGPair pairOfA:sourceIndexPath andB:destinationIndexPath]];
        
        [self updateNavAndToolbarButtonsState]; 
    }
}

- (void)reorderPendingItems {
    if ( self.viewType != kBrowseViewTypeHierarchy ) {
        NSLog(@"🔴 Cannot reorder items outside of Hierarchy view! Something v wrong to end up here.");
        self.reorderItemOperations = nil;
        [self updateAndRefresh];
        return;
    }
    
    for (MMcGPair<NSIndexPath*, NSIndexPath*> *moveOp in self.reorderItemOperations) {
        NSUInteger srcIndex;
        NSUInteger destIndex;
        
        Node* currentGroup = [self.viewModel.database getItemById:self.currentGroupId]; 
        
        if ( self.sortConfiguration.foldersOnTop ) {
            
            
            Node* src = [self getNodeFromIndexPath:moveOp.a];
            Node* dest = [self getNodeFromIndexPath:moveOp.b];
            srcIndex = [currentGroup.children indexOfObject:src];
            
            if ( src.isGroup == dest.isGroup ) { 
                destIndex = [currentGroup.children indexOfObject:dest];
            }
            else {
                if ( src.isGroup ) { 
                    Node* lastGroup = currentGroup.childGroups.lastObject;
                    destIndex = [currentGroup.children indexOfObject:lastGroup];
                }
                else { 
                    Node* firstEntry = currentGroup.childRecords.firstObject;
                    destIndex = [currentGroup.children indexOfObject:firstEntry];
                }
            }
        }
        else {
            srcIndex = moveOp.a.row;
            destIndex = moveOp.b.row;
        }
        
        BOOL s = [self.viewModel reorderChildFrom:srcIndex to:destIndex parentGroup:currentGroup] != -1;
        
        if (s) {
            NSLog(@"Reordering: %lu -> %lu Successful", (unsigned long)srcIndex, (unsigned long)destIndex);
        }
        else {
            NSLog(@"WARNWARN: Move Unsucessful!: %lu -> %lu - Terminating further re-ordering", (unsigned long)srcIndex, (unsigned long)destIndex);
            break;
        }
    }
    
    self.reorderItemOperations = nil;
    [self updateAndRefresh];
}



- (void)didDismissSearchController:(UISearchController *)searchController {
    
    [self refresh]; 
}

- (void)setupSearchBar {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.delegate = self;
    
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
    self.navigationItem.searchController = self.searchController;
    
    
    
    self.navigationItem.hidesSearchBarWhenScrolling = ![self isDisplayingRootGroup];
}

- (void)setupTips {
    if(AppPreferences.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        if (![self isUsingLegacyUi]) {
            self.navigationItem.prompt = NSLocalizedString(@"hint_tap_and_hold_to_see_options", @"TIP: Tap and hold item to see options");
        }
        else {
            
            
            if ( self.viewType != kBrowseViewTypeTags ) {
                Node* currentGroup = [self.viewModel.database getItemById:self.currentGroupId];
                
                if ( !currentGroup || currentGroup.parent == nil ) {
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
    
    
    
    if ( !self.viewModel.isInOfflineMode ) {
        UIRefreshControl* refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(onManualPulldownRefresh) forControlEvents:UIControlEventValueChanged];
        
        self.tableView.refreshControl = refreshControl;
    }
}

- (CGFloat)cellHeight {
    return self.viewType == kBrowseViewTypeTotpList ? 99.0 : 46.5;
}

- (IBAction)onClose:(id)sender {
    if ( self.isEditing ) {
        self.reorderItemOperations = nil;
        [self setEditing:NO];
    }
    else {
        [self.parentSplitViewController onClose];
        
        if (self.viewModel) {
            [self.viewModel closeAndCleanup];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.cellHeight;
}

- (IBAction)onSortItems:(id)sender {
    if ( self.isEditing ) {
        NSLog(@"🔴 onSortItems called in edit mode!");
        




















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
                [self updateAndRefresh];
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
    
    if ( !self.sni ) {
        self.sni = [[SetNodeIconUiHelper alloc] init];
    }
    self.sni.customIcons = self.viewModel.database.iconPool;
    
    __weak BrowseSafeView* weakSelf = self;
    [self.sni changeIcon:self
                    node:item
             urlOverride:nil
                  format:self.viewModel.database.originalFormat
          keePassIconSet:self.viewModel.metadata.keePassIconSet
              completion:^(BOOL goNoGo, BOOL isRecursiveGroupFavIconResult, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selected) {
        if(goNoGo) {
            if (selected) {
                [weakSelf setCustomIcons:item selected:selected isRecursiveGroupFavIconResult:isRecursiveGroupFavIconResult];
            }
            else {
                NodeIcon* icon = selected.allValues.firstObject;
                item.icon = icon;
            }
            
            [weakSelf updateAndRefresh];
        }
        
        if(completion) {
            completion(goNoGo);
        }
    }];
}

- (void)setCustomIcons:(Node*)item
              selected:(NSDictionary<NSUUID *,NodeIcon *>*)selected
isRecursiveGroupFavIconResult:(BOOL)isRecursiveGroupFavIconResult {
    if(isRecursiveGroupFavIconResult) {
        for(Node* node in item.allChildRecords) {
            node.icon = selected[node.uuid];
        }
    }
    else {
        item.icon = selected.allValues.firstObject;
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)){
    return [self isUsingLegacyUi] ? [self getLegacyRightSlideActions:indexPath] : [self getRightSlideActions:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)) {
    return [self isUsingLegacyUi] ? [self getLegacyLeftSlideActions:indexPath] : [self getLeftSlideActions:indexPath];
}

- (UIContextualAction*)getRemoveAction:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)){
    Node *item = [self getNodeFromIndexPath:indexPath];
    BOOL willRecycle = [self.viewModel canRecycle:item.uuid];
    NSString* title = willRecycle ? NSLocalizedString(@"generic_action_verb_recycle", @"Recycle") : NSLocalizedString(@"browse_vc_action_delete", @"Delete");
    
    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:title
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
    
    BOOL pinned = [self.viewModel isFavourite:item.uuid];
    
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:pinned ?
                                     NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") :
                                     NSLocalizedString(@"browse_vc_action_pin", @"Pin")
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self toggleFavourite:item];
        completionHandler(YES);
    }];
    
    if (@available(iOS 13.0, *)) {
        pinAction.image = [UIImage systemImageNamed:pinned ? @"star.slash" : @"star"];
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
    
    UIImage* auditImage;
    if (@available(iOS 13.0, *)) {
        auditImage = [UIImage systemImageNamed:@"checkmark.shield"];
    }
    else {
        auditImage = [UIImage imageNamed:@"security_checked"];
    }
    
    pinAction.image = auditImage;
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
    
    return [UISwipeActionsConfiguration configurationWithActions:item.isGroup ? @[] : @[auditAction, pinAction]];
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
            return self.viewModel.database.originalFormat != kPasswordSafe ?
            [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, setIconAction]] :
            [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction]];
        }
        else {
            return [UISwipeActionsConfiguration configurationWithActions:@[removeAction, duplicateItemAction, setIconAction, pinAction]];
        }
    }
    else {
        return [UISwipeActionsConfiguration configurationWithActions:item.isGroup ? @[] : @[auditAction]];
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
                                                                         title:[self.viewModel isFavourite:item.uuid] ?
                                       NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") :
                                       NSLocalizedString(@"browse_vc_action_pin", @"Pin")
                                                                       handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self toggleFavourite:item];
    }];
    pinAction.backgroundColor = UIColor.magentaColor;
    
    if(!self.viewModel.isReadOnly) {
        if(item.isGroup) {
            return self.viewModel.database.originalFormat != kPasswordSafe ? @[removeAction, renameAction, setIconAction] : @[removeAction, renameAction];
        }
        else {
            return @[removeAction, duplicateItemAction, auditItemAction, pinAction];
        }
    }
    else {
        return item.isGroup ? @[] : @[auditItemAction];
    }
}

- (void)showAuditDrillDown:(Node*)item {
    [self performSegueWithIdentifier:@"segueToAuditDrillDown" sender:item.uuid];
}

- (void)toggleFavourite:(Node*)item {
    if ( item.isGroup || self.viewModel.isReadOnly ) {
        return; 
    }
    
    BOOL needsSave = [self.viewModel toggleFavourite:item.uuid];
    
    if ( needsSave ) {
        [self updateAndRefresh];
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:kNotificationNameItemDetailsEditDone object:item.uuid]; 
}

- (void)duplicateItem:(Node*)item {
    [self duplicateItem:item completion:nil];
}

- (void)duplicateItem:(Node*)item completion:(void (^)(BOOL actionPerformed))completion {
    DuplicateOptionsViewController* vc = [DuplicateOptionsViewController instantiate];
    NSString* newTitle = [item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")];
    
    vc.initialTitle = newTitle;
    vc.showFieldReferencingOptions = self.viewModel.database.originalFormat != kPasswordSafe;
    vc.completion = ^(BOOL go, BOOL referencePassword, BOOL referenceUsername, BOOL preserveTimestamp, NSString * _Nonnull title, BOOL editAfter) {
        if ( go ) {
            Node* dupe = [item duplicate:title preserveTimestamps:preserveTimestamp];
            
            if ( self.viewModel.database.originalFormat != kPasswordSafe ) {
                if ( referencePassword ) {
                    NSString *fieldReference = [NSString stringWithFormat:@"{REF:P@I:%@}", keePassStringIdFromUuid(item.uuid)];
                    dupe.fields.password = fieldReference;
                }
                
                if ( referenceUsername ) {
                    NSString *fieldReference = [NSString stringWithFormat:@"{REF:U@I:%@}", keePassStringIdFromUuid(item.uuid)];
                    dupe.fields.username = fieldReference;
                }
            }
            
            [item touch:NO touchParents:YES];
            
            BOOL done = [self.viewModel addChildren:@[dupe] destination:item.parent];
            
            [self updateAndRefresh];
            
            if ( done && editAfter ) {
                [self editEntry:dupe];
            }
        }
        
        if ( completion ) {
            completion( go );
        }
    };
    
    [vc presentFromViewController:self];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    
    return !self.isEditing && (sender == self || [identifier isEqualToString:@"segueToSafeSettings"]);
}




- (void)onDatabaseReloaded:(id)param {
    if ( !self.isEditing ) {
        NSLog(@"Received Database Reloaded Notification from Model");
        
        if ( self.viewModel.database.originalFormat == kPasswordSafe ) { 
            Node* node = [self.viewModel.database getItemByCrossSerializationFriendlyId:self.pwSafeRefreshSerializationId];
            if ( node ) {
                self.currentGroupId = node.uuid;
            }
            else {
                self.currentGroupId = self.viewModel.database.effectiveRootGroup.uuid;
            }
        }
        
        [self refresh];
    }
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

- (void)refresh {
    [self refreshItems];
    
    [self refreshNavBarTitle];
    
    [self refreshiOS14ButtonMenus];
}

- (void)refreshItems {
    if ( self.searchController.isActive ) {
        [self updateSearchResultsForSearchController:self.searchController];
    }
    else {
        [self.configuredDataSource refresh];
        [self.tableView reloadData];
        
        self.editButtonItem.enabled = !self.viewModel.isReadOnly;
    }
    
    [self updateNavAndToolbarButtonsState];
}

- (void)refreshNavBarTitle {
    NSString* title;
    UIImage *image = nil;
    UIColor* tint = nil;
    
    if ( self.viewType == kBrowseViewTypeTags ) {
        if ( self.currentTag == nil ) {
            title = NSLocalizedString(@"browse_prefs_item_subtitle_tags", @"Tags");
            if (@available(iOS 13.0, *)) {
                image = [UIImage systemImageNamed:@"tag.circle" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
            }
        }
        else {
            title = self.currentTag;
            if (@available(iOS 13.0, *)) {
                image = [UIImage systemImageNamed:@"tag.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
            }
        }
    }
    else if ( self.viewType == kBrowseViewTypeFavourites ) {
        title = NSLocalizedString(@"browse_vc_section_title_pinned", @"Favourites");
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"star.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
        }
        tint = UIColor.systemYellowColor;
    }
    else if ( self.viewType == kBrowseViewTypeList ) {
        title = NSLocalizedString(@"browse_prefs_view_as_flat_list", @"Entries");
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"list.bullet" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
        }
    }
    else if ( self.viewType == kBrowseViewTypeTotpList ) {
        title = NSLocalizedString(@"browse_prefs_view_as_totp_list", @"TOTPs");
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:@"timer" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
        }
    }
    else {
        Node* currentGroup = [self.viewModel.database getItemById:self.currentGroupId];
        title = (currentGroup == nil || currentGroup.parent == nil) ? self.viewModel.metadata.nickName : currentGroup.title;
        image = [NodeIconHelper getIconForNode:currentGroup predefinedIconSet:self.viewModel.metadata.keePassIconSet format:self.viewModel.database.originalFormat];
        tint = self.viewModel.database.recycleBinNode == currentGroup ? Constants.recycleBinTintColor : nil;
    }
    
    NSString* suffix = self.viewModel.isInOfflineMode ? NSLocalizedString(@"browse_vc_offline_suffix", @" (Offline)") : (self.viewModel.isReadOnly ? NSLocalizedString(@"browse_vc_read_only_suffix", @" (Read Only)") : @"" );
    NSString* fullTitle = [NSString stringWithFormat:@"%@%@", title, suffix];
    
    UIView* view = [MMcGSwiftUtils navTitleWithImageAndTextWithTitleText:fullTitle
                                                                   image:image
                                                                    tint:tint];
    
    self.navigationItem.title = nil;
    self.navigationItem.titleView = view;
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

- (NSString*)getTagFromIndexPath:(NSIndexPath*)indexPath {
    id ret = [[self getTableDataSource] getParamFromIndexPath:indexPath];
    
    if ( [ret isKindOfClass:NSString.class] ) {
        return ret;
    }
    
    return nil;
}

- (Node*)getNodeFromIndexPath:(NSIndexPath*)indexPath {
    id ret = [[self getTableDataSource] getParamFromIndexPath:indexPath];
    
    if ( [ret isKindOfClass:Node.class] ) {
        return ret;
    }
    
    return nil;
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

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [[self getTableDataSource] sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [[self getTableDataSource] sectionForSectionIndexTitle:title atIndex:index];
}

- (BOOL)isShowingQuickViews {
    return self.searchController.isActive && self.searchController.searchBar.text.length == 0;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( self.isEditing ) {
        [self updateNavAndToolbarButtonsState]; 
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    if ( [DatabasePreferences isEditing:self.viewModel.metadata] ) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"item_details_vc_discard_changes", @"Discard Changes?")
              message:NSLocalizedString(@"item_details_vc_are_you_sure_discard_changes", @"Are you sure you want to discard all your changes?")
               action:^(BOOL response) {
            if(response) {
                [self continueDidSelectRowAtIndexPath:indexPath];
            }
            else {
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
        }];
    }
    else {
        [self continueDidSelectRowAtIndexPath:indexPath];
    }
}

- (void)continueDidSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    if ([self isShowingQuickViews]) {
        [self.quickViewsDataSource performTapAction:indexPath searchController:self.searchController];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    if ( [self isUsingLegacyUi] ) {
        [self handleLegacyDidSelectRowAtIndexPath:indexPath];
        return;
    }
    if ( self.isEditing ) {
        [self updateNavAndToolbarButtonsState]; 
        return;
    }
 
    Node* item = nil;
    NSString* tag = nil;
    if ( self.searchController.isActive ) {
        item = [self getNodeFromIndexPath:indexPath];
    }
    else if ( self.viewType != kBrowseViewTypeTags || self.currentTag != nil ) {
        item = [self getNodeFromIndexPath:indexPath];
    }
    else {
        tag = [self getTagFromIndexPath:indexPath];
    }

    if ( item != nil ) {
        if ( item.isGroup ) {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item.uuid];
        }
        else {
            BrowseTapAction action = self.viewModel.metadata.tapAction;
            action = self.viewType == kBrowseViewTypeTotpList ? kBrowseTapActionCopyTotp : action; 
            
            [self performTapAction:item action:action];
        }
    }
    else if ( tag != nil ) {
        NSString* tag = [self getTagFromIndexPath:indexPath];
        [self performSegueWithIdentifier:@"sequeToSubgroup" sender:tag];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDetails:(Node*)item {
    if (item) {
        if ( item.isGroup ) {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item.uuid]; 
        }
        else {
            [self showEntry:item];
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
    if ([segue.identifier isEqualToString:@"segueToAuditDrillDown"]) {
        UINavigationController* nav = segue.destinationViewController;
        AuditDrillDownController *vc = (AuditDrillDownController*)nav.topViewController;
        
        __weak BrowseSafeView* weakSelf = self;
        
        vc.model = self.viewModel;
        vc.itemId = sender;
        vc.onDone = ^(BOOL showAllAuditIssues, UIViewController *__weak  _Nonnull viewControllerToDismiss) {
            
            
            [viewControllerToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if (showAllAuditIssues) {
                    [weakSelf showAllAuditIssues];
                }
            }];
        };
        vc.updateDatabase = ^{
            [weakSelf updateAndRefresh];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueMasterDetailToDetail"] || [segue.identifier isEqualToString:@"segueMasterDetailToDetail-NonAnimated"]) {

        ItemDetailsViewController *vc = (ItemDetailsViewController*)segue.destinationViewController;
        
        NSDictionary* params = (NSDictionary*)sender;
        Node* record = params[kItemToEditParam];
        NSNumber* editImmediately = params[kEditImmediatelyParam];
        vc.createNewItem = record == nil;
        vc.editImmediately = editImmediately.boolValue;
        vc.itemId = record ? record.uuid : nil;
        vc.parentGroupId = record ? record.parent.uuid : self.currentGroupId;
        vc.forcedReadOnly = self.viewModel.isReadOnly;
        vc.databaseModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToConfigureTabs"]){
        UINavigationController *nav = segue.destinationViewController;
        ConfigureTabsViewController *vc = (ConfigureTabsViewController*)nav.topViewController;
        vc.model = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"sequeToSubgroup"]){
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewType = self.viewType;
        vc.viewModel = self.viewModel;
        
        if ( sender ) {
            if ( [sender isKindOfClass:NSString.class] ) {
                vc.currentTag = sender;
                vc.viewType = kBrowseViewTypeTags;
            }
            else {
                vc.currentGroupId = (NSUUID *)sender;
                vc.viewType = kBrowseViewTypeHierarchy; 
            }
        }
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectDestination"]) {
        NSArray *itemsToMove = (NSArray *)sender;
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = (SelectDestinationGroupController*)nav.topViewController;
        
        vc.currentGroup = self.viewModel.database.effectiveRootGroup;
        vc.viewModel = self.viewModel;
        
        __weak BrowseSafeView* weakSelf = self;
        
        vc.validateDestination = ^BOOL(Node * _Nonnull destinationGroup) {
            return [weakSelf validateMoveDestination:itemsToMove destinationGroup:destinationGroup];
        };
        
        vc.onSelectedDestination = ^(Node * _Nonnull destination) {
            [weakSelf onMoveItems:destination items:itemsToMove];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToPreferencesAndManagement"]) {
        UINavigationController* nav = segue.destinationViewController;
        
        DatabasePreferencesController *vc = (DatabasePreferencesController*)nav.topViewController;
        vc.viewModel = self.viewModel;
        
        __weak BrowseSafeView* weakSelf = self;
        
        vc.onDatabaseBulkIconUpdate = ^(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
            for(Node* node in weakSelf.viewModel.database.allActiveEntries) {
                UIImage* img = selectedFavIcons[node.uuid];
                if(img) {
                    NSData *data = UIImagePNGRepresentation(img);
                    node.icon = [NodeIcon withCustom:data];
                }
            }
            [weakSelf updateAndRefresh];
        };
        
        vc.onSetMasterCredentials = ^(NSString * _Nullable password, NSString * _Nullable keyFileBookmark, NSString * _Nullable keyFileFileName, NSData * _Nullable oneTimeKeyFileData, YubiKeyHardwareConfiguration * _Nullable yubiConfig) {
            [weakSelf setCredentials:password
                     keyFileBookmark:keyFileBookmark
                     keyFileFileName:keyFileFileName
                  oneTimeKeyFileData:oneTimeKeyFileData
                          yubiConfig:yubiConfig];
        };
        
        vc.updateDatabase = ^{
            [weakSelf updateAndRefresh];
        };
        
        vc.onDone = ^(BOOL showAllAuditIssues, UIViewController *__weak  _Nonnull viewControllerToDismiss) {
            [weakSelf refreshiOS14ButtonMenus];
            
            
            
            [viewControllerToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if (showAllAuditIssues) {
                    [weakSelf showAllAuditIssues];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToConvenienceUnlock"]) {
        UINavigationController* nav = segue.destinationViewController;
        ConvenienceUnlockPreferences* vc = (ConvenienceUnlockPreferences*)nav.topViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToSortOrder"]){
        UINavigationController* nav = segue.destinationViewController;
        SortOrderTableViewController* vc = (SortOrderTableViewController*)nav.topViewController;
        vc.format = self.viewModel.database.originalFormat;
        vc.field = self.sortConfiguration.field;
        vc.descending = self.sortConfiguration.descending;
        vc.foldersSeparately = self.sortConfiguration.foldersOnTop;
        
        BOOL showAlphaIndex = self.sortConfiguration.showAlphaIndex; 
        
        vc.onChangedOrder = ^(BrowseSortField field, BOOL descending, BOOL foldersSeparately) {
            [self onChangedBrowseSortOrder:field descending:descending foldersSeparately:foldersSeparately showAlphaIndex:showAlphaIndex];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToCustomizeView"]){
        UINavigationController* nav = segue.destinationViewController;
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)nav.topViewController;
        vc.databaseMetaData = self.viewModel.metadata;
        vc.model = self.viewModel;
        vc.format = self.viewModel.database.originalFormat;
        
        vc.onDone = ^{
            [self refreshiOS14ButtonMenus];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToChangeMasterCredentials"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        scVc.mode = kCASGModeSetCredentials;
        scVc.initialFormat = self.viewModel.database.originalFormat;
        scVc.initialKeyFileBookmark = self.viewModel.metadata.keyFileBookmark;
        scVc.initialYubiKeyConfig = self.viewModel.metadata.contextAwareYubiKeyConfig;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self setCredentials:creds.password
                         keyFileBookmark:creds.keyFileBookmark
                         keyFileFileName:creds.keyFileFileName
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
    else if ( [segue.identifier isEqualToString:@"segueToExportItems"] ) {
        __weak BrowseSafeView* weakSelf = self;
        
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SecondDatabaseListTableViewController* vc = (SecondDatabaseListTableViewController*)nav.topViewController;
        vc.firstDatabase = self.viewModel;
        vc.disableReadOnlyDatabases = YES;
        vc.customTitle = NSLocalizedString(@"export_items_select_destination_database_title", @"Destination Database");
        
        NSArray<Node*>* itemsToExport = sender;
        vc.onSelectedDatabase = ^(DatabasePreferences * _Nonnull secondDatabase, UIViewController *__weak  _Nonnull vcToDismiss) {
            [vcToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
                [weakSelf onExportItemsToDatabase:secondDatabase itemsToExport:itemsToExport];
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectDestinationExportGroup"]) {
        NSDictionary* params = sender;
        
        NSArray *items = (NSArray *)params[@"items"];
        Model* destinationModel = (Model *)params[@"destinationModel"];
        
        UINavigationController *nav = segue.destinationViewController;
        SelectDestinationGroupController *vc = (SelectDestinationGroupController*)nav.topViewController;
        
        vc.currentGroup = destinationModel.database.effectiveRootGroup;
        vc.viewModel = destinationModel;
        vc.hideAddGroupButton = YES;
        vc.customSelectDestinationButtonTitle = NSLocalizedString(@"export_items_select_destination_group_title", @"Export Here");
        
        __weak BrowseSafeView* weakSelf = self;
        
        vc.validateDestination = ^BOOL(Node * _Nonnull destinationGroup) {
            return [weakSelf validateExportDestinationGroup:destinationModel
                                           destinationGroup:destinationGroup
                                              itemsToExport:items];
        };
        
        vc.onSelectedDestination = ^(Node * _Nonnull destination) {
            [weakSelf onExportItemsToUnlockedDatabase:destinationModel destinationGroup:destination itemsToExport:items];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToExportItemsOptions"] ) {
        NSDictionary* params = sender;
        NSArray<Node*>* itemsToExport = params[@"items"];
        Model* destinationModel = params[@"destinationModel"];
        Node* destinationGroup = params[@"destinationGroup"];
        NSSet<NSUUID*>* itemsIntersection = params[@"itemsIntersection"];
        
        UINavigationController* nav = segue.destinationViewController;
        ExportItemsOptionsViewController* vc = (ExportItemsOptionsViewController*)nav.topViewController;
        
        vc.items = itemsToExport;
        vc.destinationModel = destinationModel;
        vc.itemsIntersection = itemsIntersection;
        
        vc.completion = ^(BOOL makeBrandNewCopy, BOOL preserveTimestamps) {
            [self onExportItemsToUnlockedDatabaseContinuation:destinationModel
                                             destinationGroup:destinationGroup
                                                itemsToExport:itemsToExport
                                           makeBrandNewCopies:makeBrandNewCopy
                                           preserveTimestamps:preserveTimestamps];
        };
    }
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
    __weak BrowseSafeView* weakSelf = self;
    
    Node* currentGroup = [self.viewModel.database getItemById:self.currentGroupId];
    
    __weak Node* weakCurrentGroup = currentGroup;
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:NSLocalizedString(@"browse_vc_group_name", @"Group Name")
                            title:NSLocalizedString(@"browse_vc_enter_group_name", @"Enter Group Name")
                          message:NSLocalizedString(@"browse_vc_enter_group_name_message", @"Please Enter the New Group Name:")
                       completion:^(NSString *text, BOOL response) {
        if (response) {
            if ([weakSelf.viewModel addNewGroup:weakCurrentGroup title:text] != nil) {
                [weakSelf updateAndRefresh];
            }
            else {
                [Alerts warn:weakSelf
                       title:NSLocalizedString(@"browse_vc_cannot_create_group", @"Cannot create group")
                     message:NSLocalizedString(@"browse_vc_cannot_create_group_message", @"Could not create a group with this name here, possibly because one with this name already exists.")];
            }
        }
    }];
}

- (void)onAddEntry {
    [self createNewEntry];
}



- (void)createNewEntry {
    [self showEntry:nil editImmediately:YES];
}

- (void)editEntry:(Node*)item {
    if(item.isGroup) {
        return;
    }
    
    [self showEntry:item editImmediately:YES];
}

- (void)showEntry:(Node*)item {
    [self showEntry:item animated:YES];
}

- (void)showEntry:(Node*)item animated:(BOOL)animated {
    if(item.isGroup) {
        return;
    }
    
    [self showEntry:item editImmediately:NO animated:animated];
}

- (void)showEntry:(Node*)item editImmediately:(BOOL)editImmediately {
    [self showEntry:item editImmediately:editImmediately animated:YES];
}

- (void)showEntry:(Node*)item editImmediately:(BOOL)editImmediately animated:(BOOL)animated {
    NSString* segueName = animated ? @"segueMasterDetailToDetail" : @"segueMasterDetailToDetail-NonAnimated";
    
    if ( item ) {
        self.viewModel.metadata.lastViewedEntry = item.uuid;
        
        [self performSegueWithIdentifier:segueName
                                  sender:@{ kItemToEditParam : item, kEditImmediatelyParam : @(editImmediately) } ];
    }
    else {
        if ( editImmediately ) { 
            [self performSegueWithIdentifier:segueName sender:nil];
        }
        else if ( !self.splitViewController.isCollapsed ) {
            self.viewModel.metadata.lastViewedEntry = nil;
            
            [self performSegueWithIdentifier:@"segueMasterDetailToEmptyDetail" sender:nil];
        }
    }
}

- (IBAction)onMove:(id)sender {
    if ( self.isEditing ) {
        NSArray<NSIndexPath*> *selectedRows = self.tableView.indexPathsForSelectedRows;
        
        if (selectedRows && selectedRows.count > 0) {
            NSArray<Node *> *itemsToMove = [self getSelectedItems:selectedRows];
            
            [self performSegueWithIdentifier:@"segueToSelectDestination" sender:itemsToMove];
            
            [self setEditing:NO animated:YES];
        }
    }
}

- (BOOL)validateMoveDestination:(NSArray*)itemsToMove destinationGroup:(Node*)destinationGroup {
    return [self.viewModel.database validateMoveItems:itemsToMove destination:destinationGroup];
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
    BOOL willRecycle = [self.viewModel canRecycle:item.uuid];

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
                        if(self.isEditing) {
                            [self setEditing:NO animated:YES];
                        }
                        
                        [self updateAndRefresh:YES];
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
        BOOL delete = [self.viewModel canRecycle:obj.uuid];
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
            
            if(self.isEditing) {
                [self setEditing:NO animated:YES];
            }
            [self updateAndRefresh:YES];
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
                   
                   if(self.isEditing) {
                       [self setEditing:NO animated:YES];
                   }
                   [self updateAndRefresh:YES];
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
               
               [self refresh];
           }
           else {
               if(self.isEditing) {
                   [self setEditing:NO animated:YES];
               }
               
               [self updateAndRefresh:YES];
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



- (void)handleSingleTap:(NSIndexPath *)indexPath  {
    if ( self.isEditing ) {
        [self updateNavAndToolbarButtonsState]; 
        return;
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    Node* item = nil;
    NSString* tag = nil;
    if ( self.searchController.isActive ) {
        item = [self getNodeFromIndexPath:indexPath];
    }
    else if ( self.viewType != kBrowseViewTypeTags || self.currentTag != nil ) {
        item = [self getNodeFromIndexPath:indexPath];
    }
    else {
        tag = [self getTagFromIndexPath:indexPath];
    }
    
    if ( item != nil ) {
        if ( item.isGroup ) {
            [self performSegueWithIdentifier:@"sequeToSubgroup" sender:item.uuid];
        }
        else {
            [self performTapAction:item action:self.viewModel.metadata.tapAction];
        }
    }
    else if ( tag != nil ) {
        NSString* tag = [self getTagFromIndexPath:indexPath];
        [self performSegueWithIdentifier:@"sequeToSubgroup" sender:tag];
    }
}

- (void)handleDoubleTap:(NSIndexPath *)indexPath {
    if(self.isEditing) {
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
    if(self.isEditing) {
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
    if(self.isEditing) {
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
            [self showEntry:item];
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

- (void)copyAllFields:(Node*)item {
    NSMutableArray<NSString*>* fields = NSMutableArray.array;
    
    [fields addObject:[self dereference:item.title node:item]];
    [fields addObject:[self dereference:item.fields.username node:item]];
    [fields addObject:[self dereference:item.fields.password node:item]];
    [fields addObject:[self dereference:item.fields.url node:item]];
    [fields addObject:[self dereference:item.fields.notes node:item]];
    [fields addObject:[self dereference:item.fields.email node:item]];
    
    
    
    NSArray* sortedKeys = [item.fields.customFieldsNoEmail.allKeys sortedArrayUsingComparator:finderStringComparator];
    for(NSString* key in sortedKeys) {
        if ( ![NodeFields isTotpCustomFieldKey:key] ) {
            StringValue* sv = item.fields.customFields[key];
            NSString *val = [self dereference:sv.value node:item];
            [fields addObject:val];
        }
    }

    
    
    NSArray<NSString*> *all = [fields filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length != 0;
    }];
    
    NSString* allString = [all componentsJoinedByString:@"\n"];
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:allString];
    
    [ISMessages showCardAlertWithTitle:NSLocalizedString(@"generic_copied", @"Copied")
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
    
    if( self.viewType == kBrowseViewTypeTotpList ) {
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





- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)){
    if (self.isEditing || [self isShowingQuickViews]) {
        return nil;
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item) {
        return nil;
    }

    __weak BrowseSafeView* weakSelf = self;
    
    return [UIContextMenuConfiguration configurationWithIdentifier:indexPath
                                                   previewProvider:^UIViewController * _Nullable{ return item.isGroup ? nil : [PreviewItemViewController forItem:item andModel:self.viewModel];   }
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:@[
                                [weakSelf getContextualMenuNonMutators:indexPath item:item],

                                [weakSelf getContextualMenuCopyFieldToClipboard:indexPath item:item],
                                [weakSelf getContextualMenuMutators:indexPath item:item],
                            ]];
    }];
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    Node *item = [self getNodeFromIndexPath:(NSIndexPath*)configuration.identifier];
    [self openDetails:item];
}

- (UIMenu*)getContextualMenuNonMutators:(NSIndexPath*)indexPath item:(Node*)item  API_AVAILABLE(ios(13.0)){
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    if (!item.isGroup) [ma addObject:[self getContextualMenuAuditSettingsAction:indexPath item:item]];
    if (item.fields.password.length) [ma addObject:[self getContextualMenuShowLargePasswordAction:indexPath item:item]];
    
    [ma addObject:[self getContextualMenuPropertiesAction:indexPath item:item]];
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuPropertiesAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_vc_action_properties", @"Properties")
                           systemImage:@"list.bullet"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToItemProperties" sender:item];
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
    __weak BrowseSafeView* weakSelf = self;
    
    if ( !item.isGroup ) {
        
        
        [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_all_fields" item:item handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf copyAllFields:item];
        }]];
        
        
        
        if ( item.fields.username.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_username" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyUsername:item];
            }]];
        }
        
        

        [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_password" item:item handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf copyPassword:item];
        }]];
        
        

        if (item.fields.otpToken) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_totp" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyTotp:item];
            }]];
        }
     
        
        
        NSURL* launchUrl = [self getLaunchUrlForItem:item];
        
        if ( launchUrl ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_url" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyUrl:item];
            }]];
        }
        
        

        if ( item.fields.email.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_email" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyEmail:item];
            }]];
        }
        
        

        if ( item.fields.notes.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_notes" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyNotes:item];
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
                    
                    NSString* value = [weakSelf dereference:sv.value node:item];
                    
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
    
    if (!self.viewModel.isReadOnly) {
        
        
        if (!item.isGroup) [ma addObject:[self getContextualMenuTogglePinAction:indexPath item:item]];

        
    
        [ma addObject:[self getContextualMenuMoveAction:indexPath item:item]];

        

        if(!item.isGroup) {
            [ma addObject:[self getContextualMenuDuplicateAction:indexPath item:item]];
        }
    
        
        
        if (item.isGroup) {
            
            if ( self.viewModel.database.originalFormat != kPasswordSafe ) {
                [ma addObject:[self getContextualMenuSetIconAction:indexPath item:item]];
            }

            [ma addObject:[self getContextualMenuRenameAction:indexPath item:item]];
        }
    }
    
    if ( self.isItemsCanBeExported ) { 
        [ma addObject:[self getContextualExportItemsAction:indexPath item:item]];
    
    }

    if ( !self.viewModel.isReadOnly || self.isItemsCanBeExported ) {
        if ( self.searchController.isActive && !self.tableView.isEditing ) {
            [ma addObject:[self getContextualSelectItemsAction:indexPath item:item]];
        }
    }

    if(!self.viewModel.isReadOnly) {    
        [ma addObject:[self getContextualMenuRemoveAction:indexPath item:item]];
    }

    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}



- (UIAction*)getContextualMenuTogglePinAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    BOOL pinned = [self.viewModel isFavourite:item.uuid];
    NSString* title = pinned ? NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") : NSLocalizedString(@"browse_vc_action_pin", @"Pin");

    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                           systemImage:pinned ? @"star.slash" : @"star"
                               handler:^(__kindof UIAction * _Nonnull action) {
         [weakSelf toggleFavourite:item];
    }];
}

- (UIAction*)getContextualMenuAuditSettingsAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                           systemImage:@"checkmark.shield"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAuditDrillDown:item];
    }];
}

- (UIAction*)getContextualMenuShowLargePasswordAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)){
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_show_password", @"Show Password")
                           systemImage:@"eye"
                               handler:^(__kindof UIAction * _Nonnull action) {
        NSString* pw = [weakSelf dereference:item.fields.password node:item];
        [weakSelf performSegueWithIdentifier:@"segueBrowseToLargeTextView" sender:@{ @"text" : pw, @"colorize" : @(weakSelf.viewModel.metadata.colorizePasswords) }];
    }];
}

- (UIAction*)getContextualMenuCopyUsernameAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyUsername:item];
    }];
}

- (UIAction*)getContextualMenuCopyPasswordAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyPassword:item];
    }];
}

- (UIAction*)getContextualMenuCopyTotpAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyTotp:item];
    }];
}

- (UIAction*)getContextualMenuLaunchAndCopyAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_action_launch_url_copy_password", @"Launch URL & Copy")
                           systemImage:@"bolt"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyAndLaunch:item];
    }];
}

- (UIAction*)getContextualMenuGenericCopy:(NSString*)locKey item:(Node*)item handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0)) {
    return [ContextMenuHelper getItem:NSLocalizedString(locKey, nil)
                           systemImage:@"doc.on.doc"
                               handler:handler];
}

- (UIAction*)getContextualMenuSetIconAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") : NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon");
    __weak BrowseSafeView* weakSelf = self;
    return [ContextMenuHelper getItem:title
                           systemImage:@"photo"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onSetIconForItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuDuplicateAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate");
        
    __weak BrowseSafeView* weakSelf = self;

    return [ContextMenuHelper getItem:title
                           systemImage:@"plus.square.on.square"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf duplicateItem:item completion:nil];
    }];
}

- (UIAction*)getContextualMenuRenameAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"browse_vc_action_rename", @"Rename");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                           systemImage:@"pencil"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onRenameItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuMoveAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"generic_move", @"Move");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                           systemImage:@"arrow.up.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToSelectDestination" sender:@[item]];
    }];
}

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    BOOL willRecycle = [self.viewModel canRecycle:item.uuid];
    NSString* title = willRecycle ? NSLocalizedString(@"generic_action_verb_recycle", @"Recycle") : NSLocalizedString(@"browse_vc_action_delete", @"Delete");

    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getDestructiveItem:title
                                     systemImage:@"trash"
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onDeleteSingleItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualExportItemsAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    NSString* title = NSLocalizedString(@"generic_export_item", @"Export Item");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                           systemImage:@"square.and.arrow.up.on.square"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onExportItemSingleItem:item];
    }];
}

- (UIAction*)getContextualSelectItemsAction:(NSIndexPath*)indexPath item:(Node*)item API_AVAILABLE(ios(13.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"generic_select", @"Select")
                          systemImage:@"checkmark.circle"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf setEditing:YES animated:YES];
        
        [weakSelf.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
 
        [weakSelf updateNavAndToolbarButtonsState];
    }];
}



- (NSURL*)getLaunchUrlForItem:(Node*)item {
    NSString* urlString = [self dereference:item.fields.url node:item];

    if (!urlString.length) {
        return nil;
    }
        
    return urlString.urlExtendedParseAddingDefaultScheme;
}

- (void)copyAndLaunch:(Node*)item {
    if ( item.fields.url.length ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self copyPassword:item];
            [self.viewModel launchUrl:item];
        });
    }
}



- (void)onManualPulldownRefresh {
    NSLog(@"Browse: onManualPulldownRefresh. Syncing.");
    
    __weak BrowseSafeView* weakSelf = self;
    
    if ( self.viewModel.isInOfflineMode ) {
        [ISMessages showCardAlertWithTitle:NSLocalizedString(@"browse_vc_pulldown_refresh_offline_title", @"Offline Mode")
                                   message:NSLocalizedString(@"browse_vc_pulldown_refresh_offline_message", @"Database Not Refreshed")
                                  duration:1.5f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeInfo
                             alertPosition:ISAlertPositionTop
                                   didHide:^(BOOL finished) {
            [weakSelf.tableView.refreshControl endRefreshing];
        }];
        
        return;
    }
    
    [self.parentSplitViewController syncWithCompletion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView.refreshControl endRefreshing];

            if ( localWasChanged ) {
                [StrongboxToastMessages showSlimInfoStatusBarWithBody:NSLocalizedString(@"browse_vc_pulldown_refresh_updated_title", @"Database Updated")
                                                                delay:1.5];
            }
        });
    }];
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



- (void)setCredentials:(NSString*)password
       keyFileBookmark:(NSString*)keyFileBookmark
       keyFileFileName:(NSString*)keyFileFileName
    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    CompositeKeyFactors *newCkf = [[CompositeKeyFactors alloc] initWithPassword:password];
        
    BOOL usingImportedKeyFile = keyFileBookmark || keyFileFileName;
    BOOL keyFileInvolved = usingImportedKeyFile || oneTimeKeyFileData;
    
    if( keyFileInvolved ) {
        NSError* error;
        NSData* keyFileDigest = [KeyFileParser getDigestFromSources:keyFileBookmark
                                                    keyFileFileName:keyFileFileName
                                                 onceOffKeyFileData:oneTimeKeyFileData
                                                             format:self.viewModel.database.originalFormat
                                                              error:&error];
        
        if ( keyFileDigest == nil ) {
            [Alerts error:self
                    title:NSLocalizedString(@"db_management_error_title_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
            return;
        }
        
        newCkf = [CompositeKeyFactors password:newCkf.password keyFileDigest:keyFileDigest];
    }

    if (yubiConfig && yubiConfig.mode != kNoYubiKey) {
        newCkf = [CompositeKeyFactors password:newCkf.password keyFileDigest:newCkf.keyFileDigest yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [YubiManager.sharedInstance getResponse:yubiConfig challenge:challenge completion:completion];
        }];
    }

    CompositeKeyFactors *rollbackCkf = [self.viewModel.database.ckfs clone];
    self.viewModel.database.ckfs = newCkf;
    
    [self updateAndRefresh:NO
                completion:^(BOOL savedWorkingCopy) {
        if ( savedWorkingCopy ) {
            [self onSuccessfulCredentialsChanged:keyFileBookmark
                                 keyFileFileName:keyFileFileName
                              oneTimeKeyFileData:oneTimeKeyFileData
                                      yubiConfig:yubiConfig];
        }
        else { 
            self.viewModel.database.ckfs = rollbackCkf;
        }
    }];
    











}

- (void)onSuccessfulCredentialsChanged:(NSString*)keyFileBookmark
                       keyFileFileName:(NSString*)keyFileFileName
                    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    if ( self.viewModel.metadata.isConvenienceUnlockEnabled ) {
        if(!oneTimeKeyFileData) {
            self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.ckfs.password;
            self.viewModel.metadata.conveniencePasswordHasBeenStored = YES;
            NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
        }
        else {
            
            self.viewModel.metadata.convenienceMasterPassword = nil;
            self.viewModel.metadata.autoFillConvenienceAutoUnlockPassword = nil;
            self.viewModel.metadata.conveniencePasswordHasBeenStored = NO;
        }
    }
    
    [self.viewModel.metadata setKeyFile:keyFileBookmark keyFileFileName:keyFileFileName];
    self.viewModel.metadata.contextAwareYubiKeyConfig = yubiConfig;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [ISMessages showCardAlertWithTitle:self.viewModel.database.originalFormat == kPasswordSafe ?
         NSLocalizedString(@"db_management_password_changed", @"Master Password Changed") :
         NSLocalizedString(@"db_management_credentials_changed", @"Master Credentials Changed")
                                   message:nil
                                  duration:3.f
                               hideOnSwipe:YES
                                 hideOnTap:YES
                                 alertType:ISAlertTypeSuccess
                             alertPosition:ISAlertPositionTop
                                   didHide:nil];
    });
}

- (void)onMoveItems:(Node*)destination items:(NSArray<Node*>*)items {
    BOOL ret = [self.viewModel.database moveItems:items destination:destination];
        
    if (!ret) {
        NSLog(@"Error Moving");
        NSError* error = [Utils createNSError:NSLocalizedString(@"moveentry_vc_error_moving", @"Error Moving") errorCode:-1];
        [Alerts error:self error:error];
        return;
    }
    
    if(self.isEditing) {
        [self setEditing:NO animated:YES];
    }

    [self updateAndRefresh];
};




- (void)updateAndRefresh {
    [self updateAndRefresh:NO];
}

- (void)updateAndRefresh:(BOOL)clearSelectedDetailItem {
    [self updateAndRefresh:clearSelectedDetailItem completion:nil];
}

- (void)updateAndRefresh:(BOOL)clearSelectedDetailItem completion:(void (^)(BOOL savedWorkingCopy))completion {
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refresh];
        
        if ( clearSelectedDetailItem ) {
            [self showEntry:nil];
        }
    });

    [self.parentSplitViewController updateAndQueueSyncWithCompletion:^(BOOL savedWorkingCopy) {





        if ( completion ) {
            completion(savedWorkingCopy);
        }
    }];
}



- (BOOL)isItemsCanBeExported {
    return [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return ![obj.uuid isEqualToString:self.viewModel.metadata.uuid] && !obj.readOnly;
    }].count > 0;
}

- (void)onExportItemSingleItem:(Node*)node {
    [self beginExportItemsSequence:@[node]];
}

- (IBAction)onExportItemsBarButton:(id)sender {
    if ( self.isEditing ) {
        NSArray<NSIndexPath*> *selectedRows = self.tableView.indexPathsForSelectedRows;
        
        if ( selectedRows && selectedRows.count > 0 ) {
            NSArray<Node *> *items = [self getSelectedItems:selectedRows];
            
            [self beginExportItemsSequence:items];
        }
    }
}

- (void)beginExportItemsSequence:(NSArray<Node*>*)items {
    NSSet* minimalNodeSet = [self.viewModel.database getMinimalNodeSet:items];

    if ( minimalNodeSet.count ) {
        [self performSegueWithIdentifier:@"segueToExportItems" sender:minimalNodeSet.allObjects];
    }
}

- (void)onExportItemsToDatabase:(DatabasePreferences*)destinationDatabase
                  itemsToExport:(NSArray<Node*>*)itemsToExport {
    

    CompositeKeyFactors* firstKey = self.viewModel.database.ckfs;

    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"Loading...")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        Model* expressAttempt = [DatabaseUnlocker expressTryUnlockWithKey:destinationDatabase key:firstKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            
            if ( expressAttempt ) {
                NSLog(@"YAY - Express Unlocked Second DB with same CKFs! No need to re-request CKFs...");
                [self onExportItemsToDatabaseUnlockDestinationDone:kUnlockDatabaseResultSuccess model:expressAttempt itemsToExport:itemsToExport error:nil];
            }
            else {
                IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self database:destinationDatabase isAutoFillOpen:NO isAutoFillQuickTypeOpen:NO biometricPreCleared:NO noConvenienceUnlock:NO];
                [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
                    if (result == kGetCompositeKeyResultSuccess) {
                        DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:destinationDatabase viewController:self forceReadOnly:NO isNativeAutoFillAppExtensionOpen:NO offlineMode:YES];
                        [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                            [self onExportItemsToDatabaseUnlockDestinationDone:result model:model itemsToExport:itemsToExport error:error];
                        }];
                    }
                    else if (result == kGetCompositeKeyResultError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [Alerts error:self
                                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                                    error:error];
                        });
                    }
                    else { 
                    
                    }
                }];
            }
    
        });
    });
}

- (void)onExportItemsToDatabaseUnlockDestinationDone:(UnlockDatabaseResult)result
                                               model:(Model * _Nullable)model
                                       itemsToExport:(NSArray<Node*>*)itemsToExport
                                               error:(NSError * _Nullable)error {
    if(result == kUnlockDatabaseResultSuccess) {
        NSLog(@"model = [%@]", model);
        [self onExportItemsToUnlockedDatabase:model itemsToExport:itemsToExport];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        NSLog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
    }
    else if (result == kUnlockDatabaseResultError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Alerts error:self
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        });
    }
}

- (void)onExportItemsToUnlockedDatabase:(Model * _Nullable)destinationModel
                          itemsToExport:(NSArray<Node*>*)itemsToExport {
    [self performSegueWithIdentifier:@"segueToSelectDestinationExportGroup"
                              sender:@{ @"items" : itemsToExport,
                                        @"destinationModel" : destinationModel
    }];
}

- (BOOL)validateExportDestinationGroup:(Model*)destinationModel
                      destinationGroup:(Node*)destinationGroup
                         itemsToExport:(NSArray<Node*>*)itemsToExport {
    return YES;
}

- (void)onExportItemsToUnlockedDatabase:(Model*)destinationModel
                       destinationGroup:(Node*)destinationGroup
                          itemsToExport:(NSArray<Node*>*)itemsToExport {
    
    NSSet<NSUUID*>* itemsIntersection = [self getSourceDestinationIntersection:itemsToExport destinationModel:destinationModel];
    
    [self performSegueWithIdentifier:@"segueToExportItemsOptions"
                              sender:@{ @"items" : itemsToExport,
                                        @"destinationModel" : destinationModel,
                                        @"destinationGroup" : destinationGroup,
                                        @"itemsIntersection" : itemsIntersection,
    }];
}

- (void)onExportItemsToUnlockedDatabaseContinuation:(Model*)destinationModel
                                   destinationGroup:(Node*)destinationGroup
                                      itemsToExport:(NSArray<Node*>*)itemsToExport
                                 makeBrandNewCopies:(BOOL)makeBrandNewCopies
                                 preserveTimestamps:(BOOL)preserveTimestamps {
    NSLog(@"makeBrandNewCopies = %hhd, preserveTimestamps = %hhd", makeBrandNewCopies, preserveTimestamps);
    
    
    

    NSMutableArray* clonedForExport = NSMutableArray.array;
    
    for (Node* exportItem in itemsToExport) {
        Node* clone = [exportItem cloneOrDuplicate:preserveTimestamps
                                         cloneUuid:!makeBrandNewCopies
                                    cloneRecursive:YES
                                          newTitle:nil
                                        parentNode:destinationGroup];
        
        [clonedForExport addObject:clone];
    }

    
    

    BOOL destinationIsRootGroup = (destinationGroup == nil || destinationGroup == destinationModel.database.effectiveRootGroup);
    
    [DatabaseFormatIncompatibilityHelper processFormatIncompatibilities:clonedForExport
                                                 destinationIsRootGroup:destinationIsRootGroup
                                                           sourceFormat:self.viewModel.database.originalFormat
                                                      destinationFormat:destinationModel.database.originalFormat
                                                    confirmChangesBlock:^(NSString * _Nullable confirmMessage, IncompatibilityConfirmChangesResultBlock resultBlock) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"database_format_incompatibilities_title", @"Format Incompatibilities")
              message:confirmMessage
               action:^(BOOL response) {
            resultBlock(response);
        }];
    } completion:^(BOOL go, NSArray<Node *> * _Nullable compatibleFilteredNodes) {
        if ( go ) {
            [self continueExportItems:destinationModel
                     destinationGroup:destinationGroup
                        itemsToExport:compatibleFilteredNodes
                   makeBrandNewCopies:makeBrandNewCopies];
        }
    }];
}

- (NSSet<NSUUID*>*)getSourceDestinationIntersection:(NSArray<Node*>*)items destinationModel:(Model*)destinationModel {
    NSMutableArray<Node*> *srcNodes = [items flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildren;
    }].mutableCopy;
    [srcNodes addObjectsFromArray:items];
    NSSet<NSUUID*>* srcIds = [srcNodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;

    NSSet<NSUUID*>* destIds = [destinationModel.allItems map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
    
    NSMutableSet *intersection = srcIds.mutableCopy;
    [intersection intersectSet:destIds];
    
    return intersection;
}

- (void)continueExportItems:(Model*)destinationModel
           destinationGroup:(Node*)destinationGroup
              itemsToExport:(NSArray<Node*>*)itemsToExport
         makeBrandNewCopies:(BOOL)makeBrandNewCopies {
    if ( itemsToExport.count == 0 ) {
        NSLog(@"No items left to export!");
        return;
    }
    
    
    
    NSSet<NSUUID*>* itemsIntersection = [self getSourceDestinationIntersection:itemsToExport destinationModel:destinationModel];

    NSMutableArray<Node*>* existingInDestination = NSMutableArray.array;
    for (NSUUID* existing in itemsIntersection) {
        Node* node = [destinationModel.database getItemById:existing];
        if ( node ) {
            [existingInDestination addObject:node];
        }
    }
    
    if ( existingInDestination.count ) {

        [destinationModel.database deleteItems:existingInDestination];
    }
    
    
    
    BOOL failOccurred = NO;
    for ( Node* exportItem in itemsToExport ) {
        BOOL added = [destinationModel addChildren:@[exportItem] destination:destinationGroup];
        
        if ( !added ) {
            NSLog(@"Failed to exportItem: [%@]", exportItem);
            failOccurred = YES;
        }
        else {
            NSLog(@"Exported Item: [%@]", exportItem);
        }
    }

    
    
    if ( !failOccurred ) {
        [destinationModel asyncUpdateAndSync];
        
        [Alerts info:self
               title:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
             message:NSLocalizedString(@"export_vc_export_items_successful_message", @"Your selected items have now be exported to the destination database.")
          completion:^{ 
            if ( self.isEditing ) {
                [self setEditing:NO animated:YES];
            }
        }];
    }
    else {
        [Alerts warn:self
               title:NSLocalizedString(@"export_vc_export_failed_title", @"Export Failed")
             message:NSLocalizedString(@"export_vc_export_items_failed_message", @"There was a problem exporting some or all of these items. The export has been cancelled.")
          completion:^{
            if ( self.isEditing ) {
                [self setEditing:NO animated:YES];
            }
        }];
    }
}

- (MainSplitViewController *)parentSplitViewController {
    return (MainSplitViewController*)self.splitViewController;
}

- (NSUInteger)getPrimaryNumberOfItemsDisplayed {
    NSUInteger numberOfSections = [self getTableDataSource].sections;
    
    NSUInteger sum = 0;
    
    for ( int i = 0;i<numberOfSections;i++) {
        sum += [[self getTableDataSource] rowsForSection:i];
    }
    
    return sum;
}

- (void)refreshiOS14SortMenu API_AVAILABLE(ios(14.0)) {
    __weak BrowseSafeView* weakSelf = self;
    
    BrowseSortField originalConfiguredSortField = self.sortConfiguration.field;
    BrowseSortField effectiveSortField = originalConfiguredSortField;
    
    BOOL customOrderPossible = (self.viewType == kBrowseViewTypeHierarchy && self.viewModel.originalFormat != kPasswordSafe );
    
    if ( effectiveSortField == kBrowseSortFieldNone && !customOrderPossible ) {
        effectiveSortField = kBrowseSortFieldTitle;
    }
    
    BOOL descending = self.sortConfiguration.descending;
    BOOL foldersSeparately = self.sortConfiguration.foldersOnTop;
    BOOL showAlphaIndex = self.sortConfiguration.showAlphaIndex;
    
    

    NSMutableArray<UIMenuElement*>* ma0 = [NSMutableArray array];

    
    
    if ( customOrderPossible ) {
        [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_sort_order_custom", @"Custom")
                                          checked:effectiveSortField == kBrowseSortFieldNone
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldNone descending:descending foldersSeparately:foldersSeparately showAlphaIndex:showAlphaIndex];
        }]];
    }

    

    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_fieldname_title", @"Title")
                                      checked:effectiveSortField == kBrowseSortFieldTitle
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldTitle
                                descending:NO
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:showAlphaIndex];
    }]];
   
    
    
    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_fieldname_username", @"Username")
                                      checked:effectiveSortField == kBrowseSortFieldUsername
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldUsername
                                descending:NO
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:showAlphaIndex];
    }]];

    
    
    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_fieldname_email", @"Email")
                                      checked:effectiveSortField == kBrowseSortFieldEmail
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldEmail
                                descending:NO
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:showAlphaIndex];
    }]];









    
    
    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_item_subtitle_date_created", @"Date Created")
                                      checked:effectiveSortField == kBrowseSortFieldCreated
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldCreated
                                descending:YES
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:showAlphaIndex];
    }]];

    
    
    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_item_subtitle_date_modified", @"Date Modified")
                                      checked:effectiveSortField == kBrowseSortFieldModified
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:kBrowseSortFieldModified
                                descending:YES
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:showAlphaIndex];
    }]];

    UIMenu* menu0 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma0];

    

    BOOL isDateField = effectiveSortField == kBrowseSortFieldCreated || effectiveSortField == kBrowseSortFieldModified;
    
    NSString* ascTitle = isDateField ? NSLocalizedString(@"generic_sort_order_chronologically_oldest_first", @"Oldest First") : NSLocalizedString(@"generic_sort_order_alphabetically", @"Alphabetically");
    NSString* descTitle = isDateField ? NSLocalizedString(@"generic_sort_order_chronologically_newest_first", @"Newest First") : NSLocalizedString(@"generic_sort_order_reverse_alphabetically", @"Reverse Alphabetically");
    
    NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
    
    [ma1 addObject:[ContextMenuHelper getItem:ascTitle
                                      checked:!descending
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:originalConfiguredSortField descending:NO foldersSeparately:foldersSeparately showAlphaIndex:showAlphaIndex];
    }]];
    
    [ma1 addObject:[ContextMenuHelper getItem:descTitle
                                      checked:descending
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:originalConfiguredSortField descending:YES foldersSeparately:foldersSeparately showAlphaIndex:showAlphaIndex];
    }]];


    UIMenu* menuAscDesc = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma1];

    
    
    NSMutableArray<UIMenuElement*>* ma2 = [NSMutableArray array];

    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"sort_configuration_custom_sort_order_and_sort_groups_separately", @"Keep Groups on Top")
                                      checked:foldersSeparately
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:originalConfiguredSortField descending:descending foldersSeparately:!foldersSeparately showAlphaIndex:showAlphaIndex];
    }]];

    UIMenu* menuFoldersSeparate = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma2];

    
    
    NSMutableArray<UIMenuElement*>* ma3 = [NSMutableArray array];
    
    [ma3 addObject:[ContextMenuHelper getItem: NSLocalizedString(@"alphabetic_index_menu_item_title", @"Alphabetic Index")
                                      checked:showAlphaIndex
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onChangedBrowseSortOrder:originalConfiguredSortField
                                descending:descending
                         foldersSeparately:foldersSeparately
                            showAlphaIndex:!showAlphaIndex];
    }]];
    
    UIMenu* menuAlphaIndex = [UIMenu menuWithTitle:@""
                                             image:nil
                                        identifier:nil
                                           options:UIMenuOptionsDisplayInline
                                          children:ma3];

    
    
    
    NSUInteger itemCount = [self getPrimaryNumberOfItemsDisplayed];
    NSString* plural = [NSString stringWithFormat:NSLocalizedString(@"sort_menu_header_number_of_items_plural_sorted_by_fmt", @"%@ Items Sorted By"), @(itemCount).stringValue];
    NSString* singular = [NSString stringWithFormat:NSLocalizedString(@"sort_menu_header_singular_item_sorted_by", @"1 Item Sorted By")];
    
    NSMutableArray *menus = [NSMutableArray arrayWithObject:menu0];

    if ( effectiveSortField != kBrowseSortFieldNone ) {
        [menus addObject:menuAscDesc];
    }

    if ( self.viewType == kBrowseViewTypeHierarchy ) {
        [menus addObject:menuFoldersSeparate];
    }
    
    if ( effectiveSortField == kBrowseSortFieldTitle ) {
        [menus addObject:menuAlphaIndex];
    }
    
    UIMenu* menu = [UIMenu menuWithTitle:itemCount == 1 ? singular : plural
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:menus];
    
    self.sortiOS14Button.menu = menu;
}

- (void)onChangedBrowseSortOrder:(BrowseSortField)field
                      descending:(BOOL)descending
               foldersSeparately:(BOOL)foldersSeparately
                  showAlphaIndex:(BOOL)showAlphaIndex {
    BrowseSortConfiguration* config = [[BrowseSortConfiguration alloc] init];

    config.field = field;
    config.descending = descending;
    config.foldersOnTop = foldersSeparately;
    config.showAlphaIndex = showAlphaIndex;
    
    [self setSortConfiguration:config];
    
    [self refresh];
    
    [self doHapticFeedback];
}

- (void)doHapticFeedback {
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
}

- (BrowseSortConfiguration *)sortConfiguration {
    BrowseSortConfiguration* sortConfig = [self.viewModel getSortConfigurationForViewType:self.viewType];

    return sortConfig;
}

- (void)setSortConfiguration:(BrowseSortConfiguration *)sortConfiguration {
    [self.viewModel setSortConfigurationForViewType:self.viewType configuration:sortConfiguration];
}

@end
