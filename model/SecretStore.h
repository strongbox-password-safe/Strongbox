//
//  CredentialsStore.h
//  Strongbox
//
//  Created by Mark on 13/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSInteger, SecretExpiryMode) {
    kNeverExpires,
    kExpiresAtTime,
    kExpiresOnAppExitStoreSecretInMemoryOnly, // Reset
};

@interface SecretStore : NSObject

+ (instancetype)sharedInstance;

@property (readonly) BOOL secureEnclaveAvailable;

- (BOOL)setSecureObject:(id)object forIdentifier:(NSString*)identifier;
- (BOOL)setSecureObject:(id)object forIdentifier:(NSString*)identifier expiresAt:(NSDate*)expiresAt;
- (BOOL)setSecureEphemeralObject:(id)object forIdentifer:(NSString*)identifier;

- (id _Nullable)getSecureObject:(NSString*)identifier;
- (id _Nullable)getSecureObject:(NSString *)identifier expired:(BOOL*_Nullable)expired;

- (BOOL)setSecureString:(NSString*)string forIdentifier:(NSString*)identifier;
- (NSString*_Nullable)getSecureString:(NSString*)identifier;

- (void)deleteSecureItem:(NSString*)identifier;

@end

NS_ASSUME_NONNULL_END
