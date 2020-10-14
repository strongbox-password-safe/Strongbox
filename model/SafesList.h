//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;
- (NSString*_Nullable)getSuggestedDatabaseNameUsingDeviceName;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;

- (NSString*_Nullable)getUniqueNameFromSuggestedName:(NSString*)suggested;

- (void)update:(SafeMetaData *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;

- (void)addWithDuplicateCheck:(SafeMetaData *_Nonnull)safe initialCache:(NSData*_Nullable)initialCache initialCacheModDate:(NSDate*_Nullable)initialCacheModDate;

// Optional but highly desirable to provide an initial cache and mod date...

- (void)add:(SafeMetaData *_Nonnull)safe initialCache:(NSData*_Nullable)initialCache initialCacheModDate:(NSDate*_Nullable)initialCacheModDate;

- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)deleteAll;

// Required for Auto-Fill interaction at the moment, since there is some kind of strange caching going on that survives even a
// Host process restart (particularly evident in Firefox app and others but strangely not in Safari?!) - Because this
// class operates a cached set of databases once initially loaded, we need to force a full reload on entry into the Auto-Fill
// app as for some reason the Singleton is still around... MMcG - 17-June-2020
//
// AutoFill needs to write for these reasons
//
// 1. Incorrect Password -> Clear Convenience Unlock - Update
// 2. Biometrics Has Changed - Clear Convenience Unlock - Update
// 3. PIN Code -> Clear invalid attempts on good login - Update
// 4. PIN Code Fails -> Clear Convenience Unlock - Update
// 5. Duress -> Remove or Delete Safe - Remove
// 6. Change in Manual Unlock Params (Read-Only) - Update
// 7. Failed to Read Key File -> Reset Convenience Unlock -> Update
// 8. Outstanding Updates Flag when DB is edited in Auto Fill mode

- (void)reloadIfChangedByOtherComponent;

#ifndef IS_APP_EXTENSION

#else

#endif

@end

NS_ASSUME_NONNULL_END
