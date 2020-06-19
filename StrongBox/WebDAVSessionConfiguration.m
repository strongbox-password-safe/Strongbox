//
//  WebDAVSessionConfiguration.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "WebDAVSessionConfiguration.h"
#import "SecretStore.h"
#import "NSString+Extensions.h"

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
    }
    
    return self;
}

- (NSDictionary *)serializationDictionary {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    if(self.host) [ret setValue:self.host.absoluteString forKey:@"host"];
    if(self.username) [ret setValue:self.username forKey:@"username"];
    if(self.keyChainUuid) [ret setValue:self.keyChainUuid forKey:@"keyChainUuid"];
    [ret setValue:@(self.allowUntrustedCertificate) forKey:@"allowUntrustedCertificate"];
    
    return ret;
}

+ (instancetype)fromSerializationDictionary:(NSDictionary *)dictionary {
    NSString* keyChainUuid = [dictionary objectForKey:@"keyChainUuid"];
    
    WebDAVSessionConfiguration *ret = [[WebDAVSessionConfiguration alloc] initWithKeyChainUuid:keyChainUuid];
    
    NSString* host = [dictionary objectForKey:@"host"];
    
    ret.host = host.urlExtendedParse;
    ret.username = [dictionary objectForKey:@"username"];
    
    NSNumber* num = [dictionary objectForKey:@"allowUntrustedCertificate"];
    if(num != nil) {
        ret.allowUntrustedCertificate = num.boolValue;
    }
    
    return ret;
}
//
//- (NSURL *)host {
//    return self.root;
//}
//
//- (void)setHost:(NSString *)host {
//    if(host.length && [host hasSuffix:@"/"]) {
//        self.root = [host substringToIndex:host.length - 1];
//    }
//    else {
//        self.root = host;
//    }
//}

-(NSString*)getKeyChainKey:(NSString*)propertyName {
    return [NSString stringWithFormat:@"Strongbox-WebDAV-%@-%@", self.keyChainUuid, propertyName];
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

@end
