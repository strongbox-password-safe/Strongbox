//
//  SFTPSessionConfiguration.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, SFTPAuthenticationMode) {
    kUsernamePassword,
    kPrivateKey,
};

@interface SFTPSessionConfiguration : NSObject

@property NSString* identifier;

@property (nullable) NSString* name;
@property NSString* host;
@property SFTPAuthenticationMode authenticationMode;
@property (nullable) NSString* username;
@property (nullable) NSString* password;
@property (nullable) NSString* privateKey;
@property (nullable) NSString* initialDirectory;
@property (nullable) NSString* sha256FingerPrint;

@property NSString* keyChainUuid;

- (NSDictionary*)serializationDictionary;
+ (instancetype _Nullable)fromSerializationDictionary:(NSDictionary*)dictionary;

-(NSString*)getKeyChainKey:(NSString*)propertyName;

- (void)clearKeychainItems;

- (BOOL)isTheSameConnection:(SFTPSessionConfiguration*)other;
- (BOOL)isNetworkingFieldsAreSame:(SFTPSessionConfiguration*)other;

@end

NS_ASSUME_NONNULL_END
