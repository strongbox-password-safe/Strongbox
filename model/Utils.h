//
//  Utils.h
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

@interface Utils : NSObject

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode;
+ (NSString *)getAppName;
+ (NSString *)getAppVersion;
+ (NSString *)insertTimestampInFilename:(NSString *)title;
+ (NSString *)hostname;
+ (NSString *)getUsername;
+ (NSString *)trim:(NSString*)string;
+ (NSComparisonResult)finderStringCompare:(NSString*)string1 string2:(NSString*)string2;
+ (NSString*)generateUniqueId;

@end
