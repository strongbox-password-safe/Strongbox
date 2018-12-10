//
//  WindowController.m
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "WindowController.h"
#import "Document.h"
#import "Settings.h"

@interface WindowController ()

@end

@implementation WindowController

- (void)windowDidLoad {
    self.shouldCascadeWindows = YES;
    
    [super windowDidLoad];
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    NSString* freeTrialLiteSuffix = @"";
        
    if(![Settings sharedInstance].fullVersion) {
        if (![Settings sharedInstance].freeTrial) {
            freeTrialLiteSuffix = @" - (Pro Upgrade Available)";
        }
        else {
            long daysLeft = (long)[Settings sharedInstance].freeTrialDaysRemaining;
            
            if(daysLeft < 15) {
                freeTrialLiteSuffix = [NSString stringWithFormat:@" - [%ld 'Pro' Days Left]", daysLeft];
            }
        }
    }
    
    return [NSString stringWithFormat:@"%@%@", displayName, freeTrialLiteSuffix];
}

@end
