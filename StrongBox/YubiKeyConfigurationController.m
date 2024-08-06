//
//  YubiKeyConfigurationController.m
//  Strongbox
//
//  Created by Mark on 10/02/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "YubiKeyConfigurationController.h"
#import "AppPreferences.h"
#import "YubiManager.h"
#import "VirtualYubiKeys.h"
#import "Alerts.h"

@interface YubiKeyConfigurationController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellNoYubiKey;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNfcSlot1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNfcSlot2;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellMfiSlot1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellMfiSlot2;

@property YubiKeyHardwareConfiguration* currentConfig;
@property NSArray<VirtualYubiKey*>* virtualKeys;

@end

static NSString* const kVirtualYubiKeyCellId = @"VirtualYubiKeyCell";

@implementation YubiKeyConfigurationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:kVirtualYubiKeyCellId bundle:nil] forCellReuseIdentifier:kVirtualYubiKeyCellId];

    self.currentConfig = self.initialConfiguration ? [self.initialConfiguration clone] : [YubiKeyHardwareConfiguration defaults];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadVirtualYubiKeys)
                                               name:kVirtualYubiKeysChangedNotification
                                             object:nil];
    
    [self bindUi];
}

- (void)bindUi {
    self.cellNoYubiKey.accessoryType = (self.currentConfig == nil || self.currentConfig.mode == kNoYubiKey) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellNfcSlot1.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kNfc && self.currentConfig.slot == kSlot1) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellNfcSlot2.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kNfc && self.currentConfig.slot == kSlot2) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.cellMfiSlot1.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kMfi && self.currentConfig.slot == kSlot1) ?  UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellMfiSlot2.accessoryType = (self.currentConfig != nil && self.currentConfig.mode == kMfi && self.currentConfig.slot == kSlot2) ?  UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    self.cellNfcSlot1.userInteractionEnabled = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey];
    self.cellNfcSlot2.userInteractionEnabled = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey];
    self.cellNfcSlot1.textLabel.textColor = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey] ? nil : UIColor.lightGrayColor;
    self.cellNfcSlot2.textLabel.textColor = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey] ? nil : UIColor.lightGrayColor;

    self.cellMfiSlot1.userInteractionEnabled = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey];
    self.cellMfiSlot2.userInteractionEnabled = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey];
    self.cellMfiSlot1.textLabel.textColor = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey] ? nil : UIColor.lightGrayColor;
    self.cellMfiSlot2.textLabel.textColor = AppPreferences.sharedInstance.isPro && [self deviceAndContextSupportsHardwareYubiKey] ? nil : UIColor.lightGrayColor;

    [self reloadVirtualYubiKeys];
}

- (void)reloadVirtualYubiKeys {
    self.virtualKeys = VirtualYubiKeys.sharedInstance.snapshot;

    slog(@"Reloading Virtual Hardware Keys after changed: [%lu]", (unsigned long)self.virtualKeys.count);
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 3) {
        return self.virtualKeys.count + 1;
    }

    return [super tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 3) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kVirtualYubiKeyCellId forIndexPath:indexPath];
        cell.userInteractionEnabled = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        if (indexPath.row == 0) { 
            UITableViewCell* oldStaticCell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
            cell.textLabel.text = oldStaticCell.textLabel.text;

#ifndef IS_APP_EXTENSION
            cell.userInteractionEnabled = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.textColor = UIColor.systemBlueColor;
#else
            cell.userInteractionEnabled = NO;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
#endif
        }
        else {
            NSUInteger row = indexPath.row - 1;
            
            VirtualYubiKey* key = self.virtualKeys[row];
            cell.textLabel.text = key.name;
            cell.textLabel.textColor = nil;
            cell.userInteractionEnabled = YES;
            
            if (self.currentConfig.mode == kVirtual && [self.currentConfig.virtualKeyIdentifier isEqualToString:key.identifier]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            
#ifndef IS_APP_EXTENSION
            if (key.autoFillOnly) {
                cell.textLabel.textColor = UIColor.secondaryLabelColor;
                cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"yubikeys_virtual_autofill_only", @"%@ (AutoFill Only)"), key.name];
                cell.userInteractionEnabled = NO;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
#endif
        }
        
        return cell;

    }
    
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        #ifndef IS_APP_EXTENSION
        if(![YubiManager.sharedInstance yubiKeySupportedOnDevice]) {
            return NSLocalizedString(@"yubikey_config_section_header_nfc_device_not_supported", @"NFC Yubikey (NFC Not Supported on Device)");
        }
        
        if(!AppPreferences.sharedInstance.isPro) {
            return NSLocalizedString(@"yubikey_config_section_header_nfc_pro_only", @"NFC Yubikey (Pro Edition Only)");
        }
        #else
            return NSLocalizedString(@"yubikey_config_section_header_nfc_autofill_unavailable", @"NFC Yubikey (AutoFill Mode - NFC Unavailable)");
        #endif
    }

    if (section == 2) {
        #ifndef IS_APP_EXTENSION
        if(![YubiManager.sharedInstance yubiKeySupportedOnDevice]) {
            return NSLocalizedString(@"yubikey_config_section_header_lightning_device_not_supported", @"Lightning Yubikey (Lightning Not Supported on Device)");
        }
        
        if(!AppPreferences.sharedInstance.isPro) {
            return NSLocalizedString(@"yubikey_config_section_header_lightning_pro_only", @"Lightning Yubikey (Pro Edition Only)");
        }
        #else
            return NSLocalizedString(@"yubikey_config_section_header_lightning_autofill_unavailable", @"Lightning Yubikey (AutoFill Mode - Lightning Unavailable)");
        #endif
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 3) {
        if (indexPath.row == 0) {
#ifndef IS_APP_EXTENSION 
            [self performSegueWithIdentifier:@"segueToAddVirtual" sender:nil];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
#else
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
#endif
        }
        else {
            NSUInteger row = indexPath.row - 1;
            VirtualYubiKey* key = self.virtualKeys[row];
            
#ifndef IS_APP_EXTENSION
            if (key.autoFillOnly) {
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                return;
            }
#endif
            self.currentConfig.mode = kVirtual;
            self.currentConfig.virtualKeyIdentifier = key.identifier;
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

            [self bindUi];
            
            [self.navigationController popViewControllerAnimated:YES];

            if(self.onDone) {
                self.onDone(self.currentConfig);
            }
        }
    }
    else {
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
        else if (cell == self.cellMfiSlot1) {
            self.currentConfig.mode = kMfi;
            self.currentConfig.slot = kSlot1;
        }
        else if (cell == self.cellMfiSlot2) {
            self.currentConfig.mode = kMfi;
            self.currentConfig.slot = kSlot2;
        }
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        [self bindUi];
        
        [self.navigationController popViewControllerAnimated:YES];
        
        if(self.onDone) {
            self.onDone(self.currentConfig);
        }
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (indexPath.section == 3) {
        NSIndexPath* ip = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
        return [super tableView:tableView heightForRowAtIndexPath:ip];
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 3) {
        NSIndexPath* ip = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
        return [super tableView:tableView indentationLevelForRowAtIndexPath:ip];
    }
    
    return [super tableView:tableView indentationLevelForRowAtIndexPath:indexPath];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (indexPath.section == 3 && indexPath.row > 0) {
        UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                                title:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                                                              handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
                  message:NSLocalizedString(@"yubikey_config_are_you_sure_delete", @"Are you sure you want to delete this Virtual Hardware Key?")
                   action:^(BOOL response) {
                if (response) {
                    NSUInteger row = indexPath.row - 1;
                    VirtualYubiKey* key = self.virtualKeys[row];
                    [VirtualYubiKeys.sharedInstance deleteKey:key.identifier];
                }
            }];
        }];
        
        return @[removeAction];
    }
    else {
        return @[];
    }
}

- (BOOL)deviceAndContextSupportsHardwareYubiKey {
#ifndef IS_APP_EXTENSION
    return [YubiManager.sharedInstance yubiKeySupportedOnDevice];
#else
    
    return NO;
#endif
}

@end
