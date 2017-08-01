//
//  Utils.m
//
//
//  Created by Mark on 31/08/2015.
//
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode;
+ (NSString *)getAppName;
+ (NSString *)getAppVersion;
+ (NSString *)insertTimestampInFilename:(NSString *)title;

@end
