//
//  UIColorExtensions.m
//  Strongbox
//
//  Created by Strongbox on 18/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UIColor+Extensions.h"

@implementation UIColor (Extensions)

// Inspired by https://stackoverflow.com/questions/22868182/uicolor-transition-based-on-progress-value

- (instancetype)interpolateRGBColorTo:(UIColor*)end fraction:(CGFloat)fraction {
    CGFloat f = MIN(MAX(0, fraction), 1);

    const CGFloat *c1 = CGColorGetComponents(self.CGColor);
    const CGFloat *c2 = CGColorGetComponents(end.CGColor);

    const CGFloat r = c1[0] + (c2[0] - c1[0]) * f;
    const CGFloat g = c1[1] + (c2[1] - c1[1]) * f;
    const CGFloat b = c1[2] + (c2[2] - c1[2]) * f;
    const CGFloat a = c1[3] + (c2[3] - c1[3]) * f;

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

- (UIColor *)interpolateHSVColorFrom:(UIColor *)end fraction:(CGFloat)fraction {
    fraction = MAX(0, fraction);
    fraction = MIN(1, fraction);

    CGFloat h1,s1,v1,a1;
    [self getHue:&h1 saturation:&s1 brightness:&v1 alpha:&a1];

    CGFloat h2,s2,v2,a2;
    [end getHue:&h2 saturation:&s2 brightness:&v2 alpha:&a2];

    CGFloat h = h1 + (h2 - h1) * fraction;
    CGFloat s = s1 + (s2 - s1) * fraction;
    CGFloat v = v1 + (v2 - v1) * fraction;
    CGFloat a = a1 + (a2 - a1) * fraction;

    return [UIColor colorWithHue:h saturation:s brightness:v alpha:a];
}

+ (UIColor *)getSuccessGreenToRedColor:(CGFloat)success {
    return [UIColor.systemRedColor interpolateHSVColorFrom:UIColor.systemGreenColor fraction:success];
}

@end
