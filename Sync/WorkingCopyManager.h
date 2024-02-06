//
//  WorkingCopyManager.h
//  Strongbox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WorkingCopyManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isLocalWorkingCacheAvailable:(NSString*)databaseUuid modified:(NSDate*_Nullable*_Nullable)modified;

- (NSDate* _Nullable)getModDate:(NSString*)databaseUuid;
- (NSURL*_Nullable)getLocalWorkingCache:(NSString*)databaseUuid;
- (NSURL*_Nullable)getLocalWorkingCache:(NSString*)databaseUuid modified:(NSDate *_Nullable*_Nullable)modified;
- (NSURL*_Nullable)getLocalWorkingCache:(NSString*)databaseUuid modified:(NSDate *_Nullable*_Nullable)modified fileSize:(unsigned long long*_Nullable)fileSize;


- (NSURL*_Nullable)setWorkingCacheWithData:(NSData*)data dateModified:(NSDate*)dateModified database:(NSString*)databaseUuid error:(NSError**)error;
- (NSURL*_Nullable)setWorkingCacheWithFile:(NSString*)file dateModified:(NSDate*)dateModified database:(NSString*)databaseUuid error:(NSError**)error;

- (NSURL*)getLocalWorkingCacheUrlForDatabase:(NSString*)databaseUuid;

- (void)deleteLocalWorkingCache:(NSString*)databaseUuid;

@end

NS_ASSUME_NONNULL_END
