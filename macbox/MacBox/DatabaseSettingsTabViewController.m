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

@interface DatabaseSettingsTabViewController () <NSWindowDelegate>

@property ViewModel* vm;
@property NSInteger initialTab;

@end

@implementation DatabaseSettingsTabViewController

- (void)cancel:(id)sender { 
   [self.view.window close];
}
    
- (void)viewWillAppear {
    [super viewWillAppear];
    
    self.view.window.delegate = self; 
    
    [self initializeTabs];
}

- (void)setModel:(ViewModel *)model initialTab:(NSInteger)initialTab {
    self.vm = model;
    self.initialTab = initialTab;
}

- (void)initializeTabs {
    NSTabViewItem* item = self.tabViewItems[0];
    
    DatabaseConvenienceUnlockPreferences* preferences = (DatabaseConvenienceUnlockPreferences*)item.viewController;
    preferences.model = self.vm;

    NSTabViewItem* item2 = self.tabViewItems[1];
    
    if (!AutoFillManager.sharedInstance.isPossible) {
        [self removeTabViewItem:item2];
    }
    else {
        NSViewController* iv = item2.viewController;
        AutoFillSettingsViewController* af = (AutoFillSettingsViewController*)iv;
        af.model = self.vm;
    }
    
    if (AutoFillManager.sharedInstance.isPossible) {
        self.selectedTabViewItemIndex = self.initialTab;
    }
}









@end
