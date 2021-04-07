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

@interface DatabaseSettingsTabViewController () <NSWindowDelegate>

@property DatabaseModel* databaseModel;
@property DatabaseMetadata* databaseMetadata;
@property NSInteger initialTab;

@end

@implementation DatabaseSettingsTabViewController

- (void)cancel:(id)sender { 
   [self.view.window close];
}

- (void)viewWillAppear {
    [super viewWillAppear];    
    self.view.window.delegate = self; 
}

- (void)setModel:(DatabaseModel *)databaseModel databaseMetadata:(DatabaseMetadata *)databaseMetadata initialTab:(NSInteger)initialTab {
    self.databaseModel = databaseModel;
    self.databaseMetadata = databaseMetadata;
    self.initialTab = initialTab;
    
    [self initializeTabs];
}

- (void)initializeTabs {
    NSTabViewItem* generalItem = self.tabViewItems[0];
    NSTabViewItem* convenienceUnlockItem = self.tabViewItems[1];
    NSTabViewItem* autoFillItem = self.tabViewItems[2];

    GeneralDatabaseSettings* general = (GeneralDatabaseSettings*)generalItem.viewController;
    general.databaseModel = self.databaseModel;
    general.databaseMetadata = self.databaseMetadata;

    DatabaseConvenienceUnlockPreferences* preferences = (DatabaseConvenienceUnlockPreferences*)convenienceUnlockItem.viewController;
    preferences.databaseModel = self.databaseModel;
    preferences.databaseMetadata = self.databaseMetadata;

    
    if (!AutoFillManager.sharedInstance.isPossible) {
        [self removeTabViewItem:autoFillItem];
    }
    else {
        NSViewController* iv = autoFillItem.viewController;
        AutoFillSettingsViewController* af = (AutoFillSettingsViewController*)iv;
        af.databaseModel = self.databaseModel;
        af.databaseMetadata = self.databaseMetadata;
    }
    
    if (AutoFillManager.sharedInstance.isPossible) {
        self.selectedTabViewItemIndex = self.initialTab;
    }
}









@end
