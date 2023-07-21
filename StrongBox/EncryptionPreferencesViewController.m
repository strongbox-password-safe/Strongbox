//
//  EncryptionPreferencesViewController.m
//  Strongbox
//
//  Created by Strongbox on 10/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "EncryptionPreferencesViewController.h"
#import "Alerts.h"
#import "EncryptionSettingsViewModel.h"
#import "Utils.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "Argon2KdfCipher.h"

@interface EncryptionPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonSave;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellFormat;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUpgradeToV4;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellKdfAlgo;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellArgonMemory;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellArgonParallelism;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCalibrate;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReduceArgon2;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellEncryption;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellCompression;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellInnerStreamAlgo;

@property EncryptionSettingsViewModel* initialSettings;
@property EncryptionSettingsViewModel* currentSettings;

@property (weak, nonatomic) IBOutlet UILabel *labelIterations;
@property (weak, nonatomic) IBOutlet UISlider *sliderIterations;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellRestoreDefaults;

@end

@implementation EncryptionPreferencesViewController

+ (UINavigationController *)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"EncryptionPreferences" bundle:nil];
    
    return [sb instantiateInitialViewController];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.initialSettings = [EncryptionSettingsViewModel fromDatabaseModel:self.model.database];
    self.currentSettings = [self.initialSettings clone];
    
    [self bindUI];
}

- (void)bindUI {
    self.barButtonSave.enabled = NO;
    
    self.cellFormat.textLabel.text = self.currentSettings.formatAndVersion;
    self.cellKdfAlgo.textLabel.text = self.currentSettings.kdf;
    
    self.cellArgonMemory.detailTextLabel.text = friendlyMemorySizeString(self.currentSettings.argonMemory);
    self.cellArgonMemory.textLabel.text = NSLocalizedString(@"database_metadata_field_argon2_memory", @"Memory");
    
    float logValue = log2(self.currentSettings.iterations);
    NSString* strIterations = [NSNumberFormatter localizedStringFromNumber:@(self.currentSettings.iterations) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.labelIterations.text = strIterations;
    
    self.sliderIterations.minimumValue = self.currentSettings.minKdfIterations;
    self.sliderIterations.maximumValue = self.currentSettings.maxKdfIterations;
    self.sliderIterations.value = logValue;
    self.sliderIterations.enabled = !self.model.isReadOnly;
    
    self.cellArgonParallelism.detailTextLabel.text = @(self.currentSettings.argonParallelism).stringValue;
    self.cellEncryption.textLabel.text = self.currentSettings.encryption;
    self.cellCompression.textLabel.text = self.currentSettings.compressionString;
    self.cellInnerStreamAlgo.textLabel.text = self.currentSettings.innerStreamCipher;
        
    [self cell:self.cellCompression setHidden:!self.currentSettings.shouldShowCompressionSwitch];
    [self cell:self.cellArgonMemory setHidden:!self.currentSettings.shouldShowArgon2Fields];
    [self cell:self.cellArgonParallelism setHidden:!self.currentSettings.shouldShowArgon2Fields];
    [self cell:self.cellInnerStreamAlgo setHidden:!self.currentSettings.shouldShowInnerStreamEncryption];
    
    self.cellFormat.accessoryType = !self.model.isReadOnly && self.currentSettings.formatIsEditable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellFormat.selectionStyle = !self.model.isReadOnly && self.currentSettings.formatIsEditable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    
    self.cellKdfAlgo.accessoryType = !self.model.isReadOnly && self.currentSettings.kdfIsEditable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellKdfAlgo.selectionStyle = !self.model.isReadOnly && self.currentSettings.kdfIsEditable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

    self.cellEncryption.accessoryType = !self.model.isReadOnly && self.currentSettings.encryptionIsEditable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellEncryption.selectionStyle = !self.model.isReadOnly && self.currentSettings.encryptionIsEditable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

    self.cellCompression.accessoryType = !self.model.isReadOnly ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellCompression.selectionStyle = !self.model.isReadOnly ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

    self.cellArgonMemory.accessoryType = !self.model.isReadOnly ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellArgonParallelism.accessoryType = !self.model.isReadOnly ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    self.cellArgonMemory.selectionStyle = !self.model.isReadOnly ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    self.cellArgonParallelism.selectionStyle = !self.model.isReadOnly ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    
    [self cell:self.cellUpgradeToV4 setHidden:!self.currentSettings.shouldUpgradeToV4];
    [self cell:self.cellReduceArgon2 setHidden:!self.currentSettings.shouldReduceArgon2Memory];

    self.cellUpgradeToV4.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
    self.cellReduceArgon2.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
    
    [self cell:self.cellCalibrate setHidden:YES]; 
    
    [self cell:self.cellRestoreDefaults setHidden:self.currentSettings.isStrongboxDefaultEncryptionSettings];
    
    if ( self.model.isReadOnly || self.currentSettings.isStrongboxDefaultEncryptionSettings ) {
        self.cellRestoreDefaults.selectionStyle = UITableViewCellSelectionStyleNone;
        self.cellRestoreDefaults.userInteractionEnabled = NO;
        self.cellRestoreDefaults.textLabel.enabled = NO;

    }
    else {
        self.cellRestoreDefaults.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.cellRestoreDefaults.userInteractionEnabled = YES;
        self.cellRestoreDefaults.textLabel.enabled = YES;

    }
    
    [self reloadDataAnimated:YES];
    
    self.barButtonSave.enabled = !self.model.isReadOnly && [self.currentSettings isDifferentFrom:self.initialSettings];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ( self.model.isReadOnly ) {
        return;
    }
    
    if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellFormat ) {
        [self promptForAlternativeFormat];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellKdfAlgo ) {
        [self promptForAlternativeKdf];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellArgonMemory ) {
        [self promptForArgonMemory];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellArgonParallelism ) {
        [self promptForArgonParallelism];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellEncryption ) {
        [self promptForEncryption];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellCompression ) {
        [self promptForCompression];
    }
    else if ( [self.tableView cellForRowAtIndexPath:indexPath] == self.cellRestoreDefaults ) {
        [self restoreDefaults];
    }
}

- (void)promptForArgonMemory {
    if ( self.currentSettings.format == kKeePass4 &&
        ( self.currentSettings.kdfAlgorithm == kKdfAlgorithmArgon2d || self.currentSettings.kdfAlgorithm == kKdfAlgorithmArgon2id )) {
        NSArray<NSNumber*>* choices = @[@(1 * 1024 * 1024),
                                        @(2 * 1024 * 1024),
                                        @(4 * 1024 * 1024),
                                        @(8 * 1024 * 1024),
                                        @(16 * 1024 * 1024),
                                        @(32 * 1024 * 1024),
                                        @(64 * 1024 * 1024),
                                        @(128 * 1024 * 1024),
                                        @(256 * 1024 * 1024),
                                        @(512 * 1024 * 1024),
                                        @(1024 * 1024 * 1024),
        ];
        
        NSArray<NSString*>* choiceStrings = [choices map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            BOOL shouldWarn = obj.unsignedLongLongValue > Argon2KdfCipher.maxRecommendedMemory;
            NSString *warn = shouldWarn ? @"⚠️ " : @"";
            return [NSString stringWithFormat:@"%@%@", warn, friendlyMemorySizeString(obj.unsignedLongLongValue)];
        }];
        
        NSInteger currentIndex = [choices indexOfFirstMatch:^BOOL(NSNumber * _Nonnull obj) {
            return obj.integerValue == self.currentSettings.argonMemory;
        }];
        
        [self promptForChoice:NSLocalizedString(@"generic_memory", @"Memory")
                      options:choiceStrings
         currentlySelectIndex:currentIndex
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                NSNumber* foo = choices[selectedIndex];
                self.currentSettings.argonMemory = foo.integerValue;
                [self bindUI];
            }
        }];
    }
}

- (void)promptForArgonParallelism {
    if ( self.currentSettings.format == kKeePass4 &&
        ( self.currentSettings.kdfAlgorithm == kKdfAlgorithmArgon2d || self.currentSettings.kdfAlgorithm == kKdfAlgorithmArgon2id )) {
        NSArray<NSNumber*>* choices = @[@(1),
                                        @(2),
                                        @(3),
                                        @(4),
                                        @(8),
                                        @(12),
                                        @(16),
                                        @(32)];
        
        NSArray<NSString*>* choiceStrings = [choices map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return obj.stringValue;
        }];
        
        NSInteger currentIndex = [choices indexOfFirstMatch:^BOOL(NSNumber * _Nonnull obj) {
            return obj.integerValue == self.currentSettings.argonParallelism;
        }];
        
        [self promptForChoice:NSLocalizedString(@"generic_parallelism", @"Parallelism")
                      options:choiceStrings
         currentlySelectIndex:currentIndex
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                NSNumber* foo = choices[selectedIndex];
                self.currentSettings.argonParallelism = foo.intValue;
                [self bindUI];
            }
        }];
    }
}

- (void)promptForEncryption {
    if ( self.currentSettings.encryptionIsEditable ) {
        NSArray<NSNumber*>* choices = @[@(kEncryptionAlgorithmAes256),
                                        @(kEncryptionAlgorithmChaCha20),
                                        @(kEncryptionAlgorithmTwoFish256)];
        
        NSArray<NSString*>* choiceStrings = [choices map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return [EncryptionSettingsViewModel encryptionStringForAlgo:obj.integerValue];
        }];
        
        NSInteger currentIndex = [choices indexOfFirstMatch:^BOOL(NSNumber * _Nonnull obj) {
            return obj.integerValue == self.currentSettings.encryptionAlgorithm;
        }];
        
        [self promptForChoice:NSLocalizedString(@"generic_algorithm", @"Algorithm")
                      options:choiceStrings
         currentlySelectIndex:currentIndex
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                NSNumber* algo = choices[selectedIndex];
                self.currentSettings.encryptionAlgorithm = algo.integerValue;
                [self bindUI];
            }
        }];
    }
}

- (void)promptForCompression {
    NSArray<NSString*>* choiceStrings = @[[EncryptionSettingsViewModel compressionStringForCompression:NO],
                                          [EncryptionSettingsViewModel compressionStringForCompression:YES]];
            
    [self promptForChoice:NSLocalizedString(@"generic_compression", @"Compression")
                  options:choiceStrings
     currentlySelectIndex:self.currentSettings.compression ? 1 : 0
               completion:^(BOOL success, NSInteger selectedIndex) {
        if ( success ) {
            self.currentSettings.compression = selectedIndex == 0 ? NO : YES;
            [self bindUI];
        }
    }];
}

- (void)restoreDefaults {
    EncryptionSettingsViewModel* defaults = [EncryptionSettingsViewModel defaultsForFormat:self.currentSettings.format];
    
    self.currentSettings = [defaults clone];

    [self bindUI];
}

- (void)promptForAlternativeKdf {
    if ( self.currentSettings.kdfIsEditable ) {
        NSArray<NSNumber*>* choices = @[@(kKdfAlgorithmAes256),
                             @(kKdfAlgorithmArgon2d),
                             @(kKdfAlgorithmArgon2id)];
        
        NSArray<NSString*>* choiceStrings = [choices map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return [EncryptionSettingsViewModel kdfStringForKdf:obj.integerValue];
        }];
        
        NSInteger currentIndex = [choices indexOfFirstMatch:^BOOL(NSNumber * _Nonnull obj) {
            return obj.integerValue == self.currentSettings.kdfAlgorithm;
        }];
        
        [self promptForChoice:NSLocalizedString(@"generic_algorithm", @"Algorithm")
                      options:choiceStrings
         currentlySelectIndex:currentIndex
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                NSNumber* algo = choices[selectedIndex];
                self.currentSettings.kdfAlgorithm = algo.integerValue;
                [self bindUI];
            }
        }];
    }
}

- (void)promptForAlternativeFormat {
    if ( self.currentSettings.formatIsEditable ) {
        NSArray<NSString*>* choices = @[[EncryptionSettingsViewModel getAlternativeFormatString:kKeePass],
                                        [EncryptionSettingsViewModel getAlternativeFormatString:kKeePass4]];

        NSUInteger currentIndex = self.currentSettings.format == kKeePass ? 0 : 1;
        [self promptForChoice:NSLocalizedString(@"database_metadata_field_format", @"Database Format")
                      options:choices
         currentlySelectIndex:currentIndex
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                if ( currentIndex != selectedIndex) {
                    self.currentSettings.format = selectedIndex == 0 ? kKeePass : kKeePass4;
                    
                    [self bindUI];
                }
            }
        }];
    }
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onSave:(id)sender {
    [Alerts areYouSure:self
               message:NSLocalizedString(@"are_you_sure_change_encryption_settings", @"Are you sure you want to change your database encryption settings?")
                action:^(BOOL response) {
        if ( response ) {
            [self.currentSettings applyToDatabaseModel:self.model.database];

            [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if ( self.onChangedDatabaseEncryptionSettings ) {
                    self.onChangedDatabaseEncryptionSettings();
                }
            }];
        }
    }];
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
    currentlySelectIndex:(NSInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    if ( currentlySelectIndex != NSNotFound ) {
        vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    }
    else {
        vc.selectedIndexPaths = nil;
    }
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onIterationsChanged:(id)sender {
    self.currentSettings.iterations = pow(2.0f, self.sliderIterations.value);
    
    [self bindUI];
}

@end
