//
//  DatabasePropertiesController.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseSettingsTabViewController.h"
#import "DatabaseConvenienceUnlockPreferences.h"
#import "AutoFillSettingsViewController.h"
#import "AutoFillManager.h"
#import "GeneralDatabaseSettings.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface DatabaseSettingsTabViewController () <NSWindowDelegate>

@property ViewModel* viewModel;
@property NSInteger initialTab;

@property (readonly) BOOL encryptionChanged;
@property EncryptionSettings* encryptionSettings;
@end

@implementation DatabaseSettingsTabViewController

+ (instancetype)fromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"DatabaseProperties" bundle:nil];
    return (DatabaseSettingsTabViewController*)[sb instantiateInitialController];
}

- (BOOL)encryptionChanged {
    return self.encryptionSettings.isDirty;
}

- (void)promptToApplyChanges:(void (^)(BOOL cancelled))completion {
    [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"generic_apply_changes", @"Apply Changes")
                    informativeText:NSLocalizedString(@"are_you_sure_change_encryption_settings", @"Are you sure you want to change your database encryption settings?")
                  option1AndDefault:NSLocalizedString(@"generic_apply_changes", @"Apply Changes")
                            option2:NSLocalizedString(@"discard_changes", @"Discard Changes")
                             window:self.view.window
                         completion:^(int response) {
        if ( response == 0 ) {
            [self.encryptionSettings applyCurrentChanges];
            completion(NO);
        }
        else if ( response == 1) {
            [self.encryptionSettings discardCurrentChanges];
            completion(NO);
        }
        else {
            completion(YES);
        }
    }];
}

- (void)cancel:(id)sender { 
    if ( self.encryptionChanged ) {
        [self promptToApplyChanges:^(BOOL cancelled) {
            if ( !cancelled ) {
                [self.view.window close];
            }
        }];
    }
    else {
        [self.view.window close];
    }
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    if ( self.encryptionChanged ) {
        [self promptToApplyChanges:^(BOOL cancelled) {
            if ( !cancelled ) {
                [self.tabView selectTabViewItem:tabViewItem];
            }
        }];
        return NO;
    }
    else {
        return [super tabView:tabView shouldSelectTabViewItem:tabViewItem];
    }
}

- (void)viewWillAppear {
    [super viewWillAppear];    
    self.view.window.delegate = self; 
}

- (void)setModel:(ViewModel *)model initialTab:(DatabaseSettingsInitialTab)initialTab {
    self.viewModel = model;
    self.initialTab = initialTab;
    
    [self initializeTabs];
    
    if ( !Settings.sharedInstance.nextGenUI ) {
        [self removeTabViewItem:self.tabViewItems[4]];
    }
}

- (void)initializeTabs {
    NSTabViewItem* generalItem = self.tabViewItems[0];
    NSTabViewItem* sideBarItem = self.tabViewItems[1];
    NSTabViewItem* convenienceUnlockItem = self.tabViewItems[2];
    NSTabViewItem* autoFillItem = self.tabViewItems[3];
    NSTabViewItem* auditItem = self.tabViewItems[4];
    NSTabViewItem* encryption = self.tabViewItems[5];
    NSTabViewItem* advanced = self.tabViewItems[6];

    GeneralDatabaseSettings* general = (GeneralDatabaseSettings*)generalItem.viewController;
    general.model = self.viewModel;

    SideBarSettings* sideBarSettings = (SideBarSettings*)sideBarItem.viewController;
    sideBarSettings.model = self.viewModel;
        
    DatabaseConvenienceUnlockPreferences* preferences = (DatabaseConvenienceUnlockPreferences*)convenienceUnlockItem.viewController;
    preferences.model = self.viewModel;

    NSViewController* iv = autoFillItem.viewController;
    AutoFillSettingsViewController* af = (AutoFillSettingsViewController*)iv;
    af.model = self.viewModel;

    AuditConfigurationViewController* audit = (AuditConfigurationViewController*)auditItem.viewController;
    audit.database = self.viewModel;

    self.encryptionSettings = (EncryptionSettings*)encryption.viewController;
    self.encryptionSettings.model = self.viewModel;

    AdvancedDatabasePreferences* advancedPreferences = (AdvancedDatabasePreferences*)advanced.viewController;
    advancedPreferences.model = self.viewModel;

    self.selectedTabViewItemIndex = self.initialTab;
}

@end
