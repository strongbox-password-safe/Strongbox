//
//  YubiKeyMenuHelper.m
//  MacBox
//
//  Created by Strongbox on 11/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "HardwareKeyMenuHelper.h"
#import "YubiKeyConfiguration.h"
#import "HardwareKeyData.h"
#import "Settings.h"
#import "VirtualYubiKeys.h"
#import "NSData+Extensions.h"
#import "NSArray+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

#import "MacHardwareKeyManager.h"

@interface HardwareKeyMenuHelper ()

@property (weak) NSViewController* viewController;
@property (weak) NSPopUpButton *yubiKeyPopup;
@property YubiKeyConfiguration *currentlySetDatabaseConfiguration;
@property (nullable) HardwareKeyData* connectedYubiKey;
@property BOOL verifyMode;

@end

@implementation HardwareKeyMenuHelper

- (instancetype)initWithViewController:(NSViewController*)viewController 
                          yubiKeyPopup:(NSPopUpButton*)yubiKeyPopup
                  currentConfiguration:(YubiKeyConfiguration*)currentConfiguration
                            verifyMode:(BOOL)verifyMode {
    self = [super init];
    
    if (self) {
        self.viewController = viewController;
        self.yubiKeyPopup = yubiKeyPopup;
        self.currentlySetDatabaseConfiguration = currentConfiguration;
        self.verifyMode = verifyMode;
        self.selectedConfiguration = verifyMode ? nil : currentConfiguration;
    }
    
    return self;
}

- (void)scanForConnectedAndRefresh {
    self.connectedYubiKey = nil;
    
    [self.yubiKeyPopup.menu removeAllItems];
    
    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    
    [self.yubiKeyPopup.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];
    self.yubiKeyPopup.enabled = NO;
    
    [MacHardwareKeyManager.sharedInstance getAvailableKey:^(HardwareKeyData * _Nonnull yk) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onDoneScanningForConnectedHardwareKey:yk];
        });
    }];
}

- (void)onDoneScanningForConnectedHardwareKey:(HardwareKeyData*)yk {
    self.connectedYubiKey = yk;
    
    [self refreshHardwareKeyDropdownMenu];
}

- (void)addNoneProHardwareKeyMenuItem {
    [self.yubiKeyPopup.menu removeAllItems];
    NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"Hardware Key (Pro Only)");
    [self.yubiKeyPopup.menu addItemWithTitle:loc action:nil keyEquivalent:@""];
    [self.yubiKeyPopup selectItemAtIndex:0];
}

- (void)addNoHardwareKeyMenuItem {
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:NSLocalizedString(@"generic_none", @"None") action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.target = self;
}

- (void)addConfiguredButCRUnavailableHardwareKey:(YubiKeyConfiguration*)config {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_key_configured_but_cr_unavailable", @"🔴 Configured Key [CR Unavailable]");
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.representedObject = config;
    item.target = self;
}

- (void)addConfiguredButUnavailableHardwareKey:(YubiKeyConfiguration*)config {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_key_configured_but_disconnected", @"⚠️ Disconnected Key (Configured)");
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.representedObject = config;
    item.target = self;
}

- (void)addConnectedButCRUnsupported:(YubiKeyConfiguration*)config {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_key_connected_but_cr_unavailable", @"%@ [Slot %@ CR Unavailable]");
    NSString* fmt = [NSString stringWithFormat:loc, config.deviceSerial, @(config.slot)];
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:fmt action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.enabled = NO;
    item.representedObject = config;
    item.target = self;
}

- (void)addConfiguredAndReadyToGo:(YubiKeyConfiguration*)config {
    NSString* loc = [NSString stringWithFormat:NSLocalizedString(@"mac_hardware_key_configured_and_connected_slot_n_fmt", @"Connected Key Slot %@ (Configured)"), @(config.slot)];
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.representedObject = config;
    item.target = self;
}

- (void)addConnectedAndReadyToGo:(YubiKeyConfiguration*)config {
    NSString* loc = [NSString stringWithFormat:NSLocalizedString(@"mac_hardware_key_connected_slot_n_fmt", @"Connected Key Slot %@"), @(config.slot)];
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectYubiKeyConfiguration:) keyEquivalent:@""];
    item.representedObject = config;
    item.target = self;
}

- (void)addOptionToAddVirtualMenuItem {
#ifndef IS_APP_EXTENSION
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:NSLocalizedString(@"new_virtual_hardware_key_ellipsis", @"New Virtual Hardware Key...")
                                                         action:@selector(onAddNewVirtualHardwareKey)
                                                  keyEquivalent:@""];
    
#else
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:NSLocalizedString(@"new_virtual_hardware_key_ellipsis", @"New Virtual Hardware Key...")
                                                         action:nil
                                                  keyEquivalent:@""];
    
    item.enabled = NO;
#endif
    
    item.target = self;
}

- (void)addNoAvailableHardwareKeysMenuItem {
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"no_connected_keys_detected", @"No Connected Keys Detected")
                                                  action:nil
                                           keyEquivalent:@""];
    item.enabled = NO;
    [self.yubiKeyPopup.menu addItem:item];
}

- (void)addNoAvailableVirtualHardwareKeysMenuItem {
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"generic_none_available", @"None Available")
                                                  action:nil
                                           keyEquivalent:@""];
    item.enabled = NO;
    [self.yubiKeyPopup.menu addItem:item];
}

- (void)addHardwareKeyMenuOptions:(HardwareKeyData*)yk {
    YubiKeyConfiguration* configured = self.verifyMode ? nil : self.currentlySetDatabaseConfiguration;
    
    
    
    YubiKeyConfiguration* keyConfigurationSlot1 = [YubiKeyConfiguration realKeyWithSerial:yk.serial slot:1];
    BOOL slot1MatchesConfigured = [keyConfigurationSlot1 isEqual:configured];
    
    if ( slot1MatchesConfigured ) {
        if ( yk.slot1CrEnabled ) {
            [self addConfiguredAndReadyToGo:keyConfigurationSlot1];
        }
        else {
            [self addConfiguredButCRUnavailableHardwareKey:keyConfigurationSlot1];
        }
    }
    else {
        if ( yk.slot1CrEnabled ) {
            [self addConnectedAndReadyToGo:keyConfigurationSlot1];
        }
        else {
            [self addConnectedButCRUnsupported:keyConfigurationSlot1];
        }
    }
    
    
    
    YubiKeyConfiguration* keyConfigurationSlot2 = [YubiKeyConfiguration realKeyWithSerial:yk.serial slot:2];
    BOOL slot2MatchesConfigured = [keyConfigurationSlot2 isEqual:configured];
    
    if ( slot2MatchesConfigured ) {
        if ( yk.slot2CrEnabled ) {
            [self addConfiguredAndReadyToGo:keyConfigurationSlot2];
        }
        else {
            [self addConfiguredButCRUnavailableHardwareKey:keyConfigurationSlot2];
        }
    }
    else {
        if ( yk.slot2CrEnabled ) {
            [self addConnectedAndReadyToGo:keyConfigurationSlot2];
        }
        else {
            [self addConnectedButCRUnsupported:keyConfigurationSlot2];
        }
    }
    
    
    
    if (configured && !configured.isVirtual && !( slot1MatchesConfigured || slot2MatchesConfigured ) ) {
        [self addConfiguredButUnavailableHardwareKey:configured];
    }
}

- (void)refreshHardwareKeyDropdownMenu {
    if ( !Settings.sharedInstance.isPro ) {
        [self addNoneProHardwareKeyMenuItem];
        self.selectedConfiguration = nil;
        self.yubiKeyPopup.enabled = NO;
        return;
    }
    
    [self.yubiKeyPopup.menu removeAllItems];
    
    
    
    [self addNoHardwareKeyMenuItem];
    
    [self.yubiKeyPopup.menu addItem:NSMenuItem.separatorItem];
    
    
    
    [self.yubiKeyPopup.menu addItem:[self createHeaderItem:@"Hardware Keys"]];
    
    if ( self.connectedYubiKey ) {
        [self addHardwareKeyMenuOptions:self.connectedYubiKey];
    }
    else if ( !self.verifyMode && self.currentlySetDatabaseConfiguration && !self.currentlySetDatabaseConfiguration.isVirtual ) {
        [self addConfiguredButUnavailableHardwareKey:self.currentlySetDatabaseConfiguration];
    }
    else {
        [self addNoAvailableHardwareKeysMenuItem];
    }
    
    
    
    [self.yubiKeyPopup.menu addItem:NSMenuItem.separatorItem];
    
    [self.yubiKeyPopup.menu addItem:[self createHeaderItem:NSLocalizedString(@"virtual_hardware_keys", @"Virtual Hardware Keys")]];
    
    NSArray<VirtualYubiKey*>* virtuals = VirtualYubiKeys.sharedInstance.snapshot;
    
    if ( virtuals.count ) {
        for ( VirtualYubiKey* virtual in virtuals ) {
            [self addVirtualHardwareKeyMenuItem:virtual];
        }
    }
    else {
        [self addNoAvailableVirtualHardwareKeysMenuItem];
    }
    
    [self.yubiKeyPopup.menu addItem:NSMenuItem.separatorItem];
    
    [self addOptionToAddVirtualMenuItem];
    
    if ( self.selectedConfiguration ) {
        NSArray<NSMenuItem*>* items = self.yubiKeyPopup.menu.itemArray;
        for ( NSMenuItem* item in items ) {
            YubiKeyConfiguration* config = item.representedObject;
            if ( [self.selectedConfiguration isEqual:config] ) {
                [self.yubiKeyPopup selectItem:item];
                break;
            }
        }
    }
    else {
        [self.yubiKeyPopup selectItemAtIndex:0]; 
    }
    
    self.yubiKeyPopup.enabled = YES;
}

- (NSMenuItem*)createHeaderItem:(NSString*)title {
    NSMenuItem* header = [[NSMenuItem alloc] init];
    header.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{ NSFontAttributeName: FontManager.shared.headlineFont }];
    header.enabled = NO;
    return header;
}

#ifndef IS_APP_EXTENSION
- (void)onAddNewVirtualHardwareKey {
    __weak HardwareKeyMenuHelper* weakSelf = self;
    
    NSViewController* vc = [SwiftUIViewFactory getVirtualHardwareKeyCreateViewWithCompletion:^(BOOL userCancelled, NSString *name, NSString *secret, BOOL fixedLength) {
        if ( weakSelf.dismissViewControllerOverride ) {
            weakSelf.dismissViewControllerOverride();
        }
        else {
            NSViewController* toDismiss = weakSelf.viewController.presentedViewControllers.firstObject;
            
            if ( toDismiss ) {
                NSViewController* sheet = weakSelf.viewController.presentedViewControllers.firstObject;
                [Utils dismissViewControllerCorrectly:sheet];
            }
        }
        
        if ( !userCancelled ) {
            [weakSelf addNewVirtualKey:name secret:secret fixedLength:fixedLength];
        }
        else {
            [weakSelf refreshHardwareKeyDropdownMenu];
        }
    }];
    
    if ( self.showViewControllerOverride ) {
        self.showViewControllerOverride(vc);
    }
    else {
        [self.viewController presentViewControllerAsSheet:vc];
    }
}
#endif

- (void)addNewVirtualKey:(NSString*)name secret:(NSString*)secret fixedLength:(BOOL)fixedLength {
    NSData* yubikeySecretData = secret.dataFromHex;
    
    NSString* hexSecret = [NSString stringWithFormat:@"%@%@", fixedLength ? @"P" : @"", yubikeySecretData.upperHexString];
    
    VirtualYubiKey *key = [VirtualYubiKey keyWithName:name secret:hexSecret autoFillOnly:NO];
    
    [VirtualYubiKeys.sharedInstance addKey:key];
    
    [self refreshHardwareKeyDropdownMenu];
}

- (NSMenuItem*)addVirtualHardwareKeyMenuItem:(VirtualYubiKey*)key {
    NSString* loc = key.name;
    
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc
                                                         action:@selector(onSelectVirtualHardwareKey:)
                                                  keyEquivalent:@""];

    YubiKeyConfiguration* config = [YubiKeyConfiguration virtualKeyWithSerial:key.identifier];
    
    item.representedObject = config;
    item.target = self;
    
    return item;
}

- (void)onSelectVirtualHardwareKey:(id)sender {
    NSMenuItem* item = (NSMenuItem*)sender;
    YubiKeyConfiguration* config = item.representedObject;
    
    if ( ( NSApp.currentEvent.modifierFlags & NSEventModifierFlagOption ) == NSEventModifierFlagOption ) {
        [self onDeleteVirtual:config];
    }
    else {
        [self onSelectYubiKeyConfiguration:sender];
    }
}

- (void)onSelectYubiKeyConfiguration:(id)sender {
    NSMenuItem* menuItem = sender;
    YubiKeyConfiguration* configuration = menuItem.representedObject;
    self.selectedConfiguration = configuration;
}

- (void)onDeleteVirtual:(YubiKeyConfiguration*)config {
    VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:config.deviceSerial];
    
    NSString* loc = NSLocalizedString(@"ays_delete_virtual_hardware_key_fmt", @"Are you sure you would like to delete the virtual hardware key '%@'?");
    
    [MacAlerts areYouSure:[NSString stringWithFormat:loc, key.name]
                   window:self.alertWindowOverride ? self.alertWindowOverride : self.viewController.view.window
               completion:^(BOOL response) {
        if ( response ) {
            [VirtualYubiKeys.sharedInstance deleteKey:key.identifier];
            
            NSArray<MacDatabasePreferences*> *dbsUsingIt = [MacDatabasePreferences.allDatabases filter:^BOOL(MacDatabasePreferences * _Nonnull obj) {
                return [obj.yubiKeyConfiguration isEqual:config];
            }];
            
            for ( MacDatabasePreferences *db in dbsUsingIt ) {
                db.yubiKeyConfiguration = nil;
            }
            
            [self refreshHardwareKeyDropdownMenu];
        }
    }];
}

@end
