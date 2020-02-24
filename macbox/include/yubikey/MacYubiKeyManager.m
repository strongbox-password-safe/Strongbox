//
//  YubiKeyManager.m
//  Strongbox
//
//  Created by Mark on 18/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "MacYubiKeyManager.h"

#include "ykcore.h"

//#include <ykdef.h>
//#include <ykpers-version.h>
//#include <ykstatus.h>
//#include "yubikey.h"

@implementation MacYubiKeyManager

+ (instancetype)sharedInstance {
    static MacYubiKeyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacYubiKeyManager alloc] init];
    });
    return sharedInstance;
}

- (void)doIt {
    if (!yk_init()) {
        NSLog(@"Ruh roh...");
    }
    else {
        NSLog(@"YubiKey Init good!");
    }
    
    YK_KEY *firstKey = yk_open_first_key();

    NSLog(@"firstKey = %@", firstKey);
    
    if (firstKey) {
        yk_close_key(firstKey);
    }
}


@end
