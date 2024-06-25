//
//  DatabasePreferences.h
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

+ (instancetype)sharedInstance;
@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *snapshot;

- (SafeMetaData *)getById:(NSString*)uuid;

- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

+ (NSString *_Nonnull)trimDatabaseNickName:(NSString *_Nonnull)string;
- (NSString*)getSuggestedNewDatabaseName;
- (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested;

- (BOOL)isUnique:(NSString *)nickName;
- (BOOL)isValid:(NSString *)nickName;

- (void)atomicUpdate:(NSString *_Nonnull)uuid touch:(void (^_Nonnull)(SafeMetaData* metadata))touch;

- (void)remove:(NSString*_Nonnull)uuid;



- (BOOL)add:(SafeMetaData *)safe
      error:(NSError *__autoreleasing  _Nullable *  _Nullable )error;

- (BOOL)add:(SafeMetaData *)safe
initialCache:(NSData * _Nullable )initialCache
initialCacheModDate:(NSDate * _Nullable )initialCacheModDate
      error:(NSError* _Nullable * _Nullable )error;

- (BOOL)addWithDuplicateCheck:(SafeMetaData *)safe
                 initialCache:(NSData * _Nullable )initialCache
          initialCacheModDate:(NSDate * _Nullable )initialCacheModDate
                        error:(NSError* _Nullable * _Nullable )error;

- (BOOL)addWithDuplicateCheck:(SafeMetaData *)safe
                 initialCache:(NSData * _Nullable )initialCache
          initialCacheModDate:(NSDate * _Nullable )initialCacheModDate
                duplicateUuid:(NSString* _Nullable * _Nullable )duplicatedUuid
                        error:(NSError* _Nullable * _Nullable )error;

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;

















- (BOOL)reloadIfChangedByOtherComponent;

- (void)notifyDatabasesListChanged;
- (void)notifyDatabaseChanged:(NSString*)databaseIdChanged;

#ifndef IS_APP_EXTENSION

#else

#endif

@end

NS_ASSUME_NONNULL_END
