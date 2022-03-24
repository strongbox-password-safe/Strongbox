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

@end

@implementation DatabaseSettingsTabViewController

+ (instancetype)fromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"DatabaseProperties" bundle:nil];
    return (DatabaseSettingsTabViewController*)[sb instantiateInitialController];
}

- (void)cancel:(id)sender { 
   [self.view.window close];
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
    NSTabViewItem* advanced = self.tabViewItems[5];

    GeneralDatabaseSettings* general = (GeneralDatabaseSettings*)generalItem.viewController;
    general.model = self.viewModel;
    
    SideBarSettings* sideBarSettings = (SideBarSettings*)sideBarItem.viewController;
    sideBarSettings.model = self.viewModel;
        
    DatabaseConvenienceUnlockPreferences* preferences = (DatabaseConvenienceUnlockPreferences*)convenienceUnlockItem.viewController;
    preferences.model = self.viewModel;

    AuditConfigurationViewController* audit = (AuditConfigurationViewController*)auditItem.viewController;
    audit.database = self.viewModel;
    
    AdvancedDatabasePreferences* advancedPreferences = (AdvancedDatabasePreferences*)advanced.viewController;
    advancedPreferences.model = self.viewModel;

    NSViewController* iv = autoFillItem.viewController;
    AutoFillSettingsViewController* af = (AutoFillSettingsViewController*)iv;
    af.model = self.viewModel;

    self.selectedTabViewItemIndex = self.initialTab;
}

@end
