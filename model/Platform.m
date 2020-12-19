//
//  Platform.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "Platform.h"

@implementation Platform

+ (instancetype)sharedInstance {
    static Platform *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Platform alloc] init];
    });
    return sharedInstance;
}

- (BOOL)isSimulator {
    return TARGET_OS_SIMULATOR != 0;
}

@end
