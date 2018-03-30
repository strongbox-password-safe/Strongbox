//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"

@interface SafesList : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *snapshot;

- (void)add:(SafeMetaData *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;
- (void)insert:(SafeMetaData*_Nonnull)safe atIndex:(NSUInteger)atIndex;

- (void)save;

//- (BOOL)safeWithTouchIdIsAvailable;
//- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;
- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

@end
