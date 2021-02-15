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

+ (BOOL)iOS11Available {
    if ( @available(iOS 11.0, *) ) { 
        return YES;
    }
    
    return NO;
}

+ (BOOL)iOS13Available {
    if ( @available(iOS 13.0, *) ) { 
        return YES;
    }
    
    return NO;
}

+ (BOOL)iOS14Available {
    if ( @available(iOS 14.0, *) ) { 
        return YES;
    }
    
    return NO;
}

@end
