//
//  LastCrashReportModule.m
//  Strongbox
//
//  Created by Strongbox on 02/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "LastCrashReportModule.h"
#import "GenericOnboardingViewController.h"
#import "StrongboxiOSFilesManager.h"
#import "DebugHelper.h"
#import "ClipboardManager.h"

@implementation LastCrashReportModule

- (nonnull instancetype)initWithModel:(Model *)model {
    self = [super init];
    if (self) {

    }
    return self;
}

- (BOOL)shouldDisplay {
    
    
    

    if ( [NSFileManager.defaultManager fileExistsAtPath:StrongboxFilesManager.sharedInstance.crashFile.path] ) {
        [NSFileManager.defaultManager removeItemAtURL:StrongboxFilesManager.sharedInstance.archivedCrashFile error:nil];
        [NSFileManager.defaultManager moveItemAtURL:StrongboxFilesManager.sharedInstance.crashFile toURL:StrongboxFilesManager.sharedInstance.archivedCrashFile error:nil];

        NSData* data = [NSData dataWithContentsOfURL:StrongboxFilesManager.sharedInstance.archivedCrashFile];
        NSString* crashStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
        return YES;
    }
    
    return NO;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"GenericOnboardSlide" bundle:nil];
    GenericOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.header = NSLocalizedString(@"crash_diagnostics_share_last_title", @"Share Crash Diagnostics?");
    vc.message = NSLocalizedString(@"crash_diagnostics_share_last_message", @"It looks like Strongbox had a crash last time. Would you be so kind as to share the diagnostics with Strongbox Support?\n\nPlease mail to support@strongboxsafe.com");
    vc.image = [UIImage imageNamed:@"crash-bug"];
    vc.onDone = onDone;
    vc.button1 = NSLocalizedString(@"crash_diagnostics_share_action", @"Share");
    vc.button2 = NSLocalizedString(@"crash_diagnostics_copy_action", @"Copy to Clipboard");

    __weak id weakSelf = self;
    vc.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        slog(@"onButtonClicked: %ld", (long)buttonIdCancelIsZero);
        
        if ( buttonIdCancelIsZero == 1 ) {
            [weakSelf sharePreviousCrash:viewController onDone:onDone];
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            [weakSelf copyPreviousCrashToClipboard];
            
            onDone(NO, NO);
        }
        else {
            onDone(NO, NO);
        }
    };

    return vc;
}

- (void)getCrashMessage:(void(^)(NSString* message))completion {
    [DebugHelper getCrashEmailDebugString:^(NSString * _Nonnull debugInfo) {
        NSString* loc = NSLocalizedString(@"safes_vc_please_send_crash_report", @"Please send this crash to support@strongboxsafe.com");
        
        NSString* message = [NSString stringWithFormat:@"%@\n\n%@", loc, debugInfo];
        
        completion ( message );
    }];
}

- (void)sharePreviousCrash:(UIViewController*)viewController onDone:(OnboardingModuleDoneBlock  _Nonnull)onDone {
    [self getCrashMessage:^(NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sharePreviousCrashWithDebugInfo:viewController message:message onDone:onDone];
        });
    }];
}

- (void)sharePreviousCrashWithDebugInfo:(UIViewController*)viewController message:(NSString*)message onDone:(OnboardingModuleDoneBlock  _Nonnull)onDone  {
    NSArray *activityItems = @[
                               message];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];

    
    
    activityViewController.popoverPresentationController.sourceView = viewController.view;
    activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(viewController.view.bounds), CGRectGetMidY(viewController.view.bounds),0,0);
    activityViewController.popoverPresentationController.permittedArrowDirections = 0L; 
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        onDone(NO, NO);
    }];


    
    [viewController presentViewController:activityViewController animated:YES completion:nil];
}

- (void)copyPreviousCrashToClipboard {
    [self getCrashMessage:^(NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{ 
            [ClipboardManager.sharedInstance copyStringWithNoExpiration:message];
        });
    }];
 }

@end
