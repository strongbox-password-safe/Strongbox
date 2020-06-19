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

@interface SafesList : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *snapshot;

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;
- (NSString*_Nullable)getSuggestedDatabaseNameUsingDeviceName;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;

// TODO: This is called from only one location for the moment in Auto-Fill until we can trust the SafesList again
// This needs to ask host app to reload settings if changes are made from Auto-Fill - however the idea is not to have
// Auto-Fill update the safes list at all (currently only used for Files based bookmarks which will be removed shortly)
// So at that point move to read-only list. MMcG - 17-June-2020

- (void)update:(SafeMetaData *_Nonnull)safe;

// TODO: Required for Auto-Fill at the moment = since there is some kind of strange caching going on that survives even a
// Host process restart (particularly evident in Firefox app and others but strangely not in Safari?!) - Because this
// class operates a cached set of databases once initially loaded, we need to force a full reload on entry into the Auto-Fill
// app as for some reason the Singleton is still around... MMcG - 17-June-2020
- (void)forceReload;

#ifndef IS_APP_EXTENSION

- (void)add:(SafeMetaData *_Nonnull)safe;
- (void)addWithDuplicateCheck:(SafeMetaData *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)deleteAll;

- (NSString*_Nullable)getUniqueNameFromSuggestedName:(NSString*)suggested;

#endif


@end

NS_ASSUME_NONNULL_END
