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
#import "DatabasePreferences.h"
#import "Model.h"
#import "AppPreferences.h"
#import "Strongbox-Swift.h"

@interface BrowsePreferencesTableViewController () <UIAdaptivePresentationControllerDelegate> 

@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *showChildCountOnFolder;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowIcons;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowKeePass1BackupFolder;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *labelBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowBackupFolder;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBin;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBinInSearch;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellSingleTapAction;
@property (weak, nonatomic) IBOutlet UILabel *labelSingleTapAction;

@property (weak, nonatomic) IBOutlet UISwitch *swtichShowExpiredInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowExpiredInSearch;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowFavourites;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowNearlyExpired;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowSpecialExpired;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellIconSet;
@property (weak, nonatomic) IBOutlet UILabel *labelIconSet;

@property (weak, nonatomic) IBOutlet UISwitch *switchStartWithLastViewedEntry;

@property (readonly) DatabaseFormat format;
@property (readonly) DatabasePreferences* databaseMetaData;

@end

@implementation BrowsePreferencesTableViewController

+ (instancetype)fromStoryboard {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"CustomizeView" bundle:nil];
    BrowsePreferencesTableViewController* ret = [sb instantiateInitialViewController];
    return ret;
}

- (DatabaseFormat)format {
    return self.model.originalFormat;
}

- (DatabasePreferences *)databaseMetaData {
    return self.model.metadata;
}

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
            
    [self reloadDataAnimated:NO];
}

- (IBAction)onGenericPreferencesChanged:(id)sender {
    self.databaseMetaData.hideIconInBrowse = !self.switchShowIcons.on;
    self.databaseMetaData.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    
    self.databaseMetaData.showLastViewedEntryOnUnlock = self.switchStartWithLastViewedEntry.on;
    
    self.databaseMetaData.showKeePass1BackupGroup = self.switchShowKeePass1BackupFolder.on;
    self.databaseMetaData.showRecycleBinInSearchResults = self.switchShowRecycleBinInSearch.on;

    self.databaseMetaData.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    
    self.databaseMetaData.showExpiredInBrowse = self.swtichShowExpiredInBrowse.on;
    self.databaseMetaData.showExpiredInSearch = self.switchShowExpiredInSearch.on;
    
    self.databaseMetaData.showQuickViewNearlyExpired = self.switchShowNearlyExpired.on;
    self.databaseMetaData.showQuickViewFavourites = self.switchShowFavourites.on;
    self.databaseMetaData.showQuickViewExpired = self.switchShowSpecialExpired.on;
        
    [self bindPreferences];

    [self notifyDatabaseViewPreferencesChanged];
}

- (void)notifyDatabaseViewPreferencesChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDatabaseViewPreferencesChangedNotificationKey object:nil];
}

- (void)bindPreferences {
    self.switchShowIcons.on = !self.databaseMetaData.hideIconInBrowse;
    self.showChildCountOnFolder.on = self.databaseMetaData.showChildCountOnFolderInBrowse;
    
    self.switchStartWithLastViewedEntry.on = self.databaseMetaData.showLastViewedEntryOnUnlock;
    
    self.switchShowKeePass1BackupFolder.on = self.databaseMetaData.showKeePass1BackupGroup;
    self.switchShowRecycleBinInSearch.on = self.databaseMetaData.showRecycleBinInSearchResults;
    
    BrowseItemSubtitleField effective = self.databaseMetaData.browseItemSubtitleField;
    
    self.labelBrowseItemSubtitle.text = [self getBrowseItemSubtitleFieldName:effective];
    
    self.switchShowRecycleBinInBrowse.on = !self.databaseMetaData.doNotShowRecycleBinInBrowse;
    
    
    
    self.swtichShowExpiredInBrowse.on = self.databaseMetaData.showExpiredInBrowse;
    self.switchShowExpiredInSearch.on = self.databaseMetaData.showExpiredInSearch;
    
    
    
    self.labelSingleTapAction.text = [self getTapActionString:(self.databaseMetaData.tapAction)];
    
    
    
    self.switchShowNearlyExpired.on = self.databaseMetaData.showQuickViewNearlyExpired;
    self.switchShowFavourites.on = self.databaseMetaData.showQuickViewFavourites;
    self.switchShowSpecialExpired.on = self.databaseMetaData.showQuickViewExpired;
    
    self.labelIconSet.text = getIconSetName(self.databaseMetaData.keePassIconSet);
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
            return NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy 2FA");
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
    else if (cell == self.cellSingleTapAction ) {
        [self onChangeSingleTapAction];
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
        return  getIconSetName((KeePassIconSet)obj.integerValue);
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
        }

        [self bindPreferences];
        [self notifyDatabaseViewPreferencesChanged];
    }];
}

- (void)onChangeSingleTapAction {
    NSArray<NSNumber*>* options = @[@(kBrowseTapActionNone),
                                    @(kBrowseTapActionOpenDetails),
                                    @(kBrowseTapActionEdit),
                                    @(kBrowseTapActionCopyTitle),
                                    @(kBrowseTapActionCopyUsername),
                                    @(kBrowseTapActionCopyPassword),
                                    @(kBrowseTapActionCopyUrl),
                                    @(kBrowseTapActionCopyEmail),
                                    @(kBrowseTapActionCopyNotes),
                                    @(kBrowseTapActionCopyTotp)];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getTapActionString:(BrowseTapAction)obj.integerValue];
    }];
    
    BrowseTapAction current = self.databaseMetaData.tapAction;
    NSString* title = NSLocalizedString(@"browse_prefs_single_tap_action", @"Single Tap Action");
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:title
                  options:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
                   if (success) {
                       self.databaseMetaData.tapAction = (BrowseTapAction)options[selectedIdx].integerValue;
                   }
                   
                   [self bindPreferences];
                   [self notifyDatabaseViewPreferencesChanged];
               }];
}

- (void)onChangeBrowseItemSubtitle {
    NSArray<NSNumber*>* options = self.format == kKeePass1 ?
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
