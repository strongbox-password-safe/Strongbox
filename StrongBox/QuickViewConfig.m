//
//  QuickViewConfig.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "QuickViewConfig.h"

@implementation QuickViewConfig

+ (instancetype)title:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image searchTerm:(NSString *)searchTerm {
    return [QuickViewConfig title:title subtitle:subtitle image:image searchTerm:searchTerm imageTint:nil];
}

+ (instancetype)title:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image searchTerm:(NSString *)searchTerm imageTint:(UIColor *)imageTint {
    QuickViewConfig* config = [[QuickViewConfig alloc] init];
    
    config.title = title;
    config.subtitle = subtitle;
    config.image = image;
    config.searchTerm = searchTerm;
    config.imageTint = imageTint;
    
    return config;
}

@end
