//
//  UIColorExtensions.h
//  Strongbox
//
//  Created by Strongbox on 18/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (Extensions)

- (instancetype)interpolateRGBColorTo:(UIColor*)end fraction:(CGFloat)fraction;
- (instancetype)interpolateHSVColorFrom:(UIColor *)end fraction:(CGFloat)fraction;

+ (UIColor*)getSuccessGreenToRedColor:(CGFloat)success;

@end

NS_ASSUME_NONNULL_END
