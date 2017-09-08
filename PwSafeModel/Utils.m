//
//  Utils.m
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Utils.h"

@implementation Utils

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode {
    NSArray *keys = @[NSLocalizedDescriptionKey];
    NSArray *values = @[description];
    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    NSError *error = [[NSError alloc] initWithDomain:@"com.markmcguill.StrongBox.ErrorDomain." code:errorCode userInfo:(userDict)];
    
    return error;
}

+ (NSString *)getAppVersion {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    
    return [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
}

+ (NSString *)getAppName {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", info[@"CFBundleName"], info[@"CFBundleShortVersionString"]];
    
    return appName;
}

+ (NSString *)insertTimestampInFilename:(NSString *)title {
    NSString *fn = title;
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    
    dateFormat.dateFormat = @"yyyyMMdd-HHmmss";
    NSDate *date = [[NSDate alloc] init];
    
    NSString *extension = title.pathExtension;
    fn = [NSString stringWithFormat:@"%@-%@.%@", title, [dateFormat stringFromDate:date], extension];
    
    return fn;
}


+ (NSString *)hostname {
    char baseHostName[256];
    int success = gethostname(baseHostName, 255);
    
    if (success != 0) return nil;
    
    baseHostName[255] = '\0';
    
#if !TARGET_IPHONE_SIMULATOR
    return [NSString stringWithFormat:@"%s.local", baseHostName];
    
#else
    return [NSString stringWithFormat:@"%s", baseHostName];    
#endif
}

+ (NSString *)generatePassword {
    NSString *letters = @"!@#$%*[];?()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    NSUInteger len = 16;
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    
    for (int i = 0; i < len; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((u_int32_t)letters.length)]];
    }
    
    return randomString;
}


//#define kStrongBoxUser @"StrongBox User"

+ (NSString*)getUsername {
    return NSFullUserName();
}

@end
