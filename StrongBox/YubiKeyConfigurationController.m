//
//  YubiKeyConfigurationController.m
//  Strongbox
//
//  Created by Mark on 10/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "YubiKeyConfigurationController.h"
#import "Settings.h"

@interface YubiKeyConfigurationController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellNoYubiKey;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNfcSlot1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNfcSlot2;

@property YubiKeyHardwareConfiguration* currentConfig;

@end

@implementation YubiKeyConfigurationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentConfig = self.initialConfiguration ? [self.initialConfiguration clone] : [YubiKeyHardwareConfiguration defaults];
    
    if (!Settings.sharedInstance.isProOrFreeTrial) {
        self.currentConfig.mode = kNoYubiKey;
    }
    
    [self bindUi];
}

- (void)bindUi {
    self.cellNoYubiKey.accessoryType = (self.currentConfig == nil || self.currentConfig.mode == kNoYubiKey) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellNfcSlot1.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kNfc && self.currentConfig.slot == kSlot1) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellNfcSlot2.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kNfc && self.currentConfig.slot == kSlot2) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.cellNfcSlot1.userInteractionEnabled = Settings.sharedInstance.isProOrFreeTrial;
    self.cellNfcSlot2.userInteractionEnabled = Settings.sharedInstance.isProOrFreeTrial;
    self.cellNfcSlot1.textLabel.textColor = Settings.sharedInstance.isProOrFreeTrial ? nil : UIColor.lightGrayColor;
    self.cellNfcSlot2.textLabel.textColor = Settings.sharedInstance.isProOrFreeTrial ? nil : UIColor.lightGrayColor;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == 1 && !Settings.sharedInstance.isProOrFreeTrial) {
        return NSLocalizedString(@"yubikey_config_section_header_nfc_pro_only", @"NFC Yubikey (Pro Edition Only)");
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellNoYubiKey) {
        self.currentConfig.mode = kNoYubiKey;
    }
    else if (cell == self.cellNfcSlot1) {
        self.currentConfig.mode = kNfc;
        self.currentConfig.slot = kSlot1;
    }
    else if (cell == self.cellNfcSlot2) {
        self.currentConfig.mode = kNfc;
        self.currentConfig.slot = kSlot2;
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self bindUi];
    
    [self.navigationController popViewControllerAnimated:YES];
    
    if(self.onDone) {
        self.onDone(self.currentConfig);
    }
}

@end
