//
//  AutoFillPreferencesViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AutoFillPreferencesViewController.h"
#import "AppPreferences.h"
#import "AutoFillManager.h"
#import "NSArray+Extensions.h"
#import "SelectItemTableViewController.h"
#import "Utils.h"
#import "DatabasePreferences.h"

@interface AutoFillPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *autoProceed;
@property (weak, nonatomic) IBOutlet UISwitch *addServiceIds;
@property (weak, nonatomic) IBOutlet UISwitch *useHostOnlyUrl;

@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchQuickTypeAutoFill;
@property (weak, nonatomic) IBOutlet UILabel *labelQuickTypeFormat;
@property (weak, nonatomic) IBOutlet UILabel *labelConvenienceAutoUnlockTimeout;
@property (weak, nonatomic) IBOutlet UISwitch *switchCopyTOTP;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoLaunchSingle;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPinned;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellSystemLevelEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSystemLevelDisabled;


@property (weak, nonatomic) IBOutlet UITableViewCell *howTo1;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo2;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo3;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo4;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo5;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo6;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowAutoFill;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowQuickType;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellQuickTypeFormat;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCopyTotp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoLaunchDatabase;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoSelectSingle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowPinned;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellConvenienceAutoUnlock;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUseHostOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAddServiceIds;
@property (weak, nonatomic) IBOutlet UISwitch *switchScanCustomFields;
@property (weak, nonatomic) IBOutlet UISwitch *switchScanAlternativeURLs;
@property (weak, nonatomic) IBOutlet UISwitch *switchScanNotes;
@property (weak, nonatomic) IBOutlet UISwitch *switchSuggestConcealed;
@property (weak, nonatomic) IBOutlet UISwitch *suggestUnconcealed;
@property (weak, nonatomic) IBOutlet UISwitch *switchLongTapPreview;

@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeAltUrls;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeScanCustom;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeScanNotes;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeSuggestConcealable;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeSuggestUnconcealable;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLongTapPreview;

@end

@implementation AutoFillPreferencesViewController

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(bind)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    [self bind];
}

- (void)bind {
    BOOL onForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox;
    
    
    
    UIImage* check;
    UIImage* notCheck;

    if (@available(iOS 13.0, *)) {
        check = [UIImage systemImageNamed:@"checkmark.circle"];
        notCheck = [UIImage systemImageNamed:@"exclamationmark.triangle"];
    } else {
        check = [UIImage imageNamed:@"ok"];
        notCheck = [UIImage imageNamed:@"error"];
    }
    
    self.cellSystemLevelEnabled.imageView.image = check;
    self.cellSystemLevelEnabled.imageView.tintColor = UIColor.systemGreenColor;

    self.cellSystemLevelDisabled.imageView.image = notCheck;
    self.cellSystemLevelDisabled.imageView.tintColor = UIColor.systemOrangeColor;

    [self cell:self.cellSystemLevelEnabled setHidden:!onForStrongbox];
    [self cell:self.cellSystemLevelDisabled setHidden:onForStrongbox];
    
    
    
    [self cell:self.howTo1 setHidden:onForStrongbox];
    [self cell:self.howTo2 setHidden:onForStrongbox];
    [self cell:self.howTo3 setHidden:onForStrongbox];
    [self cell:self.howTo4 setHidden:onForStrongbox];
    [self cell:self.howTo5 setHidden:onForStrongbox];
    [self cell:self.howTo6 setHidden:onForStrongbox];
    
    
    
    [self cell:self.cellAllowAutoFill setHidden:!onForStrongbox];

    self.switchAutoFill.on = self.viewModel.metadata.autoFillEnabled;
    
    BOOL on = onForStrongbox && self.viewModel.metadata.autoFillEnabled;
    
    
    
    [self cell:self.cellAllowQuickType setHidden:!on];
    [self cell:self.cellQuickTypeFormat setHidden:!on];
    [self cell:self.cellCopyTotp setHidden:!on];
    [self cell:self.cellAutoLaunchDatabase setHidden:!on];
    [self cell:self.cellAutoSelectSingle setHidden:!on];
    [self cell:self.cellShowPinned setHidden:!on];
    [self cell:self.cellConvenienceAutoUnlock setHidden:!on];
    [self cell:self.cellUseHostOnly setHidden:!on];
    [self cell:self.cellAddServiceIds setHidden:!on];
    [self cell:self.cellLongTapPreview setHidden:!on];
    [self cell:self.quickTypeAltUrls setHidden:!on];
    [self cell:self.quickTypeScanCustom setHidden:!on];
    [self cell:self.quickTypeScanNotes setHidden:!on];
    [self cell:self.quickTypeSuggestConcealable setHidden:!on];
    [self cell:self.quickTypeSuggestUnconcealable setHidden:!on];
    [self cell:self.cellAddServiceIds setHidden:!on];

    
    
    self.switchQuickTypeAutoFill.on = self.viewModel.metadata.autoFillEnabled && self.viewModel.metadata.quickTypeEnabled;
    self.switchQuickTypeAutoFill.enabled = self.switchAutoFill.on;
        
    
    
    self.cellQuickTypeFormat.userInteractionEnabled = self.switchQuickTypeAutoFill.on;
    self.labelQuickTypeFormat.text = quickTypeFormatString(self.viewModel.metadata.quickTypeDisplayFormat);
    if (@available(iOS 13.0, *)) {
        self.labelQuickTypeFormat.textColor = self.switchQuickTypeAutoFill.on ? UIColor.labelColor : UIColor.secondaryLabelColor;
    }
    else {
        self.labelQuickTypeFormat.textColor = self.switchQuickTypeAutoFill.on ? UIColor.blackColor : UIColor.lightGrayColor;
    }
    
    
    
    self.switchScanAlternativeURLs.on = self.viewModel.metadata.autoFillScanAltUrls;
    self.switchScanNotes.on = self.viewModel.metadata.autoFillScanNotes;
    self.switchScanCustomFields.on = self.viewModel.metadata.autoFillScanCustomFields;
    self.switchSuggestConcealed.on = self.viewModel.metadata.autoFillConcealedFieldsAsCreds;
    self.suggestUnconcealed.on = self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds;
    self.switchScanAlternativeURLs.enabled = self.switchQuickTypeAutoFill.on;
    self.switchScanNotes.enabled = self.switchQuickTypeAutoFill.on;
    self.switchScanCustomFields.enabled = self.switchQuickTypeAutoFill.on;
    self.switchSuggestConcealed.enabled = self.switchQuickTypeAutoFill.on;
    self.suggestUnconcealed.enabled = self.switchQuickTypeAutoFill.on;
    
    
    
    self.autoProceed.on = AppPreferences.sharedInstance.autoProceedOnSingleMatch;
    self.switchCopyTOTP.on = self.viewModel.metadata.autoFillCopyTotp;
    self.switchAutoLaunchSingle.on = AppPreferences.sharedInstance.autoFillAutoLaunchSingleDatabase;
    self.switchShowPinned.on = AppPreferences.sharedInstance.autoFillShowPinned;
    self.switchLongTapPreview.on = AppPreferences.sharedInstance.autoFillLongTapPreview;
    
    
    
    self.cellConvenienceAutoUnlock.userInteractionEnabled = self.viewModel.metadata.autoFillEnabled;
    self.labelConvenienceAutoUnlockTimeout.text = stringForConvenienceAutoUnlock(self.viewModel.metadata.autoFillConvenienceAutoUnlockTimeout);

    if (@available(iOS 13.0, *)) {
        self.labelConvenienceAutoUnlockTimeout.textColor = self.viewModel.metadata.autoFillEnabled ? UIColor.labelColor : UIColor.secondaryLabelColor;
    }
    else {
        self.labelConvenienceAutoUnlockTimeout.textColor = self.viewModel.metadata.autoFillEnabled ? UIColor.blackColor : UIColor.lightGrayColor;
    }
    
    
    
    self.addServiceIds.on = AppPreferences.sharedInstance.storeAutoFillServiceIdentifiersInNotes;
    self.useHostOnlyUrl.on = !AppPreferences.sharedInstance.useFullUrlAsURLSuggestion;
    
    [self reloadDataAnimated:YES];
}

static NSString* stringForConvenienceAutoUnlock(NSInteger val) {
    if (val == -1) {
        return NSLocalizedString(@"generic_preference_not_configured", @"Not Configured");
    }
    else if ( val == 0 ) {
        return NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    }
    else {
        return [Utils formatTimeInterval:val];
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onChanged:(id)sender {
    AppPreferences.sharedInstance.autoProceedOnSingleMatch = self.autoProceed.on;
    AppPreferences.sharedInstance.storeAutoFillServiceIdentifiersInNotes = self.addServiceIds.on;
    AppPreferences.sharedInstance.useFullUrlAsURLSuggestion = !self.useHostOnlyUrl.on;
    AppPreferences.sharedInstance.autoFillAutoLaunchSingleDatabase = self.switchAutoLaunchSingle.on;
    AppPreferences.sharedInstance.autoFillShowPinned = self.switchShowPinned.on;
    AppPreferences.sharedInstance.autoFillLongTapPreview = self.switchLongTapPreview.on;
    
    [self bind];
}

- (IBAction)onCopyTotp:(id)sender {
    BOOL on = self.switchCopyTOTP.on;
    
    self.viewModel.metadata.autoFillCopyTotp = on;

    [self bind];
}

- (IBAction)onSwitchQuickTypeAutoFill:(id)sender {
    
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    self.viewModel.metadata.quickTypeEnabled = self.switchQuickTypeAutoFill.on;
    self.viewModel.metadata.autoFillScanAltUrls = self.switchScanAlternativeURLs.on;
    self.viewModel.metadata.autoFillScanNotes = self.switchScanNotes.on;
    self.viewModel.metadata.autoFillScanCustomFields = self.switchScanCustomFields.on;
    self.viewModel.metadata.autoFillConcealedFieldsAsCreds = self.switchSuggestConcealed.on;
    self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds = self.suggestUnconcealed.on;

    if ( self.switchQuickTypeAutoFill.on ) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel
                                                           databaseUuid:self.viewModel.metadata.uuid
                                                          displayFormat:self.viewModel.metadata.quickTypeDisplayFormat
                                                        alternativeUrls:self.viewModel.metadata.autoFillScanAltUrls
                                                           customFields:self.viewModel.metadata.autoFillScanCustomFields
                                                                  notes:self.viewModel.metadata.autoFillScanNotes
                                           concealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillConcealedFieldsAsCreds
                                         unConcealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds nickName:self.viewModel.metadata.nickName];
    }
    
    [self bind];
}

- (IBAction)onSwitchAutoFill:(id)sender {
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

    if (!self.switchAutoFill.on) {
       [self.viewModel disableAndClearAutoFill];
       [self bind];
    }
    else {
        [self.viewModel enableAutoFill];
        
        if ( self.viewModel.metadata.quickTypeEnabled ) {
            
            [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel
                                                               databaseUuid:self.viewModel.metadata.uuid
                                                              displayFormat:self.viewModel.metadata.quickTypeDisplayFormat
                                                            alternativeUrls:self.viewModel.metadata.autoFillScanAltUrls
                                                               customFields:self.viewModel.metadata.autoFillScanCustomFields
                                                                      notes:self.viewModel.metadata.autoFillScanNotes
                                               concealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillConcealedFieldsAsCreds
                                             unConcealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds
                                                                   nickName:self.viewModel.metadata.nickName];
        }
        
        [self bind];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if ( cell == self.cellQuickTypeFormat ) {
        [self promptForQuickTypeFormat];
    }
    else if ( cell == self.cellConvenienceAutoUnlock ) {
        [self promptForConvenienceAutoUnlock];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptForConvenienceAutoUnlock {
    NSArray<NSNumber*>* options = @[@(0), @(15), @(30), @(60), @(120), @(180), @(300), @(600), @(1200), @(1800), @(3600), @(2 * 3600), @(8 * 3600), @(24 * 3600), @(48 * 3600), @(72 * 3600)];
    
    NSArray<NSString*>* optionsStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return stringForConvenienceAutoUnlock(obj.integerValue);
    }];
    
    NSUInteger currentlySelected = [options indexOfObject:@(self.viewModel.metadata.autoFillConvenienceAutoUnlockTimeout)];
    
    [self promptForChoice:NSLocalizedString(@"prefs_vc_autofill_convenience_auto_unlock", @"Convenience Auto Unlock")
                  options:optionsStrings
     currentlySelectIndex:currentlySelected
               completion:^(BOOL success, NSInteger selectedIndex) {
        if (success) {
            NSNumber *numFormat = options[selectedIndex];
            
            self.viewModel.metadata.autoFillConvenienceAutoUnlockTimeout = numFormat.integerValue;
            
            if (self.viewModel.metadata.autoFillConvenienceAutoUnlockTimeout == 0) {
                self.viewModel.metadata.autoFillConvenienceAutoUnlockPassword = nil;
            }
            
            [self bind];
        }
    }];
}

- (void)promptForQuickTypeFormat {
    NSArray<NSNumber*>* options = @[@(kQuickTypeFormatTitleThenUsername),
                                    @(kQuickTypeFormatUsernameOnly),
                                    @(kQuickTypeFormatTitleOnly),
                                    @(kQuickTypeFormatDatabaseThenTitleThenUsername),
                                    @(kQuickTypeFormatDatabaseThenTitle),
                                    @(kQuickTypeFormatDatabaseThenUsername)];
    
    NSArray<NSString*>* optionsStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return quickTypeFormatString(obj.integerValue);
    }];
    
    NSUInteger currentlySelected = [options indexOfObject:@(self.viewModel.metadata.quickTypeDisplayFormat)];
    
    [self promptForChoice:NSLocalizedString(@"prefs_vc_quick_type_format", @"QuickType Format")
                  options:optionsStrings
     currentlySelectIndex:currentlySelected
               completion:^(BOOL success, NSInteger selectedIndex) {
        if (success) {
            NSNumber *numFormat = options[selectedIndex];
            self.viewModel.metadata.quickTypeDisplayFormat = numFormat.integerValue;
            
            

            
            
            [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
            
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel
                                                               databaseUuid:self.viewModel.metadata.uuid
                                                              displayFormat:self.viewModel.metadata.quickTypeDisplayFormat
                                                            alternativeUrls:self.viewModel.metadata.autoFillScanAltUrls
                                                               customFields:self.viewModel.metadata.autoFillScanCustomFields
                                                                      notes:self.viewModel.metadata.autoFillScanNotes
                                               concealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillConcealedFieldsAsCreds
                                             unConcealedCustomFieldsAsCreds:self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds
                                                                   nickName:self.viewModel.metadata.nickName];

            [self bind];
        }
    }];
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
   currentlySelectIndex:(NSUInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    if ( currentlySelectIndex != NSNotFound ) {
        vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    }
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
