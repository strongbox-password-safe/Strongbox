//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabasesListChangedNotification;

@interface DatabasesManager : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<DatabaseMetadata*> *snapshot;



- (void)forceSerialize;
- (void)forceReload;

- (void)add:(DatabaseMetadata *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;

- (void)atomicUpdate:(NSString *_Nonnull)uuid touch:(void (^_Nonnull)(DatabaseMetadata* metadata))touch;

+ (NSString *_Nonnull)trimDatabaseNickName:(NSString *_Nonnull)string;
- (BOOL)isUnique:(NSString *)nickName;
- (BOOL)isValid:(NSString *)nickName;

- (DatabaseMetadata*_Nullable)getDatabaseById:(NSString*)uuid;
- (DatabaseMetadata*)addOrGet:(NSURL *)url;

- (NSString*)getUniqueNameFromSuggestedName:(NSString*)suggested;
- (NSString*)getSuggestedNewDatabaseName;

@end

NS_ASSUME_NONNULL_END
