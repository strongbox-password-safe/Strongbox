//
//  BrowsePreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 08/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BrowsePreferencesTableViewController.h"
#import "NSArray+Extensions.h"
#import "SelectItemTableViewController.h"
#import "SafesList.h"

@interface BrowsePreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchStartWithSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotpBrowseView;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInBrowse;
@property (weak, nonatomic) IBOutlet UISwitch *showChildCountOnFolder;
@property (weak, nonatomic) IBOutlet UISwitch *showFlagsInBrowse;

@property (weak, nonatomic) IBOutlet UISwitch *switchSearchDereferenced;
@property (weak, nonatomic) IBOutlet UISwitch *switchViewDereferenced;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowKeePass1BackupFolder;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *labelBrowseItemSubtitle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowBackupFolder;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBin;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowRecycleBinInSearch;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDereference;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDerefenceDuringSearch;
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

@end

@implementation BrowsePreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindPreferences];
    
    [self bindTableviewToFormat];
}

- (void)bindTableviewToFormat {
    [self cell:self.cellShowBackupFolder setHidden:self.format != kKeePass1];
    [self cell:self.cellShowRecycleBin setHidden:self.format != kKeePass && self.format != kKeePass4];
    [self cell:self.cellShowRecycleBinInSearch setHidden:self.format != kKeePass && self.format != kKeePass4];
    [self cell:self.cellDereference setHidden:self.format != kKeePass && self.format != kKeePass4];
    [self cell:self.cellDerefenceDuringSearch setHidden:self.format != kKeePass && self.format != kKeePass4];
    
    [self reloadDataAnimated:NO];
}

- (IBAction)onGenericPreferencesChanged:(id)sender {
    NSLog(@"Generic Preference Changed: [%@]", sender);
    
    self.databaseMetaData.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    self.databaseMetaData.showFlagsInBrowse = self.showFlagsInBrowse.on;
    self.databaseMetaData.immediateSearchOnBrowse = self.switchStartWithSearch.on;
    
    self.databaseMetaData.viewDereferencedFields = self.switchViewDereferenced.on;
    self.databaseMetaData.searchDereferencedFields = self.switchSearchDereferenced.on;
    self.databaseMetaData.showKeePass1BackupGroup = self.switchShowKeePass1BackupFolder.on;
    self.databaseMetaData.showRecycleBinInSearchResults = self.switchShowRecycleBinInSearch.on;

    self.databaseMetaData.hideTotpInBrowse = !self.switchShowTotpBrowseView.on;
    self.databaseMetaData.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    
    self.databaseMetaData.showExpiredInBrowse = self.swtichShowExpiredInBrowse.on;
    self.databaseMetaData.showExpiredInSearch = self.switchShowExpiredInSearch.on;
    
    [SafesList.sharedInstance update:self.databaseMetaData];
    
    [self bindPreferences];
    self.onPreferencesChanged();
}

- (void)bindPreferences {
    self.showChildCountOnFolder.on = self.databaseMetaData.showChildCountOnFolderInBrowse;
    self.showFlagsInBrowse.on = self.databaseMetaData.showFlagsInBrowse;
    self.switchStartWithSearch.on = self.databaseMetaData.immediateSearchOnBrowse;
    
    self.switchViewDereferenced.on = self.databaseMetaData.viewDereferencedFields;
    self.switchSearchDereferenced.on = self.databaseMetaData.searchDereferencedFields;
    self.switchShowKeePass1BackupFolder.on = self.databaseMetaData.showKeePass1BackupGroup;
    self.switchShowRecycleBinInSearch.on = self.databaseMetaData.showRecycleBinInSearchResults;
    
    BrowseItemSubtitleField current = self.databaseMetaData.browseItemSubtitleField;
    BrowseItemSubtitleField effective = (current == kBrowseItemSubtitleEmail && self.format != kPasswordSafe) ? kBrowseItemSubtitleNoField : current;
    self.labelBrowseItemSubtitle.text = [self getBrowseItemSubtitleFieldName:effective];
    
    self.switchShowTotpBrowseView.on = !self.databaseMetaData.hideTotpInBrowse;
    self.switchShowRecycleBinInBrowse.on = !self.databaseMetaData.doNotShowRecycleBinInBrowse;

    self.labelViewAs.text = [self getBrowseViewTypeName:self.databaseMetaData.browseViewType];
    
    // Expired
    
    self.swtichShowExpiredInBrowse.on = self.databaseMetaData.showExpiredInBrowse;
    self.switchShowExpiredInSearch.on = self.databaseMetaData.showExpiredInSearch;
    
    // Tap Actions
    
    self.labelSingleTapAction.text = [self getTapActionString:(self.databaseMetaData.tapAction)];
    self.labelDoubleTapAction.text = [self getTapActionString:(self.databaseMetaData.doubleTapAction)];
    self.labelTripleTapAction.text = [self getTapActionString:(self.databaseMetaData.tripleTapAction)];
    self.labelLongPressAction.text = [self getTapActionString:(self.databaseMetaData.longPressTapAction)];
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
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (cell == self.cellBrowseItemSubtitle) {
        [self onChangeBrowseItemSubtitle];
    }
    else if (cell == self.cellViewAs) {
        [self onChangeViewType];
    }
    else if (cell == self.cellSingleTapAction || cell == self.cellDoubleTapAction || cell == self.cellTripleTapAction || cell == self.cellLongPressAction) {
        [self onChangeTapAction:cell];
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
                   self.onPreferencesChanged();
               }];
}

- (void)onChangeViewType {
    NSArray<NSNumber*>* options = @[@(kBrowseViewTypeHierarchy),
                                    @(kBrowseViewTypeList),
                                    @(kBrowseViewTypeTotpList)];
    
    NSArray* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getBrowseViewTypeName:(BrowseViewType)obj.integerValue];
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
                   self.onPreferencesChanged();
               }];
}

- (NSString*)getBrowseViewTypeName:(BrowseViewType)field {
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
          @(kBrowseItemSubtitleModified)] :
    
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
                   self.onPreferencesChanged();
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
    
    vc.items = options;
    vc.selected = [NSIndexSet indexSetWithIndex:currentIndex];
    vc.onSelectionChanged = ^(NSIndexSet * _Nonnull selectedIndices) {
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedIndices.firstIndex);
    };
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
