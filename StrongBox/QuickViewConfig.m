//
//  QuickViewConfig.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "QuickViewConfig.h"

@implementation QuickViewConfig

+ (instancetype)title:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image searchTerm:(NSString *)searchTerm {
    QuickViewConfig* config = [[QuickViewConfig alloc] init];
    
    config.title = title;
    config.subtitle = subtitle;
    config.image = image;
    config.searchTerm = searchTerm;
    
    return config;
}

@end
