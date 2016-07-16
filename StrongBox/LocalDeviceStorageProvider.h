//
//  LocalDeviceStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SafeMetaData.h"
#import "core-model/SafeDatabase.h"

@interface LocalDeviceStorageProvider : NSObject <SafeStorageProvider>
- (void)readOfflineCachedSafe:(SafeMetaData*)safeMetaData viewController:(UIViewController*)viewController completionHandler:(void (^)(NSData*, NSError* error))completion;
- (void)updateOfflineCachedSafe:(SafeMetaData*)safeMetaData data:(NSData*)data viewController:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completion;
- (void)deleteOfflineCachedSafe:(SafeMetaData*)safeMetaData completionHandler:(void (^)(NSError *error))completion;

-(NSDate*)getOfflineCacheFileModificationDate:(SafeMetaData*)safeMetadata;

@end
