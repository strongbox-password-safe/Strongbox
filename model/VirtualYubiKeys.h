//
//  VirtualYubiKeys.h
//  Strongbox
//
//  Created by Strongbox on 16/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VirtualYubiKey.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* _Nonnull const kVirtualYubiKeysChangedNotification;

@interface VirtualYubiKeys : NSObject

+ (instancetype)sharedInstance;

- (VirtualYubiKey*)getById:(NSString*)identifier;
- (void)addKey:(VirtualYubiKey*)key;
- (void)deleteKey:(NSString*)identifier;

- (NSArray<VirtualYubiKey*>*)snapshot;

@end

NS_ASSUME_NONNULL_END
