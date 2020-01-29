//
//  DatabasePropertiesController.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabasePropertiesController.h"
#import "DatabasePreferences.h"

@interface DatabasePropertiesController ()

@end

@implementation DatabasePropertiesController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSLog(@"viewDidLoad %@", self.tabViewItems);
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    NSLog(@"viewWillAppear %@", self.tabViewItems);
}
          

- (void)setModel:(DatabaseMetadata *)metadata {
    NSLog(@"setModel %@", self.tabViewItems);
    
    NSTabViewItem* item = [self.tabView tabViewItemAtIndex:0];
    DatabasePreferences* preferences = (DatabasePreferences*)item.viewController;
    preferences.metadata = metadata;
}

@end
