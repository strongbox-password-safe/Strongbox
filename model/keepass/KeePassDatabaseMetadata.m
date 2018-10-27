//
//  KeePassDatabaseMetadata.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassDatabaseMetadata.h"
#import "KeePassConstants.h"
#import "BasicOrderedDictionary.h"

static NSString* const kDefaultFileVersion = @"3.1";
static const uint32_t kDefaultTransformRounds = 600000;
static const uint32_t kDefaultInnerRandomStreamId = kInnerStreamSalsa20;

@implementation KeePassDatabaseMetadata

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.generator = kDefaultGenerator;
        self.version = kDefaultFileVersion;
        self.compressionFlags = YES;
        self.transformRounds = kDefaultTransformRounds;
        self.innerRandomStreamId = kDefaultInnerRandomStreamId;
    }
    
    return self;
}

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi {
    BasicOrderedDictionary<NSString*, NSString*>* kvps = [[BasicOrderedDictionary alloc] init];
    
    [kvps addKey:@"Database Format" andValue:@"KeePass"];
    [kvps addKey:@"KeePass File Version"  andValue:self.version];
    [kvps addKey:@"Database Generator" andValue:self.generator];
    [kvps addKey:@"Compressed"  andValue:self.compressionFlags == kGzipCompressionFlag ? @"Yes (GZIP)" : @"No"];
    [kvps addKey:@"Transform Rounds" andValue:[NSString stringWithFormat:@"%llu", self.transformRounds]];
    [kvps addKey:@"Inner Encryption" andValue:innerEncryptionString(self.innerRandomStreamId)];

    return kvps;
}

NSString* innerEncryptionString(uint32_t innerRandomStreamId) {
    switch (innerRandomStreamId) {
        case kInnerStreamPlainText:
            return @"None (Plaintext)";
            break;
        case kInnerStreamArc4:
            return @"ARC4";
            break;
        case kInnerStreamSalsa20:
            return @"Salsa20";
            break;
        case kInnerChaCha20:
            return @"ChaCha20";
            break;
        default:
            return [NSString stringWithFormat:@"Unknown (%d)", innerRandomStreamId];
            break;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", [self kvpForUi]];
}

@end
