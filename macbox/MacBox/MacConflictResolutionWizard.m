//
//  MacConflictResolutionWizard.m
//  MacBox
//
//  Created by Strongbox on 06/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacConflictResolutionWizard.h"
#import "Settings.h"

@interface MacConflictResolutionWizard ()

@property (weak) IBOutlet NSButton *buttonSyncLater;
@property (weak) IBOutlet NSButton *buttonCompareFirst;

@end

@implementation MacConflictResolutionWizard

+ (instancetype)fromStoryboard {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"MacConflictResolutionWizard" bundle:nil];
    
    MacConflictResolutionWizard *ret = [storyboard instantiateInitialController];
    
    return ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.buttonSyncLater.hidden = YES;
    self.buttonCompareFirst.hidden = !Settings.sharedInstance.isPro;
}

- (IBAction)onCancel:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardCancel);
    }
}

- (IBAction)onAutoMerge:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultAutoMerge);
    }
}

- (IBAction)onSyncLater:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultSyncLater);
    }
}

- (IBAction)onForcePush:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultForcePushLocal);
    }
}

- (IBAction)onForcePull:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultForcePullRemote);
    }
}

- (IBAction)onAlwaysAutoMerge:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultAlwaysAutoMerge);
    }
}

- (IBAction)onCompare:(id)sender {
    [self dismissController:self];
    
    if ( self.completion ) {
        self.completion(kConflictWizardResultCompare);
    }
}

@end
