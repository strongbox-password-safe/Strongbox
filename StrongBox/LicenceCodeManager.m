//
//  LicenceCodeManager.m
//  Strongbox-iOS
//
//  Created by Mark on 11/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LicenceCodeManager.h"

@implementation LicenceCodeManager

+ (instancetype)sharedInstance {
    static LicenceCodeManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LicenceCodeManager alloc] init];
    });
    return sharedInstance;
}

- (void)verifyCode:(NSString *)code completion:(VerifyCompletionBlock)completion {
}

@end
