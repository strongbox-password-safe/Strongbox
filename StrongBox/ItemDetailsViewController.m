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
#import "MarkdownCell.h"

#ifndef IS_APP_EXTENSION

#import "ISMessages/ISMessages.h"
#import "SetNodeIconUiHelper.h"
#import "QRCodeScannerViewController.h"
#import "Strongbox-Swift.h"
#import "NavBarSyncButtonHelper.h"

#else

#import "Strongbox_Auto_Fill-Swift.h"

#endif

#import "DatabasePreferences.h"
#import "AutoFillNewRecordSettingsController.h"
#import "SyncManager.h"

NSString *const CellHeightsChangedNotification = @"ConfidentialTableCellViewHeightChangedNotification";
NSString *const kNotificationNameItemDetailsEditDone = @"kNotificationModelEdited";

static NSInteger const kRowTitleAndIcon = 0;
static NSInteger const kRowUsername = 1;
static NSInteger const kRowPassword = 2;
static NSInteger const kRowURL = 3;
static NSInteger const kRowEmail = 4;
static NSInteger const kRowTags = 5;
static NSInteger const kRowExpires = 6;
static NSInteger const kRowTotp = 7;
static NSInteger const kRowSshKey = 8;
static NSInteger const kSimpleRowCount = 9;

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



@interface ItemDetailsViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property EntryViewModel* model;
@property EntryViewModel* preEditModelClone;
@property BOOL passwordConcealedInUi;
@property UIBarButtonItem* cancelOrDiscardBarButton;
@property UIView* coverView;
@property BOOL isAutoFillContext;
@property BOOL inCellHeightsChangedProcess;

@property BOOL urlJustChanged;
@property BOOL iconExplicitlyChanged;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

#ifndef IS_APP_EXTENSION

@property SetNodeIconUiHelper* sni;
@property (readonly) MainSplitViewController* parentSplitViewController; 

#endif


@property BOOL hideMetadataSection;

#ifndef IS_APP_EXTENSION
@property UIBarButtonItem* syncBarButton;
@property UIButton* syncButton;
#endif

@property (readonly) BOOL isEffectivelyReadOnly;
@property (readonly) DatabaseFormat databaseFormat;

@end



@implementation ItemDetailsViewController



static NSInteger const kSimpleFieldsSectionIdx = 0;
static NSInteger const kNotesSectionIdx = 1;
static NSInteger const kAttachmentsSectionIdx = 2;
static NSInteger const kMetadataSectionIdx = 3;
static NSInteger const kOtherSectionIdx = 4;
static NSInteger const kSectionCount = 5;

+ (NSArray<NSNumber*>*)defaultCollapsedSections {
    






    return @[@(0),
             @(0),
             @(0),
             @(1),
             @(1)];
}

- (void)dealloc {
    NSLog(@"ItemDetailsViewController::DEALLOC [%@]", self);
    
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [UIView setAnimationsEnabled:NO];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    [self listenToNotifications];
    
    [self.tableView reloadData];
    
    
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    
    [UIView setAnimationsEnabled:YES];
    
    [self updateSyncBarButtonItemState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
        
    [self unListenToNotifications];
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
    
    self.hideMetadataSection = !AppPreferences.sharedInstance.showMetadataOnDetailsScreen;
    
#ifndef IS_APP_EXTENSION
    self.isAutoFillContext = NO;
#else
    self.isAutoFillContext = YES;
#endif
    
    [self customizeRightBarButtons];
    

    
    self.cancelOrDiscardBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_verb_close", @"Close")
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(onCancel:)];
    
    [self setupTableview];
    
    self.passwordConcealedInUi = !self.databaseModel.metadata.showPasswordByDefaultOnEditScreen;
    
    self.model = [self reloadViewModelFromNodeItem];
    [self bindNavBar];
    
    if(self.createNewItem || self.editImmediately) {
        [self setEditing:YES animated:YES];
    }
    
    [self updateSyncBarButtonItemState];
    
    [self listenToNotifications];
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
                                               name:kAuditCompletedNotificationKey
                                             object:nil];
    
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateStarting
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kAsyncUpdateDone
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseReloaded:)
                                               name:kDatabaseReloadedNotificationKey
                                             object:nil];
    
#ifndef IS_APP_EXTENSION
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onSyncOrUpdateStatusChanged:)
                                               name:kSyncManagerDatabaseSyncStatusChanged
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
        [self performFullReload];
    }
}

- (void)onDatabaseReloaded:(id)param {
    if ( !self.isEditing ) {
        [self performFullReload];
    }
}

- (void)onDatabaseViewPreferencesChanged:(id)param {
    [self performFullReload];
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
    
    if (@available(iOS 15.0, *)) {
        [self.tableView setSectionHeaderTopPadding:4.0f];
    }
    
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
        [DatabasePreferences setEditing:self.databaseModel.metadata editing:NO];
        
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
}

- (void)onModelEdited {
    if(!self.editing) {
        NSLog(@"EEEEEEEKKKKK on Model edited while not editing!");
        return;
    }
    
    [self bindNavBar];
}

- (void)bindNavBar {
    if( self.isEditing ) {
        self.navigationItem.leftItemsSupplementBackButton = NO;
        BOOL isDifferent = [self.model isDifferentFrom:self.preEditModelClone];
        BOOL saveable = isDifferent || self.createNewItem;
        self.editButtonItem.enabled = saveable;
        self.navigationItem.leftBarButtonItem = self.cancelOrDiscardBarButton;
        [self.cancelOrDiscardBarButton setTitle:saveable ? NSLocalizedString(@"generic_verb_discard", @"Discard") :  NSLocalizedString(@"generic_verb_close", @"Close")];
        
        
        
        
        
        
        
        
        
    }
    else {
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.editButtonItem.enabled = !self.isEffectivelyReadOnly;
        self.navigationItem.leftBarButtonItem = self.splitViewController ? self.splitViewController.displayModeButtonItem : nil;
        
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

- (void)prepareTableViewForEditing {
    BOOL showAddCustomFieldRow = self.editing && (self.databaseModel.database.originalFormat == kKeePass || self.databaseModel.database.originalFormat == kKeePass4);
    NSUInteger addCustomFieldIdx = self.model.customFields.count + kSimpleRowCount;
    
    if(self.editing) {
        if (showAddCustomFieldRow) {
            NSUInteger addCustomFieldIdx = self.model.customFields.count + kSimpleRowCount;
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:addCustomFieldIdx inSection:kSimpleFieldsSectionIdx]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:kAttachmentsSectionIdx]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kSectionCount)]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    else {
        if (showAddCustomFieldRow) {
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:addCustomFieldIdx
                                                                        inSection:kSimpleFieldsSectionIdx]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:kAttachmentsSectionIdx]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kSectionCount)]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }
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
    
    [DatabasePreferences setEditing:self.databaseModel.metadata editing:editing];
    
    [self.tableView performBatchUpdates:^{
        [self prepareTableViewForEditing];
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(section == kSimpleFieldsSectionIdx) {
        BOOL showAddCustomFieldRow = self.editing && (self.databaseModel.database.originalFormat == kKeePass || self.databaseModel.database.originalFormat == kKeePass4);
        return kSimpleRowCount + (self.model.customFields.count + (showAddCustomFieldRow ? 1 : 0));
    }
    else if (section == kNotesSectionIdx) {
        return 1;
    }
    else if (section == kAttachmentsSectionIdx) {
        return self.model.attachments.count + (self.editing ? 1 : 0);
    }
    else if (section == kMetadataSectionIdx) {
        return self.model.metadata.count;
    }
    else if (section == kOtherSectionIdx) {
        return self.model.hasHistory ? 1 : 0;
    }
    else {
        return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(!self.editing && self.databaseModel.metadata.detailsViewCollapsedSections[indexPath.section].boolValue) {
        return CGFLOAT_MIN;
    }
    
    BOOL shouldHideEmpty = !self.databaseModel.metadata.showEmptyFieldsInDetailsView && !self.editing;
    
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
        else if ( indexPath.row == kRowSshKey ) {
            if ( self.editing || !self.model.keeAgentSshKey ) {
                return CGFLOAT_MIN;
            }
        }
        else if(indexPath.row == kRowTotp) {
#ifndef IS_APP_EXTENSION
            if((!self.model.totp || self.databaseModel.metadata.hideTotp) && !self.editing) {
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
            NSUInteger idx = indexPath.row - kSimpleRowCount;
            if(idx < self.model.customFields.count) {
                CustomFieldViewModel* f = self.model.customFields[idx];
                if (!f.protected && !f.value.length && shouldHideEmpty) { 
                    return CGFLOAT_MIN;
                }
                
                BOOL shouldHideTotpFields = self.databaseModel.metadata.hideTotpCustomFieldsInViewMode && !self.editing;
                if (shouldHideTotpFields && [NodeFields isTotpCustomFieldKey:f.key]) {
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
    else if(indexPath.section == kAttachmentsSectionIdx && self.databaseModel.database.originalFormat == kPasswordSafe) {
        return CGFLOAT_MIN;
    }
    else if(indexPath.section == kMetadataSectionIdx && (self.editing || self.hideMetadataSection)) {
        return CGFLOAT_MIN;
    }
    else if(indexPath.section == kOtherSectionIdx && (!self.model.hasHistory || self.editing)) {
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
    BOOL shouldHideEmpty = !self.databaseModel.metadata.showEmptyFieldsInDetailsView && !self.editing;
    
    if(section == kSimpleFieldsSectionIdx) {
        return CGFLOAT_MIN;
    }
    else if (section == kNotesSectionIdx && shouldHideEmpty && !self.model.notes.length) {
        return CGFLOAT_MIN;
    }
#ifndef IS_APP_EXTENSION
    else if(section == kAttachmentsSectionIdx) {
        if(self.databaseModel.database.originalFormat == kPasswordSafe || (!self.editing && self.model.attachments.count == 0)) {
            return CGFLOAT_MIN;
        }
    }
    else if(section == kMetadataSectionIdx && (self.editing || self.hideMetadataSection)) {
        return CGFLOAT_MIN;
    }
    else if(section == kOtherSectionIdx && (self.editing || !self.model.hasHistory)) {
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

        if (indexPath.row >= kSimpleRowCount) { 
            return indexPath.row - kSimpleRowCount == self.model.customFields.count ? UITableViewCellEditingStyleInsert : UITableViewCellEditingStyleDelete;
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
    if (indexPath.section == kSimpleFieldsSectionIdx || indexPath.section == kNotesSectionIdx || indexPath.section == kMetadataSectionIdx || indexPath.section == kOtherSectionIdx) {
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
    if ( !self.model.sortCustomFields && indexPath.section == kSimpleFieldsSectionIdx && self.model.customFields.count > 1 ) {
        NSInteger customFieldIdx = indexPath.row - kSimpleRowCount;
        
        if ( customFieldIdx >= 0 && customFieldIdx < self.model.customFields.count ) { 
            return YES;
        }
    }
    
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if ( proposedDestinationIndexPath.section == kSimpleFieldsSectionIdx && self.model.customFields.count > 1 ) {
        NSInteger customFieldIdx = proposedDestinationIndexPath.row - kSimpleRowCount;
        
        if ( customFieldIdx >= 0 && customFieldIdx < self.model.customFields.count ) { 
            return proposedDestinationIndexPath;
        }
    }
    
    return sourceIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if ( sourceIndexPath.section == kSimpleFieldsSectionIdx && destinationIndexPath.section == kSimpleFieldsSectionIdx && self.model.customFields.count > 1 ) {
        NSInteger sourceIdx = sourceIndexPath.row - kSimpleRowCount;
        NSInteger destIdx = destinationIndexPath.row - kSimpleRowCount;
        
        if ( sourceIdx >= 0 && sourceIdx < self.model.customFields.count && destIdx >= 0 && destIdx < self.model.customFields.count && sourceIdx != destIdx ) {
            NSLog(@"Move: [%ld] -> [%ld]", (long)sourceIdx, destIdx);
            [self.model moveCustomFieldAtIndex:sourceIdx to:destIdx];
            [self onModelEdited];
        }
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if(indexPath.section == kAttachmentsSectionIdx && indexPath.row > 0) {
            NSString* filename = self.model.attachments.allKeys[indexPath.row - 1];
            [self.model removeAttachment:filename];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self onModelEdited];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx) {
            if (indexPath.row == kRowTotp) {
                [self onClearTotp];
            }
            else if (indexPath.row == kRowSshKey) {
                self.model.keeAgentSshKey = nil;
                [self onModelEdited];
            }
            else if (indexPath.row >= kSimpleRowCount) {
                NSUInteger idx = indexPath.row - kSimpleRowCount;
                [self.model removeCustomFieldAtIndex:idx];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self onModelEdited];
            }
        }
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        if(indexPath.section == kSimpleFieldsSectionIdx && indexPath.row == self.model.customFields.count + kSimpleRowCount) {
            [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:nil];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx && indexPath.row == kRowTotp) {
            [self onSetTotp];
        }
        else if(indexPath.section == kAttachmentsSectionIdx && indexPath.row == 0) {
            [self promptToAddAttachment];
        }
    }
}

- (void)promptToAddAttachment {
    NSArray* usedFilenames = self.model.attachments.allKeys;
    
    [AddAttachmentHelper.sharedInstance beginAddAttachmentUi:self
                                               usedFilenames:usedFilenames
                                                       onAdd:^(NSString * _Nonnull filename, KeePassAttachmentAbstractionLayer * _Nonnull databaseAttachment) {
        [self onAddAttachment:filename attachment:databaseAttachment];
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
    NSLog(@"Adding new Attachment: [%@]", attachment);
    
    NSUInteger idx = [self.model insertAttachment:filename attachment:attachment];
    
    [self.tableView performBatchUpdates:^{
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx + 1 inSection:kAttachmentsSectionIdx]] 
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    } completion:^(BOOL finished) {
        [self onModelEdited];
    }];
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [StrongboxFilesManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
    });
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.model.attachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    NSString* filename = self.model.attachments.allKeys[index];
    KeePassAttachmentAbstractionLayer* attachment = self.model.attachments[filename];
    
    NSString* f = [StrongboxFilesManager.sharedInstance.tmpAttachmentPreviewPath stringByAppendingPathComponent:filename];
    
    NSInputStream* attStream = [attachment getPlainTextInputStream];
    [StreamUtils pipeFromStream:attStream to:[NSOutputStream outputStreamToFileAtPath:f append:NO]];
    
    NSURL* url = [NSURL fileURLWithPath:f];
    
    return url;
}



- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToCustomFieldEditor"]) {
        UINavigationController *nav = segue.destinationViewController;
        CustomFieldEditorViewController* vc = (CustomFieldEditorViewController*)[nav topViewController];
        
        vc.colorizeValue = self.databaseModel.metadata.colorizePasswords;
        vc.customFieldsKeySet = [NSSet setWithArray:[self.model.customFields map:^id _Nonnull(CustomFieldViewModel * _Nonnull obj, NSUInteger idx) {
            return obj.key;
        }]];
        
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
        vc.colorize = ((NSNumber*)(d[@"colorize"])).boolValue;
    }
    else if ([segue.identifier isEqualToString:@"segueToAuditDrillDown"]) {
        UINavigationController* nav = segue.destinationViewController;
        AuditDrillDownController* vc = (AuditDrillDownController*)nav.topViewController;
        
        vc.model = self.databaseModel;
        vc.itemId = self.itemId;
        vc.hideShowAllAuditIssues = YES;
        vc.onDone = ^(BOOL showAllAuditIssues, UIViewController * _Nonnull viewControllerToDismiss) {
            [viewControllerToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        };
        
        __weak ItemDetailsViewController* weakSelf = self;
        vc.updateDatabase = ^{
            [weakSelf updateAndSync];
        };
    }
}

- (void)onCustomFieldEditedOrAdded:(CustomFieldViewModel * _Nonnull)field fieldToEdit:(CustomFieldViewModel*)fieldToEdit {
    NSLog(@"onCustomFieldEditedOrAdded: [%@] - fieldToEdit = [%@]", field, fieldToEdit);
    
    if ( fieldToEdit ) { 
        NSUInteger oldIdx = [self.model.customFields indexOfObject:fieldToEdit];

        if (oldIdx != NSNotFound) {
            [self.model removeCustomFieldAtIndex:oldIdx];
            [self.model addCustomField:field atIndex:oldIdx];
            
            [self.tableView performBatchUpdates:^{
                NSIndexPath* ip = [NSIndexPath indexPathForRow:oldIdx + kSimpleRowCount inSection:kSimpleFieldsSectionIdx];
                [self.tableView reloadRowsAtIndexPaths:@[ip]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            } completion:^(BOOL finished) {
                [self onModelEdited];
            }];
        }
        else {
            
            
            
            
            
            

            NSLog(@"⚠️ WARNWARN - Could not find custom field to edit!!");
            return;
        }
    }
    else {
        NSUInteger idx = [self.model addCustomField:field];
        [self.tableView performBatchUpdates:^{
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx + kSimpleRowCount
                                                                        inSection:kSimpleFieldsSectionIdx]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
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
#ifndef IS_APP_EXTENSION
    [Alerts fourOptionsWithCancel:self
                            title:NSLocalizedString(@"item_details_setup_totp_how_title", @"How would you like to setup TOTP?")
                          message:NSLocalizedString(@"item_details_setup_totp_how_message", @"You can setup TOTP by using a QR Code, or manually by entering the secret or an OTPAuth URL")
                defaultButtonText:NSLocalizedString(@"scan_qr_code_from_camera", @"Scan QR Code with Camera")
                 secondButtonText:NSLocalizedString(@"key_files_vc_one_time_key_file_source_option_photos", @"Photo Library...")
                  thirdButtonText:NSLocalizedString(@"item_details_setup_totp_manual_rfc", @"Manual (Standard/RFC 6238)...")
                 fourthButtonText:NSLocalizedString(@"item_details_setup_totp_manual_steam", @"Manual (Steam Token)...")
                           action:^(int response) {
        if(response == 0){
#ifndef IS_READ_ONLY_BUILD
            
            QRCodeScannerViewController* vc = [[QRCodeScannerViewController alloc] init];
            vc.modalPresentationStyle = UIModalPresentationFormSheet;
            
            vc.onDone = ^(BOOL response, NSString * _Nonnull string) {
                [self dismissViewControllerAnimated:YES completion:nil];
                if(response) {
                    NSURL* url = string.urlExtendedParse; 
                    [self setTotpWithString:url.absoluteString steam:NO];
                }
            };
            
            [self presentViewController:vc animated:YES completion:nil];
#endif
        }
        else if(response == 1) {
            [self scanPhotoLibraryImageForQRCode];
        }
        else if(response == 2 || response == 3) {
            [Alerts OkCancelWithTextField:self
                     textFieldPlaceHolder:NSLocalizedString(@"item_details_setup_totp_secret_title", @"Secret or OTPAuth URL")
                                    title:NSLocalizedString(@"item_details_setup_totp_secret_message", @"Please enter the secret or an OTPAuth URL")
                                  message:@""
                               completion:^(NSString *text, BOOL success) {
                if(success) {
                    [self setTotpWithString:text steam:(response == 3)];
                }
            }];
        }
    }];
#endif
}

- (void)setTotpWithString:(NSString*)string steam:(BOOL)steam {
    OTPToken* token = [NodeFields getOtpTokenFromString:string
                                             forceSteam:steam
                                                 issuer:self.model.title
                                               username:self.model.username];
    
    if(token) {
        self.model.totp = token;
        
        [self updateTotpRow];
        
        [self onModelEdited];
        
        NSLog(@"✅ Saving as just added a TOTP");
        
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
            NSLog(@"Couldn't find QR Code!");
            
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
            NSLog(@"WARNWARN: Could not get CIImage for QR Code");
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
                   databaseFormat:self.databaseFormat
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
                              completion:^(UIImage * _Nullable favIcon) {
        if( favIcon ) {
            NSData *data = UIImagePNGRepresentation(favIcon);
            item.icon = [NodeIcon withCustom:data];
        }
        
        completion();
    }];
}

- (void)onChangeIcon {
    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.databaseModel.database.iconPool;
    
    NSString* urlHint = self.model.url.length ? self.model.url : self.model.title;
    
    [self.sni changeIcon:self
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
    if(self.editing) {
        return nil; 
    }
    
    CollapsibleTableViewHeader* header = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    
    if(!header) {
        header = [[CollapsibleTableViewHeader alloc] initWithReuseIdentifier:@"header"];
    }
    
    [header setCollapsed:self.databaseModel.metadata.detailsViewCollapsedSections[section].boolValue];
    
    __weak CollapsibleTableViewHeader* weakHeader = header;
    __weak ItemDetailsViewController* weakSelf = self;
    
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
    if(self.editing) {
        if(indexPath.section == kAttachmentsSectionIdx) {
            if(indexPath.row == 0) {
                [self promptToAddAttachment];
            }
            else {
                [self launchAttachmentPreview:indexPath.row - 1];
            }
        }
        else if (indexPath.section == kSimpleFieldsSectionIdx) {
            NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
            
            if(indexPath.row == kRowTotp) {
                if(!self.model.totp) {
                    [self onSetTotp];
                }
            }
            else if(virtualRow == self.model.customFields.count  ) { 
                [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:nil];
            }
            else if (virtualRow >= 0 && virtualRow < self.model.customFields.count) {
                NSInteger idx = virtualRow;
                CustomFieldViewModel* cf = self.model.customFields[idx];
                [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:cf];
            }
        }
    }
    else {
        NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
        
        if(indexPath.section == kAttachmentsSectionIdx) {
            [self launchAttachmentPreview:indexPath.row];
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
            else if (virtualRow >= 0 && virtualRow < self.model.customFields.count) {
                NSInteger idx = virtualRow;
                CustomFieldViewModel* cf = self.model.customFields[idx];
                NSString* value = [self maybeDereference:cf.value];
                [self copyToClipboard:value message:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), cf.key]];
            }
        }
        else if(indexPath.section == kNotesSectionIdx) {
            
        }
        else if(indexPath.section == kMetadataSectionIdx) {
            ItemMetadataEntry* entry = self.model.metadata[indexPath.row];
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
    TagsViewTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTagsViewCellId forIndexPath:indexPath];
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    [cell setModel:!self.editing
              tags:self.model.tags
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
             onAdd:^(NSString * _Nonnull tag) {
        [weakSelf.model addTag:trim(tag)];
        [weakSelf onModelEdited];
    }
          onRemove:^(NSString * _Nonnull tag) {
        [weakSelf.model removeTag:trim(tag)];
        [weakSelf onModelEdited];
    }];
    
    
    
    
    
    
    
    
    
    
    return cell;
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
                   showStrength:YES];
        
        __weak GenericKeyValueTableViewCell* weakCell = cell;
        cell.onRightButton = ^{
            weakSelf.passwordConcealedInUi = !weakSelf.passwordConcealedInUi;
            weakCell.isConcealed = weakSelf.passwordConcealedInUi;
        };
        
        cell.onAuditTap = ^{
            [weakSelf performSegueWithIdentifier:@"segueToAuditDrillDown" sender:nil];
        };
        
        cell.historyMenu = [self getPasswordHistoryMenu];
        
        return cell;
    }
}

- (UITableViewCell*)getTotpCell:(NSIndexPath*)indexPath {
    if(self.editing && !self.model.totp) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = NSLocalizedString(@"item_details_setup_totp", @"Setup TOTP...");
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        TotpCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kTotpCell forIndexPath:indexPath];
        
        [cell setItem:self.model.totp];
        
        return cell;
    }
}

- (UITableViewCell*)getKeeAgentSshKeyCell:(NSIndexPath*)indexPath {
    if ( self.editing ) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = @"Remove SSH Key"; 
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;

        return cell;
    }
    else {
        SshKeyViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kSshKeyViewCellId forIndexPath:indexPath];
        
        OpenSSHPrivateKey* theKey = self.model.keeAgentSshKey.openSshKey;
        
        [cell setContent:self.model.keeAgentSshKey
                password:self.model.password
          viewController:self
               onCopyPub:^{
            [self copyToClipboard:theKey.publicKey message:NSLocalizedString(@"generic_copied", @"Copied")];
        } onCopyFinger:^{
            [self copyToClipboard:theKey.fingerprint message:NSLocalizedString(@"generic_copied", @"Copied")];
        }];

        return cell;
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
        
        [cell setForUrlOrCustomFieldUrl:NSLocalizedString(@"item_details_url_field_title", @"URL")
                                  value:value
                            formatAsUrl:url
                       rightButtonImage:launchUrlImage
                        useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
        
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
           value:self.model.email
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
            NSLog(@"Setting Expiry Date to %@", date ? date.friendlyDateTimeString : @"");
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

- (UITableViewCell*)getNotesCell:(NSIndexPath*)indexPath {
    __weak ItemDetailsViewController* weakSelf = self;
    
    if ( self.editing || self.databaseModel.metadata.easyReadFontForAll || !AppPreferences.sharedInstance.markdownNotes ) {
        NotesTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kNotesCellId forIndexPath:indexPath];
        
        [cell setNotes:[self maybeDereference:self.model.notes]
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
    else {
        MarkdownCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kMarkdownNotesCellId forIndexPath:indexPath];
        
        [cell setNotes:[self maybeDereference:self.model.notes]];
        
        cell.onNotesDoubleTap = ^{
            [weakSelf copyToClipboard:weakSelf.model.notes
                              message:NSLocalizedString(@"item_details_notes_copied", @"Notes Copied")];
        };
        
        return cell;
    }
}

- (UITableViewCell*)getCustomFieldCell:(NSIndexPath*)indexPath {
    NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
    
    __weak ItemDetailsViewController* weakSelf = self;
    
    if(self.editing && virtualRow == self.model.customFields.count) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        
        cell.labelText.text = NSLocalizedString(@"item_details_new_custom_field_button", @"New Custom Field...");
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    else {
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        
        NSInteger idx = virtualRow;
        if (idx < 0 || idx >= self.model.customFields.count) {
            return cell;
        }
        
        CustomFieldViewModel* cf =  self.model.customFields[idx];
        
        if(cf.protected && !self.editing) {
            [cell setConcealableKey:cf.key
                              value:[self maybeDereference:cf.value]
                          concealed:cf.concealedInUI
                           colorize:self.databaseModel.metadata.colorizeProtectedCustomFields
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
                [cell setForUrlOrCustomFieldUrl:cf.key value:value formatAsUrl:url rightButtonImage:launchUrlImage useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
                
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
    if(self.editing && indexPath.row == 0) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = NSLocalizedString(@"item_details_add_attachment_button", @"Add Attachment...");
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        NSInteger idx = indexPath.row - (self.editing ? 1 : 0);
        NSString* filename = self.model.attachments.allKeys[idx];
        KeePassAttachmentAbstractionLayer* attachment = self.model.attachments[filename];
        
        if(self.editing) {
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
        else {
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
    }
}

- (UITableViewCell*)getMetadataCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    ItemMetadataEntry* entry = self.model.metadata[indexPath.row];
    
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
            if ( self.model.totp ) {
                NSURL* url = [self.model.totp url:YES];
                if ( url ) {
                    [self showLargeText:url.absoluteString colorize:NO];
                }
            }
        }
        else if (indexPath.row >= kSimpleRowCount) { 
            NSUInteger idx = indexPath.row - kSimpleRowCount;
            CustomFieldViewModel* field = self.model.customFields[idx];
            [self showLargeText:field.value colorize:field.protected && self.databaseModel.metadata.colorizePasswords];
        }
    }
    else if (indexPath.section == kNotesSectionIdx) {
        [self showLargeText:self.model.notes colorize:NO];
    }
}

- (void)showLargeText:(NSString*)text colorize:(BOOL)colorize {
    if (text) {
        [self performSegueWithIdentifier:@"segueToLargeView" sender:@{ @"text" : text, @"colorize" : @(colorize) }];
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
        NSLog(@"ItemDetailsViewController::applyChangesAndSave => No Changes or Edits to Save - NOP...");
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
            self.model = [self reloadViewModelFromNodeItem];
            self.preEditModelClone = [self.model clone];
            
            [self bindNavBar];
            
            [self.tableView performBatchUpdates:^{
                [self prepareTableViewForEditing];
            } completion:^(BOOL finished) {
                [self bindNavBar];
                
                [self refreshPublishAndSyncAfterModelEdit];
            }];
        }
    }];
}

- (EntryViewModel*)reloadViewModelFromNodeItem {
    DatabaseFormat format = self.databaseModel.database.originalFormat;
    
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
    
    return [EntryViewModel fromNode:item
                             format:format
                              model:self.databaseModel
                   sortCustomFields:!self.databaseModel.metadata.customSortOrderForFields];
}

- (void)performFullReload {
    self.model = [self reloadViewModelFromNodeItem]; 
    [self.tableView reloadData];
    [self bindNavBar];
    [self updateSyncBarButtonItemState];
}

- (void)refreshPublishAndSyncAfterModelEdit {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self performFullReload];
        
        [NSNotificationCenter.defaultCenter postNotificationName:kNotificationNameItemDetailsEditDone object:self.itemId];
        
        [self updateAndSync];
    });
}

#ifdef IS_APP_EXTENSION
- (void)updateAndSync {
    [self disableUi];
    
    AppPreferences.sharedInstance.autoFillWroteCleanly = NO;
    
    [self.databaseModel update:self.navigationController.visibleViewController
                       handler:^(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error) {
        AppPreferences.sharedInstance.autoFillWroteCleanly = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableUi];
            
            if ( !userCancelled && !error ) {
                if (self.onAutoFillNewItemAdded) {
                    self.onAutoFillNewItemAdded(self.model.username, self.model.password);
                }
            }
            else if (error) {
                [Alerts error:self.navigationController.visibleViewController error:error];
            }
        });
    }];
}
#else
- (void)updateAndSync {


    [self.parentSplitViewController updateAndQueueSyncWithCompletion:^(BOOL savedWorkingCopy) {



    }];
}
#endif

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

    BOOL keePassHistoryAvailable = item.fields.keePassHistory.count > 0; 

    if (!self.model.hasHistory || !keePassHistoryAvailable ) {
        return nil;
    }
    
    NSMutableArray<UIMenu*>* mut = NSMutableArray.array;
    
    NSDate* mod = item.fields.modified;
    NSString* currentPassword = item.fields.password;
    __weak ItemDetailsViewController* weakSelf = self;
    
    for ( Node* hist in item.fields.keePassHistory.reverseObjectEnumerator ) {
        if ( [hist.fields.password localizedCompare:currentPassword] == NSOrderedSame ) {
            continue;
        }
        
        NSString* pw = hist.fields.password;
        UIAction *action = [UIAction actionWithTitle:pw
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf copyToClipboard:pw message:NSLocalizedString(@"item_details_password_copied", @"Password Copied")];
        }];
        
        NSString* fmt = NSLocalizedString(@"password_history_this_password_was_used_until_fmt", "Used until %@");
        NSString* header = [NSString stringWithFormat:fmt, mod.friendlyDateTimeString];

        UIMenu* submenu = [UIMenu menuWithTitle:header
                                          image:nil
                                     identifier:nil
                                        options:UIMenuOptionsDisplayInline
                                       children:@[action]];
        
        [mut addObject:submenu];
        
        mod = hist.fields.modified;
        currentPassword = hist.fields.password;
    }
        
    return mut.count ? [UIMenu menuWithTitle:NSLocalizedString(@"password_history_previous_passwords", @"Previous Passwords")
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:mut] : nil;
}

@end
