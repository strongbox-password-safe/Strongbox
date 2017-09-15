//
//  PasswordGenerationSettings.m
//  Strongbox
//
//  Created by Mark on 13/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationSettings.h"

@implementation PasswordGenerationSettings

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.navigationController.toolbar.hidden = YES;
}

@end
