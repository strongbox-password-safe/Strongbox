//
//  WindowController.m
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "WindowController.h"
#import "Settings.h"
#import "Document.h"
#import "ViewController.h"
#import "LockScreenViewController.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@implementation WindowController

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    Document* doc = (Document*)self.document;
    NSMutableArray* statusii = NSMutableArray.array;
    if ( doc.viewModel.offlineMode ) {
        [statusii addObject:NSLocalizedString(@"database_offline_mode_window_suffix", @"Offline")];
    }
    if ( doc.viewModel.isEffectivelyReadOnly ) {
        [statusii addObject:NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read-Only")];
    }

    NSString* statusSuffix = @"";
    if ( statusii.firstObject ) {
        NSString* statusiiStrings = [statusii componentsJoinedByString:@", "];
        statusSuffix = [NSString stringWithFormat:@" (%@)", statusiiStrings];
    }
    
    NSString* freeTrialSuffix = @"";
    if(![Settings sharedInstance].fullVersion) {
        if (![Settings sharedInstance].freeTrial) {
            NSString* loc = NSLocalizedString(@"mac_free_trial_window_title_suffix", @" - (Pro Upgrade Available)");
            freeTrialSuffix = loc;
        }
        else {
            long daysLeft = (long)[Settings sharedInstance].freeTrialDaysRemaining;

            if(daysLeft < 1 || daysLeft > 88) {
                NSString* loc = NSLocalizedString(@"mac_free_trial_window_title_suffix", @" - (Pro Upgrade Available)");
                freeTrialSuffix = loc;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_pro_days_left_window_title_suffix_fmt", @" - [%ld Pro Days Left]");
                freeTrialSuffix = [NSString stringWithFormat:loc, daysLeft];
            }
        }
    }










    return [NSString stringWithFormat:@"%@%@%@", displayName, statusSuffix, freeTrialSuffix];
}

- (void)setDocument:(id)document {
    [super setDocument:document];
    
    if ( document ) {
        NSLog(@"WindowController::setDocument [%@] - [%@]", self.document, self.contentViewController);
        
        
        
        
        
        if ( self.contentViewController ) {
            if ( [self.contentViewController respondsToSelector:@selector(onDocumentLoaded)]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.contentViewController performSelector:@selector(onDocumentLoaded)];
                });
            }
            else {
                NSLog(@"Unknown Content View Controller in Set Document: [%@]", self.contentViewController.class);
            }
        }
        else {
            NSLog(@"WARNWARN: No Content View Controller");
        }
        
        
        

        Document* doc = (Document*)document;
        if ( doc.databaseMetadata ) {
            self.windowFrameAutosaveName = [NSString stringWithFormat:@"autosave-frame-%@", doc.databaseMetadata.uuid];
        }
    }
}

- (void)updateContentView { 
    NSLog(@"WindowController::updateContentView");
    
    Document* doc = self.document;
    
    CGRect oldFrame = self.contentViewController.view.frame;
    NSViewController* vc;
    
    if ( !doc || doc.isModelLocked ) {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        vc = [storyboard instantiateControllerWithIdentifier:@"LockScreen"];
    }
    else {
        if ( ( !Settings.sharedInstance.nextGenUI ) ) {
            NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
            vc = [storyboard instantiateControllerWithIdentifier:@"DatabaseViewerScreen"];
        }
        else {
            NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"NextGen" bundle:nil];
            vc = [storyboard instantiateControllerWithIdentifier:@"DatabaseViewerScreen"];
        }
    }
    
    
    
    [vc.view setFrame:oldFrame];

    self.contentViewController = vc;

    if ( doc ) { 
        if ( [self.contentViewController respondsToSelector:@selector(onDocumentLoaded)]) {
            [self.contentViewController performSelector:@selector(onDocumentLoaded)];
        }
    }
}

- (ViewModel *)viewModel {
    Document* doc = self.document;

    return doc ? doc.viewModel : nil;
}

- (DatabaseMetadata*)databaseMetadata {
    return self.viewModel ? self.viewModel.databaseMetadata : nil;
}




- (IBAction)onVCToggleOfflineMode:(id)sender {
    self.viewModel.offlineMode = !self.viewModel.offlineMode;
}

- (IBAction)onVCToggleReadOnly:(id)sender {
    self.viewModel.readOnly = !self.viewModel.readOnly;
}

- (IBAction)onVCToggleLaunchAtStartup:(id)sender {
    self.viewModel.launchAtStartup = !self.viewModel.launchAtStartup;
}

- (IBAction)onVCToggleStartInSearchMode:(id)sender {
    self.viewModel.startWithSearch = !self.viewModel.startWithSearch;
}

- (IBAction)onVCToggleShowEditToasts:(id)sender {
    self.viewModel.showChangeNotifications = !self.viewModel.showChangeNotifications;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL theAction = menuItem.action;


    
    if ( theAction == @selector(onVCToggleOfflineMode:)) {
        menuItem.state = self.databaseMetadata.offlineMode ? NSControlStateValueOn : NSControlStateValueOff;
        return !self.databaseMetadata.isLocalDeviceDatabase;
    }
    else if ( theAction == @selector(onVCToggleReadOnly:)) {
        menuItem.state = self.viewModel.isEffectivelyReadOnly ? NSControlStateValueOn : NSControlStateValueOff;
        return !self.viewModel.offlineMode; 
    }
    else if ( theAction == @selector(onVCToggleLaunchAtStartup:)) {
        menuItem.state = self.databaseMetadata.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleStartInSearchMode:)) {
        menuItem.state = self.viewModel.startWithSearch ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowEditToasts:)) {
        menuItem.state = self.viewModel.showChangeNotifications ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }

    return YES;
}



@end
