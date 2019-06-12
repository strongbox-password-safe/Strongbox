//
//  BrowsePreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 08/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BrowsePreferencesTableViewController.h"
#import "Settings.h"
#import "NSArray+Extensions.h"
#import "SelectItemTableViewController.h"

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

@end

@implementation BrowsePreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindGenericPreferencesChanged];
    
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
    
    Settings.sharedInstance.showChildCountOnFolderInBrowse = self.showChildCountOnFolder.on;
    Settings.sharedInstance.showFlagsInBrowse = self.showFlagsInBrowse.on;
    Settings.sharedInstance.immediateSearchOnBrowse = self.switchStartWithSearch.on;
    
    Settings.sharedInstance.viewDereferencedFields = self.switchViewDereferenced.on;
    Settings.sharedInstance.searchDereferencedFields = self.switchSearchDereferenced.on;
    Settings.sharedInstance.showKeePass1BackupGroup = self.switchShowKeePass1BackupFolder.on;
    Settings.sharedInstance.showRecycleBinInSearchResults = self.switchShowRecycleBinInSearch.on;

    Settings.sharedInstance.hideTotpInBrowse = !self.switchShowTotpBrowseView.on;
    Settings.sharedInstance.doNotShowRecycleBinInBrowse = !self.switchShowRecycleBinInBrowse.on;
    
    [self bindGenericPreferencesChanged];
    
    self.onPreferencesChanged();
}

- (void)bindGenericPreferencesChanged {
    self.showChildCountOnFolder.on = Settings.sharedInstance.showChildCountOnFolderInBrowse;
    self.showFlagsInBrowse.on = Settings.sharedInstance.showFlagsInBrowse;
    self.switchStartWithSearch.on = Settings.sharedInstance.immediateSearchOnBrowse;
    
    self.switchViewDereferenced.on = Settings.sharedInstance.viewDereferencedFields;
    self.switchSearchDereferenced.on = Settings.sharedInstance.searchDereferencedFields;
    self.switchShowKeePass1BackupFolder.on = Settings.sharedInstance.showKeePass1BackupGroup;
    self.switchShowRecycleBinInSearch.on = Settings.sharedInstance.showRecycleBinInSearchResults;
    
    BrowseItemSubtitleField current = Settings.sharedInstance.browseItemSubtitleField;
    BrowseItemSubtitleField effective = (current == kBrowseItemSubtitleEmail && self.format != kPasswordSafe) ? kBrowseItemSubtitleNoField : current;
    self.labelBrowseItemSubtitle.text = [self getBrowseItemSubtitleFieldName:effective];
    
    self.switchShowTotpBrowseView.on = !Settings.sharedInstance.hideTotpInBrowse;
    self.switchShowRecycleBinInBrowse.on = !Settings.sharedInstance.doNotShowRecycleBinInBrowse;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (cell == self.cellBrowseItemSubtitle) {
        [self onChangeBrowseItemSubtitle];
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
    
    BrowseItemSubtitleField current = Settings.sharedInstance.browseItemSubtitleField;
    if(current == kBrowseItemSubtitleEmail && self.format != kPasswordSafe) {
        current = kBrowseItemSubtitleNoField;
    }
    
    NSInteger currentIndex = [options indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == current;
    }];
    
    [self promptForString:optionStrings
             currentIndex:currentIndex
               completion:^(BOOL success, NSInteger selectedIdx) {
                   if (success) {
                       Settings.sharedInstance.browseItemSubtitleField = (BrowseItemSubtitleField)options[selectedIdx].integerValue;
                   }
                   
                   [self bindGenericPreferencesChanged];
                   self.onPreferencesChanged();
               }];
}

- (NSString*)getBrowseItemSubtitleFieldName:(BrowseItemSubtitleField)field {
    switch (field) {
        case kBrowseItemSubtitleNoField:
            return @"None";
            break;
        case kBrowseItemSubtitleUsername:
            return @"Username";
            break;
        case kBrowseItemSubtitlePassword:
            return @"Password";
            break;
        case kBrowseItemSubtitleUrl:
            return @"URL";
            break;
        case kBrowseItemSubtitleEmail:
            return @"Email";
            break;
        case kBrowseItemSubtitleModified:
            return @"Date Modified";
        case kBrowseItemSubtitleNotes:
            return @"Notes";
            break;
        case kBrowseItemSubtitleCreated:
            return @"Date Created";
            break;
        default:
            return @"None";
            break;
    }
}

- (void)promptForString:(NSArray<NSString*>*)options
           currentIndex:(NSInteger)currentIndex
             completion:(void(^)(BOOL success, NSInteger selectedIdx))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = options;
    vc.currentlySelectedIndex = currentIndex;
    vc.onDone = ^(BOOL success, NSInteger selectedIndex) {
        [self.navigationController popViewControllerAnimated:YES];
        completion(success, selectedIndex);
    };
    vc.title = @"Item Subtitle";
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
