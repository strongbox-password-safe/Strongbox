//
//  SFTPSessionConfiguration.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SFTPAuthenticationMode) {
    kUsernamePassword,
    kPrivateKey,
};

@interface SFTPSessionConfiguration : NSObject

@property NSString* host;
@property SFTPAuthenticationMode authenticationMode;
@property (nullable) NSString* username;
@property (nullable) NSString* password;
@property (nullable) NSString* privateKey;
@property (nullable) NSString* publicKey;

@property NSString* keyChainUuid;

- (NSDictionary*)serializationDictionary;
+ (instancetype)fromSerializationDictionary:(NSDictionary*)dictionary;

-(NSString*)getKeyChainKey:(NSString*)propertyName;

@end

NS_ASSUME_NONNULL_END
