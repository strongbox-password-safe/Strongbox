//
//  WorkingCopyManager.h
//  Strongbox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import "SafeMetaData.h"
    typedef SafeMetaData* METADATA_PTR;
#else
    #import "DatabaseMetadata.h"
    typedef DatabaseMetadata* METADATA_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface WorkingCopyManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isLocalWorkingCacheAvailable:(METADATA_PTR)database modified:(NSDate*_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache:(METADATA_PTR)database;
- (NSURL*_Nullable)getLocalWorkingCache:(METADATA_PTR)database modified:(NSDate *_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache:(METADATA_PTR)database modified:(NSDate *_Nullable*_Nullable)modified fileSize:(unsigned long long*_Nullable)fileSize;


- (NSURL*_Nullable)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(METADATA_PTR)database error:(NSError**)error;

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(METADATA_PTR)database;

- (void)deleteLocalWorkingCache:(METADATA_PTR)database;

@end

NS_ASSUME_NONNULL_END
