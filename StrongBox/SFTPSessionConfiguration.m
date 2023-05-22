//
//  SFTPSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SFTPSessionConfiguration.h"
#import "SecretStore.h"

@interface SFTPSessionConfiguration ()

@end

@implementation SFTPSessionConfiguration

- (instancetype)init {
    return [self initWithKeyChainUuid:[[NSUUID UUID] UUIDString]];
}

- (instancetype)initWithKeyChainUuid:(NSString*)keyChainUuid {
    if(self = [super init]) {
        self.keyChainUuid = keyChainUuid;
        self.identifier = NSUUID.UUID.UUIDString;
    }
    
    return self;
}

- (NSDictionary *)serializationDictionary {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    [ret setValue:self.identifier forKey:@"identifier"];
    if ( self.name ) [ret setValue:self.name forKey:@"name"];
    
    if(self.host) [ret setValue:self.host forKey:@"host"];
    if(self.authenticationMode) [ret setValue:@(self.authenticationMode) forKey:@"authenticationMode"];
    if(self.username) [ret setValue:self.username forKey:@"username"];
    if(self.keyChainUuid) [ret setValue:self.keyChainUuid forKey:@"keyChainUuid"];
    if(self.initialDirectory) [ret setValue:self.initialDirectory forKey:@"initialDirectory"];
    
    if ( self.sha256FingerPrint ) {
        [ret setValue:self.sha256FingerPrint forKey:@"sha256FingerPrint"];
    }
    
    return ret;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    NSString* keyChainUuid = [dictionary objectForKey:@"keyChainUuid"];
    if ( !keyChainUuid ) {
        return nil;
    }
    
    SFTPSessionConfiguration *ret = [[SFTPSessionConfiguration alloc] initWithKeyChainUuid:keyChainUuid];
    
    if ( dictionary[@"identifier"] ) ret.identifier = dictionary[@"identifier"];
    if ( dictionary[@"name"] ) ret.name = dictionary[@"name"];
    
    ret.host = [dictionary objectForKey:@"host"];
    
    NSNumber* num = [dictionary objectForKey:@"authenticationMode"];
    if(num != nil) {
        ret.authenticationMode = num.intValue;
    }
    
    ret.username = [dictionary objectForKey:@"username"];
    ret.initialDirectory = [dictionary objectForKey:@"initialDirectory"];
    
    if ( dictionary[@"sha256FingerPrint"] ) {
        ret.sha256FingerPrint = [dictionary objectForKey:@"sha256FingerPrint"];
    }
    
    return ret;
}

-(NSString*)getKeyChainKey:(NSString*)propertyName {
    return [NSString stringWithFormat:@"Strongbox-SFTP-%@-%@", self.keyChainUuid, propertyName];
}

-(NSString *)password {
    return [SecretStore.sharedInstance getSecureString:[self getKeyChainKey:@"password"]];
}

- (void)setPassword:(NSString *)password {
    if(password) {
        [SecretStore.sharedInstance setSecureString:password forIdentifier:[self getKeyChainKey:@"password"]];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:[self getKeyChainKey:@"password"]];
    }
}

- (NSString *)privateKey {
    return [SecretStore.sharedInstance getSecureString:[self getKeyChainKey:@"privateKey"]];
}

- (void)setPrivateKey:(NSString *)privateKey {
    if(privateKey) {
        [SecretStore.sharedInstance setSecureString:privateKey forIdentifier:[self getKeyChainKey:@"privateKey"]];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:[self getKeyChainKey:@"privateKey"]];
    }
}

- (NSString *)publicKey {
    return [SecretStore.sharedInstance getSecureString:[self getKeyChainKey:@"publicKey"]];
}

- (void)setPublicKey:(NSString *)publicKey {
    if(publicKey) {
        [SecretStore.sharedInstance setSecureString:publicKey forIdentifier:[self getKeyChainKey:@"publicKey"]];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:[self getKeyChainKey:@"publicKey"]];
    }
}

- (void)clearKeychainItems {
    [self setPublicKey:nil];
    [self setPrivateKey:nil];
    [self setPassword:nil];
}

@end
