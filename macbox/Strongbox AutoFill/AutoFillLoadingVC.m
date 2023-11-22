//
//  AutoFillLoadingVC.m
//  MacBox
//
//  Created by Strongbox on 28/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AutoFillLoadingVC.h"

@interface AutoFillLoadingVC ()
@property (weak) IBOutlet NSProgressIndicator *spinner;

@end

@implementation AutoFillLoadingVC

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.spinner startAnimation:nil];
}

- (IBAction)onCancel:(id)sender {
    self.onCancelButton();
}

@end
