//
//  Utils.h
//  StrongBox
//
//  Created by Mark McGuill on 19/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IOsUtils : NSObject

//+ (NSString *)getAppName;
+ (NSURL *)applicationDocumentsDirectory;
//+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode;
+ (BOOL) isTouchIDAvailable;

@end
