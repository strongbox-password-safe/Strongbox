//
//  CredentialsStore.h
//  Strongbox
//
//  Created by Mark on 13/01/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSInteger, SecretExpiryMode) {
    kNeverExpires,
    kExpiresAtTime,
    kExpiresOnAppExitStoreSecretInMemoryOnly, // Reset
    kUnknown,
};

@interface SecretStore : NSObject

+ (instancetype)sharedInstance;

@property (readonly) BOOL secureEnclaveAvailable;

- (BOOL)setSecureObject:(id _Nullable)object forIdentifier:(NSString*)identifier;
- (BOOL)setSecureObject:(id _Nullable)object forIdentifier:(NSString*)identifier expiresAt:(NSDate*)expiresAt;
- (BOOL)setSecureEphemeralObject:(id)object forIdentifer:(NSString*)identifier;

- (id _Nullable)getSecureObject:(NSString*)identifier;
- (id _Nullable)getSecureObject:(NSString *)identifier expired:(BOOL*_Nullable)expired;
- (NSString * _Nullable)getSecureString:(NSString *)identifier error:(NSError**)error;
- (id _Nullable )getSecureObject:(NSString *)identifier error:(NSError**)error;

- (BOOL)setSecureString:(NSString* _Nullable)string forIdentifier:(NSString*)identifier;
- (NSString*_Nullable)getSecureString:(NSString*)identifier;

- (void)deleteSecureItem:(NSString*)identifier;

- (SecretExpiryMode)getSecureObjectExpiryMode:(NSString*)identifier;
- (NSDate*_Nullable)getSecureObjectExpiryDate:(NSString*)identifier;

- (void)factoryReset;

@end

NS_ASSUME_NONNULL_END
