//
//  VirtualYubiKey.h
//  Strongbox
//
//  Created by Strongbox on 16/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface VirtualYubiKey : NSObject

+ (instancetype)keyWithName:(NSString*)name secret:(NSString*)secret autoFillOnly:(BOOL)autoFillOnly;

@property (readonly) NSString* name;
@property (readonly) NSString* identifier;
@property (readonly) BOOL autoFillOnly;

- (NSData*)doChallengeResponse:(NSData*)challenge;

- (NSDictionary*)getJsonSerializationDictionary;
+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)dictionary;

+ (NSData*)getDummyYubiKeyResponse:(NSData*)challenge secret:(NSString*)secret; 

- (void)clearSecret;

@property (readonly) BOOL secretIsNoLongerPresent; 

@end

NS_ASSUME_NONNULL_END
