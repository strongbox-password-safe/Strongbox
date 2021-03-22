//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* _Nonnull const kDatabasesListChangedNotification;
extern NSString* _Nonnull const kDatabaseUpdatedNotification;

@interface SafesList : NSObject

+ (instancetype _Nullable)sharedInstance;
@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *snapshot;

- (SafeMetaData *)getById:(NSString*)uuid;

- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

+ (NSString *_Nonnull)trimDatabaseNickName:(NSString *_Nonnull)string;
- (NSString*_Nullable)getSuggestedDatabaseNameUsingDeviceName;
- (NSString*_Nullable)getUniqueNameFromSuggestedName:(NSString*)suggested;

- (BOOL)isUnique:(NSString *)nickName;
- (BOOL)isValid:(NSString *)nickName;

- (void)update:(SafeMetaData *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;

- (void)addWithDuplicateCheck:(SafeMetaData *_Nonnull)safe initialCache:(NSData*_Nullable)initialCache initialCacheModDate:(NSDate*_Nullable)initialCacheModDate;



- (void)add:(SafeMetaData *_Nonnull)safe initialCache:(NSData*_Nullable)initialCache initialCacheModDate:(NSDate*_Nullable)initialCacheModDate;

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)deleteAll;

















- (void)reloadIfChangedByOtherComponent;

#ifndef IS_APP_EXTENSION

#else

#endif

@end

NS_ASSUME_NONNULL_END
