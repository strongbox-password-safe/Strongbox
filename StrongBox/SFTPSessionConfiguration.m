//
//  SFTPSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SFTPSessionConfiguration.h"
#import "JNKeychain.h"

@interface SFTPSessionConfiguration ()

@property NSString* keyChainUuid;

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
    
    return ret;
}

-(NSString*)getKeyChainKey:(NSString*)propertyName {
    return [NSString stringWithFormat:@"Strongbox-SFTP-%@-%@", self.keyChainUuid, propertyName];
}

-(NSString *)password {
    return [JNKeychain loadValueForKey:[self getKeyChainKey:@"password"]];
}

- (void)setPassword:(NSString *)password {
    if(password) {
        [JNKeychain saveValue:password forKey:[self getKeyChainKey:@"password"]];
    }
    else {
        [JNKeychain deleteValueForKey:[self getKeyChainKey:@"password"]];
    }
}

- (NSString *)privateKey {
    return [JNKeychain loadValueForKey:[self getKeyChainKey:@"privateKey"]];
}

- (void)setPrivateKey:(NSString *)privateKey {
    if(privateKey) {
        [JNKeychain saveValue:privateKey forKey:[self getKeyChainKey:@"privateKey"]];
    }
    else {
        [JNKeychain deleteValueForKey:[self getKeyChainKey:@"privateKey"]];
    }
}

- (NSString *)publicKey {
    return [JNKeychain loadValueForKey:[self getKeyChainKey:@"publicKey"]];
}

- (void)setPublicKey:(NSString *)publicKey {
    if(publicKey) {
        [JNKeychain saveValue:publicKey forKey:[self getKeyChainKey:@"publicKey"]];
    }
    else {
        [JNKeychain deleteValueForKey:[self getKeyChainKey:@"publicKey"]];
    }
}

@end
