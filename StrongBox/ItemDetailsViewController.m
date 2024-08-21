//
//  ItemDetailsViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ItemDetailsViewController.h"
#import "NotesTableViewCell.h"
#import "GenericKeyValueTableViewCell.h"
#import "EntryViewModel.h"
#import "EditPasswordTableViewCell.h"
#import "EditAttachmentCell.h"
#import "CustomFieldEditorViewController.h"
#import "NSArray+Extensions.h"
#import "GenericBasicCell.h"
#import "Utils.h"
#import "AddAttachmentHelper.h"
#import <QuickLook/QuickLook.h>
#import "NodeIconHelper.h"
#import "IconTableCell.h"
#import "TotpCell.h"
#import "Alerts.h"
#import "NSDictionary+Extensions.h"
#import "OTPToken+Serialization.h"
#import "KeePassHistoryController.h"
#import "PasswordHistoryViewController.h"
#import "CollapsibleTableViewHeader.h"
#import "BrowseSafeView.h"
#import "EditDateCell.h"
#import "PasswordGenerationViewController.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "LargeTextViewController.h"
#import "PasswordMaker.h"
#import "TagsViewTableViewCell.h"
#import "AuditDrillDownController.h"
#import "NSString+Extensions.h"
#import "AppPreferences.h"
#import "StrongboxiOSFilesManager.h"
#import "StreamUtils.h"
#import "NSData+Extensions.h"
#import "Constants.h"
#import "NSDate+Extensions.h"
#import <MobileCoreServices/MobileCoreServices.h>

#ifndef IS_APP_EXTENSION

#import "ISMessages/ISMessages.h"
#import "SetNodeIconUiHelper.h"
#import "Strongbox-Swift.h"
#import "NavBarSyncButtonHelper.h"

#else

#import "Strongbox_Auto_Fill-Swift.h"

#endif

#import "DatabasePreferences.h"
#import "AutoFillNewRecordSettingsController.h"
#import "SyncManager.h"
#import "ContextMenuHelper.h"

NSString *const CellHeightsChangedNotification = @"ConfidentialTableCellViewHeightChangedNotification";

static NSInteger const kRowTitleAndIcon = 0;
static NSInteger const kRowUsername = 1;
static NSInteger const kRowPassword = 2;
static NSInteger const kRowURL = 3;
static NSInteger const kRowEmail = 4;
static NSInteger const kRowTags = 5;
static NSInteger const kRowExpires = 6;
static NSInteger const kRowTotp = 7;
static NSInteger const kRowPasskey = 8;
static NSInteger const kRowSshKey = 9;
static NSInteger const kSimpleRowCount = 10;

static NSInteger const kSimpleFieldsSectionIdx = 0;
static NSInteger const kNotesSectionIdx = 1;
static NSInteger const kAttachmentsSectionIdx = 2;
static NSInteger const kMetadataSectionIdx = 3;
static NSInteger const kOtherSectionIdx = 4;
static NSInteger const kSectionCount = 5;

static NSString* const kGenericKeyValueCellId = @"GenericKeyValueTableViewCell";
static NSString* const kEditPasswordCellId = @"EditPasswordCell";
static NSString* const kNotesCellId = @"NotesTableViewCell";
static NSString* const kGenericBasicCellId = @"GenericBasicCell";
static NSString* const kEditAttachmentCellId = @"EditAttachmentCell";
static NSString* const kViewAttachmentCellId = @"ViewAttachmentCell";
static NSString* const kIconTableCell = @"IconTableCell";
static NSString* const kTotpCell = @"TotpCell";
static NSString* const kEditDateCell = @"EditDateCell";
static NSString* const kTagsViewCellId = @"TagsViewCell";
static NSString* const kMarkdownNotesCellId = @"MarkdownNotesTableViewCell";
static NSString* const kSshKeyViewCellId = @"SshKeyViewCell";
static NSString* const kPasskeyTableCellViewId = @"PasskeyTableCellView";
static NSString* const kMarkdownUIKitTableCellViewId = @"MarkdownUIKitTableCellView";



@interface ItemDetailsViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property EntryViewModel* model;
@property EntryViewModel* preEditModelClone;
@property BOOL passwordConcealedInUi;
@property UIBarButtonItem* cancelOrDiscardBarButton;
@property UIView* coverView;
@property BOOL isAutoFillContext;
@property BOOL inCellHeightsChangedProcess;

@property BOOL urlJustChanged;
@property BOOL justAutoCommittedTotp;
@property BOOL iconExplicitlyChanged;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

#ifndef IS_APP_EXTENSION

@property SetNodeIconUiHelper* sni;
@property (readonly) MainSplitViewController* parentSplitViewController; 

#endif

@property (readonly) BOOL supportsCustomFields;
@property (readonly) BOOL supportsAttachments;
@property BOOL hideMetadataSection;

#ifndef IS_APP_EXTENSION
@property UIBarButtonItem* syncBarButton;
@property UIButton* syncButton;
#endif

@property (readonly) BOOL isEffectivelyReadOnly;
@property (readonly) DatabaseFormat databaseFormat;
@property UIBarButtonItem* preferencesBarButton;

@property NSArray<ItemMetadataEntry*>* metadataRows; 
@property (readonly) BOOL hasHistory;

@end



@implementation ItemDetailsViewController



+ (NSArray<NSNumber*>*)defaultCollapsedSections {
    
    
    
    
    
    
    
    return @[@(0),
             @(0),
             @(0),
             @(1),
             @(1)];
}

+ (instancetype)fromStoryboard:(Model*)model nodeUuid:(NSUUID*)nodeUuid {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"ItemDetails" bundle:nil];
    ItemDetailsViewController* vc = (ItemDetailsViewController*)[sb instantiateInitialViewController];
    
    vc.databaseModel = model;
    vc.itemId = nodeUuid;
    vc.createNewItem = nodeUuid == nil;
    vc.editImmediately = nodeUuid == nil;
    vc.forcedReadOnly = model.isReadOnly;
    vc.parentGroupId = nil;

    return vc;
}

- (void)dealloc {
    slog(@"ItemDetailsViewController::DEALLOC [%@]", self);
    
    [self unListenToNotifications];
}

- (void)onCellHeightChangedNotification {
    
    
    
    
    if (!self.inCellHeightsChangedProcess) {
        self.inCellHeightsChangedProcess = YES;

        
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
        

        self.inCellHeightsChangedProcess = NO;
    }
}

- (BOOL)isEffectivelyReadOnly {
    return self.forcedReadOnly || self.databaseModel.isReadOnly;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    
    
    if(AppPreferences.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"item_details_tip", @"Tip: Tap to Copy, Double Tap to Launch URL or Copy Notes");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    self.hideMetadataSection = !AppPreferences.sharedInstance.showMetadataOnDetailsScreen || self.explicitHideMetadata;
    
#ifndef IS_APP_EXTENSION
    self.isAutoFillContext = NO;
#else
    self.isAutoFillContext = YES;
#endif
    
    [self customizeLeftBarButtons];
    [self customizeRightBarButtons];

    self.cancelOrDiscardBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_verb_close", @"Close")
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(onCancel:)];
    
    [self setupTableview];
    
    self.passwordConcealedInUi = !self.databaseModel.metadata.showPasswordByDefaultOnEditScreen;
    
    [self reloadViewModelFromNodeItem];
    [self bindNavBar];
    
    if(self.createNewItem || self.editImmediately) {
        [self setEditing:YES animated:YES];
    }
    
    [self updateSyncBarButtonItemState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refreshTableViewAnimated];
    
    [self updateSyncBarButtonItemState];
    
    [self listenToNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self unListenToNotifications];
}

- (void)listenToNotifications {
    [self unListenToNotifications];
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCellHeightChangedNotification)
                                                 name:CellHeightsChangedNotification
                                               object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseViewPreferencesChanged:)
                                               name:kDatabaseViewPreferencesChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAuditChanged:)
                                               name:kAuditNodesChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAuditChanged:)
                                               name:kAuditCompletedNotification
                                             object:nil];
    
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateStartingNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateDoneNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseReloaded:)
                                               name:kDatabaseReloadedNotification
                                             object:nil];
    
#ifndef IS_APP_EXTENSION
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kSyncManagerDatabaseSyncStatusChangedNotification
                                             object:nil];
#endif
    
    
}

- (void)unListenToNotifications {
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)onSyncButtonClicked:(id)sender {
    SyncStatus* syncStatus = [SyncManager.sharedInstance getSyncStatus:self.databaseModel.metadata];
    
    if ( self.databaseModel.isRunningAsyncUpdate || syncStatus.state == kSyncOperationStateInProgress ) {
        return;
    }
    
    [self updateAndSync];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    
    
    return UIModalPresentationNone;
}

- (void)customizeLeftBarButtons {
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    UIImage* image = [UIImage systemImageNamed:@"slider.horizontal.3"];
    self.preferencesBarButton = [[UIBarButtonItem alloc] initWithImage:image menu:nil];
    
    [self.navigationItem.backBarButtonItem setTitle:@""];
    
    [self refreshCustomizeViewMenu];
    
    self.navigationItem.leftBarButtonItems = self.splitViewController ? @[self.splitViewController.displayModeButtonItem, self.preferencesBarButton] : @[self.preferencesBarButton];
}

- (void)customizeRightBarButtons {
    NSMutableArray* rightBarButtons = @[].mutableCopy;
    
    if ( self.navigationItem.rightBarButtonItems ) {
        rightBarButtons = self.navigationItem.rightBarButtonItems.mutableCopy;
    }
    else if ( self.navigationItem.rightBarButtonItem ) {
        rightBarButtons = @[self.navigationItem.rightBarButtonItem].mutableCopy;
    }
    
    [rightBarButtons insertObject:self.editButtonItem atIndex:0];
    
#ifndef IS_APP_EXTENSION
    self.syncButton = [NavBarSyncButtonHelper createSyncButton:self action:@selector(onSyncButtonClicked:)];
    self.syncBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.syncButton];
    [rightBarButtons addObject:self.syncBarButton];
#endif
    
    self.navigationItem.rightBarButtonItems = rightBarButtons;
}

- (void)onToggleEasyReadFontOnAll {
    if ( !self.databaseModel.metadata.easyReadFontForAll && AppPreferences.sharedInstance.markdownNotes ) {
        [Alerts areYouSure:self
                   message:NSLocalizedString(@"are_you_sure_message_easy_read_font_markdown_notes", @"Note: Enabling Easy-Read Font will have the effect of disabling the 'Markdown Notes' formatting feature. Is this OK?")
                    action:^(BOOL response) {
            if ( response ) {
                self.databaseModel.metadata.easyReadFontForAll = !self.databaseModel.metadata.easyReadFontForAll;
                [self notifyDatabaseViewPreferencesChanged];
            }
            
            [self refreshCustomizeViewMenu];
        }];
    }
    else {
        self.databaseModel.metadata.easyReadFontForAll = !self.databaseModel.metadata.easyReadFontForAll;
        
        [self refreshCustomizeViewMenu];
        [self notifyDatabaseViewPreferencesChanged];
    }
}

- (void)notifyDatabaseViewPreferencesChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDatabaseViewPreferencesChangedNotificationKey object:nil];
}

- (void)refreshCustomizeViewMenu {
    __weak ItemDetailsViewController* weakSelf = self;
    
    NSMutableArray<UIMenuElement*>* ma1 = [NSMutableArray array];
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"new_entry_defaults", @"New Entry Defaults")
                                  systemImage:@"gear"
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onConfigureDefaults];
    }]];
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"item_details_view_settings_easy_read_all", @"Easy Read Font on All Fields")
                                  systemImage:@"eyeglasses"
                                      enabled:YES
                                      checked:self.databaseModel.metadata.easyReadFontForAll
                                      handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf onToggleEasyReadFontOnAll];
    }]];
    
    if ( !AppPreferences.sharedInstance.disableFavIconFeature ) {
        [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"item_details_view_settings_auto_fetch_favicon", @"Auto Fetch FavIcon")
                                      systemImage:@"globe"
                                          enabled:YES
                                          checked:self.databaseModel.metadata.tryDownloadFavIconForNewRecord
                                          handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.databaseModel.metadata.tryDownloadFavIconForNewRecord = !weakSelf.databaseModel.metadata.tryDownloadFavIconForNewRecord;
            [weakSelf notifyDatabaseViewPreferencesChanged];
            [weakSelf refreshCustomizeViewMenu];
        }]];
    }
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"item_details_view_settings_reveal_password_immediately", @"Reveal Password Immediately")
                                  systemImage:@"eye"
                                      enabled:YES
                                      checked:self.databaseModel.metadata.showPasswordByDefaultOnEditScreen
                                      handler:^(__kindof UIAction * _Nonnull action) {
        weakSelf.databaseModel.metadata.showPasswordByDefaultOnEditScreen = !weakSelf.databaseModel.metadata.showPasswordByDefaultOnEditScreen;
        [weakSelf notifyDatabaseViewPreferencesChanged];
        [weakSelf refreshCustomizeViewMenu];
    }]];
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"item_details_view_settings_colorize_passwords", @"Colorize Passwords")
                                  systemImage:@"paintbrush.pointed"
                                      enabled:YES
                                      checked:self.databaseModel.metadata.colorizePasswords
                                      handler:^(__kindof UIAction * _Nonnull action) {
        weakSelf.databaseModel.metadata.colorizePasswords = !weakSelf.databaseModel.metadata.colorizePasswords;
        [weakSelf notifyDatabaseViewPreferencesChanged];
        [weakSelf refreshCustomizeViewMenu];
    }]];
    
    [ma1 addObject:[ContextMenuHelper getItem:NSLocalizedString(@"item_details_view_settings_sort_custom_fields", @"Sort Custom Fields")
                                  systemImage:@"arrow.up.arrow.down"
                                      enabled:YES
                                      checked:!self.databaseModel.metadata.customSortOrderForFields
                                      handler:^(__kindof UIAction * _Nonnull action) {
        weakSelf.databaseModel.metadata.customSortOrderForFields = !weakSelf.databaseModel.metadata.customSortOrderForFields;
        [weakSelf notifyDatabaseViewPreferencesChanged];
        [weakSelf refreshCustomizeViewMenu];
    }]];
    
    UIMenu* menu1 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma1];
    
    UIMenu* menu = [UIMenu menuWithTitle:NSLocalizedString(@"browse_context_menu_customize_view", @"Customize View")
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:@[menu1]];
    
    self.preferencesBarButton.menu = menu;
}

- (void)onSyncOrUpdateStatusChanged:(id)object {
    [self updateSyncBarButtonItemState];
}

- (void)updateSyncBarButtonItemState {
#ifndef IS_APP_EXTENSION
    NSMutableArray *copy = self.navigationItem.rightBarButtonItems.mutableCopy;
    
    
    
    
    
    BOOL showSyncButton = [NavBarSyncButtonHelper bindSyncToobarButton:self.databaseModel button:self.syncButton];
    
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
#endif
}

- (void)onAuditChanged:(id)param {
    if ( !self.isEditing ) {
        [self refreshAll];
    }
}

- (void)onDatabaseReloaded:(id)param {
    if ( !self.isEditing ) {
        [self refreshAll];
    }
}

- (void)onDatabaseViewPreferencesChanged:(id)param {
    [self refreshAll];
}

- (void)setupTableview {
    [self.tableView registerNib:[UINib nibWithNibName:kGenericKeyValueCellId bundle:nil] forCellReuseIdentifier:kGenericKeyValueCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kEditPasswordCellId bundle:nil] forCellReuseIdentifier:kEditPasswordCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kNotesCellId bundle:nil] forCellReuseIdentifier:kNotesCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kEditAttachmentCellId bundle:nil] forCellReuseIdentifier:kEditAttachmentCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kIconTableCell bundle:nil] forCellReuseIdentifier:kIconTableCell];
    [self.tableView registerNib:[UINib nibWithNibName:kGenericBasicCellId bundle:nil] forCellReuseIdentifier:kGenericBasicCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kViewAttachmentCellId bundle:nil] forCellReuseIdentifier:kViewAttachmentCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kTotpCell bundle:nil] forCellReuseIdentifier:kTotpCell];
    [self.tableView registerNib:[UINib nibWithNibName:kEditDateCell bundle:nil] forCellReuseIdentifier:kEditDateCell];
    [self.tableView registerNib:[UINib nibWithNibName:kTagsViewCellId bundle:nil] forCellReuseIdentifier:kTagsViewCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kMarkdownNotesCellId bundle:nil] forCellReuseIdentifier:kMarkdownNotesCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kSshKeyViewCellId bundle:nil] forCellReuseIdentifier:kSshKeyViewCellId];
    [self.tableView registerNib:[UINib nibWithNibName:kPasskeyTableCellViewId bundle:nil] forCellReuseIdentifier:kPasskeyTableCellViewId];
    [self.tableView registerNib:[UINib nibWithNibName:kMarkdownUIKitTableCellViewId bundle:nil] forCellReuseIdentifier:kMarkdownUIKitTableCellViewId];
    
    if (@available(iOS 16.0, *)) {
        [self.tableView registerClass:TagsNGTableViewCell.class forCellReuseIdentifier:TagsNGTableViewCell.CellIdentifier];
    }
    
    [self.tableView setSectionHeaderTopPadding:0.0f];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.tableFooterView = [UIView new];
    
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                initWithTarget:self
                                action:@selector(handleLongPress:)];
    self.longPressRecognizer.minimumPressDuration = 1;
    self.longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:self.longPressRecognizer];
}

- (void)onCancelConfirmed {
    if ( self.createNewItem ) {
        [AppModel.shared markAsEditingWithId:self.databaseModel.databaseUuid editing:NO];
        
        if ( self.splitViewController ) {
            if (self.splitViewController.isCollapsed ) { 
                [self.navigationController popViewControllerAnimated:YES];
            }
            else {
                [self performSegueWithIdentifier:@"segueToEmptyDetails" sender:nil];
            }
        }
        else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    else {
        [self setEditing:NO];
    }
}

- (void)onCancel:(id)sender {
    if ( self.editing ) {
        if([self.model isDifferentFrom:self.preEditModelClone]) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"item_details_vc_discard_changes", @"Discard Changes?")
                  message:NSLocalizedString(@"item_details_vc_are_you_sure_discard_changes", @"Are you sure you want to discard all your changes?")
                   action:^(BOOL response) {
                if(response) {
                    self.model = self.preEditModelClone;
                    
                    [self onCancelConfirmed];
                }
            }];
        }
        else {
            [self onCancelConfirmed];
        }
    }
    else if ( self.isStandaloneDetailsModal ) {
        [self.presentingViewController dismissViewControllerAnimated:self completion:nil];
    }
}

- (void)onModelEdited {
    if(!self.editing) {
        slog(@"🔴 EEEEEEEKKKKK on Model edited while not editing!");
        return;
    }
    
    [self bindNavBar];
}

- (void)bindNavBar {
    if( self.isEditing ) {
        self.navigationItem.leftItemsSupplementBackButton = NO;
        BOOL isDifferent = [self.model isDifferentFrom:self.preEditModelClone];
        BOOL saveable = isDifferent || self.createNewItem;
        self.editButtonItem.enabled = saveable || self.justAutoCommittedTotp; 
        
        [self.cancelOrDiscardBarButton setTitle:saveable ? NSLocalizedString(@"generic_verb_discard", @"Discard") :  NSLocalizedString(@"generic_verb_close", @"Close")];
        
        self.navigationItem.leftBarButtonItems = @[self.cancelOrDiscardBarButton];
    }
    else {
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.editButtonItem.enabled = !self.isEffectivelyReadOnly;
        [self.cancelOrDiscardBarButton setTitle:NSLocalizedString(@"generic_verb_close", @"Close")];
        
        if ( self.isStandaloneDetailsModal ) {
            self.navigationItem.leftBarButtonItems = @[self.cancelOrDiscardBarButton];
        }
        else {
            self.navigationItem.leftBarButtonItems = self.splitViewController ? @[self.splitViewController.displayModeButtonItem, self.preferencesBarButton] : @[self.preferencesBarButton];
        }
        
        [self bindTitle];
    }
}

- (void)bindTitle {
    NSString* fullTitle = [NSString stringWithFormat:@"%@%@", [self maybeDereference:self.model.title],
                           self.isEffectivelyReadOnly ? NSLocalizedString(@"item_details_read_only_suffix", @" (Read Only)") : @""];
    
    UIImage* image = [NodeIconHelper getNodeIcon:self.model.icon
                               predefinedIconSet:self.databaseModel.metadata.keePassIconSet
                                          format:self.databaseModel.database.originalFormat];
    
    UIView* view = [MMcGSwiftUtils navTitleWithImageAndTextWithTitleText:fullTitle
                                                                   image:image
                                                                    tint:nil];
    
    self.navigationItem.titleView = view;
    
    
    
    
}

- (void)refreshTableViewAnimated {
    
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kSectionCount)]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
    
    
    return;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    BOOL changesToSave = self.createNewItem || [self.model isDifferentFrom:self.preEditModelClone];
    
    
    
    
    
    if ( self.isEditing && changesToSave ) {
        if ( ![trim(self.model.password) isEqualToString:self.model.password] ) {
            __weak ItemDetailsViewController* weakSelf = self;
            
            [Alerts twoOptionsWithCancel:self
                                   title:NSLocalizedString(@"field_tidy_title_tidy_up_field", @"Tidy Up Field?")
                                 message:NSLocalizedString(@"field_tidy_message_tidy_up_password", @"There are some blank characters (e.g. spaces, tabs) at the start or end of your password.\n\nShould Strongbox tidy up these extraneous characters?")
                       defaultButtonText:NSLocalizedString(@"field_tidy_choice_tidy_up_field", @"Tidy Up")
                        secondButtonText:NSLocalizedString(@"field_tidy_choice_dont_tidy", @"Don't Tidy")
                                  action:^(int response) {
                if ( response == 0 ) {
                    weakSelf.model.password = trim(weakSelf.model.password);
                    [weakSelf postValidationSetEditing:editing animated:animated];
                }
                else if ( response == 1) {
                    [weakSelf postValidationSetEditing:editing animated:animated];
                }
            }];
        }
        else {
            [self postValidationSetEditing:editing animated:animated];
        }
    }
    else {
        [self postValidationSetEditing:editing animated:animated];
    }
}

- (void)postValidationSetEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    
    
    
    if ( self.isEditing ) {
        self.preEditModelClone = [self.model clone];
        [self bindNavBar];
    }
    
    self.justAutoCommittedTotp = NO;
    [AppModel.shared markAsEditingWithId:self.databaseModel.databaseUuid editing:editing];
    
    [self.tableView performBatchUpdates:^{
        [self refreshTableViewAnimated];
    } completion:^(BOOL finished) {
        if ( self.isEditing ) {
            UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:kRowTitleAndIcon inSection:kSimpleFieldsSectionIdx]];
            [cell becomeFirstResponder];
        }
        else {
            [self applyChangesAndSave];
            self.preEditModelClone = nil;
        }
        
        [self bindNavBar];
    }];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    if (indexPath.section == kSimpleFieldsSectionIdx) {
        if(indexPath.row == kRowTitleAndIcon) {
            return [self getIconAndTitleCell:indexPath];
        }
        else if(indexPath.row == kRowUsername) {
            return [self getUsernameCell:indexPath];
        }
        else if(indexPath.row == kRowPassword) {
            return [self getPasswordCell:indexPath];
        }
        else if(indexPath.row == kRowTotp) {
            return [self getTotpCell:indexPath];
        }
        else if(indexPath.row == kRowURL) {
            return [self getUrlCell:indexPath];
        }
        else if(indexPath.row == kRowEmail) {
            return [self getEmailCell:indexPath];
        }
        else if (indexPath.row == kRowExpires) {
            return [self getExpiresCell:indexPath];
        }
        else if (indexPath.row == kRowTags) {
            return [self getTagsCell:indexPath];
        }
        else if(indexPath.row == kRowPasskey) {
            return [self getPasskeyCell:indexPath];
        }
        else if(indexPath.row == kRowSshKey) {
            return [self getKeeAgentSshKeyCell:indexPath];
        }
        else {
            return [self getCustomFieldCell:indexPath];
        }
    }
    else if (indexPath.section == kNotesSectionIdx) {
        return [self getNotesCell:indexPath];
    }
    else if (indexPath.section == kAttachmentsSectionIdx) {
        return [self getAttachmentCell:indexPath];
    }
    else if (indexPath.section == kMetadataSectionIdx) {
        return [self getMetadataCell:indexPath];
    }
    else if (indexPath.section == kOtherSectionIdx) {
        if(indexPath.row == 0) {
            return [self getOtherCell:indexPath];
        }
    }
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == kSimpleFieldsSectionIdx) {
        return nil; 
    }
    else if (section == kNotesSectionIdx) {
        return NSLocalizedString(@"item_details_section_header_notes", @"Notes");
    }
    else if (section == kAttachmentsSectionIdx) {
        return self.isAutoFillContext ? nil : NSLocalizedString(@"item_details_section_header_attachments", @"Attachments");
    }
    else if (section == kMetadataSectionIdx) {
        return self.isAutoFillContext ? nil : NSLocalizedString(@"item_details_section_header_metadata", @"Metadata");
    }
    else if (section == kOtherSectionIdx) {
        return self.isAutoFillContext ? nil : NSLocalizedString(@"item_details_section_header_history", @"History");
    }
    else {
        return @"<Unknown Section>";
    }
}

- (BOOL)supportsCustomFields {
    return (self.databaseFormat == kKeePass || self.databaseFormat == kKeePass4);
}
- (BOOL)supportsAttachments {
    return self.databaseFormat != kPasswordSafe;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(section == kSimpleFieldsSectionIdx) {
        return kSimpleRowCount + self.model.customFieldsFiltered.count + 1;
    }
    else if (section == kNotesSectionIdx) {
        return 1;
    }
    else if (section == kAttachmentsSectionIdx) {
        return self.model.filteredAttachments.count + 1;
    }
    else if (section == kMetadataSectionIdx) {
        return self.metadataRows.count;
    }
    else if (section == kOtherSectionIdx) {
        return 1;
    }
    else {
        return 0;
    }
}

- (BOOL)hasHistory {
    if ( self.createNewItem ) {
        return NO;
    }
    else if ( self.databaseFormat == kKeePass1 ) {
        return NO;
    }
    else if (self.databaseFormat == kPasswordSafe ) {
        return YES;
    }
    else if (self.databaseFormat == kKeePass || self.databaseFormat == kKeePass4) {
        Node* item = [self.databaseModel.database getItemById:self.itemId];
        
        return item && item.fields.keePassHistory.count > 0 ;
    }
    
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(!self.editing && self.databaseModel.metadata.detailsViewCollapsedSections[indexPath.section].boolValue) {
        return CGFLOAT_MIN;
    }
    
    BOOL shouldHideEmpty = !self.editing;
    
    if(indexPath.section == kSimpleFieldsSectionIdx) {
        if ( indexPath.row == kRowTitleAndIcon && !self.editing ) {
            return CGFLOAT_MIN;
        }
        else if(indexPath.row == kRowUsername && shouldHideEmpty && !self.model.username.length) {
            return CGFLOAT_MIN;
        }
        else if(indexPath.row == kRowPassword && shouldHideEmpty && !self.model.password.length) {
            if (!self.itemId || ![self.databaseModel isFlaggedByAudit:self.itemId]) { 
                return CGFLOAT_MIN;
            }
        }
        else if ( indexPath.row == kRowURL && shouldHideEmpty && !self.model.url.length ) {
            return CGFLOAT_MIN;
        }
        else if ( indexPath.row == kRowEmail ) {
            if ( shouldHideEmpty && !self.model.email.length ) {
                return CGFLOAT_MIN;
            }
        }
        else if ( indexPath.row == kRowPasskey ) {
#ifndef IS_APP_EXTENSION
            if ( !self.model.passkey ) {
                return CGFLOAT_MIN;
            }
#else
            return CGFLOAT_MIN;
#endif
        }
        else if ( indexPath.row == kRowSshKey ) {
#ifndef IS_APP_EXTENSION
            if ( !self.editing && !self.model.keeAgentSshKey ) {
                return CGFLOAT_MIN;
            }
#else
            return CGFLOAT_MIN;
#endif
        }
        else if(indexPath.row == kRowTotp) {
#ifndef IS_APP_EXTENSION
            if( !self.model.totp && !self.editing) {
                return CGFLOAT_MIN;
            }
#else
            return CGFLOAT_MIN;
#endif
        }
        else if(indexPath.row == kRowExpires) {
            if(self.model.expires == nil && shouldHideEmpty) {
                return CGFLOAT_MIN;
            }
        }
        else if(indexPath.row == kRowTags) {
            if ( ( self.model.tags.count == 0 && shouldHideEmpty ) || !self.databaseModel.formatSupportsTags ) {
                return CGFLOAT_MIN;
            }
        }
        else if(indexPath.row >= kSimpleRowCount) { 
            if ( !self.supportsCustomFields ) {
                return CGFLOAT_MIN;
            }

            NSUInteger idx = indexPath.row - kSimpleRowCount;
            
            if ( idx < self.model.customFieldsFiltered.count ) {
                CustomFieldViewModel* f = self.model.customFieldsFiltered[idx];
                if (!f.protected && !f.value.length && shouldHideEmpty) { 
                    return CGFLOAT_MIN;
                }
            }
            else {
                if ( !self.editing ) { 
                    return CGFLOAT_MIN;
                }
            }
        }
    }
    else if (indexPath.section == kNotesSectionIdx) {
        if(shouldHideEmpty && !self.model.notes.length) {
            return CGFLOAT_MIN;
        }
    }
#ifndef IS_APP_EXTENSION
    else if (indexPath.section == kAttachmentsSectionIdx ) {
        if ( !self.supportsAttachments ) {
            return CGFLOAT_MIN;
        }
        
        if ( !self.editing && indexPath.row == 0 ) { 
            return CGFLOAT_MIN;
        }
    }
    else if(indexPath.section == kMetadataSectionIdx && (self.editing || self.hideMetadataSection)) {
        return CGFLOAT_MIN;
    }
    else if(indexPath.section == kOtherSectionIdx && (!self.hasHistory || self.explicitHideHistory || self.editing)) {
        return CGFLOAT_MIN;
    }
#else
    if (indexPath.section == kAttachmentsSectionIdx ||
        indexPath.section == kMetadataSectionIdx ||
        indexPath.section == kOtherSectionIdx) {
        return CGFLOAT_MIN;
    }
#endif
    
    return [super tableView:self.tableView heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    BOOL shouldHideEmpty = !self.editing;
    
    if(section == kSimpleFieldsSectionIdx) {
        return CGFLOAT_MIN;
    }
    else if (section == kNotesSectionIdx && shouldHideEmpty && !self.model.notes.length) {
        return CGFLOAT_MIN;
    }
#ifndef IS_APP_EXTENSION
    else if(section == kAttachmentsSectionIdx) {
        if(self.databaseModel.database.originalFormat == kPasswordSafe || (!self.editing && self.model.filteredAttachments.count == 0)) {
            return CGFLOAT_MIN;
        }
    }
    else if(section == kMetadataSectionIdx && (self.editing || self.hideMetadataSection)) {
        return CGFLOAT_MIN;
    }
    else if(section == kOtherSectionIdx && (self.editing || !self.hasHistory || self.explicitHideHistory)) {
        return CGFLOAT_MIN;
    }
#else
    if (section == kAttachmentsSectionIdx ||
        section == kMetadataSectionIdx ||
        section == kOtherSectionIdx) {
        return CGFLOAT_MIN;
    }
#endif
    
    return UITableViewAutomaticDimension;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSimpleFieldsSectionIdx) {
        if (indexPath.row == kRowTotp) {
            return (self.model.totp ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleInsert);
        }
        
        if (indexPath.row == kRowSshKey ) {
            return (self.model.keeAgentSshKey ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleInsert);
        }
        
        if (indexPath.row == kRowPasskey && self.model.passkey ) {
            return UITableViewCellEditingStyleDelete;
        }
        
        if (indexPath.row >= kSimpleRowCount) { 
            return indexPath.row - kSimpleRowCount == self.model.customFieldsFiltered.count ? UITableViewCellEditingStyleInsert : UITableViewCellEditingStyleDelete;
        }
        
        return UITableViewCellEditingStyleNone;
    }
    else if(indexPath.section == kNotesSectionIdx || indexPath.section == kMetadataSectionIdx || indexPath.section == kOtherSectionIdx) {
        return UITableViewCellEditingStyleNone;
    }
    else if(indexPath.section == kAttachmentsSectionIdx) {
        return (indexPath.row == 0) ? UITableViewCellEditingStyleInsert : UITableViewCellEditingStyleDelete;
    }
    else {
        return UITableViewCellEditingStyleDelete;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSimpleFieldsSectionIdx ||
        indexPath.section == kNotesSectionIdx ||
        indexPath.section == kMetadataSectionIdx ||
        indexPath.section == kOtherSectionIdx) {
        return NO;
    }
    
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == kOtherSectionIdx || indexPath.section == kMetadataSectionIdx) {
        return NO;
    }
    
    return self.editing;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( !self.model.sortCustomFields &&
        indexPath.section == kSimpleFieldsSectionIdx &&
        self.model.customFieldsFiltered.count > 1 ) {
        NSInteger customFieldIdx = indexPath.row - kSimpleRowCount;
        
        if ( customFieldIdx >= 0 && customFieldIdx < self.model.customFieldsFiltered.count ) { 
            return YES;
        }
    }
    
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if ( proposedDestinationIndexPath.section == kSimpleFieldsSectionIdx && self.model.customFieldsFiltered.count > 1 ) {
        NSInteger customFieldIdx = proposedDestinationIndexPath.row - kSimpleRowCount;
        
        if ( customFieldIdx >= 0 && customFieldIdx < self.model.customFieldsFiltered.count ) { 
            return proposedDestinationIndexPath;
        }
    }
    
    return sourceIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if ( sourceIndexPath.section == kSimpleFieldsSectionIdx && destinationIndexPath.section == kSimpleFieldsSectionIdx && self.model.customFieldsFiltered.count > 1 ) {
        NSInteger sourceIdx = sourceIndexPath.row - kSimpleRowCount;
        NSInteger destIdx = destinationIndexPath.row - kSimpleRowCount;
        
        if ( sourceIdx >= 0 && sourceIdx < self.model.customFieldsFiltered.count && destIdx >= 0 && destIdx < self.model.customFieldsFiltered.count && sourceIdx != destIdx ) {
            slog(@"Move: [%ld] -> [%ld]", (long)sourceIdx, destIdx);
            [self.model moveCustomFieldAtIndex:sourceIdx to:destIdx];
            [self onModelEdited];
        }
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if(indexPath.section == kAttachmentsSectionIdx && indexPath.row > 0) {
            NSString* filename = self.model.filteredAttachments.allKeys[indexPath.row - 1];
            [self.model removeAttachment:filename];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self onModelEdited];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx) {
            if (indexPath.row == kRowTotp) {
                [self onClearTotp];
            }
            else if (indexPath.row == kRowPasskey) {
                self.model.passkey = nil;
                
                [self.tableView performBatchUpdates:^{
                    NSIndexPath* ip = [NSIndexPath indexPathForRow:kRowPasskey inSection:kSimpleFieldsSectionIdx];
                    [self.tableView reloadRowsAtIndexPaths:@[ip]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                } completion:^(BOOL finished) {
                    [self onModelEdited];
                }];
            }
            else if (indexPath.row == kRowSshKey) {
                self.model.keeAgentSshKey = nil;
                
                [self.tableView performBatchUpdates:^{
                    NSIndexPath* ip = [NSIndexPath indexPathForRow:kRowSshKey inSection:kSimpleFieldsSectionIdx];
                    [self.tableView reloadRowsAtIndexPaths:@[ip]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                } completion:^(BOOL finished) {
                    [self onModelEdited];
                }];
            }
            else if (indexPath.row >= kSimpleRowCount) {
                NSUInteger idx = indexPath.row - kSimpleRowCount;
                
                if ( idx < self.model.customFieldsFiltered.count ) {
                    [self.model removeCustomFieldAtIndex:idx];
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    [self onModelEdited];
                }
            }
        }
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        if(indexPath.section == kSimpleFieldsSectionIdx && indexPath.row == self.model.customFieldsFiltered.count + kSimpleRowCount) {
            [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:nil];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx && indexPath.row == kRowTotp) {
            [self onSetTotp];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx && indexPath.row == kRowSshKey ) {
            [self promptToAddSshKey];
        }
        else if(indexPath.section == kAttachmentsSectionIdx && indexPath.row == 0) {
            [self promptToAddAttachment];
        }
    }
}

- (void)promptToAddAttachment {
    [AddAttachmentHelper.sharedInstance beginAddAttachmentUi:self
                                               usedFilenames:self.model.reservedAttachmentNames
                                                       onAdd:^(NSString * _Nonnull filename, KeePassAttachmentAbstractionLayer * _Nonnull databaseAttachment) {
        [self onAddAttachment:filename attachment:databaseAttachment];
    }];
}

- (void)promptToAddSshKey {
    [Alerts twoOptionsWithCancel:self
                           title:NSLocalizedString(@"details_add_new_ssh_key", @"New SSH Key")
                         message:NSLocalizedString(@"details_add_new_ssh_key_what_kind_prompt", @"What kind of SSH key would you like to add?\n\nWe recommend using the modern ED25519 key type.")
               defaultButtonText:NSLocalizedString(@"details_add_new_ssh_key_ed25519", @"New ED25519 Key")
                secondButtonText:NSLocalizedString(@"details_add_new_ssh_key_rsa", @"New RSA Key")
                          action:^(int response) {
        if ( response == 0 ) {
            
            [self addNewSshKey:YES];
        }
        else if ( response == 1 ) {
            
            [self addNewSshKey:NO];
        }
    }];
}

- (void)addNewSshKey:(BOOL)ed25519 {
    if ( self.model.keeAgentSshKey ) {
        slog(@"🔴 Already an existing Key!!");
        return;
    }
    
    OpenSSHPrivateKey* key = ed25519 ? [OpenSSHPrivateKey newEd25519] : [OpenSSHPrivateKey newRsa];
    if ( key == nil ) {
        slog(@"🔴 Could not create new key!");
        return;
    }
    
    NSString* filename = ed25519 ? @"id_ed25519" : @"id_rsa";
    
    self.model.keeAgentSshKey = [KeeAgentSshKeyViewModel withKey:key filename:filename enabled:YES];
    
    [self.tableView performBatchUpdates:^{
        NSIndexPath* ip = [NSIndexPath indexPathForRow:kRowSshKey inSection:kSimpleFieldsSectionIdx];
        [self.tableView reloadRowsAtIndexPaths:@[ip]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    } completion:^(BOOL finished) {
        [self onModelEdited];
    }];
}

- (void)launchAttachmentPreview:(NSUInteger)index {
    QLPreviewController *v = [[QLPreviewController alloc] init];
    v.dataSource = self;
    v.currentPreviewItemIndex = index;
    v.delegate = self;
    
    v.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self presentViewController:v animated:YES completion:nil];
}

- (void)onAddAttachment:(NSString*)filename attachment:(KeePassAttachmentAbstractionLayer*)attachment {
    slog(@"Adding new Attachment: [%@]", attachment);
    
    [self.model insertAttachment:filename attachment:attachment]; 
    
    [self.tableView performBatchUpdates:^{
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kAttachmentsSectionIdx] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } completion:^(BOOL finished) {
        [self onModelEdited];
    }];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [StrongboxFilesManager.sharedInstance deleteAllTmpAttachmentFiles];
    });
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.model.filteredAttachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    NSString* filename = self.model.filteredAttachments.allKeys[index];
    KeePassAttachmentAbstractionLayer* attachment = self.model.filteredAttachments[filename];
    NSData* data = attachment.nonPerformantFullData;
    
    if ( filename.pathExtension.length == 0 ) {
        NSString *extension = [Utils likelyFileExtensionForData:data];
        
        filename = [filename stringByAppendingPathExtension:extension];
    }
    
    NSString* f = [StrongboxFilesManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];
    
    
    
    
    NSURL* url = [NSURL fileURLWithPath:f];
    
    NSError* error;
    if ( ![data writeToURL:url options:kNilOptions error:&error] ) {
        slog(@"🔴 Error writing preview attachment %@", error);
    }
    
    if ( ![QLPreviewController canPreviewItem:url] ) {
        slog(@"🔴 Won't be able to preview this item!");
    }
    
    return url;
}



- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToCustomFieldEditor"]) {
        UINavigationController *nav = segue.destinationViewController;
        CustomFieldEditorViewController* vc = (CustomFieldEditorViewController*)[nav topViewController];
        
        vc.colorizeValue = self.databaseModel.metadata.colorizePasswords;
        vc.customFieldsKeySet = self.model.existingCustomFieldsKeySet;
        
        CustomFieldViewModel* fieldToEdit = (CustomFieldViewModel*)sender;
        
        vc.customField = fieldToEdit;
        vc.onDone = ^(CustomFieldViewModel * _Nonnull field) {
            [self onCustomFieldEditedOrAdded:field fieldToEdit:fieldToEdit];
        };
    }
    else if ([segue.identifier isEqual:@"toPasswordHistory"] && (self.itemId != nil)) {
        PasswordHistoryViewController *vc = segue.destinationViewController;
        
        Node* item = [self.databaseModel.database getItemById:self.itemId];
        
        vc.model = item.fields.passwordHistory;
        vc.readOnly = self.isEffectivelyReadOnly;
        vc.saveFunction = ^(PasswordHistory *changed) {
            [self onPasswordHistoryChanged:changed];
        };
    }
    else if ([segue.identifier isEqualToString:@"toKeePassHistory"] && (self.itemId != nil)) {
        KeePassHistoryController *vc = (KeePassHistoryController *)segue.destinationViewController;
        
        Node* item = [self.databaseModel.database getItemById:self.itemId];
        
        vc.historicalItems = item.fields.keePassHistory;
        vc.viewModel = self.databaseModel;
        
        vc.restoreToHistoryItem = ^(Node * historicalNode) {
            [self onRestoreFromHistoryNode:historicalNode];
        };
        
        vc.deleteHistoryItem = ^(Node * historicalNode) {
            [self onDeleteHistoryItem:historicalNode];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToPasswordGenerationSettings"]) {
        UINavigationController *nav = segue.destinationViewController;
        PasswordGenerationViewController* vc = (PasswordGenerationViewController*)[nav topViewController];
        vc.onDone = ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToLargeView"]) {
        LargeTextViewController* vc = segue.destinationViewController;
        
        
        NSDictionary* d = sender;
        vc.string = d[@"text"];
        vc.subtext = d[@"subtext"];
        vc.colorize = ((NSNumber*)(d[@"colorize"])).boolValue;
        vc.hideLargeTextGrid = ((NSNumber*)(d[@"hideLargeTextGrid"])).boolValue;
    }
    else if ([segue.identifier isEqualToString:@"segueToAuditDrillDown"]) {
        UINavigationController* nav = segue.destinationViewController;
        AuditDrillDownController* vc = (AuditDrillDownController*)nav.topViewController;
        
        vc.model = self.databaseModel;
        vc.itemId = self.itemId;
        
        __weak ItemDetailsViewController* weakSelf = self;
        vc.updateDatabase = ^{
            [weakSelf updateAndSync];
        };
    }
}

- (void)onCustomFieldEditedOrAdded:(CustomFieldViewModel * _Nonnull)field
                       fieldToEdit:(CustomFieldViewModel*)fieldToEdit {
    slog(@"onCustomFieldEditedOrAdded: [%@] - fieldToEdit = [%@]", field, fieldToEdit);
    
    if ( fieldToEdit ) { 
        NSUInteger oldIdx = [self.model.customFieldsFiltered indexOfObject:fieldToEdit];
        
        if (oldIdx != NSNotFound) {
            [self.model removeCustomFieldAtIndex:oldIdx];
            [self.model addCustomField:field atIndex:oldIdx];
            
            [self.tableView performBatchUpdates:^{
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kSimpleFieldsSectionIdx] withRowAnimation:UITableViewRowAnimationAutomatic];
            } completion:^(BOOL finished) {
                [self onModelEdited];
            }];
        }
        else {
            
            
            
            
            
            
            
            slog(@"⚠️ WARNWARN - Could not find custom field to edit!!");
            return;
        }
    }
    else {
        [self.model addCustomField:field];
        [self.tableView performBatchUpdates:^{
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:kSimpleFieldsSectionIdx] withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            [self onModelEdited];
        }];
    }
}

- (UIImage*)getIconImageFromModel {
    if(self.databaseModel.database.originalFormat == kPasswordSafe) {
        return nil;
    }
    
    return [NodeIconHelper getNodeIcon:self.model.icon predefinedIconSet:self.databaseModel.metadata.keePassIconSet format:self.databaseModel.database.originalFormat];
}



- (void)updateTotpRow {
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:kRowTotp inSection:kSimpleFieldsSectionIdx]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)onClearTotp {
    self.model.totp = nil;
    
    [self updateTotpRow];
    
    [self onModelEdited];
}

- (void)onSetTotp {
    __weak ItemDetailsViewController* weakSelf = self;

    [Alerts fourOptionsWithCancel:self
                            title:NSLocalizedString(@"item_details_setup_totp_how_title", @"How would you like to setup TOTP?")
                          message:NSLocalizedString(@"item_details_setup_totp_how_message", @"You can setup TOTP by using a QR Code, or manually by entering the secret or an OTPAuth URL")
                defaultButtonText:NSLocalizedString(@"scan_qr_code_from_camera", @"Scan QR Code with Camera")
                 secondButtonText:NSLocalizedString(@"key_files_vc_one_time_key_file_source_option_photos", @"Photo Library...")
                  thirdButtonText:NSLocalizedString(@"item_details_setup_totp_manual_rfc", @"Manual (Standard/RFC 6238)...")
                 fourthButtonText:NSLocalizedString(@"item_details_setup_totp_manual_steam", @"Manual (Steam Token)...")
                           action:^(int response) {
        if(response == 0){
            TOTPScannerViewController* vc = [[TOTPScannerViewController alloc] init];
            
            vc.modalPresentationStyle = UIModalPresentationFormSheet;
            
            vc.onFoundTOTP = ^(NSURL* url) {
                [weakSelf setTotpWithString:url.absoluteString steam:NO];
            };
            
            [weakSelf presentViewController:vc animated:YES completion:nil];
            
        }
        else if(response == 1) {
            [weakSelf scanPhotoLibraryImageForQRCode];
        }
        else if(response == 2 || response == 3) {
            [Alerts OkCancelWithTextField:weakSelf
                     textFieldPlaceHolder:NSLocalizedString(@"item_details_setup_totp_secret_title", @"Secret or OTPAuth URL")
                                    title:NSLocalizedString(@"item_details_setup_totp_secret_message", @"Please enter the secret or an OTPAuth URL")
                                  message:@""
                               completion:^(NSString *text, BOOL success) {
                if(success) {
                    [weakSelf setTotpWithString:text steam:(response == 3)];
                }
            }];
        }
    }];
}

- (void)setTotpWithString:(NSString*)string steam:(BOOL)steam {
    OTPToken* token = [NodeFields getOtpTokenFromString:string forceSteam:steam];
    
    if(token) {
        self.model.totp = token;
        
        [self updateTotpRow];
        
        [self onModelEdited];
        
        slog(@"✅ Saving as just added a TOTP");
        
        self.justAutoCommittedTotp = YES;
        
        [self applyChangesAndSave];
    }
    else {
        [Alerts warn:self
               title:NSLocalizedString(@"item_details_setup_totp_failed_title", @"Failed to Set TOTP")
             message:NSLocalizedString(@"item_details_setup_totp_failed_message", @"Could not set TOTP because it could not be initialized.")];
    }
}

- (void)scanPhotoLibraryImageForQRCode {
    BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    
    if(!available) {
        [Alerts info:self
               title:NSLocalizedString(@"add_attachment_vc_error_source_unavailable_title", @"Source Unavailable")
             message:NSLocalizedString(@"add_attachment_vc_error_source_unavailable_photos", @"Strongbox could not access photos. Does it have permission?")];
        return;
    }
    
    UIImagePickerController *vc = [[UIImagePickerController alloc] init];
    vc.delegate = self;
    vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    vc.mediaTypes = @[(NSString*)kUTTypeMovie, (NSString*)kUTTypeImage];
    vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    if(!image) {
        [Alerts warn:self
               title:NSLocalizedString(@"add_attachment_vc_error_reading_title", @"Error Reading")
             message:NSLocalizedString(@"add_attachment_vc_error_reading_message", @"Could not read the data for this item.")];
        return;
    }
    
    [picker dismissViewControllerAnimated:YES completion:^{
        NSString *qrCodeString = [self detectQRCode:image];
        
        if (qrCodeString != nil) {
            NSURL* url = qrCodeString.urlExtendedParse; 
            if ( url ) {
                [self setTotpWithString:url.absoluteString steam:NO];
            }
        }
        else {
            slog(@"Couldn't find QR Code!");
            
            [Alerts warn:self
                   title:NSLocalizedString(@"add_attachment_vc_error_reading_title", @"Error Reading")
                 message:NSLocalizedString(@"could_not_find_qr_code", @"Strongbox could not find a QR Code in this image.")];
        }
    }];
}

- (NSString*)detectQRCode:(UIImage *)image {
    @autoreleasepool {
        CIImage* ciImage = image.CIImage ? image.CIImage : [CIImage imageWithCGImage:image.CGImage];
        
        if ( !ciImage ) {
            slog(@"WARNWARN: Could not get CIImage for QR Code");
            return nil;
        }
        
        CIDetector* qrDetector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                                    context:CIContext.context
                                                    options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
        
        id orientation = ciImage.properties[(NSString*)kCGImagePropertyOrientation];
        
        NSArray<CIFeature*>* features = [qrDetector featuresInImage:ciImage
                                                            options:@{ CIDetectorImageOrientation : orientation ? orientation : @1}];
        
        if ( features.firstObject && [features.firstObject isKindOfClass:CIQRCodeFeature.class] ) {
            CIQRCodeFeature* feature = (CIQRCodeFeature*)features.firstObject;
            return feature.messageString;
        }
        
        return nil;
    }
}



- (void)copyToClipboard:(NSString *)value message:(NSString *)message {
    if (value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
    
    [self showToast:message];
}

- (void)showToast:(NSString*)message {
#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:message
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

- (void)copyAndLaunchUrl {
    NSString* urlString = [self dereference:self.model.url];
    [self copyAndLaunch:urlString];
}

- (void)copyAndLaunch:(NSString*)urlString {
    if (!urlString.length) {
        return;
    }
    
    NSString* pw = [self dereference:self.model.password];
    [self copyToClipboard:pw
                  message:NSLocalizedString(@"item_details_password_copied_and_launching", @"Password Copied. Launching URL...")];
    
    [self.databaseModel launchUrlString:urlString];
}

- (NSString*)maybeDereference:(NSString*)text {
    Node* item = self.itemId ? [self.databaseModel.database getItemById:self.itemId] : nil;
    return item && !self.editing && self.databaseModel.metadata.viewDereferencedFields ? [self.databaseModel.database dereference:text node:item] : text;
}

- (NSString*)dereference:(NSString*)text {
    Node* item = self.itemId ? [self.databaseModel.database getItemById:self.itemId] : nil;
    return item ? [self.databaseModel.database dereference:text node:item] : text;
}




- (Node*)createNewEntryNode {
    AutoFillNewRecordSettings* settings = AppPreferences.sharedInstance.autoFillNewRecordSettings;
    
    NSString *title = settings.titleAutoFillMode == kDefault ?
    NSLocalizedString(@"item_details_vc_new_item_title", @"Untitled") :
    settings.titleCustomAutoFill;
    
#ifdef IS_APP_EXTENSION
    if(self.autoFillSuggestedTitle.length) {
        title = self.autoFillSuggestedTitle;
    }
#endif
    
    NSString* username = settings.usernameAutoFillMode == kNone ? @"" :
    settings.usernameAutoFillMode == kMostUsed ? self.databaseModel.database.mostPopularUsername : settings.usernameCustomAutoFill;
    
    NSString *password =
    settings.passwordAutoFillMode == kNone ? @"" :
    settings.passwordAutoFillMode == kGenerated ? [self.databaseModel generatePassword] : settings.passwordCustomAutoFill;
    
    NSString* email =
    settings.emailAutoFillMode == kNone ? @"" :
    settings.emailAutoFillMode == kMostUsed ? self.databaseModel.database.mostPopularEmail : settings.emailCustomAutoFill;
    
    NSString* url = settings.urlAutoFillMode == kNone ? @"" : settings.urlCustomAutoFill;
    
#ifdef IS_APP_EXTENSION
    if(self.autoFillSuggestedUrl.length) {
        url = self.autoFillSuggestedUrl;
    }
#endif
    
    NSString* notes = settings.notesAutoFillMode == kNone ? @"" : settings.notesCustomAutoFill;
    
#ifdef IS_APP_EXTENSION
    if(self.autoFillSuggestedNotes.length) {
        notes = self.autoFillSuggestedNotes;
    }
#endif
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:username url:url password:password notes:notes email:email];
    
    Node* parentGroup = [self getParentGroupForNewNode];
    Node* node = [[Node alloc] initAsRecord:title parent:parentGroup fields:fields uuid:nil];
    
    if ( parentGroup && !parentGroup.isUsingKeePassDefaultIcon && AppPreferences.sharedInstance.useParentGroupIconOnCreate ) {
        node.icon = parentGroup.icon;
    }
    
    return node;
}

- (Node*)getParentGroupForNewNode {
    Node* parentGroup = nil;
    
    if ( self.parentGroupId ) {
        parentGroup = [self.databaseModel.database getItemById:self.parentGroupId];
    }
    
    if ( parentGroup == nil ) {
        parentGroup = self.databaseModel.database.effectiveRootGroup;
    }
    
    if ( !parentGroup.childRecordsAllowed ) { 
        parentGroup = parentGroup.childGroups.firstObject;
    }
    
    return parentGroup ? parentGroup : self.databaseModel.database.effectiveRootGroup;
}

- (void)applyModelChangesToDatabaseNode:(void (^)(Node* item))completion {
    Node* ret;
    
    if ( self.createNewItem ) {
        ret = [self createNewEntryNode];
        Node* parentGroup = [self getParentGroupForNewNode];
        
        BOOL added = [self.databaseModel addChildren:@[ret] destination:parentGroup];
        
        if ( !added ) {
            completion(nil);
            return;
        }
    }
    else { 
        ret = [self.databaseModel.database getItemById:self.itemId];
        Node* originalNodeForHistory = [ret cloneForHistory];
        [self addHistoricalNode:ret originalNodeForHistory:originalNodeForHistory];
    }
    
    if ( ![self.model applyToNode:ret
                            model:self.databaseModel
          legacySupplementaryTotp:AppPreferences.sharedInstance.addLegacySupplementaryTotpCustomFields
                    addOtpAuthUrl:AppPreferences.sharedInstance.addOtpAuthUrl] ) {
        completion(nil);
        return;
    }
    
    [self.databaseModel.database rebuildFastMaps];
    
    
    
    [self processIconBeforeSave:ret completion:^{
        completion(ret);
    }];
}

- (void)processIconBeforeSave:(Node*)item completion:(void (^)(void))completion {
    if ( self.iconExplicitlyChanged ) {
        self.iconExplicitlyChanged = NO;
        item.icon = self.model.icon;
    }
    else {
        if (self.createNewItem || self.urlJustChanged) {
            self.urlJustChanged = NO;
#ifndef IS_APP_EXTENSION
            
            BOOL formatGood = (self.databaseModel.database.originalFormat == kKeePass || self.databaseModel.database.originalFormat == kKeePass4);
            BOOL featureAvailable = AppPreferences.sharedInstance.isPro && !AppPreferences.sharedInstance.disableFavIconFeature;
            
            BOOL favIconFetchPossible = (featureAvailable && formatGood && isValidUrl(self.model.url));
            
            if (favIconFetchPossible) {
                if (!self.databaseModel.metadata.promptedForAutoFetchFavIcon) {
                    [Alerts yesNo:self
                            title:NSLocalizedString(@"item_details_prompt_auto_fetch_favicon_title", @"Auto Fetch FavIcon?")
                          message:NSLocalizedString(@"item_details_prompt_auto_fetch_favicon_message", @"Strongbox can automatically fetch FavIcons when an new entry is created or updated.\n\nWould you like to Strongbox to do this?")
                           action:^(BOOL response) {
                        self.databaseModel.metadata.promptedForAutoFetchFavIcon = YES;
                        self.databaseModel.metadata.tryDownloadFavIconForNewRecord = response;
                        
                        if (self.databaseModel.metadata.tryDownloadFavIconForNewRecord ) {
                            [self fetchFavIcon:item completion:completion];
                            return;
                        }
                        else {
                            completion();
                        }
                    }];
                    return;
                }
                else {
                    if (self.databaseModel.metadata.tryDownloadFavIconForNewRecord ) {
                        [self fetchFavIcon:item completion:completion];
                        return;
                    }
                }
            }
#endif
        }
    }
    
    completion();
}

#ifndef IS_APP_EXTENSION

- (void)fetchFavIcon:(Node*)item completion:(void (^)(void))completion {
    self.sni = [[SetNodeIconUiHelper alloc] init];
    
    [self.sni expressDownloadBestFavIcon:self.model.url
                              completion:^(NodeIcon * _Nullable favIcon) {
        if( favIcon ) {
            item.icon = favIcon;
        }
        
        completion();
    }];
}

- (void)onChangeIcon {
    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.databaseModel.database.iconPool;
    
    NSString* urlHint = self.model.url.length ? self.model.url : self.model.title;
    
    [self.sni changeIcon:self
                   model:self.databaseModel
                    node:self.itemId ? [self.databaseModel.database getItemById:self.itemId] : [self createNewEntryNode]
             urlOverride:urlHint
                  format:self.databaseModel.database.originalFormat
          keePassIconSet:self.databaseModel.metadata.keePassIconSet
              completion:^(BOOL goNoGo, BOOL isRecursiveGroupFavIconResult, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selected) {
        if ( goNoGo ) {
            self.model.icon = selected ? selected.allValues.firstObject : nil;
            self.iconExplicitlyChanged = YES;
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:kRowTitleAndIcon inSection:kSimpleFieldsSectionIdx]] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self onModelEdited];
        }
    }];
}

#endif

- (void)disableUi {
    self.editButtonItem.enabled = NO; 
    self.cancelOrDiscardBarButton.enabled = NO;
    [self.tableView setUserInteractionEnabled:NO];
    
    CGRect screenRect = self.tableView.bounds; 
    self.coverView = [[UIView alloc] initWithFrame:screenRect];
    self.coverView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    [self.view addSubview:self.coverView];
}

- (void)enableUi {
    self.editButtonItem.enabled = YES;
    [self.tableView setUserInteractionEnabled:YES];
    self.cancelOrDiscardBarButton.enabled = YES;
    [self.coverView removeFromSuperview];
}

- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory {
    BOOL shouldAddHistory = YES; 
    if(shouldAddHistory && originalNodeForHistory != nil) {
        [item.fields.keePassHistory addObject:originalNodeForHistory];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ( self.editing ) {
        return nil;
    }
    
    
    
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    CollapsibleTableViewHeader* header;
    
    if ( section == kNotesSectionIdx ) {
        header = [[CollapsibleTableViewHeader alloc] initWithOnCopy:^{
            [weakSelf copyToClipboard:weakSelf.model.notes
                              message:NSLocalizedString(@"item_details_notes_copied", @"Notes Copied")];
        }];
    }
    else {
        header = [[CollapsibleTableViewHeader alloc] initWithOnCopy:nil];
    }
    
    [header setCollapsed:self.databaseModel.metadata.detailsViewCollapsedSections[section].boolValue];
    
    __weak CollapsibleTableViewHeader* weakHeader = header;
    
    header.onToggleSection = ^() {
        BOOL toggled = !weakSelf.databaseModel.metadata.detailsViewCollapsedSections[section].boolValue;
        
        NSMutableArray* mutable = [weakSelf.databaseModel.metadata.detailsViewCollapsedSections mutableCopy];
        mutable[section] = @(toggled);
        weakSelf.databaseModel.metadata.detailsViewCollapsedSections = mutable;
        
        [weakHeader setCollapsed:toggled];
        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
    };
    
    return header;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( self.editing ) {
        if(indexPath.section == kAttachmentsSectionIdx) {
            if(indexPath.row == 0) {
                [self promptToAddAttachment];
            }
            else {
                [self launchAttachmentPreview:indexPath.row - 1];
            }
        }
        else if (indexPath.section == kSimpleFieldsSectionIdx) {
            NSInteger customFieldIdx = indexPath.row - kSimpleRowCount;
            
            if(indexPath.row == kRowTotp) {
                if(!self.model.totp) {
                    [self onSetTotp];
                }
            }
            else if ( indexPath.row == kRowTags ) {
                [self showTagsEditor];
            }
            else if ( indexPath.row == kRowSshKey ) {
                if ( !self.model.keeAgentSshKey ) {
                    [self promptToAddSshKey];
                }
            }
            else if(customFieldIdx == self.model.customFieldsFiltered.count  ) { 
                [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:nil];
            }
            else if (customFieldIdx >= 0 && customFieldIdx < self.model.customFieldsFiltered.count) {
                NSInteger idx = customFieldIdx;
                CustomFieldViewModel* cf = self.model.customFieldsFiltered[idx];
                [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:cf];
            }
        }
    }
    else {
        NSUInteger customFieldIdx = indexPath.row - kSimpleRowCount;
        
        if(indexPath.section == kAttachmentsSectionIdx) {
            if ( indexPath.row > 0 ) { 
                [self launchAttachmentPreview:indexPath.row - 1];
            }
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx) {
            if (indexPath.row == kRowTitleAndIcon) {
                [self copyToClipboard:[self dereference:self.model.title] message:NSLocalizedString(@"item_details_title_copied", @"Title Copied")];
            }
            else if (indexPath.row == kRowUsername) {
                [self copyToClipboard:[self dereference:self.model.username] message:NSLocalizedString(@"item_details_username_copied", @"Username Copied")];
            }
            else if (indexPath.row == kRowPassword) {
                [self copyToClipboard:[self dereference:self.model.password] message:NSLocalizedString(@"item_details_password_copied", @"Password Copied")];
            }
            else if ( indexPath.row == kRowURL ) {
                [self copyToClipboard:[self dereference:self.model.url] message:NSLocalizedString(@"item_details_url_copied", @"URL Copied")];
            }
            else if ( indexPath.row == kRowEmail) {
                [self copyToClipboard:self.model.email message:NSLocalizedString(@"item_details_email_copied", @"Email Copied")];
            }
            else if (indexPath.row == kRowTotp && self.model.totp) {
                [self copyToClipboard:self.model.totp.password message:NSLocalizedString(@"item_details_totp_copied", @"One Time Password Copied")];
            }
            else if (customFieldIdx >= 0 && customFieldIdx < self.model.customFieldsFiltered.count) {
                NSInteger idx = customFieldIdx;
                CustomFieldViewModel* cf = self.model.customFieldsFiltered[idx];
                NSString* value = [self maybeDereference:cf.value];
                [self copyToClipboard:value message:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), cf.key]];
            }
        }
        else if(indexPath.section == kNotesSectionIdx) {
            
        }
        else if(indexPath.section == kMetadataSectionIdx) {
            ItemMetadataEntry* entry = self.metadataRows[indexPath.row];
            if(entry.copyable) {
                [self copyToClipboard:entry.value message:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), entry.key]];
            }
        }
        else if(indexPath.section == kOtherSectionIdx && indexPath.row == 0) {
            [self performSegueWithIdentifier:self.databaseModel.database.originalFormat == kPasswordSafe ? @"toPasswordHistory" : @"toKeePassHistory" sender:nil];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell*)getUsernameCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    UIImage* refresh = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"];
    
    UIImage* image = self.editing ? refresh : nil;
    
    [cell setKey:NSLocalizedString(@"item_details_username_field_title", @"Username")
           value:[self maybeDereference:self.model.username]
         editing:self.editing
 useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
rightButtonImage:image
suggestionProvider:^NSString * _Nullable(NSString * _Nonnull text) {
        NSArray* matches = [[[weakSelf.databaseModel.database.usernameSet allObjects] filter:^BOOL(NSString * obj) {
            return [obj hasPrefix:text];
        }] sortedArrayUsingComparator:finderStringComparator];
        return matches.firstObject;
    }];
    
    cell.onEdited = ^(NSString * _Nonnull text) {
        weakSelf.model.username = trim(text);
        [weakSelf onModelEdited];
    };
    
    if (self.editing) {
        __weak GenericKeyValueTableViewCell* weakCell = cell;
        cell.onRightButton = ^{
            [PasswordMaker.sharedInstance promptWithUsernameSuggestions:weakSelf
                                                                 config:AppPreferences.sharedInstance.passwordGenerationConfig
                                                                 action:^(NSString * _Nonnull response) {
                [weakCell pokeValue:response];
            }];
        };
    }
    else {
        cell.onRightButton = nil;
    }
    
    return cell;
}

- (UITableViewCell*)getTagsCell:(NSIndexPath*)indexPath {
    if (@available(iOS 16.0, *)) {

            TagsNGTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:TagsNGTableViewCell.CellIdentifier];
        [cell setContentWithTags:self.model.tags useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll isEditing:self.isEditing];
            
            cell.selectionStyle = self.isEditing ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryType = UITableViewCellAccessoryNone;
            return cell;









    } else {
        TagsViewTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTagsViewCellId forIndexPath:indexPath];
        
        [cell setModel:YES
                  tags:self.model.tags
       useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
        
        cell.selectionStyle = self.isEditing ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
}

- (UITableViewCell*)getPasswordCell:(NSIndexPath*)indexPath {
    __weak ItemDetailsViewController* weakSelf = self;
    
    if(self.editing) {
        EditPasswordTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditPasswordCellId forIndexPath:indexPath];
        
        cell.colorize = self.databaseModel.metadata.colorizePasswords;
        cell.parentVc = self;
        
        cell.concealPassword = self.passwordConcealedInUi; 
        cell.password = self.model.password;
        
        cell.onPasswordEdited = ^(NSString * _Nonnull password) {
            weakSelf.model.password = password;
            [weakSelf onModelEdited];
        };
        
        cell.onPasswordSettings = ^(void) {
            [weakSelf performSegueWithIdentifier:@"segueToPasswordGenerationSettings" sender:nil];
        };
        cell.showGenerationSettings = YES;
        
        cell.historyMenu = [self getPasswordHistoryMenu];
        
        return cell;
    }
    else {
        GenericKeyValueTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        NSString* audit = [self.databaseModel getQuickAuditSummaryForNode:self.itemId];
        
        [cell setConcealableKey:NSLocalizedString(@"item_details_password_field_title", @"Password")
                          value:[self maybeDereference:self.model.password]
                      concealed:self.passwordConcealedInUi
                       colorize:self.databaseModel.metadata.colorizePasswords
                          audit:audit
                   showStrength:YES
              showLargeTextView:YES];
        
        __weak GenericKeyValueTableViewCell* weakCell = cell;
        cell.onRightButton = ^{
            weakSelf.passwordConcealedInUi = !weakSelf.passwordConcealedInUi;
            weakCell.isConcealed = weakSelf.passwordConcealedInUi;
        };
        
        cell.onAuditTap = ^{
            [weakSelf performSegueWithIdentifier:@"segueToAuditDrillDown" sender:nil];
        };
        
        cell.historyMenu = [self getPasswordHistoryMenu];
        
        cell.onShowLargeTextView = ^{
            [weakSelf showLargeText:weakSelf.model.password colorize:weakSelf.databaseModel.metadata.colorizePasswords];
        };
        
        return cell;
    }
}

- (UITableViewCell*)getTotpCell:(NSIndexPath*)indexPath {
    OTPToken* totp = self.model.totp;
    
    if ( self.editing && !totp ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = NSLocalizedString(@"item_details_setup_totp", @"Setup TOTP...");
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        TotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kTotpCell forIndexPath:indexPath];
        
        [cell setItem:self.model.totp];
        
        __weak ItemDetailsViewController* weakSelf = self;
        cell.onShowQrCode = ^{
            [weakSelf showQrCodeForTotp];
        };
        
        return cell;
    }
}

- (UITableViewCell*)getKeeAgentSshKeyCell:(NSIndexPath*)indexPath {
    if ( self.editing && !self.model.keeAgentSshKey ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        
        cell.labelText.text = NSLocalizedString(@"details_add_new_ssh_key_ellipsis", @"New SSH Key...");
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        if ( self.model.keeAgentSshKey ) {
            SshKeyViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kSshKeyViewCellId forIndexPath:indexPath];
            
            OpenSSHPrivateKey* theKey = self.model.keeAgentSshKey.openSshKey;
            
            [cell setContent:self.model.keeAgentSshKey
                    password:self.model.password
              viewController:self
                    editMode:self.editing
                   onCopyPub:^{
                [self copyToClipboard:theKey.publicKey message:NSLocalizedString(@"generic_copied", @"Copied")];
            }
               onCopyPrivate:^{
                [self copyToClipboard:theKey.privateKey message:NSLocalizedString(@"generic_copied", @"Copied")];
            }
                onCopyFinger:^{
                [self copyToClipboard:theKey.fingerprint message:NSLocalizedString(@"generic_copied", @"Copied")];
            }];
            
            return cell;
        }
        else {
            
            return [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        }
    }
}

- (UITableViewCell*)getPasskeyCell:(NSIndexPath*)indexPath {
    if ( self.model.passkey ) {
        PasskeyTableCellView* cell = [self.tableView dequeueReusableCellWithIdentifier:kPasskeyTableCellViewId forIndexPath:indexPath];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        cell.viewController = self;
        
        cell.copyFunction = ^(NSString * _Nonnull string) {
            [self copyToClipboard:string message:NSLocalizedString(@"generic_copied", @"Copied")];
        };
        cell.launchUrlFunction = ^(NSString * _Nonnull string) {
            [self.databaseModel launchUrlString:string];
        };
        
        cell.passkey = self.model.passkey;
        
        return cell;
    }
    else {
        return [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath]; 
    }
}

- (UITableViewCell*)getUrlCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    if (self.editing) {
        [cell setKey:NSLocalizedString(@"item_details_url_field_title", @"URL")
               value:[self maybeDereference:self.model.url]
             editing:self.editing
     useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
         formatAsUrl:isValidUrl(self.model.url) && !self.editing
    rightButtonImage:nil
  suggestionProvider:^NSString*(NSString *text) {
            NSArray* matches = [[[weakSelf.databaseModel.database.urlSet allObjects] filter:^BOOL(NSString * obj) {
                return [obj hasPrefix:text];
            }] sortedArrayUsingComparator:finderStringComparator];
            return matches.firstObject;
        }];
        
        cell.onEdited = ^(NSString * _Nonnull text) {
            weakSelf.model.url = trim(text);
            [weakSelf onModelEdited];
        };
    }
    else {
        NSString* value = [self maybeDereference:self.model.url];
        BOOL url = isValidUrl(value);
        UIImage *launchUrlImage = url ? [UIImage imageNamed:@"link"] : nil;
        
        NSArray<NSString*>* associatedDomains = @[];
        if ( url && self.databaseModel.metadata.includeAssociatedDomains ) {
            NSSet<NSString*> *ads = [BrowserAutoFillManager getAssociatedDomainsWithUrl:value];
            associatedDomains = [ads.allObjects sortedArrayUsingComparator:finderStringComparator];
        }
        
        [cell setForUrlOrCustomFieldUrl:NSLocalizedString(@"item_details_url_field_title", @"URL")
                                  value:value
                            formatAsUrl:url
                       rightButtonImage:launchUrlImage
                        useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
                     associatedWebsites:associatedDomains];
        
        cell.onRightButton = ^{
            if (url) {
                [weakSelf copyAndLaunchUrl];
            }
            else {
                [weakSelf copyToClipboard:[weakSelf dereference:weakSelf.model.url]
                                  message:NSLocalizedString(@"item_details_url_copied", @"URL Copied")];
            }
        };
    }
    
    return cell;
}

- (UITableViewCell*)getEmailCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    [cell setKey:NSLocalizedString(@"item_details_email_field_title", @"Email")
           value:[self maybeDereference:self.model.email]
         editing:self.editing
 useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
rightButtonImage:nil
suggestionProvider:^NSString*(NSString *text) {
        NSArray* matches = [[[weakSelf.databaseModel.database.emailSet allObjects] filter:^BOOL(NSString * obj) {
            return [obj hasPrefix:text];
        }] sortedArrayUsingComparator:finderStringComparator];
        return matches.firstObject;
    }];
    
    cell.onEdited = ^(NSString * _Nonnull text) {
        weakSelf.model.email = trim(text);
        [weakSelf onModelEdited];
    };
    
    return cell;
}

- (UITableViewCell*)getExpiresCell:(NSIndexPath*)indexPath {
    __weak ItemDetailsViewController* weakSelf = self;
    
    if(self.isEditing) {
        EditDateCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditDateCell forIndexPath:indexPath];
        cell.keyLabel.text = NSLocalizedString(@"item_details_expires_field_title", @"Expires");
        [cell setDate:self.model.expires];
        
        cell.onDateChanged = ^(NSDate * _Nullable date) {
            slog(@"Setting Expiry Date to %@", date ? date.friendlyDateTimeString : @"");
            weakSelf.model.expires = date;
            [weakSelf onModelEdited];
        };
        
        
        
        
        
        
        
        return cell;
    }
    else {
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        NSDate* expires = self.model.expires;
        NSString *str = expires ? expires.friendlyDateTimeString : NSLocalizedString(@"item_details_expiry_never", @"Never");
        
        [cell setKey:NSLocalizedString(@"item_details_expires_field_title", @"Expires")
               value:str
             editing:NO
     useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        return cell;
    }
}

- (UITableViewCell*)getStandardNonMarkdownNotesCell:(NSString*)notes indexPath:(NSIndexPath*)indexPath {
    __weak ItemDetailsViewController* weakSelf = self;
    
    NotesTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kNotesCellId forIndexPath:indexPath];
    
    [cell setNotes:notes
          editable:self.editing
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
    
    cell.onNotesEdited = ^(NSString * _Nonnull notes) {
        weakSelf.model.notes = notes;
        [weakSelf onModelEdited];
    };
    
    cell.onNotesDoubleTap = ^{
        [weakSelf copyToClipboard:weakSelf.model.notes
                          message:NSLocalizedString(@"item_details_notes_copied", @"Notes Copied")];
    };
    
    return cell;
    
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ( !self.editing ) {
        [self.tableView reloadData]; 
    }
}

- (UITableViewCell*)getMarkdownNotesCell:(NSString*)markdown indexPath:(NSIndexPath*)indexPath {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    
    NSError* error;
    NSString* html = [StrongboxCMarkGFMHelper convertMarkdownWithMarkdown:markdown
                                                                 darkMode:dark
                                                          disableMarkdown:!AppPreferences.sharedInstance.markdownNotes
                                                                    error:&error];
    
    if ( error != nil || html.length == 0 ) {
        slog(@"🔴 Could not convert notes markdown to HTML, returning standard notes cell");
        return [self getStandardNonMarkdownNotesCell:markdown indexPath:indexPath];
    }
    

    
    __weak ItemDetailsViewController* weakSelf = self;
    
    MarkdownUIKitTableCellView* cell = [self.tableView dequeueReusableCellWithIdentifier:kMarkdownUIKitTableCellViewId forIndexPath:indexPath];
    
    [cell setContentWithHtml:html onHeightChanged:^{
        [weakSelf onCellHeightChangedNotification];
    }];
    
    return cell;
}

- (UITableViewCell*)getNotesCell:(NSIndexPath*)indexPath {
    NSString* notes = [self maybeDereference:self.model.notes];
    
    
    if ( self.editing || self.databaseModel.metadata.easyReadFontForAll ) {
        return [self getStandardNonMarkdownNotesCell:notes indexPath:indexPath];
    }
    else {
        return [self getMarkdownNotesCell:notes indexPath:indexPath];
    }
}

- (UITableViewCell*)getCustomFieldCell:(NSIndexPath*)indexPath {
    NSUInteger customFieldIdx = indexPath.row - kSimpleRowCount;
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    if( customFieldIdx == self.model.customFieldsFiltered.count ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        
        cell.labelText.text = NSLocalizedString(@"item_details_new_custom_field_button", @"New Custom Field...");
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    else {
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        
        NSInteger idx = customFieldIdx;
        if (idx < 0 || idx >= self.model.customFieldsFiltered.count) {
            return cell;
        }
        
        CustomFieldViewModel* cf =  self.model.customFieldsFiltered[idx];
        
        if(cf.protected && !self.editing) {
            [cell setConcealableKey:cf.key
                              value:[self maybeDereference:cf.value]
                          concealed:cf.concealedInUI
                           colorize:YES
                              audit:nil
                       showStrength:NO];
            
            __weak GenericKeyValueTableViewCell* weakCell = cell;
            
            cell.onRightButton = ^{
                cf.concealedInUI = !cf.concealedInUI;
                weakCell.isConcealed = cf.concealedInUI;
            };
        }
        else {
            NSString* value = [self maybeDereference:cf.value];
            
            if (self.editing) {
                [cell setKey:cf.key
                       value:value
                     editing:NO
             useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
                 formatAsUrl:NO
            rightButtonImage:nil
          suggestionProvider:nil];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            else {
                BOOL url = isValidUrl(value);
                UIImage *launchUrlImage = url ? [UIImage imageNamed:@"link"] : nil;
                [cell setForUrlOrCustomFieldUrl:cf.key value:value formatAsUrl:url rightButtonImage:launchUrlImage useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll associatedWebsites:@[]];
                
                if (url) {
                    cell.onRightButton = ^{
                        [weakSelf copyAndLaunch:value];
                    };
                }
            }
        }
        
        return cell;
    }
}

- (UITableViewCell*)getAttachmentCell:(NSIndexPath*)indexPath {
    if ( indexPath.row == 0 ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = NSLocalizedString(@"item_details_add_attachment_button", @"Add Attachment...");
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        NSInteger idx = indexPath.row - 1;
        if ( idx >= self.model.filteredAttachments.count ) {
            GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
            return cell;
        }
        
        NSString* filename = self.model.filteredAttachments.allKeys[idx];
        KeePassAttachmentAbstractionLayer* attachment = self.model.filteredAttachments[filename];
        if ( !attachment ) {
            GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
            return cell;
        }
        
        if ( self.editing ) {
            return [self getEditAttachmentCell:filename attachment:attachment indexPath:indexPath];
        }
        else {
            return [self getViewAttachmentCell:filename attachment:attachment indexPath:indexPath];
        }
    }
    
}

- (UITableViewCell*)getEditAttachmentCell:(NSString*)filename attachment:(KeePassAttachmentAbstractionLayer*)attachment indexPath:(NSIndexPath*)indexPath {
    EditAttachmentCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditAttachmentCellId forIndexPath:indexPath];
    cell.textField.text = filename;
    cell.image.image = [UIImage imageNamed:@"document"];
    
    if (attachment.length < kMaxAttachmentTableviewIconImageSize) {
        NSData* data = attachment.nonPerformantFullData; 
        UIImage* img = [UIImage imageWithData:data];
        if(img) {
            @autoreleasepool { 
                UIGraphicsBeginImageContextWithOptions(cell.image.bounds.size, NO, 0.0);
                
                CGRect imageRect = cell.image.bounds;
                [img drawInRect:imageRect];
                cell.image.image = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
            }
        }
    }
    
    return cell;
}

- (UITableViewCell*)getViewAttachmentCell:(NSString*)filename  attachment:(KeePassAttachmentAbstractionLayer*)attachment indexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kViewAttachmentCellId forIndexPath:indexPath];
    cell.textLabel.text = filename;
    cell.imageView.image = [UIImage imageNamed:@"document"];
    
    NSUInteger filesize = attachment.length;
    cell.detailTextLabel.text = friendlyFileSizeString(filesize);
    
    if (attachment.length < kMaxAttachmentTableviewIconImageSize) {
        NSData* data = attachment.nonPerformantFullData; 
        UIImage* img = [UIImage imageWithData:data];
        
        if(img) { 
            @autoreleasepool { 
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(48, 48), NO, 0.0);
                
                CGRect imageRect = CGRectMake(0, 0, 48, 48);
                [img drawInRect:imageRect];
                cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
            }
        }
    }
    
    return cell;
}

- (UITableViewCell*)getMetadataCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    ItemMetadataEntry* entry = self.metadataRows[indexPath.row];
    
    [cell setKey:entry.key
           value:entry.value
         editing:NO
 useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
    
    cell.selectionStyle = entry.copyable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (UITableViewCell*)getOtherCell:(NSIndexPath*)indexPath {
    GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
    
    cell.labelText.text = self.databaseModel.database.originalFormat == kPasswordSafe ?
    
    NSLocalizedString(@"item_details_password_history", @"Password History") :
    NSLocalizedString(@"item_details_item_history", @"Item History");
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (UITableViewCell*)getIconAndTitleCell:(NSIndexPath*)indexPath {
    IconTableCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kIconTableCell forIndexPath:indexPath];
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    [cell setModel:[self maybeDereference:self.model.title]
              icon:[self getIconImageFromModel]
           editing:self.editing
          newEntry:self.createNewItem
   selectAllOnEdit:self.createNewItem
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
    
#ifndef IS_APP_EXTENSION
    if(self.isEditing) {
        cell.onIconTapped = ^{
            [weakSelf onChangeIcon];
        };
        cell.onConfigureDefaultsTapped = ^{
            [weakSelf onConfigureDefaults];
        };
    }
    else {
#endif
        cell.onIconTapped = nil;
#ifndef IS_APP_EXTENSION
    }
#endif
    
    cell.onTitleEdited = ^(NSString * _Nonnull text) {
        weakSelf.model.title = trim(text);
        [weakSelf onModelEdited];
    };
    
    return cell;
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
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    
    
    if(indexPath.section == kSimpleFieldsSectionIdx) {
        if(indexPath.row == kRowUsername) {
            [self showLargeText:self.model.username colorize:NO];
        }
        else if(indexPath.row == kRowPassword) {
            [self showLargeText:self.model.password colorize:self.databaseModel.metadata.colorizePasswords];
        }
        else if(indexPath.row == kRowURL) {
            [self showLargeText:self.model.url colorize:NO];
        }
        else if (indexPath.row == kRowEmail) {
            [self showLargeText:self.model.email colorize:NO];
        }
        else if ( indexPath.row == kRowTotp ) {
            [self showQrCodeForTotp];
        }
        else if (indexPath.row >= kSimpleRowCount) { 
            NSUInteger idx = indexPath.row - kSimpleRowCount;
            CustomFieldViewModel* field = self.model.customFieldsFiltered[idx];
            [self showLargeText:field.value colorize:field.protected && self.databaseModel.metadata.colorizePasswords];
        }
    }
    else if (indexPath.section == kNotesSectionIdx) {
        [self showLargeText:self.model.notes colorize:NO];
    }
}

- (void)showQrCodeForTotp {
    if ( self.model.totp ) {
        NSURL* url = [self.model.totp url:YES];

        
        if ( url ) {
            [self showLargeText:url.absoluteString subtext:url.absoluteString colorize:YES hideLargeTextGrid:YES];
        }
    }
}

- (void)showLargeText:(NSString*)text colorize:(BOOL)colorize {
    [self showLargeText:text subtext:@"" colorize:YES hideLargeTextGrid:NO];
}

- (void)showLargeText:(NSString*)text colorize:(BOOL)colorize hideLargeTextGrid:(BOOL)hideLargeTextGrid {
    [self showLargeText:text subtext:@"" colorize:colorize hideLargeTextGrid:hideLargeTextGrid];
}

- (void)showLargeText:(NSString*)text subtext:(NSString*_Nullable)subtext colorize:(BOOL)colorize hideLargeTextGrid:(BOOL)hideLargeTextGrid {
    if (text) {
        [self performSegueWithIdentifier:@"segueToLargeView"
                                  sender:@{ @"text" : text,
                                            @"colorize" : @(colorize),
                                            @"hideLargeTextGrid" : @(hideLargeTextGrid),
                                            @"subtext" : subtext ? subtext : @"" }];
    }
}



- (DatabaseFormat)databaseFormat {
    return self.databaseModel.database.originalFormat;
}

- (void)onDeleteHistoryItem:(Node*)historicalNode {
    Node* item = [self.databaseModel.database getItemById:self.itemId];
    
    [item touch:YES touchParents:NO];
    [item.fields.keePassHistory removeObject:historicalNode];
    
    [self refreshPublishAndSyncAfterModelEdit];
}

- (void)onRestoreFromHistoryNode:(Node*)historicalNode {
    Node* item = [self.databaseModel.database getItemById:self.itemId];
    
    Node* clonedOriginalNodeForHistory = [item cloneForHistory];
    
    [self addHistoricalNode:item originalNodeForHistory:clonedOriginalNodeForHistory];
    
    [item touch:YES touchParents:NO];
    
    [item restoreFromHistoricalNode:historicalNode];
    
    [self refreshPublishAndSyncAfterModelEdit];
}

- (void)onPasswordHistoryChanged:(PasswordHistory*)changed {
    Node* item = [self.databaseModel.database getItemById:self.itemId];
    
    item.fields.passwordHistory = changed;
    [item touch:YES touchParents:NO];
    
    [self.databaseModel.database rebuildFastMaps];
    
    [self refreshPublishAndSyncAfterModelEdit];
}




- (void)applyChangesAndSave { 
    if( !self.createNewItem && ![self.model isDifferentFrom:self.preEditModelClone] ) {
        slog(@"ItemDetailsViewController::applyChangesAndSave => No Changes or Edits to Save - NOP...");
        return;
    }

    [self disableUi];

    self.urlJustChanged = [self.model.url compare:self.preEditModelClone.url] != NSOrderedSame;
    
    [self applyModelChangesToDatabaseNode:^(Node *item) { 
        [self enableUi];
        
        if ( !item ) {
            [Alerts info:self
                   title:NSLocalizedString(@"item_details_problem_saving", @"Problem Saving")
                 message:NSLocalizedString(@"item_details_problem_saving", @"Problem Saving")];
        }
        else {
            self.createNewItem = NO;
            self.itemId = item.uuid;
            [self reloadViewModelFromNodeItem];
            self.preEditModelClone = [self.model clone];
            
            [self bindNavBar];
            
            [self.tableView performBatchUpdates:^{
                [self refreshTableViewAnimated];
            } completion:^(BOOL finished) {
                [self bindNavBar];
                
                [self refreshPublishAndSyncAfterModelEdit];
            }];
        }
    }];
}

- (void)reloadViewModelFromNodeItem {
    Node* item;
    
    if ( self.createNewItem ) {
        item = [self createNewEntryNode];
    }
    else {
        item = [self.databaseModel.database getItemById:self.itemId]; 
        if ( self.historicalIndex != nil) {
            int index = self.historicalIndex.intValue;
            if ( index >= 0 && index < item.fields.keePassHistory.count ) {
                item = item.fields.keePassHistory[index];
                self.forcedReadOnly = YES;
            }
        }
    }
    
    if ( item == nil ) {
        
        
        item = [self createNewEntryNode];
    }
    else {
        self.metadataRows = [self.databaseModel getMetadataFromItem:item];
        self.model = [EntryViewModel fromNode:item model:self.databaseModel];
    }
}

- (void)refreshAll {
    [self reloadViewModelFromNodeItem];
    [self.tableView reloadData];
    [self bindNavBar];
    [self updateSyncBarButtonItemState];
}

- (void)refreshPublishAndSyncAfterModelEdit {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self refreshAll];
        
        [NSNotificationCenter.defaultCenter postNotificationName:kModelEditedNotification object:nil];
        
        [self showToast:NSLocalizedString(@"generic_database_saved", @"Database Saved")];
        
        [self updateAndSync];
    });
}

- (void)updateAndSync {
#ifdef IS_APP_EXTENSION
    [self disableUi];
    
    AppPreferences.sharedInstance.autoFillWroteCleanly = NO;
    
    [self.databaseModel asyncUpdate:^(AsyncJobResult * _Nonnull result) {
        AppPreferences.sharedInstance.autoFillWroteCleanly = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableUi];
            
            if ( !result.userCancelled && !result.error ) {
                if (self.onAutoFillNewItemAdded) {
                    self.onAutoFillNewItemAdded(self.model.username, self.model.password);
                }
            }
            else if (result.error) {
                [Alerts error:self.navigationController.visibleViewController error:result.error];
            }
        });

    }];
#else
    [self.parentSplitViewController updateAndQueueSyncWithCompletion:nil];
#endif
}

- (void)onConfigureDefaults {
#ifndef IS_APP_EXTENSION
    AutoFillNewRecordSettingsController* vc = AutoFillNewRecordSettingsController.fromStoryboard;
    
    vc.onDone = ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    
    
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    nav.toolbarHidden = YES;
    nav.toolbar.hidden = YES;
    
    [self presentViewController:nav animated:YES completion:nil];
#endif
}

#ifndef IS_APP_EXTENSION
- (MainSplitViewController *)parentSplitViewController {
    return (MainSplitViewController*)self.splitViewController;
}
#endif

- (UIMenu*)getPasswordHistoryMenu {
    Node* item = [self.databaseModel.database getItemById:self.itemId];
    
    NSArray<PasswordChangeEvent*>* changeHistory = [PasswordHistoryProcessor getHistoryChangeEventsWithItem:item];
    
    if (!self.hasHistory || changeHistory.count == 0 ) {
        return nil;
    }
    
    NSMutableArray<UIMenu*>* mut = NSMutableArray.array;
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    for ( PasswordChangeEvent* changeEvent in changeHistory ) {
        UIAction *action = [UIAction actionWithTitle:changeEvent.password
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf copyToClipboard:changeEvent.password message:NSLocalizedString(@"item_details_password_copied", @"Password Copied")];
        }];
        
        NSString* fmt;
        
        if  ( changeEvent == changeHistory.firstObject && changeHistory.count > 1 ) {
            fmt = NSLocalizedString(@"password_history_this_password_was_used_until_most_recent_fmt", @"Most Recent (Used until %@)");
        }
        else if ( changeEvent == changeHistory.lastObject && changeHistory.count > 1 ) {
            fmt = NSLocalizedString(@"password_history_this_password_was_used_until_oldest_fmt", @"Oldest (Used until %@)");
        }
        else {
            fmt = NSLocalizedString(@"password_history_this_password_was_used_until_fmt", @"Used until %@");
        }
        
        NSString* header = [NSString stringWithFormat:fmt, changeEvent.wasUsedUntil.friendlyDateTimeStringPrecise];
        
        UIMenu* submenu = [UIMenu menuWithTitle:header
                                          image:nil
                                     identifier:nil
                                        options:UIMenuOptionsDisplayInline
                                       children:@[action]];
        
        [mut addObject:submenu];
    }
    
    return [UIMenu menuWithTitle:NSLocalizedString(@"password_history_previous_passwords", @"Previous Passwords")
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:mut];
}

- (void)showTagsEditor {
    __weak ItemDetailsViewController* weakSelf = self;
    
    UIViewController* vc = [SwiftUIViewFactory getTagsEditorViewWithExistingTags:self.model.tags.set
                                                                         allTags:self.databaseModel.database.tagSet
                                                                      completion:^(BOOL cancelled, NSSet<NSString *> * _Nullable tags) {
        [weakSelf.presentedViewController dismissViewControllerAnimated:YES completion:^{
            if ( cancelled ) {
                return;
            }

            [weakSelf onTagsEdited:tags];
        }];
    }];
    
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)onTagsEdited:(NSSet<NSString*>*)tags {
    if ( [self.model resetTags:tags] ) { 
        [self onModelEdited];
        
        [self.tableView reloadData];
    }
}

@end
