//
//  PasswordStrengthUIHelper.m
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "PasswordStrengthUIHelper.h"
#import "PasswordStrengthTester.h"

@implementation PasswordStrengthUIHelper

+ (void)bindStrengthUI:(NSString *)password
                config:(PasswordStrengthConfig *)config
    emptyPwHideSummary:(BOOL)emptyPwHideSummary
                 label:(UILabel *)label
              progress:(UIProgressView *)progress {
    PasswordStrength* strength = [PasswordStrengthTester getStrength:password config:config];
    
    if ( emptyPwHideSummary && password.length == 0) {
        label.text = @" "; 
    }
    else {
        label.text = strength.summaryString;
    }

    double relativeStrength = MIN(strength.entropy / 128.0f, 1.0f); 
        
    double red = 1.0 - relativeStrength;
    double green = relativeStrength;

    progress.progress = relativeStrength;
    progress.progressTintColor = [UIColor colorWithRed:red green:green blue:0.0 alpha:1.0];
}

@end
