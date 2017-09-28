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
    NSError *error = [[NSError alloc] initWithDomain:@"com.markmcguill.strongbox." code:errorCode userInfo:(userDict)];
    
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
#if TARGET_OS_IPHONE
    char baseHostName[256];
    int success = gethostname(baseHostName, 255);
    if (success != 0) {
        return nil;
    }
    baseHostName[255] = '\0';
    return [NSString stringWithFormat:@"%s", baseHostName];
#else
    return [[NSHost currentHost] localizedName];
#endif
}
//    char baseHostName[256];
//    int success = gethostname(baseHostName, 255);
//
//    if (success != 0) return nil;
//
//    baseHostName[255] = '\0';
//
//    return [NSString stringWithFormat:@"%s.local", baseHostName];
//}

+ (NSString *)generatePassword {
    NSString *letters = @"!@#$%*[];?()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    NSUInteger len = 16;
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    
    for (int i = 0; i < len; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((u_int32_t)letters.length)]];
    }
    
    return randomString;
}

+ (NSString*)getUsername {
    return NSFullUserName();
}

+(NSString *)trim:(NSString*)string {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


+ (NSComparisonResult)finderStringCompare:(NSString*)string1 string2:(NSString*)string2
{
    // Finder Like String Sort
    // https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Strings/Articles/SearchingStrings.html#//apple_ref/doc/uid/20000149-SW1
    
    static NSStringCompareOptions comparisonOptions =
    NSCaseInsensitiveSearch | NSNumericSearch |
    NSWidthInsensitiveSearch | NSForcedOrderingSearch;
    
    NSRange string1Range = NSMakeRange(0, [string1 length]);
    
    return [string1 compare:string2
                    options:comparisonOptions
                      range:string1Range
                     locale:[NSLocale currentLocale]];
};

@end
