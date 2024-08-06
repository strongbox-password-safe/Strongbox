//
//  CryptoParameters.m
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CryptoParameters.h"
#import "KdbxSerializationCommon.h"
#import "KeePassCiphers.h"
#import "VariantObject.h"

@implementation CryptoParameters

- (instancetype)initFromHeaders:(NSDictionary<NSNumber*, NSObject*>*)headerEntries
{
    self = [super init];
    if (self) {
        self.kdfParameters = getGetKDFParameters(headerEntries);
        self.masterSeed = (NSData*)[headerEntries objectForKey:@(MASTERSEED)];
        self.iv = (NSData*)[headerEntries objectForKey:@(ENCRYPTIONIV)];
        
        if(!self.kdfParameters || !self.masterSeed || !self.iv) {
            slog(@"Required Headers (KDFPARAMETERS, MASTERSEED, ENCRYPTIONIV) not Present: [%@]", headerEntries);
            return nil;
        }
        
        self.cipherUuid = getCipherUuid(headerEntries);
        NSNumber* num = (NSNumber*)[headerEntries objectForKey:@(COMPRESSIONFLAGS)];
        self.compressionFlags = num != nil ? num.unsignedIntValue : 0;
    }
    return self;
}

static KdfParameters* getGetKDFParameters(NSDictionary<NSNumber *, NSObject *>* headers) {
    NSDictionary<NSString *, VariantObject *>* params = (NSDictionary<NSString *, VariantObject *>*)[headers objectForKey:@(KDFPARAMETERS)];
    
    return [[KdfParameters alloc] initWithParameters:params];
}

static NSUUID* getCipherUuid(NSDictionary<NSNumber *,NSObject *>* headers) {
    NSData* cipherData = (NSData*)[headers objectForKey:@(CIPHERID)];
    return cipherData ? [[NSUUID alloc] initWithUUIDBytes:cipherData.bytes] : aesCipherUuid();
}

@end
