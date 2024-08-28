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
#import "AdvancedDatabaseSettings.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "NodeIconHelper.h"
#import "SetNodeIconUiHelper.h"
#import "ItemDetailsViewController.h"
#import "BrowseItemCell.h"
#import "BrowsePreferencesTableViewController.h"
#import "BrowseItemTotpCell.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "BrowseTableDatasource.h"
#import "ConfiguredBrowseTableDatasource.h"
#import "SearchResultsBrowseTableDatasource.h"
#import "BrowseTableViewCellHelper.h"

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
#import "KeyFileManagement.h"
#import "SelectDatabaseViewController.h"
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
#import "WorkingCopyManager.h"
#import "AutoFillPreferencesViewController.h"
#import "AuditConfigurationVcTableViewController.h"
#import "AutomaticLockingPreferences.h"
#import "EncryptionPreferencesViewController.h"

#import "Strongbox-Swift.h"
#import "ExportHelper.h"
#import "BrowseActionsHelper.h"

static NSString* const kItemToEditParam = @"itemToEdit";
static NSString* const kEditImmediatelyParam = @"editImmediately";

@interface BrowseSafeView () < UISearchBarDelegate, UISearchResultsUpdating, UIAdaptivePresentationControllerDelegate, UIPopoverPresentationControllerDelegate, UISearchControllerDelegate >

@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonMove; 
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonDelete; 
@property (strong, nonatomic) IBOutlet UIBarButtonItem *exportItemsBarButton;  
@property (strong, nonatomic) IBOutlet UIBarButtonItem *closeBarButton;

@property UIBarButtonItem* moreiOS14Button;
@property UIBarButtonItem* sortiOS14Button;
@property UIBarButtonItem* preferencesBarButton;
@property UIBarButtonItem* syncBarButton;
@property UIButton* syncButton;

@property (strong, nonatomic) UISearchController *searchController;

@property (strong) SetNodeIconUiHelper* sni; 
@property NSMutableArray<MMcGPair<NSIndexPath*, NSIndexPath*>*> * reorderItemOperations;
@property BOOL sortOrderForAutomaticSortDuringEditing;

@property ConfiguredBrowseTableDatasource* configuredDataSource;
@property SearchResultsBrowseTableDatasource* searchDataSource;

@property NSString *pwSafeRefreshSerializationId;
@property (readonly) BOOL isItemsCanBeExported;

@property (readonly) BOOL isDisplayingRootTagsList;
@property (readonly) BOOL isDisplayingRoot;

@property (readonly) MainSplitViewController* parentSplitViewController;
@property BrowseSortConfiguration* sortConfiguration;

@property BrowseActionsHelper* browseActionsHelper;

@end

@implementation BrowseSafeView

- (BOOL)isDisplayingRoot {
    BOOL ret = self.navigationController.viewControllers.firstObject == self;
    
    return ret;
}

- (BOOL)isDisplayingRootTagsList {
    return self.viewType == kBrowseViewTypeTags && self.currentTag == nil;
}

+ (instancetype)fromStoryboard:(BrowseViewType)viewType model:(Model*)model {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Browse" bundle:nil];
    BrowseSafeView* vc = (BrowseSafeView*)[sb instantiateInitialViewController];
    
    vc.viewModel = model;
    vc.currentGroupId = nil;
    vc.currentTag = nil;
    vc.viewType = viewType;
    
    if ( viewType == kBrowseViewTypeHierarchy ) {
        vc.currentGroupId = model.database.effectiveRootGroup.uuid;
    }
    
    return vc;
}

- (void)dealloc {
    slog(@"DEALLOC [%@]", self);
    
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
                                               name:kModelEditedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onAuditCompleted:)
                                               name:kAuditCompletedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onClosed)
                                               name:kMasterDetailViewCloseNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onDatabaseReloaded:)
                                               name:kDatabaseReloadedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateStartingNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateDoneNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kSyncManagerDatabaseSyncStatusChangedNotification
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
    
    
    
    self.navigationController.toolbar.hidden = !self.isEditing;
    self.navigationController.toolbarHidden = !self.isEditing;
    
    [self refresh];
}

- (void)didPresentSearchController:(UISearchController *)searchController {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.searchController.searchBar becomeFirstResponder];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    
    
    
    
    
    
    if( self.isDisplayingRoot && !self.parentSplitViewController.hasDoneDatabaseOnLaunchTasks ) {
        if ( self.viewModel.metadata.immediateSearchOnBrowse ) {
            [self startWithSearch];
        }
        else if ( self.viewModel.metadata.showLastViewedEntryOnUnlock ) {
            [self displayLastViewedEntryIfAppropriate];
        }
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self addSearchBarToNav]; 
        });
    }
    
    self.parentSplitViewController.hasDoneDatabaseOnLaunchTasks = YES; 
    
    if ( self.splitViewController.isCollapsed ) {
        
        self.viewModel.metadata.lastViewedEntry = nil;
    }
}

- (void)displayLastViewedEntryIfAppropriate {
    if ( self.splitViewController.isCollapsed || !self.viewModel.metadata.lastViewedEntry ) {
        slog(@"Not showing last viewed entry because Split View collapsed");
    }
    else {
        Node* item = [self.viewModel getItemById:self.viewModel.metadata.lastViewedEntry];
        
        if ( item ) {
            [self showEntry:item animated:NO];
        }
    }
}

- (void)startWithSearch {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.searchController.active = YES;
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ( self.viewModel.originalFormat == kPasswordSafe && self.currentGroupId ) {
        self.pwSafeRefreshSerializationId = [self.viewModel.database getCrossSerializationFriendlyIdId:self.currentGroupId]; 
    }
    
    __weak BrowseSafeView* weakSelf = self;
    self.browseActionsHelper = [[BrowseActionsHelper alloc] initWithModel:self.viewModel
                                                           viewController:self
                                                     updateDatabaseAction:^(BOOL clearSelectedDetailItem, void (^ _Nullable completion)(BOOL)) {
        [weakSelf updateAndRefresh:clearSelectedDetailItem completion:completion];
    }];
    
    [self setupDatasources];
    
    [self customizeUi];
    
    [self refresh];
    
    [self listenToNotifications];
        
    [self performOnboardingDatabaseChangeRequests];
}

- (void)performOnboardingDatabaseChangeRequests {
    if ( self.viewModel.onboardingDatabaseChangeRequests && self.isDisplayingRoot ) {
        BOOL changed = NO;
        EncryptionSettingsViewModel* enc = [EncryptionSettingsViewModel fromDatabaseModel:self.viewModel.database];
        
        if ( enc ) {
            if ( self.viewModel.onboardingDatabaseChangeRequests.updateDatabaseToV4OnLoad ) {
                slog(@"Updating Database to V4 after Onboard Request...");
                enc.format = kKeePass4;
                changed = YES;
            }
            
            if ( self.viewModel.onboardingDatabaseChangeRequests.reduceArgon2MemoryOnLoad ) {
                slog(@"Reducing Argon2 Memory after Onboard Request...");
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
                                                                             tableView:self.tableView
                                                                              viewType:self.viewType
                                                                        currentGroupId:self.currentGroupId
                                                                            currentTag:self.currentTag];
    
    self.searchDataSource = [[SearchResultsBrowseTableDatasource alloc] initWithModel:self.viewModel tableView:self.tableView];
}

- (void)customizeUi {
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeTop | UIRectEdgeBottom;
    self.definesPresentationContext = YES;
    
    [self setupTableview];
    [self updateNavigationPrompt];
    [self setupNavBar];
    [self setupSearchBar];
    
    if( [self isDisplayingRoot] ) {
        
        
        [self addSearchBarToNav];
    }
    
    
    
    [self customizeRightBarButtons];
    [self customizeLeftBarButtons];
    [self customizeBottomToolbar];
}

- (void)setupNavBar {
    [self refreshNavBarTitle];
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.navigationController.toolbarHidden = NO;
    self.navigationController.toolbar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.navigationBarHidden = NO;
}

- (void)customizeLeftBarButtons {
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    NSMutableArray* leftBarButtons = @[].mutableCopy;
    
    if ( [self isDisplayingRoot] ) {
        [leftBarButtons addObject:self.closeBarButton];
    }
    
    UIImage* image = [UIImage systemImageNamed:@"gear"];
    self.preferencesBarButton = [[UIBarButtonItem alloc] initWithImage:image menu:nil];
    
    [leftBarButtons addObject:self.preferencesBarButton];
    
    
    [self.navigationItem.backBarButtonItem setTitle:@""];
    
    [self refreshSettingsMenu];
    
    self.navigationItem.leftBarButtonItems = leftBarButtons;
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
    
    self.moreiOS14Button =  [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:nil];
    [rightBarButtons insertObject:self.moreiOS14Button atIndex:0];
    [self refreshMoreMenu];
    
    self.sortiOS14Button = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleSmall]] menu:nil];
    
    if ( !self.isDisplayingRootTagsList ) {
        [rightBarButtons insertObject:self.sortiOS14Button atIndex:1];
    }
    [self refreshSortMenu];
    
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
    [self.closeBarButton setTitle:self.isEditing ? NSLocalizedString(@"generic_cancel", @"Cancel") : NSLocalizedString(@"generic_verb_close", @"Close")];
    
    BOOL ro = self.viewModel.isReadOnly;
    BOOL moveAndDeleteEnabled = (!ro && self.isEditing && self.tableView.indexPathsForSelectedRows.count > 0 && self.reorderItemOperations.count == 0);
    BOOL exportEnabled = self.isItemsCanBeExported && self.tableView.indexPathsForSelectedRows.count > 0;
    
    self.navigationController.toolbar.hidden = !(exportEnabled || moveAndDeleteEnabled); 
    self.navigationController.toolbarHidden = !(exportEnabled || moveAndDeleteEnabled); 
    
    [self updateNavigationPrompt];
    
    self.buttonMove.enabled = moveAndDeleteEnabled;
    self.buttonDelete.enabled = moveAndDeleteEnabled;
    self.exportItemsBarButton.enabled = exportEnabled;
    
    [self updateRightNavBarButtons];
}

- (void)customizeBottomToolbar {
    UIBarButtonItem* flexibleSpace1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem* flexibleSpace2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem* flexibleSpace3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem* flexibleSpace4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSArray *toolbarButtons = @[flexibleSpace1, self.buttonMove, flexibleSpace2, self.exportItemsBarButton, flexibleSpace3, self.buttonDelete, flexibleSpace4];
    
    [self.exportItemsBarButton setTitle:NSLocalizedString(@"generic_export_ellipsis", @"Export")];
    [self.buttonMove setTitle:NSLocalizedString(@"generic_move_ellipsis", @"Move...")];
    [self.buttonDelete setTintColor:UIColor.systemRedColor];
    
    [self setToolbarItems:toolbarButtons animated:NO];
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

- (void)refreshButtonDropdownMenus {
    [self refreshMoreMenu];
    [self refreshSortMenu];
    [self refreshSettingsMenu];
}

- (void)refreshMoreMenu {
    BOOL ro = self.viewModel.isReadOnly;
    
    NSMutableArray* finalMenu = NSMutableArray.array;
    
    NSMutableArray<UIMenuElement*>* ma0 = [NSMutableArray array];
    __weak BrowseSafeView* weakSelf = self;
    
    BOOL newEntryPossible = self.viewType != kBrowseViewTypeHierarchy || ( [self.viewModel.database getItemById:self.currentGroupId].childRecordsAllowed );
    
    [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_new_entry", @"New Entry")
                                  systemImage:@"doc.badge.plus"
                                      enabled:!ro && newEntryPossible
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onAddEntry];
    }]];
    
    if ( self.viewType == kBrowseViewTypeHierarchy ) {
        [ma0 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_new_group", @"New Group")
                                      systemImage:@"folder.badge.plus" enabled:!ro
                                          handler:^(__kindof UIAction * _Nonnull action) { [weakSelf onAddGroup]; }]];
    }
    
    UIMenu* menu0 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma0];
    [finalMenu addObject:menu0];
    
    
    
    NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
    
    if ( !self.isDisplayingRootTagsList ) {
        [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_select_items", @"Select Items")
                                      systemImage:@"checkmark.circle"
                                          enabled:(!self.viewModel.isReadOnly || self.isItemsCanBeExported)
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf setEditing:YES animated:YES];
        }]];
        
        [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_select_all", @"Select All")
                                      systemImage:@"checkmark.circle.fill"
                                          enabled:(!self.viewModel.isReadOnly || self.isItemsCanBeExported)
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf selectAllItems];
        }]];
        
    }
    
    if ( self.viewType == kBrowseViewTypeHierarchy ) {
        BOOL rearrangingEnabled = (!ro && self.viewType == kBrowseViewTypeHierarchy && weakSelf.viewModel.database.originalFormat != kPasswordSafe && self.sortConfiguration.field == kBrowseSortFieldNone);
        
        if ( rearrangingEnabled ) {
            [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_rearrange", @"Rearrange")
                                          systemImage:@"arrow.up.arrow.down.square.fill"
                                              enabled:!ro
                                              handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf setEditing:YES animated:YES];
            }]];
        }
    }
    
    if ( ma1.count ) {
        UIMenu *menu1 = [UIMenu menuWithTitle:@""
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:ma1];
        
        [finalMenu addObject:menu1];
    }
    
    
    
    NSMutableArray<UIMenuElement*>* ma2 = [NSMutableArray array];
    
    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_set_master_credentials", @"Set Master Credentials")
                                  systemImage:@"ellipsis.rectangle"
                                      enabled:!ro
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf.browseActionsHelper presentSetCredentials];
    }]];
    
    if ( !AppPreferences.sharedInstance.disableExport ) {
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_export_database", @"Export Database")
                                      systemImage:@"square.and.arrow.up"
                                          handler:^(__kindof UIAction * _Nonnull action) {  [weakSelf onExportDatabase:nil]; }]];
    }
    
    if ( !AppPreferences.sharedInstance.disablePrinting ) {
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_print_database", @"Print Database")
                                      systemImage:@"printer"
                                          handler:^(__kindof UIAction * _Nonnull action) {  [weakSelf onPrint]; }]];
    }
    
    UIMenu* menu2 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma2];
    
    
    [finalMenu addObject:menu2];
    
    UIMenu* menu = [UIMenu menuWithTitle:NSLocalizedString(@"generic_noun_actions", @"Actions")
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:finalMenu];
    
    self.moreiOS14Button.menu = menu;
}

- (void)refreshSettingsMenu {
    __weak BrowseSafeView* weakSelf = self;
    BOOL ro = self.viewModel.isReadOnly;
    
    NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_start_with_search", @"Start with Search") systemImage:@"magnifyingglass" enabled:YES checked:self.viewModel.metadata.immediateSearchOnBrowse handler:^(__kindof UIAction * _Nonnull action) { [weakSelf toggleStartWithSearch]; }]];
    
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"configure_tabs", @"Configure Tabs")
                                  systemImage:@"list.bullet.below.rectangle"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToConfigureTabs" sender:nil];
    }]];
    
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")
                                  systemImage:@"slider.horizontal.3"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToCustomizeView" sender:nil];
    }]];
    
    UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma1];
    
    
    
    NSMutableArray<UIMenuElement*>* ma2 = [NSMutableArray array];
    
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"convenience_unlock_preferences_title_fmt", @"%@ & PIN Codes"), BiometricsManager.sharedInstance.biometricIdName];
    UIImage *bioImage = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];
    
    [ma2 addObject:[ContextMenuHelper getItem:fmt
                                        image:bioImage
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToConvenienceUnlock" sender:nil];
    }]];
    
    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_autofill_settings", @"AutoFill")
                                  systemImage:@"rectangle.and.pencil.and.ellipsis"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAutoFillSettings];
    }]];
    
    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                                  systemImage:@"checkmark.shield"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAuditSettings];
    }]];
    
    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_auto_lock_settings", @"Automatic Locking")
                                  systemImage:@"lock.rotation.open"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAutoLockSettings];
    }]];
    
    [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_encryption_settings", @"Encryption")
                                  systemImage:@"function"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showEncryptionSettings];
    }]];
    
    if ( !ro ) {
        [ma2 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_set_master_credentials", @"Set Master Credentials")
                                      systemImage:@"ellipsis.rectangle"
                                          enabled:YES
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf.browseActionsHelper presentSetCredentials];
        }]];
    }
    
    UIMenu* menu2 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma2];
    
    NSMutableArray<UIMenuElement*>* ma3 = [NSMutableArray array];
    
    if ( AppPreferences.sharedInstance.hardwareKeyCachingBeta && self.viewModel.database.originalFormat == kKeePass4 && self.viewModel.database.ckfs.yubiKeyCR != nil ) {
        [ma3 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_hardware_key", @"Hardware Key")
                                            image:[UIImage imageNamed:@"yubikey"]
                                          handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf showHardwareKeySettings:nil];
        }]];
    }
    
    [ma3 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"generic_advanced_noun", @"Advanced")
                                  systemImage:@"gear"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAdvancedSettings:nil];
    }]];
    
    UIMenu* menu3 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma3];
    
    
    UIMenu* menu = [UIMenu menuWithTitle:NSLocalizedString(@"generic_settings", @"Settings")
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:@[menu1, menu2, menu3]];
    
    self.preferencesBarButton.menu = menu;
}

- (IBAction)showHardwareKeySettings:(id)sender  {
    [self.browseActionsHelper showHardwareKeySettings];
}

- (void)showAutoFillSettings {
    UINavigationController* nav = [AutoFillPreferencesViewController fromStoryboardWithModel:self.viewModel];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showAuditSettings {
    AuditConfigurationVcTableViewController* vc = [AuditConfigurationVcTableViewController fromStoryboard];
    
    vc.model = self.viewModel;
    
    __weak BrowseSafeView* weakSelf = self;
    vc.updateDatabase = ^{
        [weakSelf updateAndRefresh];
    };
    
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [weakSelf presentViewController:nav animated:YES completion:nil];
}

- (void)showAutoLockSettings {
    AutomaticLockingPreferences* vc = [AutomaticLockingPreferences fromStoryboardWithModel:self.viewModel];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (IBAction)showAdvancedSettings:(id)sender {
    AdvancedDatabaseSettings* vc = [AdvancedDatabaseSettings fromStoryboard];
    
    __weak BrowseSafeView* weakSelf = self;
    
    vc.viewModel = self.viewModel;
    vc.onDatabaseBulkIconUpdate = ^(NSDictionary<NSUUID *, NodeIcon *> * _Nullable selectedFavIcons) {
        [weakSelf onDatabaseBulkIconUpdate:selectedFavIcons];
    };
    
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)onDatabaseBulkIconUpdate:(NSDictionary<NSUUID *,NodeIcon *> * _Nullable)selectedFavIcons {
    [self.browseActionsHelper onDatabaseBulkIconUpdate:selectedFavIcons];
}

- (void)showEncryptionSettings {
    UINavigationController* nav = [EncryptionPreferencesViewController fromStoryboard];
    EncryptionPreferencesViewController* vc = (EncryptionPreferencesViewController*)nav.topViewController;
    
    __weak BrowseSafeView* weakSelf = self;
    vc.onChangedDatabaseEncryptionSettings = ^{
        [weakSelf updateAndRefresh];
    };
    
    vc.model = self.viewModel;
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)toggleStartWithSearch {
    self.viewModel.metadata.immediateSearchOnBrowse = !self.viewModel.metadata.immediateSearchOnBrowse;
    
    [self refreshButtonDropdownMenus];
}

- (void)toggleShowLastViewedEntryOnUnlock {
    self.viewModel.metadata.showLastViewedEntryOnUnlock = !self.viewModel.metadata.showLastViewedEntryOnUnlock;
    
    [self refreshButtonDropdownMenus];
}

- (IBAction)onExportDatabase:(id)sender {
    [self onShare];
}

- (void)onShare {
    [self.browseActionsHelper exportDatabase];
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
    slog(@"✅ Audit Completed... [%@]- userStopped = [%@]", self, numNote);
    
    
    
    
    
    
    
    if ( self.isDisplayingRoot && self.viewModel.metadata.auditConfig.auditInBackground ) {
        NSNumber* issueCount = self.viewModel.auditIssueCount;
        if (issueCount == nil) {
            slog(@"WARNWARN: Invalid Audit Issue Count but Audit Completed Notification Received. Stale BrowseView... ignore");
            return;
        }
        
        NSNumber* lastKnownAuditIssueCount = self.viewModel.metadata.auditConfig.lastKnownAuditIssueCount;
        
        slog(@"Audit Complete: Issues = %lu - Last Known = %@", issueCount.unsignedLongValue, lastKnownAuditIssueCount);
        
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
    
    slog(@"setEditing: %d", editing);
    
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
        slog(@"Move Row at %@ to %@", sourceIndexPath, destinationIndexPath);
        
        if(self.reorderItemOperations == nil) {
            self.reorderItemOperations = [NSMutableArray array];
        }
        
        [self.reorderItemOperations addObject:[MMcGPair pairOfA:sourceIndexPath andB:destinationIndexPath]];
        
        [self updateNavAndToolbarButtonsState]; 
    }
}

- (void)reorderPendingItems {
    if ( self.viewType != kBrowseViewTypeHierarchy ) {
        slog(@"🔴 Cannot reorder items outside of Hierarchy view! Something v wrong to end up here.");
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
            
            if ( !src || !dest ) {
                slog(@"Could not find one of src or dest in reordering - aborting");
                self.reorderItemOperations = nil;
                [self updateAndRefresh];
                return;
            }
            
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
            slog(@"Reordering: %lu -> %lu Successful", (unsigned long)srcIndex, (unsigned long)destIndex);
        }
        else {
            slog(@"WARNWARN: Move Unsucessful!: %lu -> %lu - Terminating further re-ordering", (unsigned long)srcIndex, (unsigned long)destIndex);
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
    self.searchController.obscuresBackgroundDuringPresentation = NO;
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
    
    
    
    self.navigationItem.hidesSearchBarWhenScrolling = !self.isDisplayingRoot;
}

- (void)updateNavigationPrompt {
    if ( self.isEditing ) {
        NSArray* selected = [self getSelectedItems];
        
        self.navigationItem.prompt = [NSString stringWithFormat:NSLocalizedString(@"detail_view_no_multiple_items_selected_message_fmt", @"%@ Items Selected"),
                                      @(selected.count)];
    }
    else {
        if ( AppPreferences.sharedInstance.showDatabaseNamesInBrowse ) {
            NSString* fullTitle = [NSString stringWithFormat:@"%@%@", self.viewModel.metadata.nickName, [self getStatusSuffix]];
            
            self.navigationItem.prompt = fullTitle;
        }
        else {
            self.navigationItem.prompt = nil;
        }
    }
}

- (NSArray *)getStatusSuffixii {
    NSMutableArray* statusii = NSMutableArray.array;
    
    if ( self.viewModel.isReadOnly ) {
        [statusii addObject:NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read-Only")];
    }
    
    if ( self.viewModel.isInOfflineMode ) {
        [statusii addObject:NSLocalizedString(@"browse_vc_pulldown_refresh_offline_title", @"Offline Mode")];
    }
    
    return statusii;
}

- (NSString*)getStatusSuffix {
    NSString* statusSuffix = @"";
    
    NSArray* statusii = [self getStatusSuffixii];
    
    if ( statusii.firstObject ) {
        NSString* statusiiStrings = [statusii componentsJoinedByString:@", "];
        statusSuffix = [NSString stringWithFormat:@" (%@)", statusiiStrings];
    }
    
    return statusSuffix;
}

- (void)setupTableview {
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.estimatedRowHeight = self.cellHeight;
    self.tableView.rowHeight = self.cellHeight;
    self.tableView.tableFooterView = [UIView new];
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    
    
    
    UIRefreshControl* refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(onManualPulldownRefresh) forControlEvents:UIControlEventValueChanged];
    
    self.tableView.refreshControl = refreshControl;
    
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
        [self.parentSplitViewController closeAndCleanupWithCompletion:nil];
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

- (void)onRenameItem:(NSIndexPath * _Nonnull)indexPath {
    [self onRenameItem:indexPath completion:nil];
}

- (void)onRenameItem:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    if ( !item ) {
        slog(@"⚠️ Could not find item at indexpath! Bailing");
        return;
    }
    
    [Alerts OkCancelWithTextField:self
                    textFieldText:item.title
                            title:NSLocalizedString(@"browse_vc_rename_item", @"Rename Item")
                          message:NSLocalizedString(@"browse_vc_rename_item_enter_title", @"Please enter a new title for this item")
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            if ( [self.viewModel setItemTitle:item.uuid title:text]) {
                [self updateAndSave];
            }
        }
        
        if(completion) {
            completion(response);
        }
    }];
}

- (void)onRenameTag:(NSString*)tag
         completion:(void (^)(BOOL actionPerformed))completion {
    [Alerts OkCancelWithTextField:self
                    textFieldText:tag
                            title:NSLocalizedString(@"browse_vc_rename_item", @"Rename Item")
                          message:NSLocalizedString(@"browse_vc_rename_item_enter_title", @"Please enter a new title for this item")
                       completion:^(NSString *text, BOOL response) {
        if ( response && text && [Utils trim:text].length ) {
            NSString* trimmed = [Utils trim:text];
            
            [self.viewModel renameTag:tag to:trimmed];
            
            [self updateAndSave];
        }
        
        if(completion) {
            completion(response);
        }
    }];
}

- (void)onDeleteTag:(NSString*)tag
         completion:(void (^)(BOOL actionPerformed))completion {
    [Alerts areYouSure:self message:NSLocalizedString(@"are_you_sure_delete_tag_message", @"Are you sure you want to delete this tag?") action:^(BOOL response) {
        if(response) {
            [self.viewModel deleteTag:tag];
            
            [self updateAndSave];
        }
        
        if(completion) {
            completion(response);
        }
    }];
}

- (void)onEmptyRecycleBin:(NSIndexPath * _Nonnull)indexPath completion:(void (^)(BOOL actionPerformed))completion {
    [self.browseActionsHelper emptyRecycleBin:^(BOOL actionPerformed) {
        if(completion) {
            completion(actionPerformed);
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
    if ( !item ) {
        slog(@"⚠️ Could not find item at indexpath! Bailing");
        if ( completion ) {
            completion(NO);
        }
        return;
    }
    
    if ( !self.sni ) {
        self.sni = [[SetNodeIconUiHelper alloc] init];
    }
    self.sni.customIcons = self.viewModel.database.iconPool;
    
    __weak BrowseSafeView* weakSelf = self;
    [self.sni changeIcon:self
                   model:self.viewModel
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

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  {
    return [self getRightSlideActions:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath   {
    return [self getLeftSlideActions:indexPath];
}

- (UIContextualAction*)getRemoveAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    BOOL willRecycle = item ? [self.viewModel canRecycle:item.uuid] : NO;
    NSString* title = willRecycle ? NSLocalizedString(@"generic_action_verb_recycle", @"Recycle") : NSLocalizedString(@"browse_vc_action_delete", @"Delete");
    
    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:title
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onDeleteSingleItem:indexPath completion:completionHandler];
    }];
    
    removeAction.image = [UIImage systemImageNamed:@"trash"];
    removeAction.backgroundColor = UIColor.systemRedColor;
    
    return removeAction;
}

- (UIContextualAction*)getRenameAction:(NSIndexPath *)indexPath {
    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"browse_vc_action_rename", @"Rename")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onRenameItem:indexPath completion:completionHandler];
    }];
    
    renameAction.image = [UIImage systemImageNamed:@"pencil"];
    renameAction.backgroundColor = UIColor.systemGreenColor;
    
    return renameAction;
}

- (UIContextualAction*)getSetIconAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *setIconAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                title:item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") :
                                         NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon")
                                                                              handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self onSetIconForItem:indexPath completion:completionHandler];
    }];
    
    setIconAction.image = [UIImage systemImageNamed:@"photo"];
    setIconAction.backgroundColor = UIColor.systemBlueColor;
    
    return setIconAction;
}

- (UIContextualAction*)getDuplicateItemAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *duplicateItemAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                      title:NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate")
                                                                                    handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self duplicateItem:item completion:completionHandler];
    }];
    
    duplicateItemAction.image = [UIImage systemImageNamed:@"plus.square.on.square"];
    duplicateItemAction.backgroundColor = UIColor.systemPurpleColor;
    
    return duplicateItemAction;
}

- (UIContextualAction*)getPinAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    BOOL pinned = item ? [self.viewModel isFavourite:item.uuid] : NO;
    
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:pinned ?
                                     NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") :
                                     NSLocalizedString(@"browse_vc_action_pin", @"Pin")
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self toggleFavourite:item];
        completionHandler(YES);
    }];
    
    pinAction.image = [UIImage systemImageNamed:pinned ? @"star.slash" : @"star"];
    pinAction.backgroundColor = UIColor.magentaColor;
    
    return pinAction;
}

- (UIContextualAction*)getAuditAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *pinAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:NSLocalizedString(@"browse_vc_action_audit", @"Audit")
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self showAuditDrillDown:item];
        completionHandler(YES);
    }];
    
    UIImage* auditImage = [UIImage systemImageNamed:@"checkmark.shield"];
    
    pinAction.image = auditImage;
    pinAction.backgroundColor = UIColor.systemOrangeColor;
    
    return pinAction;
}

- (UISwipeActionsConfiguration *)getLeftSlideActionsForGroup:(NSIndexPath *)indexPath  {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    
    UIContextualAction* removeAction = [self getRemoveAction:indexPath];
    UIContextualAction* renameAction = [self getRenameAction:indexPath];
    UIContextualAction* setIconAction = [self getSetIconAction:indexPath];
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item) {
        slog(@"⚠️ Could not find item at IndexPath... bailing");
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    
    if(!self.viewModel.isReadOnly) {
        return self.viewModel.database.originalFormat != kPasswordSafe ?
        [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction, setIconAction]] :
        [UISwipeActionsConfiguration configurationWithActions:@[removeAction, renameAction]];
    }
    else {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
}

- (UISwipeActionsConfiguration *)getRightSlideActions:(NSIndexPath *)indexPath  {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    if (!item || item.isGroup) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    
    UIContextualAction* copyPassword = [self getCopyPasswordSlideAction:indexPath];
    UIContextualAction* copyUsername = [self getCopyUsernameSlideAction:indexPath];
    
    NSMutableArray* actions = @[copyUsername, copyPassword].mutableCopy;
    
    NSURL* url = [self getLaunchUrlForItem:item];
    if (url) {
        UIContextualAction* copyAndLaunch = [self getCopyAndLaunchSlideAction:indexPath];
        [actions addObject:copyAndLaunch];
    }
    
    UISwipeActionsConfiguration* ret = [UISwipeActionsConfiguration configurationWithActions:actions];
    ret.performsFirstActionWithFullSwipe = YES;
    
    return ret;
}

- (UISwipeActionsConfiguration *)getLeftSlideActions:(NSIndexPath *)indexPath  {
    if (![self getTableDataSource].supportsSlideActions) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
    
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    if ( item ) {
        UIContextualAction* copyPassword = [self getCopyPasswordSlideAction:indexPath];
        UIContextualAction* copyUsername = [self getCopyUsernameSlideAction:indexPath];
        
        NSMutableArray* actions = @[copyPassword, copyUsername].mutableCopy;
        
        if (item.fields.otpToken) {
            UIContextualAction* copyTotp = [self getCopyTotpSlideAction:indexPath];
            [actions addObject:copyTotp];
        }
        
        UISwipeActionsConfiguration* ret = (item && item.isGroup) ? [self getLeftSlideActionsForGroup:indexPath] : [UISwipeActionsConfiguration configurationWithActions:actions];
        ret.performsFirstActionWithFullSwipe = YES;
        
        return ret;
    }
    else {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }
}

- (UIContextualAction*)getCopyAndLaunchSlideAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:NSLocalizedString(@"browse_prefs_tap_action_copy_and_launch", @"Copy & Launch")
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ( !item ) {
            slog(@"⚠️ Could not find item!");
            completionHandler(NO);
        }
        else {
            [self copyAndLaunch:item];
            completionHandler(YES);
        }
    }];
    
    action.backgroundColor = UIColor.systemOrangeColor;
    
    return action;
}

- (UIContextualAction*)getCopyTotpSlideAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ( !item ) {
            slog(@"⚠️ Could not find item!");
            completionHandler(NO);
        }
        else {
            [self copyTotp:item];
            completionHandler(YES);
        }
    }];
    
    action.backgroundColor = UIColor.systemOrangeColor;
    
    return action;
}

- (UIContextualAction*)getCopyPasswordSlideAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ( !item ) {
            slog(@"⚠️ Could not find item!");
            completionHandler(NO);
        }
        else {
            [self copyPassword:item];
            completionHandler(YES);
        }
    }];
    
    action.backgroundColor = UIColor.systemBlueColor;
    
    return action;
}

- (UIContextualAction*)getCopyUsernameSlideAction:(NSIndexPath *)indexPath {
    Node *item = [self getNodeFromIndexPath:indexPath];
    
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ( !item ) {
            slog(@"⚠️ Could not find item!");
            completionHandler(NO);
        }
        else {
            [self copyUsername:item];
            completionHandler(YES);
        }
    }];
    
    action.backgroundColor = UIColor.systemPurpleColor;
    
    return action;
}

- (void)showAuditDrillDown:(Node*)item {
    if ( !item ) {
        slog(@"⚠️ Nil Item! Bailing");
        return;
    }
    
    [self.browseActionsHelper showAuditDrillDown:item.uuid];
}

- (void)toggleFavourite:(Node*)item {
    if ( !item || item.isGroup || self.viewModel.isReadOnly ) {
        return; 
    }
    
    BOOL needsSave = [self.viewModel toggleFavourite:item.uuid];
    
    if ( needsSave ) {
        [self updateAndSave];
    }
}

- (void)toggleAutoFillExclusion:(Node*)item {
    if ( !item || item.isGroup || self.viewModel.isReadOnly ) {
        return;
    }
    
    BOOL needsSave = [self.viewModel toggleAutoFillExclusion:item.uuid];
    
    if ( needsSave ) {
        [self updateAndSave];
    }
}

- (void)toggleAuditExclusion:(Node*)item {
    [self.viewModel toggleAuditExclusion:item.uuid];
    
    [self updateAndSave];
    
    [self.viewModel restartBackgroundAudit];
}

- (void)duplicateItem:(Node*)item {
    [self duplicateItem:item completion:nil];
}

- (void)duplicateItem:(Node*)item completion:(void (^)(BOOL actionPerformed))completion {
    if ( !item ) {
        slog(@"⚠️ Could not find item at indexpath! Bailing");
        if ( completion ) {
            completion(NO);
        }
        return;
    }
    
    __weak BrowseSafeView* weakSelf = self;
    DuplicateOptionsViewController* vc = [DuplicateOptionsViewController instantiate];
    NSString* newTitle = [item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")];
    
    vc.initialTitle = newTitle;
    vc.showFieldReferencingOptions = self.viewModel.database.originalFormat != kPasswordSafe;
    vc.completion = ^(BOOL go, BOOL referencePassword, BOOL referenceUsername, BOOL preserveTimestamp, NSString * _Nonnull title, BOOL editAfter) {
        if ( go ) {
            Node* dupe = [self.viewModel duplicateWithOptions:item.uuid
                                                        title:title
                                            preserveTimestamp:preserveTimestamp
                                            referencePassword:referencePassword
                                            referenceUsername:referenceUsername];
            
            if ( dupe ) {
                BOOL done = [self.viewModel addChildren:@[dupe] destination:item.parent];
               
                if ( done ) {
                    [weakSelf updateAndSave];
                    
                    if ( editAfter ) {
                        [weakSelf editEntry:dupe];
                    }
                }
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
        slog(@"Received Database Reloaded Notification from Model");
        
        if ( self.viewModel.database.originalFormat == kPasswordSafe && self.viewType == kBrowseViewTypeHierarchy ) { 
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

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if ( searchController.searchBar.text.length == 0 ) {
        [self.tableView reloadData];
    }
    else {
        
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateSearchResultsDebounced:) object:searchController];
        [self performSelector:@selector(updateSearchResultsDebounced:) withObject:searchController afterDelay:0.400]; 
    }
}

- (void)updateSearchResultsDebounced:(UISearchController*)searchController {
    NSString* searchText = searchController.searchBar.text;
    SearchScope scope = (SearchScope)searchController.searchBar.selectedScopeButtonIndex;
    
    [self.searchDataSource updateSearchResults:searchText scope:scope];
    
    [self.tableView reloadData];
}

- (void)refresh {
    slog(@"🐞 BrowseSafeView:Refresh...");
    
    [self refreshItems];
    
    [self refreshNavBarTitle];
    
    [self refreshButtonDropdownMenus];
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
    
    if ( self.viewType == kBrowseViewTypeHierarchy ) {
        Node* currentGroup = [self.viewModel.database getItemById:self.currentGroupId];
        title = (currentGroup == nil || currentGroup.parent == nil) ? self.viewModel.metadata.nickName : currentGroup.title;
        
        if ( currentGroup ) {
            image = [NodeIconHelper getIconForNode:currentGroup predefinedIconSet:self.viewModel.metadata.keePassIconSet format:self.viewModel.database.originalFormat];
        }
        
        tint = self.viewModel.database.recycleBinNode == currentGroup ? Constants.recycleBinTintColor : nil;
    }
    else if ( self.viewType == kBrowseViewTypeTags ) {
        if ( self.currentTag == nil ) {
            title = NSLocalizedString(@"browse_prefs_item_subtitle_tags", @"Tags");
            image = [UIImage systemImageNamed:@"tag.circle" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
        }
        else {
            title = self.currentTag;
            image = [UIImage systemImageNamed:@"tag.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
        }
    }
    else if ( self.viewType == kBrowseViewTypeFavourites ) {
        title = NSLocalizedString(@"browse_vc_section_title_pinned", @"Favourites");
        
        image = [UIImage systemImageNamed:@"star.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
        tint = UIColor.systemYellowColor;
    }
    else if ( self.viewType == kBrowseViewTypeList ) {
        title = NSLocalizedString(@"browse_prefs_view_as_flat_list", @"Entries");
        
        image = [UIImage systemImageNamed:@"list.bullet" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
    }
    else if ( self.viewType == kBrowseViewTypeTotpList ) {
        title = NSLocalizedString(@"quick_view_title_totp_entries_title", @"2FA Codes");
        image = [UIImage systemImageNamed:@"timer" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
    }
    else if ( self.viewType == kBrowseViewTypePasskeys ) {
        title = NSLocalizedString(@"generic_noun_plural_passkeys", @"Passkeys");
        image = [UIImage systemImageNamed:@"person.badge.key.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
    }
    else if ( self.viewType == kBrowseViewTypeSshKeys ) {
        NSString* img = @"network";
        if ( @available(iOS 17.0, *) ) {
            img = @"apple.terminal.fill";
        }
        
        title = NSLocalizedString(@"sidebar_quick_view_keeagent_ssh_keys_title", @"SSH Keys");
        image = [UIImage systemImageNamed:img withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
    }
    else if ( self.viewType == kBrowseViewTypeAttachments ) {
        title = NSLocalizedString(@"item_details_section_header_attachments", @"Attachments");
        image = [UIImage systemImageNamed:@"doc.richtext.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
    }
    else if ( self.viewType == kBrowseViewTypeExpiredAndExpiring ) {
        title = NSLocalizedString(@"quick_view_title_expired_and_expiring", @"Expired & Expiring");
        image = [UIImage systemImageNamed:@"calendar" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleDefault]];
    }
    else {
        slog(@"🔴 Could not refreshNavBarTitle - unknown view type");
    }
    
    UIView* view = [MMcGSwiftUtils navTitleWithImageAndTextWithTitleText:title
                                                                   image:image
                                                                    tint:tint];
    
    self.navigationItem.title = nil;
    self.navigationItem.titleView = view;
}

- (id<BrowseTableDatasource>)getTableDataSource {
    if (self.searchController.isActive) {
        return self.searchDataSource;
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
    
    slog(@"⚠️ Could not get Node from IndexPath...");
    
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
    
    
    if ( [AppModel.shared isEditing:self.viewModel.databaseUuid] ) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"item_details_vc_discard_changes", @"Discard Changes?")
              message:NSLocalizedString(@"item_details_vc_are_you_sure_discard_changes", @"Are you sure you want to discard all your changes?")
               action:^(BOOL response) {
            if(response) {
                [AppModel.shared markAsEditingWithId:self.viewModel.databaseUuid editing:NO];
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
    if ( self.isEditing ) {
        [self updateNavAndToolbarButtonsState]; 
        return;
    }
    
    [self handleSingleTap:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)handleSingleTap:(NSIndexPath *)indexPath  {
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
            action = (self.viewType == kBrowseViewTypeTotpList && !self.searchController.isActive) ? kBrowseTapActionCopyTotp : action; 
            
            [self performTapAction:item action:action];
        }
    }
    else if ( tag != nil ) {
        NSString* tag = [self getTagFromIndexPath:indexPath];
        [self performSegueWithIdentifier:@"sequeToSubgroup" sender:tag];
    }
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    __weak BrowseSafeView* weakSelf = self;
    
    if ([segue.identifier isEqualToString:@"segueMasterDetailToDetail"] || [segue.identifier isEqualToString:@"segueMasterDetailToDetail-NonAnimated"]) {
        
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
    else if ([segue.identifier isEqualToString:@"segueToConvenienceUnlock"]) {
        UINavigationController* nav = segue.destinationViewController;
        ConvenienceUnlockPreferences* vc = (ConvenienceUnlockPreferences*)nav.topViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToCustomizeView"]){
        UINavigationController* nav = segue.destinationViewController;
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)nav.topViewController;
        vc.model = self.viewModel;
        
        vc.onDone = ^{
            [self refreshButtonDropdownMenus];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToItemProperties"] ) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        ItemPropertiesViewController* vc = (ItemPropertiesViewController*)nav.topViewController;
        vc.model = self.viewModel;
        vc.item = sender;
        vc.updateDatabase = ^{
            [weakSelf updateAndRefresh];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToExportItems"] ) {
        __weak BrowseSafeView* weakSelf = self;
        
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SelectDatabaseViewController* vc = (SelectDatabaseViewController*)nav.topViewController;
        vc.disableDatabaseUuid = self.viewModel.metadata.uuid;
        vc.disableReadOnlyDatabases = YES;
        vc.customTitle = NSLocalizedString(@"export_items_select_destination_database_title", @"Destination Database");
        
        NSArray<Node*>* itemsToExport = sender;
        vc.onSelectedDatabase = ^(DatabasePreferences * _Nonnull secondDatabase, UIViewController *__weak  _Nonnull vcToDismiss) {
            [vcToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if ( secondDatabase ) {
                    [weakSelf onExportItemsToDatabase:secondDatabase itemsToExport:itemsToExport];
                }
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
                [weakSelf updateAndSave];
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
    
    if ( !item ) {
        slog(@"🔴 Could not find item to delete!"); 
        if ( completion ) {
            completion(NO);
        }
        return;
    }
    
    [self deleteSingle:item completion:completion];
}

- (void)deleteSingle:(Node*)item completion:(void (^)(BOOL actionPerformed))completion {
    [self.browseActionsHelper deleteSingleItem:item.uuid completion:^(BOOL actionPerformed) {
        if ( actionPerformed && self.isEditing) {
            [self setEditing:NO animated:YES];
        }
        
        if ( completion ) {
            completion(actionPerformed);
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




- (NSArray<Node*> *)getSelectedItems {
    NSArray<Node *> *items = [self getSelectedItems:self.tableView.indexPathsForSelectedRows];
    
    return items;
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
    [self.browseActionsHelper copyUrl:item.uuid];
}

- (void)copyEmail:(Node*)item {
    [self.browseActionsHelper copyEmail:item.uuid];
}

- (void)copyNotes:(Node*)item {
    [self.browseActionsHelper copyNotes:item.uuid];
}

- (void)copyTotp:(Node*)item {
    [self.browseActionsHelper copyTotp:item.uuid];
}

- (void)copyUsername:(Node*)item {
    [self.browseActionsHelper copyUsername:item.uuid];
}

- (void)copyPassword:(Node *)item {
    [self.browseActionsHelper copyPassword:item.uuid];
}

- (void)copyCustomField:(NSString*)key item:(Node *)item {
    [self.browseActionsHelper copyCustomField:key uuid:item.uuid];
}

- (void)copyAllFields:(Node*)item {
    [self.browseActionsHelper copyAllFields:item.uuid];
}

- (void)copyAndLaunch:(Node*)item {
    [self.browseActionsHelper copyAndLaunch:item.uuid];
}



- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text = @"";
    
    if ( self.searchController.isActive ) {
        text = self.searchController.searchBar.text.length == 0 ? NSLocalizedString(@"browse_vc_view_start_typing_to_search", @"Start Typing to Search") : NSLocalizedString(@"browse_vc_view_search_no_matches", @"No matching entries found");
    }
    else if( self.viewType == kBrowseViewTypeTotpList ) {
        text = NSLocalizedString(@"browse_vc_view_as_totp_no_totps", @"View As: TOTP List (No TOTP Entries)");
    }
    else {
        text = NSLocalizedString(@"browse_vc_view_as_database_empty", @"No Entries");
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}





- (UIContextMenuConfiguration *)getContextMenuForTagAt:(NSIndexPath *)indexPath {
    __weak BrowseSafeView* weakSelf = self;
    NSString* tag = [self getTagFromIndexPath:indexPath];
    
    if ( tag.length == 0 ) {
        slog(@"⚠️ Nil empty Tag?!");
        return nil;
    }
    
    return [UIContextMenuConfiguration configurationWithIdentifier:indexPath
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:@[
            [weakSelf getContextualMenuForTag:indexPath tag:tag]]];
    }];
}

- (UIContextMenuConfiguration *)getContextMenuForNodeAt:(NSIndexPath *)indexPath {
    __weak BrowseSafeView* weakSelf = self;
    
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
            [weakSelf getFirstContextMenuSection:indexPath item:item],
            [weakSelf getContextualMenuCopyFieldToClipboard:indexPath item:item],
            [weakSelf getContextualMenuMutators:indexPath item:item],
        ]];
    }];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if (self.isEditing || [self isShowingQuickViews]) {
        return nil;
    }
    
    if ( self.viewType == kBrowseViewTypeTags && self.currentTag == nil ) {
        return [self getContextMenuForTagAt:indexPath];
    }
    else {
        return [self getContextMenuForNodeAt:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  {
    Node *item = [self getNodeFromIndexPath:(NSIndexPath*)configuration.identifier];
    
    if ( !item ) {
        slog(@"⚠️ Could not find item!");
    }
    else {
        [self openDetails:item];
    }
}

- (UIMenu*)getContextualMenuForTag:(NSIndexPath*)indexPath tag:(NSString*)tag {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    [ma addObject:[self getContextualMenuRenameTagAction:indexPath tag:tag]];
    [ma addObject:[self getContextualMenuDeleteTagAction:indexPath tag:tag]];
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuRenameTagAction:(NSIndexPath*)indexPath tag:(NSString*)tag {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_vc_action_rename", @"Rename")
                          systemImage:@"pencil"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onRenameTag:tag completion:nil];
    }];
}

- (UIAction*)getContextualMenuDeleteTagAction:(NSIndexPath*)indexPath tag:(NSString*)tag {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getDestructiveItem:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                     systemImage:@"trash"
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onDeleteTag:tag completion:nil];
    }];
}

- (UIMenu*)getFirstContextMenuSection:(NSIndexPath*)indexPath item:(Node*)item  {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if (!self.viewModel.isReadOnly) {
        BOOL isRecycleBin = item.isGroup && self.viewModel.isKeePass2Format && [self.viewModel.database.recycleBinNode.uuid isEqual:item.uuid];
        
        if ( isRecycleBin ) { 
            [ma addObject:[self getContextualMenuEmptyRecycleBinAction:indexPath]];
        }
        
        if (!item.isGroup) {
            [ma addObject:[self getContextualMenuToggleFavouriteAction:indexPath item:item]];
        }
    }
    
    if (item.fields.password.length) {
        [ma addObject:[self getContextualMenuCopyPasswordAction:indexPath item:item]];
        [ma addObject:[self getContextualMenuShowLargePasswordAction:indexPath item:item]];
    }
    
    if (!item.isGroup && [self.viewModel isFlaggedByAudit:item.uuid] ) {
        [ma addObject:[self getContextualMenuAuditSettingsAction:indexPath item:item]];
    }
    
    
    
    if ( item.isGroup ) {
        [ma addObject:[self getContextualMenuPropertiesAction:indexPath item:item]];
    }
    else {
        if ( self.viewModel.isReadOnly || (!self.viewModel.metadata.autoFillEnabled &&    !self.viewModel.metadata.auditConfig.auditInBackground) ) {
            [ma addObject:[self getContextualMenuPropertiesAction:indexPath item:item]];
        }
        else {
            [ma addObject:[self getContextMenuQuickSettingsForEntrySubmenu:indexPath item:item]];
        }
    }
    
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuPropertiesAction:(NSIndexPath*)indexPath item:(Node*)item {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"generic_item_properties_ellipsis", @"Item Properties...")
                          systemImage:@"list.bullet"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToItemProperties" sender:item];
    }];
}

- (UIMenuElement*)getContextMenuQuickSettingsForEntrySubmenu:(NSIndexPath*)indexPath item:(Node*)item {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if (!self.viewModel.isReadOnly) {
        if ( !item.isGroup ) {
            if ( item.isSearchable ) {
                if ( self.viewModel.metadata.autoFillEnabled ) {
                    [ma addObject:[self getContextualMenuExcludeFromAutoFillAction:indexPath item:item]];
                }
                
                if ( self.viewModel.metadata.auditConfig.auditInBackground ) {
                    [ma addObject:[self getContextualMenuExcludeFromAuditAction:indexPath item:item]];
                }
            }
            else {
                [ma addObject:[self getContextualMenuDisabledInfoItem:indexPath item:item text:NSLocalizedString( @"item_is_not_searchable", @"Item is not searchable")]];
            }
        }
    }
    
    [ma addObject:[self getContextualMenuPropertiesAction:indexPath item:item]];
    
    return [UIMenu menuWithTitle:NSLocalizedString(@"generic_settings", @"Settings")
                           image:[UIImage systemImageNamed:@"gear"]
                      identifier:nil
                         options:kNilOptions
                        children:ma];
}

- (UIMenu*)getContextualMenuCopyFieldToClipboard:(NSIndexPath*)indexPath item:(Node*)item {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if ( !item.isGroup ) [ma addObject:[self getContextualMenuCopyToClipboardSubmenu:indexPath item:item]];
    
    return [UIMenu menuWithTitle:NSLocalizedString(@"browse_context_menu_copy_other_field", @"Copy Field...")
                           image:[UIImage systemImageNamed:@"doc.on.doc"]
                      identifier:nil
                         options:kNilOptions
                        children:ma];
}

- (UIMenuElement*)getContextualMenuCopyToClipboardSubmenu:(NSIndexPath*)indexPath item:(Node*)item {
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
                    [weakSelf copyCustomField:key item:item];
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

- (UIMenu*)getContextualMenuMutators:(NSIndexPath*)indexPath item:(Node*)item  {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
    
    if (!self.viewModel.isReadOnly) {
        
        
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



- (UIAction*)getContextualMenuToggleFavouriteAction:(NSIndexPath*)indexPath item:(Node*)item {
    BOOL pinned = [self.viewModel isFavourite:item.uuid];
    NSString* title = pinned ? NSLocalizedString(@"browse_vc_action_unpin", @"Unpin") : NSLocalizedString(@"browse_vc_action_pin", @"Pin");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:pinned ? @"star.slash" : @"star.fill"
            
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf toggleFavourite:item];
    }];
}

- (UIAction*)getContextualMenuExcludeFromAutoFillAction:(NSIndexPath*)indexPath item:(Node*)item {
    BOOL excluded = [self.viewModel isExcludedFromAutoFill:item.uuid];
    NSString* title = NSLocalizedString(@"suggest_in_autofill_yesno_flag", @"Suggest in AutoFill");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"rectangle.and.pencil.and.ellipsis"
                              enabled:YES
                              checked:!excluded
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf toggleAutoFillExclusion:item];
    }];
}

- (UIAction*)getContextualMenuExcludeFromAuditAction:(NSIndexPath*)indexPath item:(Node*)item {
    BOOL excluded = [self.viewModel isExcludedFromAudit:item.uuid];
    NSString* title = NSLocalizedString(@"audit_drill_down_audit_this_item_preference_title", @"Audit this Item");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"checkmark.shield"
                               colour:UIColor.systemOrangeColor
                                large:NO
                          destructive:NO
                              enabled:YES
                              checked:!excluded
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf toggleAuditExclusion:item];
    }];
}

- (UIAction*)getContextualMenuDisabledInfoItem:(NSIndexPath*)indexPath item:(Node*)item text:(NSString*)text {
    
    
    return [ContextMenuHelper getItem:text
                          systemImage:@"info.circle"
                               colour:UIColor.secondaryLabelColor
                                large:NO
                          destructive:NO
                              enabled:NO
                              checked:NO
                              handler:^(__kindof UIAction * _Nonnull action) { }];
}

- (UIAction*)getContextualMenuAuditSettingsAction:(NSIndexPath*)indexPath item:(Node*)item {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"view_audit_issue_details_ellipsis", @"Audit Issue Details...")
                          systemImage:@"checkmark.shield"
            
            
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf showAuditDrillDown:item];
    }];
}

- (UIAction*)getContextualMenuShowLargePasswordAction:(NSIndexPath*)indexPath item:(Node*)item {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_show_password", @"Show Password")
                          systemImage:@"eye"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf.browseActionsHelper showPassword:item.uuid];
    }];
}

- (UIAction*)getContextualMenuCopyUsernameAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                          systemImage:@"doc.on.doc"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyUsername:item];
    }];
}

- (UIAction*)getContextualMenuCopyPasswordAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                          systemImage:@"doc.on.doc"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyPassword:item];
    }];
}

- (UIAction*)getContextualMenuCopyTotpAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                          systemImage:@"doc.on.doc"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyTotp:item];
    }];
}

- (UIAction*)getContextualMenuLaunchAndCopyAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_action_launch_url_copy_password", @"Launch URL & Copy")
                          systemImage:@"bolt"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyAndLaunch:item];
    }];
}

- (UIAction*)getContextualMenuGenericCopy:(NSString*)locKey item:(Node*)item handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:NSLocalizedString(locKey, nil)
                          systemImage:@"doc.on.doc"
                              handler:handler];
}

- (UIAction*)getContextualMenuSetIconAction:(NSIndexPath*)indexPath item:(Node*)item  {
    NSString* title = item.isGroup ? NSLocalizedString(@"browse_vc_action_set_icons", @"Icons...") : NSLocalizedString(@"browse_vc_action_set_icon", @"Set Icon");
    __weak BrowseSafeView* weakSelf = self;
    return [ContextMenuHelper getItem:title
                          systemImage:@"photo"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onSetIconForItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuDuplicateAction:(NSIndexPath*)indexPath item:(Node*)item  {
    NSString* title = NSLocalizedString(@"browse_vc_action_duplicate", @"Duplicate");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"plus.square.on.square"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf duplicateItem:item completion:nil];
    }];
}

- (UIAction*)getContextualMenuRenameAction:(NSIndexPath*)indexPath item:(Node*)item  {
    NSString* title = NSLocalizedString(@"browse_vc_action_rename", @"Rename");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"pencil"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onRenameItem:indexPath completion:nil];
    }];
}

- (UIAction*)getContextualMenuEmptyRecycleBinAction:(NSIndexPath*)indexPath {
    NSString* title = NSLocalizedString(@"browse_vc_action_empty_recycle_bin", @"Empty Recycle Bin");
    
    __weak BrowseSafeView* weakSelf = self;
    return [ContextMenuHelper getDestructiveItem:title systemImage:@"arrow.3.trianglepath" handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onEmptyRecycleBin:indexPath completion:nil];
    }];
    
    
    
    
    
    
    
}

- (UIAction*)getContextualMenuMoveAction:(NSIndexPath*)indexPath item:(Node*)item  {
    NSString* title = NSLocalizedString(@"generic_move", @"Move");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"arrow.up.doc"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf performSegueWithIdentifier:@"segueToSelectDestination" sender:@[item]];
    }];
}

- (UIAction*)getContextualMenuRemoveAction:(NSIndexPath*)indexPath item:(Node*)item  {
    BOOL willRecycle = [self.viewModel canRecycle:item.uuid];
    NSString* title = willRecycle ? NSLocalizedString(@"generic_action_verb_recycle", @"Recycle") : NSLocalizedString(@"browse_vc_action_delete", @"Delete");
    
    __weak BrowseSafeView* weakSelf = self;
    
    
    return [ContextMenuHelper getDestructiveItem:title
                                     systemImage:@"trash"
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onDeleteSingleItem:indexPath completion:nil];
    }];
    
    
    
    
    
    
    
    
    
}

- (UIAction*)getContextualExportItemsAction:(NSIndexPath*)indexPath item:(Node*)item  {
    NSString* title = NSLocalizedString(@"generic_export_item", @"Export Item");
    
    __weak BrowseSafeView* weakSelf = self;
    
    return [ContextMenuHelper getItem:title
                          systemImage:@"square.and.arrow.up.on.square"
                              handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onExportItemSingleItem:item];
    }];
}

- (UIAction*)getContextualSelectItemsAction:(NSIndexPath*)indexPath item:(Node*)item  {
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



- (void)onManualPulldownRefresh {
    __weak BrowseSafeView* weakSelf = self;
    
    [self.parentSplitViewController onManualPullDownRefreshWithCompletion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView.refreshControl endRefreshing];
        });
    }];
}




- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    return @[[UIKeyCommand commandWithTitle:NSLocalizedString(@"browse_vc_action_keyboard_shortcut_find", @"Find")
                                      image:nil
                                     action:@selector(onKeyCommandFind:)
                                      input:@"F"
                              modifierFlags:UIKeyModifierCommand
                               propertyList:nil]];
}

- (void)onKeyCommandFind:(id)param {
    [self.searchController.searchBar becomeFirstResponder];
}



- (void)onMoveItems:(Node*)destination items:(NSArray<Node*>*)items {
    BOOL ret = [self.viewModel moveItems:items destination:destination];
    
    if (!ret) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"moveentry_vc_error_moving", @"Error Moving") errorCode:-1];
        [Alerts error:self error:error];
        return;
    }
    
    if(self.isEditing) {
        [self setEditing:NO animated:YES];
    }
    
    [self updateAndSave];
};





- (BOOL)isItemsCanBeExported {
    BOOL moreThanOneDb = [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return ![obj.uuid isEqualToString:self.viewModel.metadata.uuid] && !obj.readOnly;
    }].count > 0;
    
    return !AppPreferences.sharedInstance.disableExport && moreThanOneDb;
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
                slog(@"YAY - Express Unlocked Second DB with same CKFs! No need to re-request CKFs...");
                [self onExportItemsToDatabaseUnlockDestinationDone:kUnlockDatabaseResultSuccess model:expressAttempt itemsToExport:itemsToExport error:nil];
            }
            else {
                IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self 
                                                                                                       database:destinationDatabase
                                                                                                 isAutoFillOpen:NO
                                                                     transparentAutoFillBackgroundForBiometrics:NO
                                                                                            biometricPreCleared:NO
                                                                                            noConvenienceUnlock:NO];
                
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
        slog(@"model = [%@]", model);
        [self onExportItemsToUnlockedDatabase:model itemsToExport:itemsToExport];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        slog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
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
    slog(@"makeBrandNewCopies = %hhd, preserveTimestamps = %hhd", makeBrandNewCopies, preserveTimestamps);
    
    
    

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

    NSArray<Node*>* allItems = destinationModel.database.effectiveRootGroup.allChildren;
    
    NSSet<NSUUID*>* destIds = [allItems map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
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
        slog(@"No items left to export!");
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
            slog(@"Failed to exportItem: [%@]", exportItem);
            failOccurred = YES;
        }
        else {
            slog(@"Exported Item: [%@]", exportItem);
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

- (void)refreshSortMenu {
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
    
    if ( effectiveSortField == kBrowseSortFieldTitle && self.viewType != kBrowseViewTypeExpiredAndExpiring ) {
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

- (void)selectAllItems {
    [self setEditing:YES animated:YES];
    
    id<BrowseTableDatasource> datasource = [self getTableDataSource];
    
    [self.tableView performBatchUpdates:^{
        for ( int i=0; i < datasource.sections;i++ ) {
            for ( int j = 0;j< [datasource rowsForSection:i];j++) {
                NSIndexPath* ip = [NSIndexPath indexPathForRow:j inSection:i];
                [self.tableView selectRowAtIndexPath:ip animated:YES scrollPosition:UITableViewScrollPositionNone];
            }
        }
    } completion:^(BOOL finished) {
        [self updateNavAndToolbarButtonsState]; 
    }];
}

- (void)onPrint {
    [self.browseActionsHelper printDatabase];
}




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
    
    [self updateAndSave:completion];
}

- (void)updateAndSave {
    [self updateAndSave:nil];
}

- (void)updateAndSave:(void (^ _Nullable )(BOOL savedWorkingCopy))completion {
    [self.parentSplitViewController updateAndQueueSyncWithCompletion:^(BOOL savedWorkingCopy) {
        if ( completion ) {
            completion(savedWorkingCopy);
        }
    }];
}

@end
