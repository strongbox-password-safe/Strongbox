//
//  Utils.h
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode;
+ (NSString *)getAppName;
+ (NSString *)getAppVersion;
+ (NSString *)insertTimestampInFilename:(NSString *)title;
+ (NSString *)hostname;
+ (NSString *)generatePassword;
+ (NSString *)getUsername;
+ (NSString *)trim:(NSString*)string;

@end
