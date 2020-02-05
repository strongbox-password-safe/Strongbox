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

- (void)add:(SafeMetaData *_Nonnull)safe;
- (void)addWithDuplicateCheck:(SafeMetaData *_Nonnull)safe;

- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)update:(SafeMetaData *_Nonnull)safe;

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;
- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

- (void)deleteAll;

- (NSString*_Nullable)getSuggestedDatabaseNameUsingDeviceName;
- (NSString*_Nullable)getUniqueNameFromSuggestedName:(NSString*)suggested;

@end

NS_ASSUME_NONNULL_END
