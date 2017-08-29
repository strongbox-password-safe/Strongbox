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

- (void)setDirty:(BOOL)dirty {
    [self synchronizeWindowTitleWithDocumentName];
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    NSString* freeTrialLiteSuffix = @"";
    
    if(![Settings sharedInstance].fullVersion) {
        if (![Settings sharedInstance].freeTrial) {
            freeTrialLiteSuffix = @" - LITE Version - Please Upgrade";
        }
        else {
            long daysLeft = (long)[Settings sharedInstance].freeTrialDaysRemaining;
            
            if(daysLeft < 15) {
                freeTrialLiteSuffix = [NSString stringWithFormat:@" - [Free Trial %ld Days Left]", daysLeft];
            }
        }
    }
    
    Document* doc = self.document;
    return [NSString stringWithFormat:@"%@%@%@", displayName, doc.dirty ? @" [*edited]" : @"", freeTrialLiteSuffix];
}

@end
