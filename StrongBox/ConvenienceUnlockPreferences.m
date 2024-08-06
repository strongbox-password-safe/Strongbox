//
//  ConvenienceUnlockPreferences.m
//  Strongbox
//
//  Created by Strongbox on 10/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConvenienceUnlockPreferences.h"
#import "BiometricsManager.h"
#import "PinsConfigurationController.h"
#import "AppPreferences.h"
#import "Alerts.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "DatabasePreferences.h"
#import "SafesList.h"

@interface ConvenienceUnlockPreferences () <UIAdaptivePresentationControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *cellPinCodes;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPinCodes;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometricSetting;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBiometric;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewBiometric;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellExpiry;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellMethodCombination;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrimaryMethod;
@property (weak, nonatomic) IBOutlet UILabel *labelExpiry;

@end

@implementation ConvenienceUnlockPreferences

+ (UINavigationController*)fromStoryboardWithModel:(Model *)model {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"ConvenienceUnlockPreferences" bundle:nil];
    UINavigationController* nav = [sb instantiateInitialViewController];
    
    ConvenienceUnlockPreferences* vc = (ConvenienceUnlockPreferences*)nav.topViewController;
    vc.viewModel = model;
    
    return nav;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.presentationController.delegate = self;
    
    self.imageViewBiometric.image = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];
    self.imageViewPinCodes.image = [UIImage imageNamed:@"keypad"];

    [self bindUi];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseUpdated:)
                                               name:kDatabaseUpdatedNotification
                                             object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        slog(@"viewWillDisappear");

        [NSNotificationCenter.defaultCenter removeObserver:self];
    }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {

    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)onDatabaseUpdated:(id)param { 

    [self bindUi];
}

- (void)bindUi {
    NSString *biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];

    if (![AppPreferences.sharedInstance isPro]) {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt_pro_only", @"%@ Unlock"), biometricIdName];
    }
    else {
        self.labelAllowBiometricSetting.text = [NSString stringWithFormat:NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock"), biometricIdName];
    }
    
    self.labelAllowBiometricSetting.textColor = [self canToggleTouchId] ? UIColor.labelColor : UIColor.secondaryLabelColor;
    
    self.switchAllowBiometric.enabled = [self canToggleTouchId];
    self.switchAllowBiometric.on = self.viewModel.metadata.isTouchIdEnabled;

    
    
    self.labelExpiry.text = [self getExpiryPeriodString:self.viewModel.metadata.convenienceExpiryPeriod];
    
    
    
        
    BOOL bio = self.viewModel.metadata.isTouchIdEnabled && [self canToggleTouchId];
    BOOL pin = self.viewModel.metadata.conveniencePin != nil;
    BOOL hideForEmptyNil = self.viewModel.metadata.convenienceMasterPassword.length == 0 && !self.viewModel.metadata.conveniencePasswordHasExpired && self.viewModel.metadata.convenienceExpiryPeriod == -1;
    
    [self cell:self.cellExpiry setHidden:(!(bio || pin) || hideForEmptyNil)];

    
    
    
    
    
    [self cell:self.cellMethodCombination setHidden:YES];
    [self cell:self.cellPrimaryMethod setHidden:YES];

    [self reloadDataAnimated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToPinsConfiguration"]) {
        PinsConfigurationController* vc = (PinsConfigurationController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if ( cell == self.cellPinCodes) {
        [self performSegueWithIdentifier:@"segueToPinsConfiguration" sender:nil];
    }
    else if ( cell == self.cellExpiry ) {
        [self promptForInteger:NSLocalizedString(@"convenience_unlock_require_after_prefix", @"Require After")
                       options:@[@(0), @(1), @(2), @(4), @(8), @(24), @(2 * 24), @(7 * 24), @(2 * 168), @(3 * 168), @(4 * 168), @(8 * 168), @(12 * 168), @(-1)]
                  currentValue:self.viewModel.metadata.convenienceExpiryPeriod
                    completion:^(BOOL success, NSInteger selectedValue) {
            if ( success ) {
                self.viewModel.metadata.convenienceExpiryPeriod = selectedValue;
                self.viewModel.metadata.conveniencePasswordHasBeenStored = YES;
                self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.ckfs.password;
            }
        }];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (IBAction)onSwitchBiometricUnlock:(id)sender {
    if ( !self.switchAllowBiometric.on ) {
        self.viewModel.metadata.isTouchIdEnabled = NO;

        if ( self.viewModel.metadata.conveniencePin == nil) {
            self.viewModel.metadata.conveniencePasswordHasBeenStored = NO;
            self.viewModel.metadata.convenienceMasterPassword = nil;
            self.viewModel.metadata.autoFillConvenienceAutoUnlockPassword = nil;
        }

        [self bindUi];
    }
    else {
        if (self.viewModel.database.ckfs.keyFileDigest && !self.viewModel.metadata.keyFileBookmark) {
            [Alerts warn:self
                   title:NSLocalizedString(@"config_error_one_time_key_file_convenience_title", @"One Time Key File Problem")
                 message:NSLocalizedString(@"config_error_one_time_key_file_convenience_message", @"You cannot use convenience unlock with a one time key file.")];
            
            return;
        }
        
        [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                               fallbackTitle:@""
                                                  completion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( success ) {
                    self.viewModel.metadata.isTouchIdEnabled = YES;
                    self.viewModel.metadata.conveniencePasswordHasBeenStored = YES;
                    self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.ckfs.password;
                    
                    [self bindUi];
                }
                else {
                    [self bindUi];
                }
            });
        }];
    }
}

- (BOOL)canToggleTouchId {
    return BiometricsManager.isBiometricIdAvailable && [AppPreferences.sharedInstance isPro];
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getExpiryPeriodString:obj.integerValue];
    }];
    vc.groupItems = @[items];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        
        NSInteger selectedValue = options[set.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSString*)getExpiryPeriodString:(NSInteger)expiryPeriodInHours {
    if(expiryPeriodInHours == -1) {
        return NSLocalizedString(@"mac_convenience_expiry_period_never", @"Never");
    }
    else if (expiryPeriodInHours == 0) {
        return NSLocalizedString(@"mac_convenience_expiry_period_on_app_exit", @"App Exit");
    }
    else {
        NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];
 
        fmt.allowedUnits = expiryPeriodInHours > 23 ? (NSCalendarUnitDay | NSCalendarUnitWeekOfMonth) : (NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitWeekOfMonth);
        fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        fmt.maximumUnitCount = 2;
        fmt.collapsesLargestUnit = YES;
        
        return [fmt stringFromTimeInterval:expiryPeriodInHours * 60 * 60];
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
