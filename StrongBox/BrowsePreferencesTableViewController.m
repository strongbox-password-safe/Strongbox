//
//  BrowsePreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 08/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BrowsePreferencesTableViewController.h"
#import "NSArray+Extensions.h"
#import "SelectItemTableViewController.h"
#import "SafesList.h"
#import "Settings.h"
#import "Model.h"

@interface BrowsePreferencesTableViewController () <UIAdaptivePresentationControllerDelegate> // Detect iOS13 swipe down dismiss

@property (weak, nonatomic) IBOutlet UISwitch *switchStartWithSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotpBrowseView;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *showChildCountOnFolder;
@property (weak, nonatomic) IBOutlet UISwitch *showFlagsInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowIcons;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowKeePass1BackupFolder;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *labelBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowBackupFolder;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBin;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAs;
@property (weak, nonatomic) IBOutlet UILabel *labelViewAs;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellSingleTapAction;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDoubleTapAction;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellTripleTapAction;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLongPressAction;
@property (weak, nonatomic) IBOutlet UILabel *labelSingleTapAction;
@property (weak, nonatomic) IBOutlet UILabel *labelDoubleTapAction;
@property (weak, nonatomic) IBOutlet UILabel *labelTripleTapAction;
@property (weak, nonatomic) IBOutlet UILabel *labelLongPressAction;

@property (weak, nonatomic) IBOutlet UISwitch *swtichShowExpiredInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowExpiredInSearch;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowFavourites;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowNearlyExpired;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowSpecialExpired;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellIconSet;
@property (weak, nonatomic) IBOutlet UILabel *labelIconSet;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFavIcon;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPasswordOnDetails;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowEmptyFields;
@property (weak, nonatomic) IBOutlet UISwitch *easyReadFontForAll;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotpCustom;
@property (weak, nonatomic) IBOutlet UISwitch *switchColorizePasswords;
@property (weak, nonatomic) IBOutlet UISwitch *switchColorizeProtectedCustomFields;

@end

@implementation BrowsePreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.presentationController.delegate = self;
    
    [self bindPreferences];
    
    [self bindTableviewToFormat];
}

- (void)bindTableviewToFormat {
    [self cell:self.cellShowBackupFolder setHidden:self.format != kKeePass1];
    [self cell:self.cellShowRecycleBin setHidden:self.format != kKeePass && self.format != kKeePass4];
    [self cell:self.cellShowRecycleBinInSearch setHidden:self.format != kKeePass && self.format != kKeePass4];
    [self cell:self.cellIconSet setHidden:self.format == kPasswordSafe];
    
    if (@available(iOS 13, *)) {
        

        [self cell:self.cellDoubleTapAction setHidden:YES];
        [self cell:self.cellTripleTapAction setHidden:YES];
        [self cell:self.cellLongPressAction setHidden:YES];
    }
    
    [self reloadDataAnimated:NO];
}

- (IBAction)onGenericPreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);
    
    self.databaseMetaData.hideIconInBrowse = !self.switchShowIcons.on;
    self.databaseMetaData.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    self.databaseMetaData.showFlagsInBrowse = self.showFlagsInBrowse.on;
    self.databaseMetaData.immediateSearchOnBrowse = self.switchStartWithSearch.on;
    
    self.databaseMetaData.showKeePass1BackupGroup = self.switchShowKeePass1BackupFolder.on;
    self.databaseMetaData.showRecycleBinInSearchResults = self.switchShowRecycleBinInSearch.on;

    self.databaseMetaData.hideTotpInBrowse = !self.switchShowTotpBrowseView.on;
    self.databaseMetaData.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    
    self.databaseMetaData.showExpiredInBrowse = self.swtichShowExpiredInBrowse.on;
    self.databaseMetaData.showExpiredInSearch = self.switchShowExpiredInSearch.on;
    
    self.databaseMetaData.showQuickViewNearlyExpired = self.switchShowNearlyExpired.on;
    self.databaseMetaData.showQuickViewFavourites = self.switchShowFavourites.on;
    self.databaseMetaData.showQuickViewExpired = self.switchShowSpecialExpired.on;
    
    NSLog(@"Item Details Preferences Changed: [%@]", sender);
    
    self.databaseMetaData.tryDownloadFavIconForNewRecord = self.switchAutoFavIcon.on;
    self.databaseMetaData.showPasswordByDefaultOnEditScreen = self.switchShowPasswordOnDetails.on;
    self.databaseMetaData.hideTotp = !self.switchShowTotp.on;
    self.databaseMetaData.showEmptyFieldsInDetailsView = self.switchShowEmptyFields.on;
    self.databaseMetaData.easyReadFontForAll = self.easyReadFontForAll.on;
    self.databaseMetaData.hideTotpCustomFieldsInViewMode = !self.switchShowTotpCustom.on;
    self.databaseMetaData.colorizePasswords = self.switchColorizePasswords.on;
    self.databaseMetaData.colorizeProtectedCustomFields = self.switchColorizeProtectedCustomFields.on;
    
    [SafesList.sharedInstance update:self.databaseMetaData];
    
    [self bindPreferences];

    [self notifyDatabaseViewPreferencesChanged];
}

- (void)notifyDatabaseViewPreferencesChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDatabaseViewPreferencesChangedNotificationKey object:nil];
}

- (void)bindPreferences {
    self.switchShowIcons.on = !self.databaseMetaData.hideIconInBrowse;
    self.showChildCountOnFolder.on = self.databaseMetaData.showChildCountOnFolderInBrowse;
    self.showFlagsInBrowse.on = self.databaseMetaData.showFlagsInBrowse;
    self.switchStartWithSearch.on = self.databaseMetaData.immediateSearchOnBrowse;
        
    self.switchShowKeePass1BackupFolder.on = self.databaseMetaData.showKeePass1BackupGroup;
    self.switchShowRecycleBinInSearch.on = self.databaseMetaData.showRecycleBinInSearchResults;
    
    BrowseItemSubtitleField current = self.databaseMetaData.browseItemSubtitleField;
    BrowseItemSubtitleField effective = (current == kBrowseItemSubtitleEmail && self.format != kPasswordSafe) ? kBrowseItemSubtitleNoField : current;
    self.labelBrowseItemSubtitle.text = [self getBrowseItemSubtitleFieldName:effective];
    
    self.switchShowTotpBrowseView.on = !self.databaseMetaData.hideTotpInBrowse;
    self.switchShowRecycleBinInBrowse.on = !self.databaseMetaData.doNotShowRecycleBinInBrowse;

    self.labelViewAs.text = [BrowsePreferencesTableViewController getBrowseViewTypeName:self.databaseMetaData.browseViewType];
    
    
    
    self.swtichShowExpiredInBrowse.on = self.databaseMetaData.showExpiredInBrowse;
    self.switchShowExpiredInSearch.on = self.databaseMetaData.showExpiredInSearch;
    
    
    
    self.labelSingleTapAction.text = [self getTapActionString:(self.databaseMetaData.tapAction)];
    self.labelDoubleTapAction.text = [self getTapActionString:(self.databaseMetaData.doubleTapAction)];
    self.labelTripleTapAction.text = [self getTapActionString:(self.databaseMetaData.tripleTapAction)];
    self.labelLongPressAction.text = [self getTapActionString:(self.databaseMetaData.longPressTapAction)];
    
    
    
    self.switchShowNearlyExpired.on = self.databaseMetaData.showQuickViewNearlyExpired;
    self.switchShowFavourites.on = self.databaseMetaData.showQuickViewFavourites;
    self.switchShowSpecialExpired.on = self.databaseMetaData.showQuickViewExpired;
    
    self.labelIconSet.text = [BrowsePreferencesTableViewController getIconSetName:self.databaseMetaData.keePassIconSet];
    
    self.switchAutoFavIcon.on = self.databaseMetaData.tryDownloadFavIconForNewRecord;
    self.switchShowPasswordOnDetails.on = self.databaseMetaData.showPasswordByDefaultOnEditScreen;
    self.switchShowTotp.on = !self.databaseMetaData.hideTotp;
    self.switchShowEmptyFields.on = self.databaseMetaData.showEmptyFieldsInDetailsView;
    self.easyReadFontForAll.on = self.databaseMetaData.easyReadFontForAll;
    self.switchShowTotpCustom.on = !self.databaseMetaData.hideTotpCustomFieldsInViewMode;
    
    self.switchColorizePasswords.on = self.databaseMetaData.colorizePasswords;
    self.switchColorizeProtectedCustomFields.on = self.databaseMetaData.colorizeProtectedCustomFields;
}

- (NSString*)getTapActionString:(BrowseTapAction)action {
    switch (action) {
        case kBrowseTapActionNone:
            return NSLocalizedString(@"browse_prefs_tap_action_none", @"No Action");
            break;
        case kBrowseTapActionOpenDetails:
            return NSLocalizedString(@"browse_prefs_tap_action_view_item", @"View Item");
            break;
        case kBrowseTapActionCopyTitle:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_title", @"Copy Title");
            break;
        case kBrowseTapActionCopyUsername:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username");
            break;
        case kBrowseTapActionCopyPassword:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password");
            break;
        case kBrowseTapActionCopyUrl:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_url", @"Copy URL");
            break;
        case kBrowseTapActionCopyEmail:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_email", @"Copy Email");
            break;
        case kBrowseTapActionCopyNotes:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_notes", @"Copy Notes");
            break;
        case kBrowseTapActionCopyTotp:
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP");
            break;
        case kBrowseTapActionEdit:
            return NSLocalizedString(@"browse_prefs_tap_action_edit", @"Edit Item");
            break;
        default:
            return @"Unknown";
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
    if (cell == self.cellBrowseItemSubtitle) {
        [self onChangeBrowseItemSubtitle];
    }
    else if (cell == self.cellViewAs) {
        [self onChangeViewType];
    }
    else if (cell == self.cellSingleTapAction || cell == self.cellDoubleTapAction || cell == self.cellTripleTapAction || cell == self.cellLongPressAction) {
        [self onChangeTapAction:cell];
    }
    else if (cell == self.cellIconSet) {
        [self onChangeIconSet];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)onChangeIconSet {
    NSArray<NSNumber*>* options = @[@(kKeePassIconSetClassic),
                                    @(kKeePassIconSetSfSymbols),
                                    @(kKeePassIconSetKeePassXC)
    ];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [BrowsePreferencesTableViewController getIconSetName:(KeePassIconSet)obj.integerValue];
    }];
    
    KeePassIconSet current = self.databaseMetaData.keePassIconSet;
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:NSLocalizedString(@"browse_prefs_icon_set", @"Icon Set")
                  options:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
        if (success) {
           self.databaseMetaData.keePassIconSet = (KeePassIconSet)options[selectedIdx].integerValue;
           [SafesList.sharedInstance update:self.databaseMetaData];
        }

        [self bindPreferences];
        [self notifyDatabaseViewPreferencesChanged];
    }];
}

+ (NSString*)getIconSetName:(KeePassIconSet)iconSet {
    switch (iconSet) {
        case kKeePassIconSetKeePassXC:
            return NSLocalizedString(@"keepass_icon_set_keepassxc", @"KeePassXC");
            break;
        case kKeePassIconSetSfSymbols:
            return NSLocalizedString(@"keepass_icon_set_sf_symbols", @"SF Symbols (iOS 13+)");
            break;
        default:
            return NSLocalizedString(@"keepass_icon_set_classic", @"Classic");
            break;
    }
}

- (void)onChangeTapAction:(UITableViewCell*)cell {
    NSArray<NSNumber*>* options = self.format == kPasswordSafe ? @[@(kBrowseTapActionNone),
                                    @(kBrowseTapActionOpenDetails),
                                    @(kBrowseTapActionEdit),
                                    @(kBrowseTapActionCopyTitle),
                                    @(kBrowseTapActionCopyUsername),
                                    @(kBrowseTapActionCopyPassword),
                                    @(kBrowseTapActionCopyUrl),
                                    @(kBrowseTapActionCopyEmail),
                                    @(kBrowseTapActionCopyNotes),
                                    @(kBrowseTapActionCopyTotp)]
                                                    :
                                    @[@(kBrowseTapActionNone),
                                      @(kBrowseTapActionOpenDetails),
                                      @(kBrowseTapActionEdit),
                                      @(kBrowseTapActionCopyTitle),
                                      @(kBrowseTapActionCopyUsername),
                                      @(kBrowseTapActionCopyPassword),
                                      @(kBrowseTapActionCopyUrl),
                                      @(kBrowseTapActionCopyNotes),
                                      @(kBrowseTapActionCopyTotp)];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getTapActionString:(BrowseTapAction)obj.integerValue];
    }];
    
    BrowseTapAction current;
    NSString* title;
    if(cell == self.cellSingleTapAction) {
        current = self.databaseMetaData.tapAction;
        title = NSLocalizedString(@"browse_prefs_single_tap_action", @"Single Tap Action");
    }
    else if(cell == self.cellDoubleTapAction) {
        current = self.databaseMetaData.doubleTapAction;
        title = NSLocalizedString(@"browse_prefs_double_tap_action", @"Double Tap Action");
    }
    else if(cell == self.cellTripleTapAction) {
        current = self.databaseMetaData.tripleTapAction;
        title = NSLocalizedString(@"browse_prefs_triple_tap_action", @"Triple Tap Action");
    }
    else {
        current = self.databaseMetaData.longPressTapAction;
        title = NSLocalizedString(@"browse_prefs_long_press_action", @"Long Press Action");
    }
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:title
                  options:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
                   if (success) {
                       if(cell == self.cellSingleTapAction) {
                           self.databaseMetaData.tapAction = (BrowseTapAction)options[selectedIdx].integerValue;
                       }
                       else if(cell == self.cellDoubleTapAction) {
                           self.databaseMetaData.doubleTapAction = (BrowseTapAction)options[selectedIdx].integerValue;
                       }
                       else if(cell == self.cellTripleTapAction) {
                           self.databaseMetaData.tripleTapAction = (BrowseTapAction)options[selectedIdx].integerValue;
                       }
                       else {
                           self.databaseMetaData.longPressTapAction = (BrowseTapAction)options[selectedIdx].integerValue;
                       }
                       
                       [SafesList.sharedInstance update:self.databaseMetaData];
                   }
                   
                   [self bindPreferences];
                   [self notifyDatabaseViewPreferencesChanged];
               }];
}

- (void)onChangeViewType {
    NSArray<NSNumber*>* options = @[@(kBrowseViewTypeHierarchy),
                                    @(kBrowseViewTypeList),
                                    @(kBrowseViewTypeTotpList)];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [BrowsePreferencesTableViewController getBrowseViewTypeName:(BrowseViewType)obj.integerValue];
    }];
    
    BrowseViewType current = self.databaseMetaData.browseViewType;
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:NSLocalizedString(@"browse_prefs_view_as", @"View As")
                  options:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
                   if (success) {
                       self.databaseMetaData.browseViewType = (BrowseViewType)options[selectedIdx].integerValue;
                       [SafesList.sharedInstance update:self.databaseMetaData];
                   }
                   
                   [self bindPreferences];
                   [self notifyDatabaseViewPreferencesChanged];
               }];
}

+ (NSString*)getBrowseViewTypeName:(BrowseViewType)field {
    switch (field) {
        case kBrowseViewTypeHierarchy:
            return NSLocalizedString(@"browse_prefs_view_as_folders", @"Folder Hierarchy");
            break;
        case kBrowseViewTypeList:
            return NSLocalizedString(@"browse_prefs_view_as_flat_list", @"Flat List");
            break;
        case kBrowseViewTypeTotpList:
            return NSLocalizedString(@"browse_prefs_view_as_totp_list", @"TOTP List");
            break;
        default:
            return @"None";
            break;
    }
}

- (void)onChangeBrowseItemSubtitle {
    NSArray<NSNumber*>* options = self.format != kPasswordSafe ?
        @[@(kBrowseItemSubtitleNoField),
          @(kBrowseItemSubtitleUsername),
          @(kBrowseItemSubtitlePassword),
          @(kBrowseItemSubtitleUrl),
          @(kBrowseItemSubtitleNotes),
          @(kBrowseItemSubtitleCreated),
          @(kBrowseItemSubtitleModified),
          @(kBrowseItemSubtitleTags)] :
    
            @[@(kBrowseItemSubtitleNoField),
              @(kBrowseItemSubtitleUsername),
              @(kBrowseItemSubtitlePassword),
              @(kBrowseItemSubtitleUrl),
              @(kBrowseItemSubtitleEmail),
              @(kBrowseItemSubtitleNotes),
              @(kBrowseItemSubtitleCreated),
              @(kBrowseItemSubtitleModified)];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getBrowseItemSubtitleFieldName:(BrowseItemSubtitleField)obj.integerValue];
    }];
    
    BrowseItemSubtitleField current = self.databaseMetaData.browseItemSubtitleField;
    if(current == kBrowseItemSubtitleEmail && self.format != kPasswordSafe) {
        current = kBrowseItemSubtitleNoField;
    }
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:NSLocalizedString(@"browse_prefs_item_subtitle", @"Item Subtitle")
                  options:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
                   if (success) {
                       self.databaseMetaData.browseItemSubtitleField = (BrowseItemSubtitleField)options[selectedIdx].integerValue;
                   }
                   
                   [self bindPreferences];
                   [self notifyDatabaseViewPreferencesChanged];
               }];
}

- (NSString*)getBrowseItemSubtitleFieldName:(BrowseItemSubtitleField)field {
    switch (field) {
        case kBrowseItemSubtitleNoField:
            return NSLocalizedString(@"browse_prefs_item_subtitle_none", @"None");
            break;
        case kBrowseItemSubtitleUsername:
            return NSLocalizedString(@"browse_prefs_item_subtitle_username", @"Username");
            break;
        case kBrowseItemSubtitlePassword:
            return NSLocalizedString(@"browse_prefs_item_subtitle_password", @"Password");
            break;
        case kBrowseItemSubtitleUrl:
            return NSLocalizedString(@"browse_prefs_item_subtitle_url", @"URL");
            break;
        case kBrowseItemSubtitleEmail:
            return NSLocalizedString(@"browse_prefs_item_subtitle_email", @"Email");
            break;
        case kBrowseItemSubtitleModified:
            return NSLocalizedString(@"browse_prefs_item_subtitle_date_modified", @"Date Modified");
            break;
        case kBrowseItemSubtitleNotes:
            return NSLocalizedString(@"browse_prefs_item_subtitle_notes", @"Notes");
            break;
        case kBrowseItemSubtitleCreated:
            return NSLocalizedString(@"browse_prefs_item_subtitle_date_created", @"Date Created");
            break;
        case kBrowseItemSubtitleTags:
                return NSLocalizedString(@"browse_prefs_item_subtitle_tags", @"Tags");
                break;
        default:
            return @"<Unknown>";
            break;
    }
}

- (void)promptForString:(NSString*)title
                options:(NSArray<NSString*>*)options
           currentIndex:(NSInteger)currentIndex
             completion:(void(^)(BOOL success, NSInteger selectedIdx))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.groupItems = @[options];

    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (self.onDone) {
        self.onDone();
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    
    if (self.onDone) {
        self.onDone();
    }
}

@end
