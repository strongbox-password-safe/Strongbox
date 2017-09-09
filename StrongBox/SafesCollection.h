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

- (instancetype _Nullable)  init;

@property (nonatomic, nonnull, readonly, copy) NSArray<SafeMetaData*> *safes;

- (void)add:(SafeMetaData *_Nonnull)newSafe;
- (void)removeSafesAt:(NSIndexSet *_Nonnull)index;
- (void)removeAt:(NSUInteger)index;

- (void)save;

+ (NSString * _Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;

- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;
- (BOOL)safeWithTouchIdIsAvailable;

@end
