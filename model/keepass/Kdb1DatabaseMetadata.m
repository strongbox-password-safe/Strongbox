//
//  Kdb1DatabaseMetadata.m
//  Strongbox
//
//  Created by Mark on 09/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdb1DatabaseMetadata.h"
#import "KeePassConstants.h"

static const uint32_t kDefaultVersion = 0x00030004;

@implementation Kdb1DatabaseMetadata

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.flags = kFlagsAes | kFlagsSha2;
        self.versionInt = kDefaultVersion;
        self.transformRounds = kDefaultTransformRounds;
    }
    
    return self;
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUi {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];
    
    kvps[NSLocalizedString(@"database_metadata_field_format", @"Database Format")] = @"KeePass 1";
    
    kvps[NSLocalizedString(@"database_metadata_field_outer_encryption", @"Outer Encryption")] = ((self.flags & kFlagsAes) == kFlagsAes) ? @"AES-256" : @"TwoFish";
    
    kvps[NSLocalizedString(@"database_metadata_field_transform_rounds", @"Transform Rounds")] = [NSString stringWithFormat:@"%u", self.transformRounds];
    
    return kvps;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", [self kvpForUi]];
}

@end
