//
//  Utils.h
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

static NSString* kCSVHeaderTitle = @"Title";
static NSString* kCSVHeaderUsername = @"Username";
static NSString* kCSVHeaderUrl = @"Url";
static NSString* kCSVHeaderEmail = @"Email";
static NSString* kCSVHeaderPassword = @"Password";
static NSString* kCSVHeaderNotes = @"Notes";

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
+ (NSData*)getSafeAsCsv:(Node*)rootGroup;

@end
