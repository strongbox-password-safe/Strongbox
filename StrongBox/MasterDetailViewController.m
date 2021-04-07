//
//  MasterDetailViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 04/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "MasterDetailViewController.h"
#import <ISMessages/ISMessages.h>
#import "BrowseSafeView.h"
#import "ItemDetailsViewController.h"
#import "Alerts.h"
#import "AppPreferences.h"

@interface MasterDetailViewController () <UISplitViewControllerDelegate>

@property BOOL cancelOtpTimer;
@property (readonly) UIViewController* masterVisibleViewController;
@property (readonly) UIViewController* detailVc;

@end

@implementation MasterDetailViewController

- (void)dealloc {
    NSLog(@"DEALLOC [%@]", self);
    
    [self unListenToNotifications];
}













- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    self.cancelOtpTimer = NO;
    [self startOtpRefresh];
    
    [self.viewModel restartBackgroundAudit];
    
    [self listenToNotifications];
}

- (void)listenToNotifications {
    [self unListenToNotifications];
    
    NSLog(@"MasterDetailViewController: listenToNotifications");
    
    __weak MasterDetailViewController* weakSelf = self;
    
    [NSNotificationCenter.defaultCenter addObserver:weakSelf
                                           selector:@selector(onAsyncUpdateDone:)
                                               name:kAsyncUpdateDone
                                             object:nil];
}

- (void)unListenToNotifications {
    NSLog(@"MasterDetailViewController: unListenToNotifications");
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:kAsyncUpdateDone object:nil];
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController
collapseSecondaryViewController:(UIViewController *)secondaryViewController
  ontoPrimaryViewController:(UIViewController *)primaryViewController {
    return YES;
}

- (void)onClose {
    NSLog(@"MasterDetailViewController: onClose");
    
    [self killOtpTimer];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kMasterDetailViewCloseNotification object:nil];

    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)killOtpTimer {
    self.cancelOtpTimer = YES;
}

- (void)startOtpRefresh {



    [NSNotificationCenter.defaultCenter postNotificationName:kCentralUpdateOtpUiNotification object:nil];

    if (!self.cancelOtpTimer) {
        __weak MasterDetailViewController* weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf startOtpRefresh];
        });
    }
}



- (void)onAsyncUpdateDone:(id)sender {
    AsyncUpdateResult* result = self.viewModel.lastAsyncUpdateResult;
    if ( !result ) {
        return;
    }

    [self onUpdateDoneCommonCompletion:result.success localWasChanged:result.localWasChanged userCancelled:result.userCancelled userInteractionRequired:result.userInteractionRequired error:result.error];
}

- (void)onUpdateDoneCommonCompletion:(BOOL)success localWasChanged:(BOOL)localWasChanged userCancelled:(BOOL)userCancelled userInteractionRequired:(BOOL)userInteractionRequired error:(NSError*)error {
    if ( success ) {
        if ( localWasChanged ) {
            NSLog(@"MasterDetailViewController::onAsyncUpdateDone - Database was changed by external actor reloading...");
            [self.viewModel reloadDatabaseFromLocalWorkingCopy:self completion:nil];
        }
    }
    else {
        if ( userInteractionRequired ) { 
            NSLog(@"MasterDetailViewController::onAsyncUpdateDone - User Interaction is Required - [%@]", self.masterVisibleViewController);

            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts yesNo:self.masterVisibleViewController 
                        title:NSLocalizedString(@"sync_status_user_interaction_required_prompt_title", @"Assistance Required")
                      message:NSLocalizedString(@"sync_status_user_interaction_required_prompt_yes_or_no", @"There was a problem updating your database and your assistance is required to resolve. Would you like to resolve this problem now?")
                       action:^(BOOL response) {
                    if ( response ) {
                        [self performSynchronousUpdate];
                    }
                }];
            });
        }
        else if ( error || userCancelled ) {
            
            
            

            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts error:self.masterVisibleViewController
                        title:NSLocalizedString(@"sync_status_error_updating_title", @"Error Updating")
                        error:error
                   completion:^{
                    [Alerts twoOptions:self.masterVisibleViewController
                                 title:NSLocalizedString(@"sync_status_error_updating_title", @"Error Updating")
                               message:NSLocalizedString(@"sync_status_error_updating_try_again_prompt", @"There was an error updating your database. Would you like to try updating again, or would you prefer to revert to the latest successful update?")
                     defaultButtonText:NSLocalizedString(@"sync_status_error_updating_try_again_action", @"Try Again")
                      secondButtonText:NSLocalizedString(@"sync_status_error_updating_revert_action", @"Revert to Latest")
                                action:^(BOOL response) {
                        if ( response ) {
                            [self performSynchronousUpdate];
                        }
                        else {
                            [self.viewModel reloadDatabaseFromLocalWorkingCopy:self completion:nil];
                        }
                    }];
                }];
            });
        }
    }
}

- (UIViewController *)masterVisibleViewController { 
    UINavigationController *masterVC = [self.viewControllers firstObject];
    
    return masterVC.visibleViewController;
}

- (void)performSynchronousUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *masterVC = [self.viewControllers firstObject];
        UIViewController* topVc = masterVC.topViewController;
        
        if ( [topVc isKindOfClass:BrowseSafeView.class]) {
            BrowseSafeView* browse = (BrowseSafeView*)topVc;
            [browse performSynchronousUpdate];
            return;
        }
        
        if ( [topVc isKindOfClass:UINavigationController.class] ) { 
            UINavigationController* nav = (UINavigationController*)masterVC.topViewController;
            topVc = nav.topViewController;
        }
        
        if ( [topVc isKindOfClass:ItemDetailsViewController.class]) {
            ItemDetailsViewController* details = (ItemDetailsViewController*)topVc;
            [details performSynchronousUpdate];
        }
    });
}

@end
