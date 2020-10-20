//
//  VirtualYubiKey.h
//  Strongbox
//
//  Created by Strongbox on 16/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VirtualYubiKey : NSObject

+ (instancetype)keyWithName:(NSString*)name secret:(NSString*)secret autoFillOnly:(BOOL)autoFillOnly;

@property (readonly) NSString* name;
@property (readonly) NSString* identifier;
@property (readonly) BOOL autoFillOnly;

- (NSData*)doChallengeResponse:(NSData*)challenge;

- (NSDictionary*)getJsonSerializationDictionary;
+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)dictionary;

+ (NSData*)getDummyYubikeyResponse:(NSData*)challenge secret:(NSString*)secret; // Used by Emergency workaround in OSSH - Remove and make private once those workarounds are migrated to virtual keys

- (void)clearSecret;

@end

NS_ASSUME_NONNULL_END
