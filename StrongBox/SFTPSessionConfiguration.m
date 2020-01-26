//
//  SFTPSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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
    }
    
    return self;
}

- (NSDictionary *)serializationDictionary {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    if(self.host) [ret setValue:self.host forKey:@"host"];
    if(self.authenticationMode) [ret setValue:@(self.authenticationMode) forKey:@"authenticationMode"];
    if(self.username) [ret setValue:self.username forKey:@"username"];
    if(self.keyChainUuid) [ret setValue:self.keyChainUuid forKey:@"keyChainUuid"];
    if(self.initialDirectory) [ret setValue:self.initialDirectory forKey:@"initialDirectory"];

    return ret;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    NSString* keyChainUuid = [dictionary objectForKey:@"keyChainUuid"];
    
    SFTPSessionConfiguration *ret = [[SFTPSessionConfiguration alloc] initWithKeyChainUuid:keyChainUuid];
    
    ret.host = [dictionary objectForKey:@"host"];
    
    NSNumber* num = [dictionary objectForKey:@"authenticationMode"];
    if(num != nil) {
        ret.authenticationMode = num.intValue;
    }
    
    ret.username = [dictionary objectForKey:@"username"];
    ret.initialDirectory = [dictionary objectForKey:@"initialDirectory"];
    
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

@end
