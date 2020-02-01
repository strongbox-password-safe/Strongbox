//
//  DatabasePropertiesController.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabasePropertiesController.h"
#import "DatabasePreferences.h"

@interface DatabasePropertiesController () <NSWindowDelegate>

@end

@implementation DatabasePropertiesController

- (void)cancel:(id)sender { // Pick up escape key
   [self.view.window close];
}
    
- (void)viewWillAppear {
    [super viewWillAppear];
    
    self.view.window.delegate = self; // Catch Window events like close / undo manager etc
}

- (void)setModel:(ViewModel *)model {
    NSTabViewItem* item = [self.tabView tabViewItemAtIndex:0];
    DatabasePreferences* preferences = (DatabasePreferences*)item.viewController;
    preferences.model = model;
}

@end
