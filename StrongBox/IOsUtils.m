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

+(NSInteger)getLaunchCount
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger launchCount = [prefs integerForKey:@"launchCount"];
    
    return launchCount;
}

+ (NSString *)getAppName
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", [info objectForKey:@"CFBundleDisplayName"], [info objectForKey:@"CFBundleVersion"]];
    return appName;
}

+ (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

//+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode
//{
//    NSArray *keys = [NSArray arrayWithObjects: NSLocalizedDescriptionKey, nil];
//    NSArray *values = [NSArray arrayWithObjects:description, nil];
//    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
//    NSError* error = [[NSError alloc] initWithDomain:@"com.markmcguill.StrongBox.ErrorDomain." code:errorCode userInfo:(userDict)];
//    return error;
//}

+ (BOOL) isTouchIDAvailable
{
    LAContext *localAuthContext = [[LAContext alloc] init];
    if(localAuthContext == nil)
    {
        return NO;
    }
    
    NSError *error;
    [localAuthContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    if(error) {
        //NSLog(@"Error with biometrics authentication");
        return NO;
    }
    return YES;
}


@end
