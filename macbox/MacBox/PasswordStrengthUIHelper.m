//
//  PasswordStrengthUIHelper.m
//  MacBox
//
//  Created by Strongbox on 02/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "PasswordStrengthUIHelper.h"
#import "PasswordStrengthTester.h"
#import <CoreImage/CoreImage.h>

@implementation PasswordStrengthUIHelper

+ (void)bindPasswordStrength:(NSString*)pw
               labelStrength:(NSTextField*)labelStrength
                    progress:(NSProgressIndicator*)progress {
    [PasswordStrengthUIHelper bindPasswordStrength:pw labelStrength:labelStrength progress:progress colorize:YES];
}

+ (void)bindPasswordStrength:(NSString*)pw
               labelStrength:(NSTextField*)labelStrength
                    progress:(NSProgressIndicator*)progress
                    colorize:(BOOL)colorize {
    PasswordStrength* strength = [PasswordStrengthTester getStrength:pw config:PasswordStrengthConfig.defaults]; 

    labelStrength.stringValue = strength.summaryString;

    double relativeStrength = MIN(strength.entropy / 128.0f, 1.0f); 



















    progress.doubleValue = 0.0f;
    
    if ( colorize ) {
        double red = 1.0 - relativeStrength;
        double green = relativeStrength;
        
        CIColor* col = [CIColor colorWithRed:red green:green blue:0];
        CIFilter* fil = [CIFilter filterWithName:@"CIColorMonochrome" withInputParameters:@{ kCIInputColorKey : col }];
        
        [progress setContentFilters:@[fil]];
    }
    
    progress.doubleValue = relativeStrength * 100.0f;

}

@end
