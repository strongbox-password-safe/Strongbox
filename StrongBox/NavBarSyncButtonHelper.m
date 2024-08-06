//
//  NavBarSyncButtonHelper.m
//  Strongbox
//
//  Created by Strongbox on 15/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "NavBarSyncButtonHelper.h"
#import "SyncManager.h"

@implementation NavBarSyncButtonHelper

+ (UIButton*)createSyncButton:(id)target action:(SEL)action {
    UIButton* ret = [[UIButton alloc] init];
    [ret addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [ret setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];
   
    return ret;
}

+ (BOOL)bindSyncToobarButton:(Model*)model button:(UIButton*)button {
    SyncStatus* syncStatus = [SyncManager.sharedInstance getSyncStatus:model.metadata];
    
    [self runSpinAnimationOnView:button spin:NO];
    [button setTintColor:UIColor.clearColor];
    button.enabled = NO;
    
    if ( model.isRunningAsyncUpdate || syncStatus.state == kSyncOperationStateInProgress ) {
        [self runSpinAnimationOnView:button spin:YES];
        [button setTintColor:UIColor.systemBlueColor];
        button.enabled = YES; 
        return YES;
    }
    else {
        if ( model.lastAsyncUpdateResult && !model.lastAsyncUpdateResult.success ) {
            [self runSpinAnimationOnView:button spin:NO];
            [button setTintColor:UIColor.systemRedColor];
            button.enabled = YES;
            return YES;
        }
        else if ( syncStatus.state == kSyncOperationStateError )  {
            [self runSpinAnimationOnView:button spin:NO];
            [button setTintColor:UIColor.systemRedColor];
            button.enabled = YES;
            return YES;
        }





    }
    
    return NO; 
}

+ (void)runSpinAnimationOnView:(UIView*)view spin:(BOOL)spin {
    
    
    [view.layer removeAllAnimations];
    
    if ( spin ) {
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
        rotationAnimation.duration = 1.25f;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = HUGE_VALF;
        [rotationAnimation setRemovedOnCompletion:NO]; 
        
        [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    }
}

@end
