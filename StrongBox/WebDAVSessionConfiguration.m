//
//  WebDAVSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WebDAVSessionConfiguration.h"
#import "SecretStore.h"
#import "NSString+Extensions.h"
#import "SBLog.h"

@interface WebDAVSessionConfiguration ()

@property NSString* keyChainUuid;

@end

@implementation WebDAVSessionConfiguration

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
    
    if(self.host) [ret setValue:self.host.absoluteString forKey:@"host"];
    if(self.username) [ret setValue:self.username forKey:@"username"];
    if(self.keyChainUuid) [ret setValue:self.keyChainUuid forKey:@"keyChainUuid"];
    [ret setValue:@(self.allowUntrustedCertificate) forKey:@"allowUntrustedCertificate"];
    
    return ret;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    NSString* keyChainUuid = [dictionary objectForKey:@"keyChainUuid"];
    if ( !keyChainUuid ) {
        return nil;
    }
    
    WebDAVSessionConfiguration *ret = [[WebDAVSessionConfiguration alloc] initWithKeyChainUuid:keyChainUuid];
    
    if ( dictionary[@"identifier"] ) ret.identifier = dictionary[@"identifier"];
    if ( dictionary[@"name"] ) ret.name = dictionary[@"name"];
    
    NSString* host = [dictionary objectForKey:@"host"];
    
    ret.host = host.urlExtendedParse;
    ret.username = [dictionary objectForKey:@"username"];
    
    NSNumber* num = [dictionary objectForKey:@"allowUntrustedCertificate"];
    if(num != nil) {
        ret.allowUntrustedCertificate = num.boolValue;
    }
    
    return ret;
}

-(NSString*)getKeyChainKey:(NSString*)propertyName {
    return [NSString stringWithFormat:@"Strongbox-WebDAV-%@-%@", self.keyChainUuid, propertyName];
}

-(NSString *)password {
    return [SecretStore.sharedInstance getSecureString:[self getKeyChainKey:@"password"]];
}

- (void)setPassword:(NSString *)password {
    if ( password ) {
        [SecretStore.sharedInstance setSecureString:password forIdentifier:[self getKeyChainKey:@"password"]];
    }
    else {
        [SecretStore.sharedInstance deleteSecureItem:[self getKeyChainKey:@"password"]];
    }
}

- (void)clearKeychainItems {
    [SecretStore.sharedInstance deleteSecureItem:[self getKeyChainKey:@"password"]];
}

- (BOOL)isTheSameConnection:(WebDAVSessionConfiguration *)other {
    return [self isTheSameConnection:other checkNetworkingFieldsOnly:NO];
}

- (BOOL)isNetworkingFieldsAreSame:(WebDAVSessionConfiguration *)other {
    return [self isTheSameConnection:other checkNetworkingFieldsOnly:YES];
}

- (BOOL)isTheSameConnection:(WebDAVSessionConfiguration*)other checkNetworkingFieldsOnly:(BOOL)checkNetworkingFieldsOnly {
    if (other == self) {
        return YES;
    }
    
    BOOL nameChanged = !checkNetworkingFieldsOnly && ![self.name isEqualToString:other.name];
    
    BOOL userChanged = ![self.username isEqualToString:other.username];
    BOOL pwChanged = self.password != nil ? ![self.password isEqualToString:other.password] : YES;
    BOOL hostChanged = ![self.host.absoluteString isEqualToString:other.host.absoluteString];
    BOOL certChanged = self.allowUntrustedCertificate != other.allowUntrustedCertificate;
    
    slog(@"🐞 isTheSameConnection: %hhd, %hhd, %hhd, %hhd, %hhd", nameChanged, hostChanged, userChanged, pwChanged, certChanged);
    
    return !(nameChanged || hostChanged || userChanged || pwChanged || certChanged);
}

@end
