//
//  SFTPSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SFTPSessionConfiguration.h"
#import "SecretStore.h"
#import "SBLog.h"
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

- (void)clearKeychainItems {
    [self setPrivateKey:nil];
    [self setPassword:nil];
}

- (BOOL)isTheSameConnection:(SFTPSessionConfiguration*)other {
    return [self isTheSameConnection:other checkNetworkingFieldsOnly:NO];
}

- (BOOL)isNetworkingFieldsAreSame:(SFTPSessionConfiguration *)other {
    return [self isTheSameConnection:other checkNetworkingFieldsOnly:YES];
}

- (BOOL)isTheSameConnection:(SFTPSessionConfiguration*)other checkNetworkingFieldsOnly:(BOOL)checkNetworkingFieldsOnly {
    if (other == self) {
        return YES;
    }
        
    BOOL nameChanged = !checkNetworkingFieldsOnly && ![self.name isEqualToString:other.name];
    
    BOOL hostChanged = ![self.host isEqualToString:other.host];
    BOOL userChanged = ![self.username isEqualToString:other.username];
    BOOL pwChanged = self.password != nil ? ![self.password isEqualToString:other.password] : YES;
    BOOL authModeChanged = self.authenticationMode != other.authenticationMode;
    
    NSString* mp = self.privateKey;
    NSString* op = other.privateKey;
    
    BOOL pkChanged = ![mp isEqualToString:op];
    
    BOOL pathChanged = self.initialDirectory != nil ? ![self.initialDirectory isEqualToString:other.initialDirectory] : YES;
    
    slog(@"🐞 isTheSameConnection: %hhd, %hhd, %hhd, %hhd, %hhd, %hhd, %hhd", nameChanged, hostChanged, userChanged, pwChanged, authModeChanged, pkChanged, pathChanged);
    
    return !(nameChanged || hostChanged || userChanged || pwChanged || authModeChanged || pkChanged || pathChanged);
}

@end
