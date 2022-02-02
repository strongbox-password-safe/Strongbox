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

    progress.doubleValue = relativeStrength * 100.0f;

    if ( colorize ) {
        CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
        [colorPoly setDefaults];

        double red = 1.0 - relativeStrength;
        double green = relativeStrength;

        CIVector *redVector = [CIVector vectorWithX:red Y:0 Z:0 W:0];
        CIVector *greenVector = [CIVector vectorWithX:green Y:0 Z:0 W:0];
        CIVector *blueVector = [CIVector vectorWithX:0 Y:0 Z:0 W:0];

        [colorPoly setValue:redVector forKey:@"inputRedCoefficients"];
        [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
        [colorPoly setValue:blueVector forKey:@"inputBlueCoefficients"];
        
        [progress setContentFilters:@[colorPoly]];
    }
}

@end
