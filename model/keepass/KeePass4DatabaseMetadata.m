//
//  KeePass4DatabaseMetadata.m
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePass4DatabaseMetadata.h"
#import "KeePassConstants.h"
#import "BasicOrderedDictionary.h"
#import "KdbxSerializationCommon.h"
#import "KeePassCiphers.h"
#import "Argon2KdfCipher.h"
#import "NSUUID+Zero.h"
#import "Utils.h"

static NSString* const kDefaultFileVersion = @"4.0";
static const uint32_t kDefaultInnerRandomStreamId = kInnerStreamChaCha20;

@implementation KeePass4DatabaseMetadata

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.generator = kStrongboxGenerator;
        self.version = kDefaultFileVersion;
        self.compressionFlags = kGzipCompressionFlag;
        self.innerRandomStreamId = kDefaultInnerRandomStreamId;
        self.kdfParameters = [[Argon2KdfCipher alloc] initWithDefaults].kdfParameters;
        self.cipherUuid = chaCha20CipherUuid();
        self.historyMaxItems = @(kDefaultHistoryMaxItems);
        self.historyMaxSize = @(kDefaultHistoryMaxSize);
        self.recycleBinEnabled = YES;
        self.recycleBinGroup = NSUUID.zero;
        self.recycleBinChanged = [NSDate date];
    }
    
    return self;
}

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi {
    BasicOrderedDictionary<NSString*, NSString*>* kvps = [[BasicOrderedDictionary alloc] init];

    [kvps addKey:NSLocalizedString(@"database_metadata_field_format", @"Database Format") andValue:@"KeePass 2"];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_keepass_version", @"KeePass File Version")  andValue:self.version];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_generator", @"Database Generator") andValue:self.generator];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_key_derivation", @"Key Derivation") andValue:keyDerivationAlgorithmString(self.kdfParameters.uuid)];
    
    if([self.kdfParameters.uuid isEqual:argon2CipherUuid()]) {
        static NSString* const kParameterMemory = @"M";
        VariantObject* vo = self.kdfParameters.parameters[kParameterMemory];
        if(vo && vo.theObject) {
            uint64_t memory = ((NSNumber*)vo.theObject).longLongValue;

            [kvps addKey:NSLocalizedString(@"database_metadata_field_argon2_memory", @"Argon 2 Memory") andValue:friendlyFileSizeString(memory)];
        }
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_outer_encryption", @"Outer Encryption") andValue:outerEncryptionAlgorithmString(self.cipherUuid)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_compressed", @"Compressed")  andValue:localizedYesOrNoFromBool( self.compressionFlags == kGzipCompressionFlag)];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_inner_encryption", @"Inner Encryption") andValue:innerEncryptionString(self.innerRandomStreamId)];
    
    if(self.historyMaxItems) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_items", @"Max History Items") andValue:[NSString stringWithFormat:@"%ld", self.historyMaxItems.longValue]];
    }
    
    if(self.historyMaxSize) {
        NSString* size = friendlyFileSizeString(self.historyMaxSize.integerValue);
        [kvps addKey:NSLocalizedString(@"database_metadata_field_max_history_size", @"Max History Size") andValue:size];
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_recycle_bin_enabled", @"Recycle Bin Enabled") andValue:localizedYesOrNoFromBool(self.recycleBinEnabled)];
    
    return kvps;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", [self kvpForUi]];
}

@end
