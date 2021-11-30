//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseMetadata.h"
#import "DatabasePreferencesManager.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabasesListChangedNotification;

@interface DatabasesManager : NSObject<DatabasePreferencesManager>

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<DatabaseMetadata*> *snapshot;

- (void)add:(DatabaseMetadata *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;

- (void)atomicUpdate:(NSString *_Nonnull)uuid touch:(void (^_Nonnull)(DatabaseMetadata* metadata))touch;
- (void)update:(DatabaseMetadata *_Nonnull)database; 

+ (NSString *_Nonnull)trimDatabaseNickName:(NSString *_Nonnull)string;

- (BOOL)isUnique:(NSString *)nickName;
- (BOOL)isValid:(NSString *)nickName;

- (DatabaseMetadata*_Nullable)getDatabaseById:(NSString*)uuid;
- (DatabaseMetadata*_Nullable)getDatabaseByFileUrl:(NSURL *)url;
- (DatabaseMetadata*)addOrGet:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
