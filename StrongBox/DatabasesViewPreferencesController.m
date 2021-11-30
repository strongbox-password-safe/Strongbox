//
//  DatabasesViewPreferencesController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabasesViewPreferencesController.h"
//#import "Settings.h"
#import "AppPreferences.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"

@interface DatabasesViewPreferencesController ()
@property (weak, nonatomic) IBOutlet UISwitch *switchShowStorageIcon;
@property (weak, nonatomic) IBOutlet UISwitch *showStatusIndicator;
@property (weak, nonatomic) IBOutlet UILabel *labelTopRight;
@property (weak, nonatomic) IBOutlet UILabel *labelSubtitle1;
@property (weak, nonatomic) IBOutlet UILabel *labelSubtitle2;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellTopRight;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSubtitle1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSubtitle2;
@property (weak, nonatomic) IBOutlet UISwitch *showSeparator;

@end

@implementation DatabasesViewPreferencesController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUi];
}

- (void)bindUi {
    self.switchShowStorageIcon.on = AppPreferences.sharedInstance.showDatabaseIcon;
    self.showStatusIndicator.on = AppPreferences.sharedInstance.showDatabaseStatusIcon;
    self.showSeparator.on = AppPreferences.sharedInstance.showDatabasesSeparator;
    
    self.labelTopRight.text = [self getDatabaseSubtitleFieldName:AppPreferences.sharedInstance.databaseCellTopSubtitle];
    self.labelSubtitle1.text = [self getDatabaseSubtitleFieldName:AppPreferences.sharedInstance.databaseCellSubtitle1];
    self.labelSubtitle2.text = [self getDatabaseSubtitleFieldName:AppPreferences.sharedInstance.databaseCellSubtitle2];
}

- (IBAction)onSettingChanged:(id)sender {
    AppPreferences.sharedInstance.showDatabaseIcon = self.switchShowStorageIcon.on;
    AppPreferences.sharedInstance.showDatabaseStatusIcon = self.showStatusIndicator.on;
    AppPreferences.sharedInstance.showDatabasesSeparator = self.showSeparator.on;
    
    if(self.onPreferencesChanged) {
        self.onPreferencesChanged();
    }
    
    [self bindUi];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];

    NSArray<NSNumber*>* opts = @[@(kDatabaseCellSubtitleFieldNone),
      @(kDatabaseCellSubtitleFieldFileName),
      @(kDatabaseCellSubtitleFieldStorage),
      @(kDatabaseCellSubtitleFieldLastModifiedDate),
      @(kDatabaseCellSubtitleFieldLastModifiedDatePrecise),
      @(kDatabaseCellSubtitleFieldFileSize),


    ];
    
    NSArray<NSString*>* options = [opts map:^id _Nonnull(NSNumber*  _Nonnull obj, NSUInteger idx) {
        return [self getDatabaseSubtitleFieldName:obj.integerValue];
    }];
    
    if (cell == self.cellTopRight) {
        [self promptForString:NSLocalizedString(@"databases_preferences_select_top_right_field", @"Select Top Right Field")
                      options:options
                 currentIndex:AppPreferences.sharedInstance.databaseCellTopSubtitle
                   completion:^(BOOL success, NSInteger selectedIdx) {
                       if(success) {
                           AppPreferences.sharedInstance.databaseCellTopSubtitle = selectedIdx;
                           [self onSettingChanged:nil];
                       }
                   }];
    }
    else if (cell == self.cellSubtitle1) {
        [self promptForString:NSLocalizedString(@"databases_preferences_select_subtitle1_field", @"Select Subtitle 1 Field")
                      options:options
                 currentIndex:AppPreferences.sharedInstance.databaseCellSubtitle1
                   completion:^(BOOL success, NSInteger selectedIdx) {
                       if(success) {
                           AppPreferences.sharedInstance.databaseCellSubtitle1 = selectedIdx;
                           [self onSettingChanged:nil];
                       }
                   }];
    }
    else if (cell == self.cellSubtitle2) {
        [self promptForString:NSLocalizedString(@"databases_preferences_select_subtitle2_field", @"Select Subtitle 2 Field")
                      options:options
                 currentIndex:AppPreferences.sharedInstance.databaseCellSubtitle2
                   completion:^(BOOL success, NSInteger selectedIdx) {
                       if(success) {
                           AppPreferences.sharedInstance.databaseCellSubtitle2 = selectedIdx;
                           [self onSettingChanged:nil];
                       }
                   }];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString*)getDatabaseSubtitleFieldName:(DatabaseCellSubtitleField)field {
    switch (field) {
        case kDatabaseCellSubtitleFieldNone:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_none", @"None");
            break;
        case kDatabaseCellSubtitleFieldFileName:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_filename", @"Filename");
            break;
        case kDatabaseCellSubtitleFieldLastModifiedDate:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_last_cached_data", @"Last Modified");
            break;
        case kDatabaseCellSubtitleFieldLastModifiedDatePrecise:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_last_modified_date_precise", @"Last Modified (Precise)");
            break;
        case kDatabaseCellSubtitleFieldFileSize:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_file_size", @"File Size");
            break;
        case kDatabaseCellSubtitleFieldStorage:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_database_storage", @"Database Storage");
            break;
        case kDatabaseCellSubtitleFieldCreateDate:
            return NSLocalizedString(@"browse_prefs_item_subtitle_date_created", @"Date Created");
            break;
        case kDatabaseCellSubtitleFieldCreateDatePrecise:
            return NSLocalizedString(@"databases_preferences_subtitle_field_name_create_date_precise", @"Date Created (Precise)");
            break;
        default:
            return @"<Unknown Field>";
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
        [self.navigationController popViewControllerAnimated:YES];
        
        NSIndexSet* set = selectedIndices.firstObject;
        completion(YES, set.firstIndex);
    };
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
