//
//  Utils.m
//  StrongBox
//
//  Created by Mark McGuill on 19/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Utils.h"
#import <LocalAuthentication/LocalAuthentication.h>

@implementation Utils

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode
{
    NSArray *keys = [NSArray arrayWithObjects: NSLocalizedDescriptionKey, nil];
    NSArray *values = [NSArray arrayWithObjects:description, nil];
    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    NSError* error = [[NSError alloc] initWithDomain:@"com.markmcguill.StrongBox.ErrorDomain." code:errorCode userInfo:(userDict)];
    return error;
}

+ (NSString *)getAppName
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", [info objectForKey:@"CFBundleDisplayName"], [info objectForKey:@"CFBundleVersion"]];
    return appName;
}

@end
