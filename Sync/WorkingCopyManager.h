//
//  WorkingCopyManager.h
//  Strongbox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

//#if TARGET_OS_IPHONE
//    #import "SafeMetaData.h"
//    typedef SafeMetaData* METADATA_PTR;
//#else
//    #import "DatabaseMetadata.h"
//    typedef DatabaseMetadata* METADATA_PTR;


NS_ASSUME_NONNULL_BEGIN

@interface WorkingCopyManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isLocalWorkingCacheAvailable2:(NSString*)databaseUuid modified:(NSDate*_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache2:(NSString*)databaseUuid;
- (NSURL*_Nullable)getLocalWorkingCache2:(NSString*)databaseUuid modified:(NSDate *_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache2:(NSString*)databaseUuid modified:(NSDate *_Nullable*_Nullable)modified fileSize:(unsigned long long*_Nullable)fileSize;


- (NSURL*_Nullable)setWorkingCacheWithData2:(NSData*)data dateModified:(NSDate*)dateModified database:(NSString*)databaseUuid error:(NSError**)error;

- (NSURL*)getLocalWorkingCacheUrlForDatabase2:(NSString*)databaseUuid;

- (void)deleteLocalWorkingCache2:(NSString*)databaseUuid;

@end

NS_ASSUME_NONNULL_END
