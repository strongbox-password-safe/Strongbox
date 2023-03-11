//
//  Platform.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Platform.h"

@implementation Platform

+ (BOOL)isSimulator {
    return TARGET_OS_SIMULATOR != 0;
}

@end
