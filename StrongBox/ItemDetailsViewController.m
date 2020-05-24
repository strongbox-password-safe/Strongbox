//
//  ItemDetailsViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ItemDetailsViewController.h"
#import "NotesTableViewCell.h"
#import "GenericKeyValueTableViewCell.h"
#import "ItemDetailsModel.h"
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
#import "Settings.h"
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

#ifndef IS_APP_EXTENSION

#import "ISMessages/ISMessages.h"
#import "SetNodeIconUiHelper.h"
#import "QRCodeScannerViewController.h"

#endif

NSString *const CellHeightsChangedNotification = @"ConfidentialTableCellViewHeightChangedNotification";

//+ (NSArray<NSNumber*>*)defaultCollapsedSections - Remember to change this if you change the below sections
static NSInteger const kSimpleFieldsSectionIdx = 0;
static NSInteger const kNotesSectionIdx = 1;
static NSInteger const kAttachmentsSectionIdx = 2;
static NSInteger const kMetadataSectionIdx = 3;
static NSInteger const kOtherSectionIdx = 4;
static NSInteger const kSectionCount = 5;

static NSInteger const kRowTitleAndIcon = 0;
static NSInteger const kRowUsername = 1;
static NSInteger const kRowPassword = 2;
static NSInteger const kRowURL = 3;
static NSInteger const kRowEmail = 4;
static NSInteger const kRowTags = 5;
static NSInteger const kRowExpires = 6;
static NSInteger const kRowTotp = 7;
static NSInteger const kSimpleRowCount = 8;

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ItemDetailsViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property ItemDetailsModel* model;
@property ItemDetailsModel* preEditModelClone;
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

#endif

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ItemDetailsViewController

+ (NSArray<NSNumber*>*)defaultCollapsedSections {
   return @[@(0), @(0), @(0), @(0), @(1), @(1)];
}

- (void)onCellHeightChangedNotification {
    // MMcG: Sort of a not so great way around this infinite loop/stack overflow bug
    // when dealing with resizing cells... just guarantee this happens only once and stops.
    // Because this is always done on the UI Thread we don't need a more sophisticated mutex
    
    if (!self.inCellHeightsChangedProcess) {
        self.inCellHeightsChangedProcess = YES;
        //    [UIView setAnimationsEnabled:NO];

        [self.tableView beginUpdates];
        [self.tableView endUpdates];

        //    [UIView setAnimationsEnabled:YES];
        self.inCellHeightsChangedProcess = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [UIView setAnimationsEnabled:NO];

    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.navigationBarHidden = NO;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    } 

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCellHeightChangedNotification)
                                                 name:CellHeightsChangedNotification
                                               object:nil];
    
    [self.tableView reloadData];
    
    // Avoid Password Cell Glitch...
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    
    [UIView setAnimationsEnabled:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSNotificationCenter.defaultCenter removeObserver:self name:CellHeightsChangedNotification object:nil];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Needs to be done here to avoid jumpy animation on load...
    
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"item_details_tip", @"Tip: Tap to Copy, Double Tap to Launch URL or Copy Notes");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#ifndef IS_APP_EXTENSION
    self.isAutoFillContext = NO;
#else
    self.isAutoFillContext = YES;
#endif

    NSMutableArray* rightBarButtons = self.navigationItem.rightBarButtonItems ?  self.navigationItem.rightBarButtonItems.mutableCopy : @[].mutableCopy;
    
    [rightBarButtons insertObject:self.editButtonItem atIndex:0];
    
    self.navigationItem.rightBarButtonItems = rightBarButtons;
    self.cancelOrDiscardBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
    
    [self setupTableview];

    self.passwordConcealedInUi = !self.databaseModel.metadata.showPasswordByDefaultOnEditScreen;
    
    if(self.createNewItem) {
        self.item = [self createNewRecord];
    }
    self.model = [self modelFromItem:self.item];
    [self bindNavBar];

    if(self.createNewItem || self.editImmediately) {
        [self setEditing:YES animated:YES];
    }
    
    [self listenToNotifications];
}

- (void)listenToNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseViewPreferencesChanged:)
                                               name:kDatabaseViewPreferencesChangedNotificationKey
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onAuditNodesChanged:)
                                               name:kAuditNodesChangedNotificationKey
                                             object:nil];
}

- (void)onAuditNodesChanged:(id)param {
    [self performFullReload];
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

- (Node*)createNewRecord {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
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
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:username url:url password:password notes:notes email:email];
    
    return [[Node alloc] initAsRecord:title parent:self.parentGroup fields:fields uuid:nil];
}

- (void)onCancel:(id)sender {
    if(self.editing) {
        if([self.model isDifferentFrom:self.preEditModelClone]) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"item_details_vc_discard_changes", @"Discard Changes?")
                  message:NSLocalizedString(@"item_details_vc_are_you_sure_discard_changes", @"Are you sure you want to discard all your changes?")
                   action:^(BOOL response) {
                if(response) {
                    self.model = self.preEditModelClone;
                    
                    if(self.createNewItem) {
                        if(self.splitViewController) {
                            if(self.splitViewController.isCollapsed) { // We can just pop back
                                [self.navigationController.navigationController popViewControllerAnimated:YES];
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
            }];
        }
        else {
            if(self.createNewItem) {
                if(self.splitViewController) {
                    if(self.splitViewController.isCollapsed) { // We can just pop back
                        [self.navigationController.navigationController popViewControllerAnimated:YES];
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
    if(self.isEditing) {
        self.navigationItem.leftItemsSupplementBackButton = NO;
        BOOL isDifferent = [self.model isDifferentFrom:self.preEditModelClone];
        BOOL saveable = [self.model isValid] && (isDifferent || self.createNewItem);
        self.editButtonItem.enabled = saveable;
        self.navigationItem.leftBarButtonItem = self.cancelOrDiscardBarButton;
    }
    else {
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.editButtonItem.enabled = !self.readOnly;
        self.navigationItem.leftBarButtonItem = self.splitViewController ? self.splitViewController.displayModeButtonItem : nil;
        
        [self bindTitle];
    }
}

- (void)bindTitle {
    self.navigationItem.title = [NSString stringWithFormat:@"%@%@", [self maybeDereference:self.model.title],
                                 self.readOnly ? NSLocalizedString(@"item_details_read_only_suffix", @" (Read Only)") : @""];
}

- (void)prepareTableViewForEditing {
    BOOL showAddCustomFieldRow = self.editing && (self.databaseModel.database.format == kKeePass || self.databaseModel.database.format == kKeePass4);
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
    [super setEditing:editing animated:animated];
    
    if (@available(iOS 11.0, *)) { // Silence Warnings
        [self.tableView performBatchUpdates:^{
            [self prepareTableViewForEditing];
        } completion:^(BOOL finished) {
            if(self.isEditing) {
                self.preEditModelClone = [self.model clone];
                UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:kRowTitleAndIcon inSection:kSimpleFieldsSectionIdx]];
                [cell becomeFirstResponder];
            }
            else {
                if(self.createNewItem || [self.model isDifferentFrom:self.preEditModelClone]) {
                    self.urlJustChanged = ![self.model.url isEqualToString:self.preEditModelClone.url];
                    self.preEditModelClone = nil;
                    [self saveChanges];
                    return; // We will perform below changes when saving is done...
                }
                else {
                    NSLog(@"No changes detected... switching back to view mode...");
                }
                self.preEditModelClone = nil;
            }
            
            [self bindNavBar];
        }];
    }
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
        else {
            // Custom Field
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
    cell.textLabel.text = @"<Unknown Cell>";
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == kSimpleFieldsSectionIdx) {
        return nil; // nil to hide
    }
    else if (section == kNotesSectionIdx) {
        return NSLocalizedString(@"item_details_section_header_notes", @"Notes");
    }
    else if (section == kAttachmentsSectionIdx) {
        return NSLocalizedString(@"item_details_section_header_attachments", @"Attachments");
    }
    else if (section == kMetadataSectionIdx) {
        return NSLocalizedString(@"item_details_section_header_metadata", @"Metadata");
    }
    else if (section == kOtherSectionIdx) {
        return NSLocalizedString(@"item_details_section_header_history", @"History");
    }
    else {
        return @"<Unknown Section>";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(section == kSimpleFieldsSectionIdx) {
        BOOL showAddCustomFieldRow = self.editing && (self.databaseModel.database.format == kKeePass || self.databaseModel.database.format == kKeePass4);
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
        return 0;
    }

    BOOL shouldHideEmpty = !self.databaseModel.metadata.showEmptyFieldsInDetailsView && !self.editing;
    
    if(indexPath.section == kSimpleFieldsSectionIdx) {
        if(indexPath.row == kRowUsername && shouldHideEmpty && !self.model.username.length) {
            return 0;
        }
        else if(indexPath.row == kRowPassword && shouldHideEmpty && !self.model.password.length) {
            if (![self.databaseModel isFlaggedByAudit:self.item]) { // Don't hide if there's an audit issue - No Password
                return 0;
            }
        }
        else if(indexPath.row == kRowURL && shouldHideEmpty && !self.model.url.length) {
            return 0;
        }
        else if(indexPath.row == kRowEmail) {
            if(self.databaseModel.database.format != kPasswordSafe || (shouldHideEmpty && !self.model.email.length)) {
                return 0;
            }
        }
        else if(indexPath.row == kRowTotp) {
#ifndef IS_APP_EXTENSION
            if((!self.model.totp || self.databaseModel.metadata.hideTotp) && !self.editing) {
                return 0;
            }
#else
            return 0;
#endif
        }
        else if(indexPath.row == kRowExpires) {
            if(self.model.expires == nil && shouldHideEmpty) {
                return 0;
            }
        }
        else if(indexPath.row == kRowTags) {
            if(self.model.tags.count == 0 && shouldHideEmpty) {
                return 0;
            }
        }
        else if(indexPath.row >= kSimpleRowCount) { // Custom Field
            NSUInteger idx = indexPath.row - kSimpleRowCount;
            if(idx < self.model.customFields.count) {
                CustomFieldViewModel* f = self.model.customFields[idx];
                if (!f.protected && !f.value.length && shouldHideEmpty) { // Hide empty unprotected custom row in view mode
                    return 0;
                }
            
                BOOL shouldHideTotpFields = self.databaseModel.metadata.hideTotpCustomFieldsInViewMode && !self.editing;
                if (shouldHideTotpFields && [NodeFields isTotpCustomFieldKey:f.key]) {
                    return 0;
                }
            }
#ifdef IS_APP_EXTENSION
            else {
                return 0; // Hide in App Extension because segue is not part of the iOS AutoFill Storyboard - TODO: Unify storyboards
            }
#endif
        }
    }
    else if (indexPath.section == kNotesSectionIdx) {
        if(shouldHideEmpty && !self.model.notes.length) {
            return 0;
        }
    }
#ifndef IS_APP_EXTENSION
    else if(indexPath.section == kAttachmentsSectionIdx && self.databaseModel.database.format == kPasswordSafe) {
        return 0;
    }
    else if(indexPath.section == kMetadataSectionIdx && self.editing) {
        return 0;
    }
    else if(indexPath.section == kOtherSectionIdx && (!self.model.hasHistory || self.editing)) {
        return 0;
    }
#else
    if (indexPath.section == kAttachmentsSectionIdx ||
        indexPath.section == kMetadataSectionIdx ||
        indexPath.section == kOtherSectionIdx) {
        return 0;
    }
#endif
    
    return [super tableView:self.tableView heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    BOOL shouldHideEmpty = !self.databaseModel.metadata.showEmptyFieldsInDetailsView && !self.editing;
    
    if(section == kSimpleFieldsSectionIdx) {
        return 0;
    }
    else if (section == kNotesSectionIdx && shouldHideEmpty && !self.model.notes.length) {
        return 0;
    }
#ifndef IS_APP_EXTENSION
    else if(section == kAttachmentsSectionIdx) {
        if(self.databaseModel.database.format == kPasswordSafe || (!self.editing && self.model.attachments.count == 0)) {
            return 0;
        }
    }
    else if(section == kMetadataSectionIdx && self.editing) {
        return 0;
    }
    else if(section == kOtherSectionIdx && (self.editing || !self.model.hasHistory)) {
        return 0;
    }
#else // TODO: Why hide?
    if (section == kAttachmentsSectionIdx ||
        section == kMetadataSectionIdx ||
        section == kOtherSectionIdx) {
        return 0;
    }
#endif

    return 40;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSimpleFieldsSectionIdx) {
        if (indexPath.row == kRowTotp) {
            return (self.model.totp ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleInsert);
        }
        
        if (indexPath.row >= kSimpleRowCount) { // Custom Field
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if(indexPath.section == kAttachmentsSectionIdx && indexPath.row > 0) {
            [self.model removeAttachmentAtIndex:indexPath.row - 1];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self onModelEdited];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx) {
            if (indexPath.row == kRowTotp) {
                [self onClearTotp];
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
            if(indexPath.row == kRowTotp) {
                if(!self.model.totp) {
                    [self onSetTotp];
                }
            }
            
            if( indexPath.row >= kSimpleRowCount) { // Custom Field
                NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
                CustomFieldViewModel* customField = virtualRow == self.model.customFields.count ? nil : self.model.customFields[virtualRow];
                [self performSegueWithIdentifier:@"segueToCustomFieldEditor" sender:customField];
            }
        }
    }
    else {
        if(indexPath.section == kAttachmentsSectionIdx) {
            [self launchAttachmentPreview:indexPath.row];
        }
        else if(indexPath.section == kSimpleFieldsSectionIdx) {
            if (indexPath.row == kRowTitleAndIcon) {
                [self copyToClipboard:[self dereference:self.model.title]
                              message:NSLocalizedString(@"item_details_title_copied", @"Title Copied")];
            }
            else if (indexPath.row == kRowUsername) {
                [self copyToClipboard:[self dereference:self.model.username]
                              message:NSLocalizedString(@"item_details_username_copied", @"Username Copied")];
            }
            else if (indexPath.row == kRowPassword) {
                [self copyToClipboard:[self dereference:self.model.password]
                              message:NSLocalizedString(@"item_details_password_copied", @"Password Copied")];
            }
            else if (indexPath.row == kRowTotp && self.model.totp) {
                [self copyToClipboard:self.model.totp.password
                              message:NSLocalizedString(@"item_details_totp_copied", @"One Time Password Copied")];
            }
            else if (indexPath.row == kRowURL) {
                // Handled by Tap/ Double Tap actions on Cell
            }
            else if (indexPath.row == kRowEmail) {
                [self copyToClipboard:self.model.email
                              message:NSLocalizedString(@"item_details_email_copied", @"Email Copied")];
            }
            else if (indexPath.row >= kSimpleRowCount) { // Custom Fields
                NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
                
                CustomFieldViewModel* customField = self.model.customFields[virtualRow];
                [self copyToClipboard:customField.value
                              message:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), customField.key]];
            }
        }
        else if(indexPath.section == kNotesSectionIdx) {
            // NOP - Handled by the Text Field
        }
        else if(indexPath.section == kOtherSectionIdx && indexPath.row == 0) {
            [self performSegueWithIdentifier:self.databaseModel.database.format == kPasswordSafe ? @"toPasswordHistory" : @"toKeePassHistory" sender:nil];
        }
    }
    
    if(indexPath.section == kMetadataSectionIdx) {
        ItemMetadataEntry* entry = self.model.metadata[indexPath.row];
        if(entry.copyable) {
            [self copyToClipboard:entry.value
                          message:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), entry.key]];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptToAddAttachment {
    NSArray* usedFilenames = [self.model.attachments map:^id _Nonnull(UiAttachment *obj, NSUInteger idx) {
        return obj.filename;
    }];
    
    [AddAttachmentHelper.sharedInstance beginAddAttachmentUi:self
                                               usedFilenames:usedFilenames
                                                       onAdd:^(UiAttachment * _Nonnull attachment) {
                                                           [self onAddAttachment:attachment];
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

- (void)onAddAttachment:(UiAttachment*)attachment {
    NSLog(@"Adding new Attachment: [%@]", attachment);
    
    NSUInteger idx = [self.model insertAttachment:attachment];
    if (@available(iOS 11.0, *)) { // Silence Warnings
        [self.tableView performBatchUpdates:^{
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx + 1 inSection:kAttachmentsSectionIdx]] // +1 because we're in edit mode
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            [self onModelEdited];
        }];
    }
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
        for (NSString *file in tmpDirectory) {
            NSString* path = [NSString pathWithComponents:@[NSTemporaryDirectory(), file]];
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        }
    });
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.model.attachments.count;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    UiAttachment* attachment = [self.model.attachments objectAtIndex:index];
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:attachment.filename];
    [attachment.data writeToFile:f atomically:YES];
    NSURL* url = [NSURL fileURLWithPath:f];
    
    return url;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    else if ([segue.identifier isEqual:@"toPasswordHistory"] && (self.item != nil)) {
        PasswordHistoryViewController *vc = segue.destinationViewController;
        vc.model = self.item.fields.passwordHistory;
        vc.readOnly = self.readOnly;
        vc.saveFunction = ^(PasswordHistory *changed, void (^onDone)(BOOL userCancelled, NSError *error)) {
            [self onPasswordHistoryChanged:changed onDone:onDone];
        };
    }
    else if ([segue.identifier isEqualToString:@"toKeePassHistory"] && (self.item != nil)) {
        KeePassHistoryController *vc = (KeePassHistoryController *)segue.destinationViewController;

        vc.historicalItems = self.item.fields.keePassHistory;
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
        // @{ @"text" : text, @"colorize" : @(colorize) }
        
        NSDictionary* d = sender;
        vc.string = d[@"text"];
        vc.colorize = ((NSNumber*)(d[@"colorize"])).boolValue;
    }
}

- (void)onCustomFieldEditedOrAdded:(CustomFieldViewModel * _Nonnull)field fieldToEdit:(CustomFieldViewModel*)fieldToEdit {
    NSLog(@"Received new Custom Field View Model: [%@]", field);

    NSUInteger oldIdx = -1;
    if (fieldToEdit) { // Remove old existing one...
        oldIdx = [self.model.customFields indexOfObject:fieldToEdit];
        [self.model removeCustomFieldAtIndex:oldIdx];
    }
    
    NSUInteger idx = [self.model insertCustomField:field];
    if (@available(iOS 11.0, *)) { // Silence Warnings
        [self.tableView performBatchUpdates:^{
           if(oldIdx != -1) {
                [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:oldIdx + kSimpleRowCount
                                                                            inSection:kSimpleFieldsSectionIdx]]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
           }
            
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx + kSimpleRowCount
                                                                        inSection:kSimpleFieldsSectionIdx]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        } completion:^(BOOL finished) {
            [self onModelEdited];
        }];
    }
}

- (void)onDeleteHistoryItem:(Node*)historicalNode {
    [self.item touch:YES touchParents:NO];
    [self.item.fields.keePassHistory removeObject:historicalNode];
    
    [self performFullReload];

    // Sync
    
    [self.databaseModel update:self.isAutoFillContext
                       handler:^(BOOL userCancelled, NSError * _Nullable error) {
        if(userCancelled) {
            [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert to previous state gracefully
        }
        else if (error != nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"item_details_problem_saving", @"Problem Saving")
                    error:error completion:^{
                [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert to previous state gracefully
            }];
            NSLog(@"%@", error);
        }
    }];
}

- (void)performFullReload {
    self.model = [self modelFromItem:self.item]; // Reload Model to update metadata Modified field...
    [self.tableView reloadData];
    [self bindNavBar];
}

- (void)onRestoreFromHistoryNode:(Node*)historicalNode {
    Node* clonedOriginalNodeForHistory = [self.item cloneForHistory];
    // FUTURE: This could be a template for graceful revert on error or user cancel
    [self addHistoricalNode:clonedOriginalNodeForHistory];
    
    // Make Changes
    
    [self.item touch:YES touchParents:NO];
    
    [self.item restoreFromHistoricalNode:historicalNode];
    
    [self performFullReload];
    
    // Sync
    
    [self.databaseModel update:self.isAutoFillContext handler:^(BOOL userCancelled, NSError * _Nullable error) {
        if(userCancelled) {
            [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert to previous state gracefully
        }
        else if (error != nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"item_details_problem_saving", @"Problem Saving")
                    error:error
               completion:^{
                [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE - Revert to previous state gracefully
            }];
            NSLog(@"%@", error);
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if(self.onChanged) {
                    self.onChanged();
                }
            });
        }
    }];
}

- (void)onPasswordHistoryChanged:(PasswordHistory*)changed onDone:(void (^)(BOOL userCancelled, NSError *error))onDone {
    self.item.fields.passwordHistory = changed;
    [self.item touch:YES touchParents:NO];
    
    [self performFullReload];
    
    [self.databaseModel update:self.isAutoFillContext
                       handler:^(BOOL userCancelled, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            onDone(userCancelled, error);
            if (!userCancelled && !error && self.onChanged) {
                self.onChanged();
            }
        });
    }];
}

- (UIImage*)getIconImageFromModel {
    if(self.databaseModel.database.format == kPasswordSafe) {
        return nil;
    }
    
    if(self.model.icon.customImage) {
        return self.model.icon.customImage;
    }
    
    return [NodeIconHelper getIconForNode:NO
                           customIconUuid:self.model.icon.customUuid
                                   iconId:self.model.icon.index
                                    model:self.databaseModel];
}

#ifndef IS_APP_EXTENSION
- (void)onChangeIcon {
    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.databaseModel.database.customIcons;
    
    NSString* urlHint = self.model.url.length ? self.model.url : self.model.title;
    
    [self.sni changeIcon:self
                    node:self.item
                 urlOverride:urlHint
                  format:self.databaseModel.database.format
          keePassIconSet:self.databaseModel.metadata.keePassIconSet
                   completion:^(BOOL goNoGo, NSNumber * _Nullable userSelectedNewIconIndex, NSUUID * _Nullable userSelectedExistingCustomIconId, BOOL isRecursiveGroupFavIconResult, NSDictionary<NSUUID *,UIImage *> * _Nullable selected) {
    
                  if(goNoGo) {
                      UIImage* userSelectedNewCustomIcon = selected ? selected.allValues.firstObject : nil;
                      self.model.icon = [SetIconModel setIconModelWith:userSelectedNewIconIndex customUuid:userSelectedExistingCustomIconId customImage:userSelectedNewCustomIcon];
                      self.iconExplicitlyChanged = YES;
                      
                      [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:kRowTitleAndIcon inSection:kSimpleFieldsSectionIdx]] withRowAnimation:UITableViewRowAnimationAutomatic];
                      
                      [self onModelEdited];
                  }
              }];
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    [Alerts threeOptionsWithCancel:self
                             title:NSLocalizedString(@"item_details_setup_totp_how_title", @"How would you like to setup TOTP?")
                           message:NSLocalizedString(@"item_details_setup_totp_how_message", @"You can setup TOTP by using a QR Code, or manually by entering the secret or an OTPAuth URL")
                 defaultButtonText:NSLocalizedString(@"item_details_setup_totp_qr_code", @"QR Code...")
                  secondButtonText:NSLocalizedString(@"item_details_setup_totp_manual_rfc", @"Manual (Standard/RFC 6238)...")
                   thirdButtonText:NSLocalizedString(@"item_details_setup_totp_manual_steam", @"Manual (Steam Token)...")
                            action:^(int response) {
        if(response == 0){
            QRCodeScannerViewController* vc = [[QRCodeScannerViewController alloc] init];
            vc.modalPresentationStyle = UIModalPresentationFormSheet;
            
            vc.onDone = ^(BOOL response, NSString * _Nonnull string) {
                [self dismissViewControllerAnimated:YES completion:nil];
                if(response) {
                    [self setTotpWithString:string steam:NO];
                }
            };
            
            [self presentViewController:vc animated:YES completion:nil];
        }
        else if(response == 1 || response == 2) {
            [Alerts OkCancelWithTextField:self
                     textFieldPlaceHolder:NSLocalizedString(@"item_details_setup_totp_secret_title", @"Secret or OTPAuth URL")
                                    title:NSLocalizedString(@"item_details_setup_totp_secret_message", @"Please enter the secret or an OTPAuth URL")
                                  message:@""
                               completion:^(NSString *text, BOOL success) {
                if(success) {
                    [self setTotpWithString:text steam:(response == 2)];
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
    }
    else {
        [Alerts warn:self
               title:NSLocalizedString(@"item_details_setup_totp_failed_title", @"Failed to Set TOTP")
             message:NSLocalizedString(@"item_details_setup_totp_failed_message", @"Could not set TOTP because it could not be initialized.")];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    if (!urlString.length) {
        return;
    }
    
    NSString* pw = [self dereference:self.model.password];
    [self copyToClipboard:pw
                  message:NSLocalizedString(@"item_details_password_copied_and_launching", @"Password Copied. Launching URL...")];
    
#ifndef IS_APP_EXTENSION
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
//    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
//
//    NSLog(@"%@-%@-%@", components.host, components.path, components.query);
//
//    NSURL* url = components.URL;
//    NSLog(@"Launching URL: %@", url);
    
//    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLHostAllowedCharacterSet];
//    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];

    NSURL* url = [NSURL URLWithString:urlString];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
            NSLog(@"Success = [%d]", success);
        }];
    });
#endif
}

- (NSString*)maybeDereference:(NSString*)text {
    return !self.editing && self.databaseModel.metadata.viewDereferencedFields ? [self.databaseModel.database dereference:text node:self.item] : text;
}

- (NSString*)dereference:(NSString*)text {
    return [self.databaseModel.database dereference:text node:self.item];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Node -> Model -> Node -> Save -> Model

- (NSArray<ItemMetadataEntry*>*)getMetadataFromItem:(Node*)item format:(DatabaseFormat)format {
    NSMutableArray<ItemMetadataEntry*>* metadata = [NSMutableArray array];

    [metadata addObject:[ItemMetadataEntry entryWithKey:@"ID" value:keePassStringIdFromUuid(item.uuid) copyable:YES]];

    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_created_field_title", @"Created")
                                                  value:friendlyDateString(item.fields.created)
                                               copyable:NO]];
    
//    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_accessed_field_title", @"Accessed")
//                                                  value:friendlyDateString(item.fields.accessed)
//                                               copyable:NO]];

    [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_modified_field_title", @"Modified")
                                                  value:friendlyDateString(item.fields.modified)
                                               copyable:NO]];
        
//    if (format == kKeePass4 || format == kKeePass) {
//        [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_location_changed_field_title", @"Location Changed")
//                                                      value:friendlyDateString(item.fields.locationChanged)
//                                                   copyable:NO]];
//
//        if (item.fields.usageCount) {
//            [metadata addObject:[ItemMetadataEntry entryWithKey:NSLocalizedString(@"item_details_metadata_usage_count_field_title", @"Usage Count")
//                                                          value:item.fields.usageCount.stringValue
//                                                       copyable:NO]];
//        }
//    }
    
    return metadata;
}

- (ItemDetailsModel*)modelFromItem:(Node*)item {
    DatabaseFormat format = self.databaseModel.database.format;
    
    // Metadata
    
    NSArray<ItemMetadataEntry*>* metadata = [self getMetadataFromItem:item format:format];
    
    // Has History?
    
    BOOL keePassHistoryAvailable = item.fields.keePassHistory.count > 0 && (format == kKeePass || format == kKeePass4);
    BOOL historyAvailable = format == kPasswordSafe || keePassHistoryAvailable;
    
    // Icon
    
    SetIconModel* iconModel = [SetIconModel setIconModelWith:item.iconId customUuid:item.customIconUuid customImage:nil];
    
    // Custom Fields
    
    NSArray<CustomFieldViewModel*>* customFieldModels = [item.fields.customFields map:^id(NSString *key, StringValue* value) {
        return [CustomFieldViewModel customFieldWithKey:key value:value.value protected:value.protected];
    }];
    
    // Attachments
    
    NSArray<DatabaseAttachment*>* dbAttachments = self.databaseModel.database.attachments;
    NSArray<UiAttachment*>* attachments = [item.fields.attachments map:^id _Nonnull(NodeFileAttachment * _Nonnull obj, NSUInteger idx) {
        DatabaseAttachment *dbAttachment = dbAttachments[obj.index];
        return [UiAttachment attachmentWithFilename:obj.filename data:dbAttachment.data];
    }];
    
    ItemDetailsModel *ret = [[ItemDetailsModel alloc] initWithTitle:item.title
                                                           username:item.fields.username
                                                           password:item.fields.password
                                                                url:item.fields.url
                                                              notes:item.fields.notes
                                                              email:item.fields.email
                                                            expires:item.fields.expires
                                                               tags:item.fields.tags
                                                               totp:item.fields.otpToken
                                                               icon:iconModel
                                                       customFields:customFieldModels
                                                        attachments:attachments
                                                           metadata:metadata
                                                         hasHistory:historyAvailable];
    
    return ret;
}

- (void)applyModelChangesToNodeItem {
    if (self.createNewItem) {
        [self.parentGroup addChild:self.item keePassGroupTitleRules:NO];
    }
    else { // Add History Entry for this change if appropriate...
        Node* originalNodeForHistory = [self.item cloneForHistory];
        [self addHistoricalNode:originalNodeForHistory];
    }

    [self.item touch:YES touchParents:NO];

    [self.item setTitle:self.model.title keePassGroupTitleRules:NO];

    self.item.fields.username = self.model.username;
    self.item.fields.password = self.model.password;
    self.item.fields.url = self.model.url;
    self.item.fields.email = self.model.email;
    self.item.fields.notes = self.model.notes;
    self.item.fields.expires = self.model.expires;

    // Custom Fields - Must be done before TOTP as otherwise it will be removed!

    [self.item.fields removeAllCustomFields];
    for (CustomFieldViewModel *field in self.model.customFields) {
        StringValue *value = [StringValue valueWithString:field.value protected:field.protected];
        [self.item.fields setCustomField:field.key value:value];
    }

    // TOTP

    if([OTPToken areDifferent:self.item.fields.otpToken b:self.model.totp]) {
        [self.item.fields clearTotp]; // Clears any custom fields and notes fields (Password Safe)

        if(self.model.totp != nil) {
            [self.item.fields setTotp:self.model.totp
                     appendUrlToNotes:self.databaseModel.database.format == kPasswordSafe || self.databaseModel.database.format == kKeePass1];
        }
    }

    // Attachments

    [self.databaseModel.database setNodeAttachments:self.item attachments:self.model.attachments];

    // Tags
    
    [self.item.fields.tags removeAllObjects];
    [self.item.fields.tags addObjectsFromArray:self.model.tags];
}

- (void)saveChanges {
    Node* preSaveCloneOfItem = [self.item clone];
    
    [self applyModelChangesToNodeItem];
    
    [self disableUi];
    
    NSLog(@"SAVE: Processing Icon for Save...");
    [self processIconBeforeSave:^{ // This is behind a completion because we might go out and download the FavIcon which is async...
        NSLog(@"SAVE: Icon processed for Save...");
        [self.databaseModel update:self.isAutoFillContext
                           handler:^(BOOL userCancelled, NSError * _Nullable error) {
            NSLog(@"SAVE: Storage Provider Update Done [%d-%@]...", userCancelled, error);
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self onSaveChangesDone:userCancelled preSaveCloneOfItem:preSaveCloneOfItem error:error];
            });
        }];
    }];
}

- (void)disableUi {
    self.editButtonItem.enabled = NO; // Disable Editing/Done button while we save...
    self.cancelOrDiscardBarButton.enabled = NO;
    [self.tableView setUserInteractionEnabled:NO];
    
    CGRect screenRect = self.tableView.bounds; // [[UIScreen mainScreen] bounds];
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

//- (void)resetNodeItemTo:(Node*)preSaveCloneOfItem { // TODO: Make use of UNDO in Model when available?
//    if (self.createNewItem) {
//        [self.parentGroup removeChild:self.item];
//    }
//    else {
//        self.item.fields.keePassHistory = preSaveCloneOfItem.fields.keePassHistory;
//    }
//
//    [self.item touchWithExplicitModifiedDate:preSaveCloneOfItem.fields.modified touchParents:YES];
//     
//    [self.item setTitle:preSaveCloneOfItem.title keePassGroupTitleRules:NO];
//
//    self.item.fields.username = preSaveCloneOfItem.fields.username;
//    self.item.fields.password = preSaveCloneOfItem.fields.password;
//    self.item.fields.url = preSaveCloneOfItem.fields.url;
//    self.item.fields.email = preSaveCloneOfItem.fields.email;
//    self.item.fields.notes = preSaveCloneOfItem.fields.notes;
//    self.item.fields.expires = preSaveCloneOfItem.fields.expires;
//
//    // FUTURE: There's a problem here with rationalization :( - This needs more work... perhaps use the ViewModel class
//    // from the Mac version?
//    
//    self.item.fields.customFields = preSaveCloneOfItem.fields.customFields;
//    self.item.fields.attachments = preSaveCloneOfItem.fields.attachments;
//}

- (void)onSaveChangesDone:(BOOL)userCancelled preSaveCloneOfItem:(Node*)preSaveCloneOfItem error:(NSError*)error {
    if(userCancelled) {
        if (error != nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"item_details_problem_saving", @"Problem Saving")
                    error:error
               completion:^{
                [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE: Revert gracefully
            }];
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil]; // FUTURE: Revert gracefully
        }
        return;

        // [self resetNodeItemTo:preSaveCloneOfItem];
        // FUTURE: Any way to just leave it in editing mode with all the model changes?
        // self.model = [self modelFromItem:self.item];
    }
    else {
        self.createNewItem = NO;
        self.model = [self modelFromItem:self.item];
    }
    
    [self enableUi];
    
    if (@available(iOS 11.0, *)) { // Silence Warnings
        [self.tableView performBatchUpdates:^{
            [self prepareTableViewForEditing];
        } completion:^(BOOL finished) {
            [self bindNavBar];
            
            if(self.onChanged) {
                self.onChanged();
            }
            
#ifdef IS_APP_EXTENSION
            [self.autoFillRootViewController exitWithCredential:self.item.fields.username
                                                       password:self.item.fields.password];
#endif
        }];
    }
}

- (void)processIconBeforeSave:(void (^)(void))completion {
    // Custom Icon
    // NB: addition must be done after node has been added to parent, because otherwise the custom icon rationalizer
    // will pick up the new custom icon as a bad reference (not on a node within the root group)...

    if(self.iconExplicitlyChanged) {
        self.iconExplicitlyChanged = NO;
        if(self.model.icon.customImage) {
            NSData *data = UIImagePNGRepresentation(self.model.icon.customImage);
            [self.databaseModel.database setNodeCustomIcon:self.item data:data rationalize:YES];
        }
        else if(self.model.icon.customUuid != nil) {
            if(![self.model.icon.customUuid isEqual:self.item.customIconUuid]) {
                self.item.customIconUuid = self.model.icon.customUuid;
            }
        }
        else if(self.model.icon.index != nil) {
            if(self.model.icon.index.intValue == -1) {
                self.item.iconId = @(0); // Default
            }
            else {
                self.item.iconId = self.model.icon.index;
            }
            self.item.customIconUuid = nil;
        }
    }
    else {
        if(self.createNewItem || self.urlJustChanged) {
            self.urlJustChanged = NO;
#ifndef IS_APP_EXTENSION
            // No Custom Icon has been set for this entry, and it's a brand new entry or URL has just changed, does the user want us to try grab a FavIcon?
            BOOL favIconFetchPossible = (Settings.sharedInstance.isProOrFreeTrial && (self.databaseModel.database.format == kKeePass || self.databaseModel.database.format == kKeePass4) && isValidUrl(self.model.url));

            if (favIconFetchPossible) {
                if (!self.databaseModel.metadata.promptedForAutoFetchFavIcon) {
                    [Alerts yesNo:self
                            title:NSLocalizedString(@"item_details_prompt_auto_fetch_favicon_title", @"Auto Fetch FavIcon?")
                          message:NSLocalizedString(@"item_details_prompt_auto_fetch_favicon_message", @"Strongbox can automatically fetch FavIcons when an new entry is created or updated.\n\nWould you like to Strongbox to do this?")
                           action:^(BOOL response) {
                        self.databaseModel.metadata.promptedForAutoFetchFavIcon = YES;
                        self.databaseModel.metadata.tryDownloadFavIconForNewRecord = response;
                        [SafesList.sharedInstance update:self.databaseModel.metadata];

                        if (self.databaseModel.metadata.tryDownloadFavIconForNewRecord ) {
                            [self fetchFavIcon:completion];
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
                        [self fetchFavIcon:completion];
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

- (void)fetchFavIcon:(void (^)(void))completion {
    self.sni = [[SetNodeIconUiHelper alloc] init];
    self.sni.customIcons = self.databaseModel.database.customIcons;

    [self.sni expressDownloadBestFavIcon:self.model.url
                              completion:^(UIImage * _Nullable userSelectedNewCustomIcon) {
                          if(userSelectedNewCustomIcon) {
                              NSData *data = UIImagePNGRepresentation(userSelectedNewCustomIcon);
                              [self.databaseModel.database setNodeCustomIcon:self.item data:data rationalize:YES];
                          }

                          completion();
                      }];
}

#endif

- (void)addHistoricalNode:(Node*)originalNodeForHistory {
    BOOL shouldAddHistory = YES; // FUTURE: Config on/off? only valid for KeePass 2+ also...
    if(shouldAddHistory && originalNodeForHistory != nil) {
        [self.item.fields.keePassHistory addObject:originalNodeForHistory];
    }
}

#ifndef IS_APP_EXTENSION
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if(self.editing) {
        return nil; // [self.tableView viewFo
    }
    
    CollapsibleTableViewHeader* header = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"header"];
    
    if(!header) {
        header = [[CollapsibleTableViewHeader alloc] initWithReuseIdentifier:@"header"];
    }
    
    [header setCollapsed:self.databaseModel.metadata.detailsViewCollapsedSections[section].boolValue];
    
    __weak CollapsibleTableViewHeader* weakHeader = header;
    header.onToggleSection = ^() {
        BOOL toggled = !self.databaseModel.metadata.detailsViewCollapsedSections[section].boolValue;
        
        NSMutableArray* mutable = [self.databaseModel.metadata.detailsViewCollapsedSections mutableCopy];
        mutable[section] = @(toggled);
        self.databaseModel.metadata.detailsViewCollapsedSections = mutable;
        
        [SafesList.sharedInstance update:self.databaseModel.metadata];
        
        [weakHeader setCollapsed:toggled];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
    };

    return header;
}
#endif

- (UITableViewCell*)getUsernameCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];

    [cell setKey:NSLocalizedString(@"item_details_username_field_title", @"Username")
           value:[self maybeDereference:self.model.username]
         editing:self.editing
suggestionProvider:^NSString * _Nullable(NSString * _Nonnull text) {
            NSArray* matches = [[[self.databaseModel.database.usernameSet allObjects] filter:^BOOL(NSString * obj) {
                return [obj hasPrefix:text];
            }] sortedArrayUsingComparator:finderStringComparator];
              return matches.firstObject;
        }
 useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
showGenerateButton:YES];

    cell.onEdited = ^(NSString * _Nonnull text) {
      self.model.username = trim(text);
      [self onModelEdited];
    };
    
    __weak GenericKeyValueTableViewCell* weakCell = cell;
    
    cell.onGenerate = ^{
        [PasswordMaker.sharedInstance promptWithUsernameSuggestions:self action:^(NSString * _Nonnull response) {
            [weakCell pokeValue:response];
        }];
    };
    
    return cell;
}

- (UITableViewCell*)getTagsCell:(NSIndexPath*)indexPath {
    TagsViewTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kTagsViewCellId forIndexPath:indexPath];

    [cell setModel:!self.editing
              tags:self.model.tags
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
             onAdd:^(NSString * _Nonnull tag) {
                [self.model addTag:trim(tag)];
                [self onModelEdited];
            }
          onRemove:^(NSString * _Nonnull tag) {
                [self.model removeTag:trim(tag)];
                [self onModelEdited];
            }];

    // FUTURE:
//suggestionProvider:^NSString * _Nullable(NSString * _Nonnull text) {
//            NSArray<NSString*>* matches = [[[self.databaseModel.database.tagSet allObjects] filter:^BOOL(NSString * obj) {
//                return [obj hasPrefix:text];
//            }] sortedArrayUsingComparator:finderStringComparator];
//
//            return matches.firstObject;
//        }

    return cell;
}

- (UITableViewCell*)getPasswordCell:(NSIndexPath*)indexPath { 
    if(self.editing) {
        EditPasswordTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditPasswordCellId forIndexPath:indexPath];
        
        cell.colorize = self.databaseModel.metadata.colorizePasswords;
        cell.parentVc = self;
        cell.password = self.model.password;
        cell.onPasswordEdited = ^(NSString * _Nonnull password) {
            self.model.password = trim(password);
            [self onModelEdited];
        };
        
#ifndef IS_APP_EXTENSION // TODO: Make this available - (What is this -> Allow this after unifying storyboard?)
        cell.onPasswordSettings = ^(void) {
            [self performSegueWithIdentifier:@"segueToPasswordGenerationSettings" sender:nil];
        };
        cell.showGenerationSettings = YES;
#else
        cell.showGenerationSettings = NO;
#endif
        return cell;
    }
    else {
        GenericKeyValueTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        NSString* audit = [self.databaseModel getQuickAuditSummaryForNode:self.item];
        
        [cell setConfidentialKey:NSLocalizedString(@"item_details_password_field_title", @"Password")
                           value:[self maybeDereference:self.model.password]
                       concealed:self.passwordConcealedInUi
                        colorize:self.databaseModel.metadata.colorizePasswords
                           audit:audit];
        
        __weak GenericKeyValueTableViewCell* weakCell = cell;
        cell.onRightButton = ^{
            self.passwordConcealedInUi = !self.passwordConcealedInUi;
            weakCell.isConcealed = self.passwordConcealedInUi;
        };
        
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

- (UITableViewCell*)getUrlCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
    [cell setKey:NSLocalizedString(@"item_details_url_field_title", @"URL")
         value:[self maybeDereference:self.model.url]
       editing:self.editing
    formatAsUrl:isValidUrl(self.model.url) && !self.editing
    suggestionProvider:^NSString*(NSString *text) {
      NSArray* matches = [[[self.databaseModel.database.urlSet allObjects] filter:^BOOL(NSString * obj) {
            return [obj hasPrefix:text];
      }] sortedArrayUsingComparator:finderStringComparator];
      return matches.firstObject;
    }
    useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];

    cell.onEdited = ^(NSString * _Nonnull text) {
      self.model.url = trim(text);
      [self onModelEdited];
    };

    cell.onDoubleTap = ^{
      if (isValidUrl(self.model.url)) {
          [self copyAndLaunchUrl];
      }
      else {
          [self copyToClipboard:[self dereference:self.model.url]
                        message:NSLocalizedString(@"item_details_url_copied", @"URL Copied")];
      }
    };
    cell.onTap = ^{
      [self copyToClipboard:[self dereference:self.model.url]
                    message:NSLocalizedString(@"item_details_url_copied", @"URL Copied")];
    };

    return cell;
}

- (UITableViewCell*)getEmailCell:(NSIndexPath*)indexPath {
    GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
    [cell setKey:NSLocalizedString(@"item_details_email_field_title", @"Email")
           value:self.model.email
         editing:self.editing
    suggestionProvider:^NSString*(NSString *text) {
      NSArray* matches = [[[self.databaseModel.database.emailSet allObjects] filter:^BOOL(NSString * obj) {
            return [obj hasPrefix:text];
      }] sortedArrayUsingComparator:finderStringComparator];
      return matches.firstObject;
    }
 useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll
     showGenerateButton:NO];

    cell.onEdited = ^(NSString * _Nonnull text) {
      self.model.email = trim(text);
      [self onModelEdited];
    };

    return cell;
}

- (UITableViewCell*)getExpiresCell:(NSIndexPath*)indexPath {
    if(self.isEditing) {
        EditDateCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditDateCell forIndexPath:indexPath];
        cell.keyLabel.text = NSLocalizedString(@"item_details_expires_field_title", @"Expires");
        [cell setDate:self.model.expires];
        
        cell.onDateChanged = ^(NSDate * _Nullable date) {
            NSLog(@"Setting Expiry Date to %@", friendlyDateString(date));
            self.model.expires = date;
            [self onModelEdited];
        };
        return cell;
    }
    else {
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        NSDate* expires = self.model.expires;
        NSString *str = expires ? friendlyDateString(expires) : NSLocalizedString(@"item_details_expiry_never", @"Never");
        
        [cell setKey:NSLocalizedString(@"item_details_expires_field_title", @"Expires")
               value:str
             editing:NO
     useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        return cell;
    }
}

- (UITableViewCell*)getNotesCell:(NSIndexPath*)indexPath {
    NotesTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kNotesCellId forIndexPath:indexPath];

    [cell setNotes:[self maybeDereference:self.model.notes]
          editable:self.editing
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
    
    cell.onNotesEdited = ^(NSString * _Nonnull notes) {
        self.model.notes = notes;
        [self onModelEdited];
    };
    
    cell.onNotesDoubleTap = ^{
        [self copyToClipboard:self.model.notes
                      message:NSLocalizedString(@"item_details_notes_copied", @"Notes Copied")];
    };

    return cell;
}

- (UITableViewCell*)getCustomFieldCell:(NSIndexPath*)indexPath {
    NSUInteger virtualRow = indexPath.row - kSimpleRowCount;
    
    if(self.editing && virtualRow == self.model.customFields.count) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        
        cell.labelText.text = NSLocalizedString(@"item_details_new_custom_field_button", @"New Custom Field...");
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    else {
        GenericKeyValueTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericKeyValueCellId forIndexPath:indexPath];
        
        NSInteger idx = virtualRow;
        CustomFieldViewModel* cf = self.model.customFields[idx];

        if(cf.protected && !self.editing) {
            [cell setConfidentialKey:cf.key
                               value:[self maybeDereference:cf.value]
                           concealed:cf.concealedInUI
                            colorize:self.databaseModel.metadata.colorizeProtectedCustomFields
                               audit:nil];

            __weak GenericKeyValueTableViewCell* weakCell = cell;
            cell.onRightButton = ^{
                cf.concealedInUI = !cf.concealedInUI;
                weakCell.isConcealed = cf.concealedInUI;
            };
        }
        else {
            NSString* value = [self maybeDereference:cf.value];
            [cell setKey:cf.key value:value editing:NO useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        return cell;
    }
}

- (UITableViewCell*)getAttachmentCell:(NSIndexPath*)indexPath {
    if(self.editing && indexPath.row == 0) {
        GenericBasicCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kGenericBasicCellId forIndexPath:indexPath];
        cell.labelText.text = NSLocalizedString(@"item_details_add_attachment_button", @"Add Attachment...");
    //            cell.labelText.textColor = UIColor.blueColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.editingAccessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else {
        NSInteger idx = indexPath.row - (self.editing ? 1 : 0);
        UiAttachment* attachment = self.model.attachments[idx];
        
        if(self.editing) {
            EditAttachmentCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kEditAttachmentCellId forIndexPath:indexPath];
            cell.textField.text = attachment.filename;
            
            UIImage* img = [UIImage imageWithData:attachment.data];
            if(img) {
                @autoreleasepool { // Prevent App Extension Crash
                    UIGraphicsBeginImageContextWithOptions(cell.image.bounds.size, NO, 0.0);
                    
                    CGRect imageRect = cell.image.bounds;
                    [img drawInRect:imageRect];
                    cell.image.image = UIGraphicsGetImageFromCurrentImageContext();
                    
                    UIGraphicsEndImageContext();
                }
            }
            else {
                cell.image.image = [UIImage imageNamed:@"document"];
            }
            
            return cell;
        }
        else {
            UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kViewAttachmentCellId forIndexPath:indexPath];
            cell.textLabel.text = attachment.filename;
            NSUInteger filesize = attachment.data ? attachment.data.length : 0;
            cell.detailTextLabel.text = friendlyFileSizeString(filesize);
            
            UIImage* img = [UIImage imageWithData:attachment.data];

            if(img) { // Trick to keep all images to a fixed size
                @autoreleasepool { // Prevent App Extension Crash
                    UIGraphicsBeginImageContextWithOptions(CGSizeMake(48, 48), NO, 0.0);

                    CGRect imageRect = CGRectMake(0, 0, 48, 48);
                    [img drawInRect:imageRect];
                    cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();

                    UIGraphicsEndImageContext();
                }
            }
            else {
                cell.imageView.image = [UIImage imageNamed:@"document"];
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
    
    cell.labelText.text = self.databaseModel.database.format == kPasswordSafe ?
    
    NSLocalizedString(@"item_details_password_history", @"Password History") :
    NSLocalizedString(@"item_details_item_history", @"Item History");
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}
    
- (UITableViewCell*)getIconAndTitleCell:(NSIndexPath*)indexPath {
    IconTableCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kIconTableCell forIndexPath:indexPath];

    [cell setModel:[self maybeDereference:self.model.title]
              icon:[self getIconImageFromModel]
           editing:self.editing
   selectAllOnEdit:self.createNewItem
   useEasyReadFont:self.databaseModel.metadata.easyReadFontForAll];

#ifndef IS_APP_EXTENSION
        if(self.isEditing) {
            cell.onIconTapped = ^{
                [self onChangeIcon];
            };
        }
        else {
#endif
            cell.onIconTapped = nil;
#ifndef IS_APP_EXTENSION
        }
#endif

    cell.onTitleEdited = ^(NSString * _Nonnull text) {
        self.model.title = trim(text);
        [self onModelEdited];
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
    
    NSLog(@"Long Press at %@", indexPath);

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
        else if (indexPath.row >= kSimpleRowCount) { // Custom Field
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

@end
