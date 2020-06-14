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

- (void)update:(SafeMetaData *_Nonnull)safe; // This is called from only one location for the moment in Auto-Fill until we can trust the SafesList again

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
