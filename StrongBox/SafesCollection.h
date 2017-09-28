//
//  SafesCollection.h
//  StrongBox
//
//  Created by Mark on 22/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"

@interface SafesCollection : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<SafeMetaData*> *sortedSafes;

- (BOOL)add:(SafeMetaData *_Nonnull)safe;
- (void)removeSafe:(NSString *_Nonnull)nickName;

+ (NSString * _Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;

- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;
- (BOOL)safeWithTouchIdIsAvailable;

- (void)save;

- (NSArray<SafeMetaData*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

- (BOOL)changeNickName:(NSString*_Nonnull)nickName newNickName:(NSString*_Nonnull)newNickName;

@end
