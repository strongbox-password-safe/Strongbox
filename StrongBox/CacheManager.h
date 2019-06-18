//
//  CacheManager.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface CacheManager : NSObject

+ (instancetype)sharedInstance;

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
                   completion:(void (^)(NSData *, NSError *error))completion;

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData
                           data:(NSData *)data
                     completion:(void (^)(BOOL success))completion;

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;

- (NSDate*_Nullable)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata;

// Auto Fill Cache

- (void)readAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^)(NSData *, NSError *error))completion;
- (void)deleteAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;
- (void)updateAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion;
- (NSDate*_Nullable)getAutoFillCacheModificationDate:(SafeMetaData *)safeMetadata;

@end

NS_ASSUME_NONNULL_END
