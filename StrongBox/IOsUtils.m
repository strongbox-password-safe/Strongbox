//
//  Utils.m
//  StrongBox
//
//  Created by Mark McGuill on 19/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>

@implementation IOsUtils

+ (NSString *)getAppName {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", info[@"CFBundleDisplayName"], info[@"CFBundleVersion"]];

    return appName;
}

+ (NSURL *)applicationDocumentsDirectory {
    return [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                  inDomains:NSUserDomainMask].lastObject;
}

+ (BOOL)isTouchIDAvailable {
    LAContext *localAuthContext = [[LAContext alloc] init];

    if (localAuthContext == nil) {
        return NO;
    }

    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];

    if (error) {
        //NSLog(@"Error with biometrics authentication");
        return NO;
    }

    return YES;
}

@end
