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
#import <AuthenticationServices/AuthenticationServices.h>

@interface AutoFillPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *autoProceed;
@property (weak, nonatomic) IBOutlet UISwitch *addServiceIds;
@property (weak, nonatomic) IBOutlet UISwitch *useHostOnlyUrl;

@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchQuickTypeAutoFill;
@property (weak, nonatomic) IBOutlet UILabel *labelQuickTypeFormat;
@property (weak, nonatomic) IBOutlet UILabel *labelConvenienceAutoUnlockTimeout;
@property (weak, nonatomic) IBOutlet UISwitch *switchCopyTOTP;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowFavourites;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellSystemLevelEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSystemLevelDisabled;


@property (weak, nonatomic) IBOutlet UITableViewCell *howTo1;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo2;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo3;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo4;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo5;
@property (weak, nonatomic) IBOutlet UITableViewCell *howTo6;

@property (weak, nonatomic) IBOutlet UITableViewCell *howToiOS171;
@property (weak, nonatomic) IBOutlet UITableViewCell *howToiOS172;
@property (weak, nonatomic) IBOutlet UITableViewCell *howToiOS173;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowAutoFill;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowQuickType;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellQuickTypeFormat;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCopyTotp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoSelectSingle;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellShowPinned;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellConvenienceAutoUnlock;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUseHostOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAddServiceIds;
@property (weak, nonatomic) IBOutlet UISwitch *switchScanCustomFields;
@property (weak, nonatomic) IBOutlet UISwitch *switchIncludeAssociatedDomains;

@property (weak, nonatomic) IBOutlet UISwitch *switchScanNotes;
@property (weak, nonatomic) IBOutlet UISwitch *switchSuggestConcealed;
@property (weak, nonatomic) IBOutlet UISwitch *suggestUnconcealed;
@property (weak, nonatomic) IBOutlet UISwitch *switchLongTapPreview;

@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeIncludeAssociated;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeScanCustom;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeScanNotes;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeSuggestConcealable;
@property (weak, nonatomic) IBOutlet UITableViewCell *quickTypeSuggestUnconcealable;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLongTapPreview;

@end

@implementation AutoFillPreferencesViewController

+ (UINavigationController*)fromStoryboardWithModel:(Model*)model {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"AutoFillPreferences" bundle:nil];
    
    UINavigationController* ret = [sb instantiateInitialViewController];
    
    AutoFillPreferencesViewController* prefs = (AutoFillPreferencesViewController*)ret.topViewController;
    
    prefs.viewModel = model;
    
    return ret;
}

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
    
    check = [UIImage systemImageNamed:@"checkmark.circle"];
    notCheck = [UIImage systemImageNamed:@"exclamationmark.triangle"];

    self.cellSystemLevelEnabled.imageView.image = check;
    self.cellSystemLevelEnabled.imageView.tintColor = UIColor.systemGreenColor;

    self.cellSystemLevelDisabled.imageView.image = notCheck;
    self.cellSystemLevelDisabled.imageView.tintColor = UIColor.systemOrangeColor;

    [self cell:self.cellSystemLevelEnabled setHidden:!onForStrongbox];
    [self cell:self.cellSystemLevelDisabled setHidden:onForStrongbox];
    
    
    
    if (@available(iOS 17.0, *)) {
        [self cell:self.howTo1 setHidden:YES];
        [self cell:self.howTo2 setHidden:YES];
        [self cell:self.howTo3 setHidden:YES];
        [self cell:self.howTo4 setHidden:YES];
        [self cell:self.howTo5 setHidden:YES];
        [self cell:self.howTo6 setHidden:YES];
        
        [self cell:self.howToiOS171 setHidden:onForStrongbox];
        [self cell:self.howToiOS172 setHidden:onForStrongbox];
        [self cell:self.howToiOS173 setHidden:onForStrongbox];
    }
    else {
        [self cell:self.howTo1 setHidden:onForStrongbox];
        [self cell:self.howTo2 setHidden:onForStrongbox];
        [self cell:self.howTo3 setHidden:onForStrongbox];
        [self cell:self.howTo4 setHidden:onForStrongbox];
        [self cell:self.howTo5 setHidden:onForStrongbox];
        [self cell:self.howTo6 setHidden:onForStrongbox];
        
        [self cell:self.howToiOS171 setHidden:YES];
        [self cell:self.howToiOS172 setHidden:YES];
        [self cell:self.howToiOS173 setHidden:YES];
    }
    
    
    
    [self cell:self.cellAllowAutoFill setHidden:!onForStrongbox];

    self.switchAutoFill.on = self.viewModel.metadata.autoFillEnabled;
    
    BOOL on = onForStrongbox && self.viewModel.metadata.autoFillEnabled;
    
    
    
    [self cell:self.cellAllowQuickType setHidden:!on];
    [self cell:self.cellQuickTypeFormat setHidden:!on];
    [self cell:self.cellCopyTotp setHidden:!on];
    
    [self cell:self.cellAutoSelectSingle setHidden:!on];
    [self cell:self.cellShowPinned setHidden:!on];
    [self cell:self.cellConvenienceAutoUnlock setHidden:!on];
    [self cell:self.cellUseHostOnly setHidden:!on];
    [self cell:self.cellAddServiceIds setHidden:!on];
    [self cell:self.cellLongTapPreview setHidden:!on];
    
    [self cell:self.quickTypeIncludeAssociated setHidden:!on];
    [self cell:self.quickTypeScanCustom setHidden:!on];
    [self cell:self.quickTypeScanCustom setHidden:!on];
    [self cell:self.quickTypeScanNotes setHidden:!on];
    [self cell:self.quickTypeSuggestConcealable setHidden:!on];
    [self cell:self.quickTypeSuggestUnconcealable setHidden:!on];
    [self cell:self.cellAddServiceIds setHidden:!on];

    
    
    self.switchQuickTypeAutoFill.on = self.viewModel.metadata.autoFillEnabled && self.viewModel.metadata.quickTypeEnabled;
    self.switchQuickTypeAutoFill.enabled = self.switchAutoFill.on;
        
    
    
    self.cellQuickTypeFormat.userInteractionEnabled = self.switchQuickTypeAutoFill.on;
    self.labelQuickTypeFormat.text = quickTypeFormatString(self.viewModel.metadata.quickTypeDisplayFormat);
    
    self.labelQuickTypeFormat.textColor = self.switchQuickTypeAutoFill.on ? UIColor.labelColor : UIColor.secondaryLabelColor;
    
    
    
    self.switchIncludeAssociatedDomains.on = self.viewModel.metadata.includeAssociatedDomains;
    self.switchScanNotes.on = self.viewModel.metadata.autoFillScanNotes;
    self.switchScanCustomFields.on = self.viewModel.metadata.autoFillScanCustomFields;
    self.switchSuggestConcealed.on = self.viewModel.metadata.autoFillConcealedFieldsAsCreds;
    self.suggestUnconcealed.on = self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds;
    
    self.switchIncludeAssociatedDomains.enabled = self.switchQuickTypeAutoFill.on;
    self.switchScanNotes.enabled = self.switchQuickTypeAutoFill.on;
    self.switchScanCustomFields.enabled = self.switchQuickTypeAutoFill.on;
    self.switchSuggestConcealed.enabled = self.switchQuickTypeAutoFill.on;
    self.suggestUnconcealed.enabled = self.switchQuickTypeAutoFill.on;
    
    
    
    self.autoProceed.on = AppPreferences.sharedInstance.autoProceedOnSingleMatch;
    self.switchCopyTOTP.on = self.viewModel.metadata.autoFillCopyTotp;
    self.switchShowFavourites.on = AppPreferences.sharedInstance.autoFillShowFavourites;
    self.switchLongTapPreview.on = AppPreferences.sharedInstance.autoFillLongTapPreview;
    
    
    
    self.cellConvenienceAutoUnlock.userInteractionEnabled = self.viewModel.metadata.autoFillEnabled;
    self.labelConvenienceAutoUnlockTimeout.text = stringForConvenienceAutoUnlock(self.viewModel.metadata.autoFillConvenienceAutoUnlockTimeout);

    
    self.labelConvenienceAutoUnlockTimeout.textColor = self.viewModel.metadata.autoFillEnabled ? UIColor.labelColor : UIColor.secondaryLabelColor;
    
    
    
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

    AppPreferences.sharedInstance.autoFillShowFavourites = self.switchShowFavourites.on;
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

    self.viewModel.metadata.includeAssociatedDomains = self.switchIncludeAssociatedDomains.on;
    self.viewModel.metadata.autoFillScanNotes = self.switchScanNotes.on;
    self.viewModel.metadata.autoFillScanCustomFields = self.switchScanCustomFields.on;
    self.viewModel.metadata.autoFillConcealedFieldsAsCreds = self.switchSuggestConcealed.on;
    self.viewModel.metadata.autoFillUnConcealedFieldsAsCreds = self.suggestUnconcealed.on;

    if ( self.switchQuickTypeAutoFill.on ) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel clearFirst:NO];
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

            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel clearFirst:NO];
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
    else if ( cell == self.howToiOS171 ) {
        if (@available(iOS 17.0, *)) {
            [ASSettingsHelper openCredentialProviderAppSettingsWithCompletionHandler:^(NSError * _Nullable error) {

            }];
        }
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
            
            

            
            
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel clearFirst:YES];

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
