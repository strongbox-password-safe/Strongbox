//
//  KeePassCiphers.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassCiphers.h"

@implementation KeePassCiphers

static NSString* const aesUuid = @"31C1F2E6-BF71-4350-BE58-05216AFC5AFF";
static NSString* const chaCha20Uuid = @"D6038A2B-8B6F-4CB5-A524-339A31DBB59A";
static NSString* const argon2Uuid = @"EF636DDF-8C29-444B-91F7-A9A403E30A0C";

NSUUID* const chaCha20CipherUuid() {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:chaCha20Uuid];
    }
    
    return foo;
}

NSData* chaCha20CipherUuidData() {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [chaCha20CipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const argon2CipherUuid() {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:argon2Uuid];
    }
    
    return foo;
}

NSData* argon2CipherUuidData() {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [argon2CipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const aesCipherUuid() {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:aesUuid];
    }
    
    return foo;
}

NSData* aesCipherUuidData() {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [aesCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

@end
