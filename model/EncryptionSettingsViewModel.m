//
//  EncryptionSettingsModel.m
//  Strongbox
//
//  Created by Strongbox on 11/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "EncryptionSettingsViewModel.h"
#import "Argon2KdfCipher.h"
#import "KeePassConstants.h"
#import "KeePassCiphers.h"
#import "AesKdfCipher.h"
#import "PwSafeSerialization.h"
#import "UnifiedDatabaseMetadata.h"
#import "PwSafeDatabase.h"
#import "Argon2dKdfCipher.h"
#import "Argon2idKdfCipher.h"
#import "Utils.h"

@interface EncryptionSettingsViewModel ()

@property DatabaseFormat _format;
@property KdfAlgorithm _kdfAlgorithm;

@property (nullable) NSString* subVersion;

@property (nullable) NSString* generator;

@end

@implementation EncryptionSettingsViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        self.format = kFormatUnknown;
        self.subVersion = @"";
        self.kdfAlgorithm = kKdfAlgorithmUnknown;
        self.argonMemory = Argon2KdfCipher.defaultMemory;
        self.iterations = Argon2KdfCipher.defaultIterations;
        self.argonParallelism = Argon2KdfCipher.defaultParallelism;
        self.encryptionAlgorithm = kEncryptionAlgorithmUnknown;
        self.compression = NO;
        self.innerStreamAlgorithm = kInnerStreamAlgorithmUnknown;
    }
    return self;
}

+ (instancetype)defaultsForFormat:(DatabaseFormat)format {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
    
    UnifiedDatabaseMetadata* meta = [UnifiedDatabaseMetadata withDefaultsForFormat:format];
    
    ret.format = format;
    
    ret.subVersion = meta.version;
    ret.iterations = meta.kdfIterations;
    ret.kdfAlgorithm = kKdfAlgorithmAes256;

    if ( format == kPasswordSafe ) {
        ret.encryptionAlgorithm = kEncryptionAlgorithmTwoFish256;
    }
    else if( format == kKeePass ) {
        ret.encryptionAlgorithm = [EncryptionSettingsViewModel getEncryptionAlgorithm:meta.cipherUuid];
        ret.compression = meta.compressionFlags == kGzipCompressionFlag;
        ret.innerStreamAlgorithm = [EncryptionSettingsViewModel getInnerStreamAlgorithm:meta.innerRandomStreamId];
    }
    else if( format == kKeePass4 ) {
        [EncryptionSettingsViewModel fillKeePass4FromMeta:ret meta:meta];
    }
    else if( format == kKeePass1 ) {
        ret.subVersion = nil;
        ret.encryptionAlgorithm = kEncryptionAlgorithmTwoFish256;
    }
    else {
        slog(@"🔴 EERROR Unknown Format in defaultsForFormat");
    }
    
    return ret;
}

+ (instancetype)fromDatabaseModel:(DatabaseModel*)databaseModel {
    switch ( databaseModel.originalFormat ) {
        case kPasswordSafe:
            return [EncryptionSettingsViewModel processPasswordSafe:databaseModel];
            break;
        case kKeePass:
            return [EncryptionSettingsViewModel processKP31:databaseModel];

            break;
        case kKeePass4:
            return [EncryptionSettingsViewModel processKP4:databaseModel];
            break;
        case kKeePass1:
            return [EncryptionSettingsViewModel processKP1:databaseModel];
            break;
        case kFormatUnknown:
            slog(@"WARNWARN - Unknown Datavase format");
            break;
    }
    
    return nil;
}

+ (EncryptionSettingsViewModel*)processPasswordSafe:(DatabaseModel*)databaseModel {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
    
    ret.format = kPasswordSafe;
    ret.subVersion = databaseModel.meta.version;
    ret.kdfAlgorithm = kKdfAlgorithmSha256;
    ret.iterations = databaseModel.meta.kdfIterations;
    ret.encryptionAlgorithm = kEncryptionAlgorithmTwoFish256;
        
    return ret;
}

+ (EncryptionSettingsViewModel*)processKP1:(DatabaseModel*)databaseModel {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
    
    ret.format = kKeePass1;
    ret.subVersion = nil;
    ret.kdfAlgorithm = kKdfAlgorithmAes256;
    ret.iterations = databaseModel.meta.kdfIterations;
    ret.encryptionAlgorithm = kEncryptionAlgorithmTwoFish256;
        
    return ret;
}

+ (EncryptionSettingsViewModel*)processKP31:(DatabaseModel*)databaseModel {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
            
    ret.format = kKeePass;
    ret.subVersion = databaseModel.meta.version;
    ret.kdfAlgorithm = kKdfAlgorithmAes256;
    ret.iterations = databaseModel.meta.kdfIterations;
    ret.encryptionAlgorithm = [EncryptionSettingsViewModel getEncryptionAlgorithm:databaseModel.meta.cipherUuid];
    ret.compression = databaseModel.meta.compressionFlags == kGzipCompressionFlag;
    ret.innerStreamAlgorithm = [EncryptionSettingsViewModel getInnerStreamAlgorithm:databaseModel.meta.innerRandomStreamId];

    ret.generator = databaseModel.meta.generator;
    
    return ret;
}

+ (void)fillKeePass4FromMeta:(EncryptionSettingsViewModel*)ret meta:(UnifiedDatabaseMetadata*)meta {
    ret.subVersion = meta.version;
    ret.encryptionAlgorithm = [EncryptionSettingsViewModel getEncryptionAlgorithm:meta.cipherUuid];
    ret.compression = meta.compressionFlags == kGzipCompressionFlag;
    ret.innerStreamAlgorithm = [EncryptionSettingsViewModel getInnerStreamAlgorithm:meta.innerRandomStreamId];
    
    KdfParameters* kdfParameters = meta.kdfParameters;
    KdfAlgorithm kdfAlgorithm = kKdfAlgorithmUnknown;
    
    if ( [kdfParameters.uuid isEqual:argon2dCipherUuid()] ) {
        kdfAlgorithm = kKdfAlgorithmArgon2d;
    }
    else if([kdfParameters.uuid isEqual:argon2idCipherUuid()]) {
        kdfAlgorithm = kKdfAlgorithmArgon2id;
    }
    else if([kdfParameters.uuid isEqual:aesKdbx3KdfCipherUuid()] || [kdfParameters.uuid isEqual:aesKdbx4KdfCipherUuid()]) {
        kdfAlgorithm = kKdfAlgorithmAes256;
    }
    
    ret.kdfAlgorithm = kdfAlgorithm;
    
    if ( kdfAlgorithm == kKdfAlgorithmArgon2d || kdfAlgorithm == kKdfAlgorithmArgon2id ) {
        Argon2KdfCipher* cip = [[Argon2KdfCipher alloc] initWithParametersDictionary:kdfParameters];
        ret.iterations = cip.iterations;
        ret.argonMemory = cip.memory;
        ret.argonParallelism = cip.parallelism;
        
    }
    else if (kdfAlgorithm == kKdfAlgorithmAes256 ) {
        AesKdfCipher* cip = [[AesKdfCipher alloc] initWithParametersDictionary:kdfParameters];
        ret.iterations = cip.iterations;
    }
}

+ (EncryptionSettingsViewModel*)processKP4:(DatabaseModel*)databaseModel {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
    
    ret.format = kKeePass4;
    ret.generator = databaseModel.meta.generator;
    
    [EncryptionSettingsViewModel fillKeePass4FromMeta:ret meta:databaseModel.meta];
        
    return ret;
}



- (instancetype)clone {
    EncryptionSettingsViewModel* ret = [[EncryptionSettingsViewModel alloc] init];
   
    ret.format = self.format;
    ret.subVersion = self.subVersion;
    ret.kdfAlgorithm = self.kdfAlgorithm;
    ret.argonMemory = self.argonMemory;
    ret.iterations = self.iterations;
    ret.argonParallelism = self.argonParallelism;
    ret.encryptionAlgorithm = self.encryptionAlgorithm;
    ret.compression = self.compression;
    ret.innerStreamAlgorithm = self.innerStreamAlgorithm;
    
    return ret;
}

- (BOOL)shouldUpgradeToV4 {
    return self.format == kKeePass;
}

- (BOOL)shouldReduceArgon2Memory {    
    return self.format == kKeePass4 && (self.kdfAlgorithm == kKdfAlgorithmArgon2d || self.kdfAlgorithm == kKdfAlgorithmArgon2id) && self.argonMemory > Argon2KdfCipher.maxRecommendedMemory;
}

- (BOOL)shouldShowCompressionSwitch {
    return self.format != kPasswordSafe && self.format != kKeePass1;
}

- (BOOL)shouldShowArgon2Fields {
    return self.format == kKeePass4 && (self.kdfAlgorithm == kKdfAlgorithmArgon2d || self.kdfAlgorithm == kKdfAlgorithmArgon2id);
}

- (BOOL)shouldShowInnerStreamEncryption {
    return self.format != kPasswordSafe && self.format != kKeePass1;
}

- (BOOL)formatIsEditable {
    return self.format != kPasswordSafe && self.format != kKeePass1;
}

- (BOOL)kdfIsEditable {
    return self.format == kKeePass4;
}

- (BOOL)encryptionIsEditable {
    return self.format == kKeePass4;
}

- (CGFloat)minKdfIterations { 
    if (self.kdfAlgorithm == kKdfAlgorithmSha256 ) {
        return 11.0f;
    }
    else {
        return 1.0f;
    }
}

- (CGFloat)maxKdfIterations { 
    if ( self.kdfAlgorithm == kKdfAlgorithmArgon2d || self.kdfAlgorithm == kKdfAlgorithmArgon2id ) {
        return 12;
    }
    else if (self.kdfAlgorithm == kKdfAlgorithmSha256 ) {
        return 22;
    }
    
    return 31; 
}

- (NSString *)formatAndVersion {
    NSString* format = [self getFormatString];
    
    NSString* ret;
    if ( self.subVersion ) {
        ret = [NSString stringWithFormat:@"%@ (%@)", format, self.subVersion];
    }
    else {
        ret = format;
    }
    
    return ret;
}

- (NSString *)kdf {
    return [EncryptionSettingsViewModel kdfStringForKdf:self.kdfAlgorithm];
}

+ (NSString *)kdfStringForKdf:(KdfAlgorithm)algo {
    if( algo == kKdfAlgorithmAes256 ) {
        return @"AES-256";
    }
    else if(algo == kKdfAlgorithmArgon2d) {
        return @"Argon2d";
    }
    else if(algo == kKdfAlgorithmArgon2id) {
        return @"Argon2id";
    }
    else if(algo == kKdfAlgorithmSha256) {
        return @"SHA-256";
    }

    return @"<Unknown>";
}

- (NSString *)encryption {
    return [EncryptionSettingsViewModel encryptionStringForAlgo:self.encryptionAlgorithm];
}

+ (NSString *)encryptionStringForAlgo:(EncryptionAlgorithm)algo {
    if( algo == kEncryptionAlgorithmChaCha20 ) {
        return @"ChaCha20";
    }
    else if(algo == kEncryptionAlgorithmTwoFish256) {
        return @"TwoFish";
    }
    else if(algo == kEncryptionAlgorithmAes256) {
        return @"AES-256";
    }

    return @"<Unknown>";
}

- (NSString *)compressionString {
    return [EncryptionSettingsViewModel compressionStringForCompression:self.compression];
}

+ (NSString *)compressionStringForCompression:(BOOL)compressed {
    return compressed ? @"GZip" : NSLocalizedString(@"generic_none", @"None");
}

- (NSString *)innerStreamCipher {
    if( self.innerStreamAlgorithm == kInnerStreamAlgorithmChaCha20 ) {
        return @"ChaCha20";
    }
    else if(self.innerStreamAlgorithm == kInnerStreamAlgorithmSalsa20) {
        return @"Salsa20";
    }
    else if(self.innerStreamAlgorithm == kInnerStreamAlgorithmPlainText) {
        return @"None (Plaintext)";
    }
    
    return @"<Unknown>";
}



- (NSString*)getFormatString {
    return [EncryptionSettingsViewModel getFormatString:self.format];
}

+ (NSString*)getFormatString:(DatabaseFormat)format {
    if ( format == kPasswordSafe ) {
        return @"Password Safe";
    }
    else if ( format == kKeePass1 ) {
        return @"KeePass 1";
    }
    else if ( format == kKeePass ) {
        return @"KeePass 2";
    }
    else if ( format == kKeePass4 ) {
        return @"KeePass 2";
    }
    
    return @"Unknown";
}

+ (NSString *)getAlternativeFormatString:(DatabaseFormat)format {
    if ( format == kKeePass ) {
        return NSLocalizedString(@"keepass_kdbx3_format_not_recommended", @"KeePass 2 (KDBX 3.x) ⚠️");
    }
    else {
        return NSLocalizedString(@"keepass_kdbx4x_format", @"KeePass 2 (KDBX 4.x)");
    }
}



- (DatabaseFormat)format {
    return self._format;
}

- (void)setFormat:(DatabaseFormat)format {
    if ( format == kKeePass ) {
        self.subVersion = kKP3DefaultFileVersion;
        self.kdfAlgorithm = kKdfAlgorithmAes256;
        self.encryptionAlgorithm = kEncryptionAlgorithmAes256;
        self.iterations = kDefaultTransformRounds;
        self.innerStreamAlgorithm = kInnerStreamSalsa20;
    }
    else if ( format == kKeePass4 ) {
        self.subVersion = kKdb4DefaultFileVersion;
        self.kdfAlgorithm = kKdfAlgorithmArgon2d;
        self.encryptionAlgorithm = kEncryptionAlgorithmAes256;
        self.iterations = Argon2KdfCipher.defaultIterations;
        self.innerStreamAlgorithm = kInnerStreamChaCha20;
    }
    else if ( format == kPasswordSafe ) {
        self.subVersion = [NSString stringWithFormat:@"%ld.%ld", (long)kPwSafeDefaultVersionMajor, (long)kPwSafeDefaultVersionMinor];
        self.iterations = DEFAULT_KEYSTRETCH_ITERATIONS;
    }
    else if (format == kKeePass1) {
        self.iterations = kDefaultTransformRounds;
    }
    
    self._format = format;
}

- (KdfAlgorithm)kdfAlgorithm {
    return self._kdfAlgorithm;
}

- (void)setKdfAlgorithm:(KdfAlgorithm)kdfAlgorithm {
    self._kdfAlgorithm = kdfAlgorithm;
    
    if ( self.format == kKeePass4 ) {
        if ( kdfAlgorithm == kKdfAlgorithmAes256 ) {
            self.iterations = AesKdfCipher.defaultIterations;
        }
        else {
            self.iterations = Argon2KdfCipher.defaultIterations;
        }
    }
}



- (void)calibrateFor1Second {
    
}

- (BOOL)isDifferentFrom:(EncryptionSettingsViewModel*)other {
    if ( self.format != other.format ) {
        return YES;
    }
    if ( self.subVersion != nil && other.subVersion != nil && ![self.subVersion isEqualToString:other.subVersion] ) {
        return YES;
    }
    
    return [self isEncryptionParamsDifferentFrom:other];
}

- (BOOL)isEncryptionParamsDifferentFrom:(EncryptionSettingsViewModel*)other {
    if ( self.kdfAlgorithm != other.kdfAlgorithm ) {
        return YES;
    }
    if ( self.argonMemory != other.argonMemory ) {
        return YES;
    }
    if ( self.iterations != other.iterations ) {
        return YES;
    }
    if ( self.argonParallelism != other.argonParallelism ) {
        return YES;
    }
    if ( self.encryptionAlgorithm != other.encryptionAlgorithm ) {
        return YES;
    }
    if ( self.compression != other.compression ) {
        return YES;
    }
    if ( self.innerStreamAlgorithm != other.innerStreamAlgorithm ) {
        return YES;
    }
    
    return NO;
}



+ (int)getInnerStreamId:(InnerStreamAlgorithm)algo {
    switch ( algo ) {
        case kInnerStreamAlgorithmPlainText:
            return kInnerStreamPlainText;
            break;
        case kInnerStreamAlgorithmSalsa20:
            return kInnerStreamSalsa20;
            break;
        case kInnerStreamAlgorithmChaCha20:
            return  kInnerStreamChaCha20;
            break;
        default:
            break;
    }

    slog(@"WARNWARN: Unknown Inner Stream Algo");

    return -1;
}

+ (InnerStreamAlgorithm)getInnerStreamAlgorithm:(int)innerStreamId {
    switch ( innerStreamId ) {
        case kInnerStreamPlainText:
            return kInnerStreamAlgorithmPlainText;
            break;
        case kInnerStreamSalsa20:
            return  kInnerStreamAlgorithmSalsa20;
            break;
        case kInnerStreamChaCha20:
            return  kInnerStreamAlgorithmChaCha20;
            break;
        default:
            break;
    }
    
    slog(@"WARNWARN: Unknown Inner Stream ID");
    
    return kInnerStreamAlgorithmUnknown;
}

+ (EncryptionAlgorithm)getEncryptionAlgorithm:(NSUUID*)uuid {
    if ([uuid isEqual:aesCipherUuid()]) {
        return kEncryptionAlgorithmAes256;
    }
    else if([uuid isEqual:chaCha20CipherUuid()]) {
        return kEncryptionAlgorithmChaCha20;
    }
    else if([uuid isEqual:twoFishCipherUuid()]) {
        return kEncryptionAlgorithmTwoFish256;
    }
    
    return kEncryptionAlgorithmUnknown;
}

+ (NSUUID*)getEncryptionCipherUuid:(EncryptionAlgorithm)algo {
    if ( algo == kEncryptionAlgorithmAes256 ) {
        return aesCipherUuid();
    }
    if ( algo == kEncryptionAlgorithmChaCha20 ) {
        return chaCha20CipherUuid();
    }
    if ( algo == kEncryptionAlgorithmTwoFish256 ) {
        return twoFishCipherUuid();
    }

    return nil;
}

- (void)applyToDatabaseModel:(DatabaseModel*)model {
    if ( self.format == kKeePass || self.format == kKeePass4 ) {
        [model changeKeePassFormat:self.format];
        
        if ( ![model.meta.version isEqualToString:self.subVersion] ) {
            model.meta.version = self.subVersion;
        }
    }
 
    if ( self.format == kKeePass4 ) {
        KdfParameters* newKdfParams;
        
        if ( self.kdfAlgorithm == kKdfAlgorithmArgon2d ) {
            Argon2dKdfCipher* foo = [[Argon2dKdfCipher alloc] initWithMemory:self.argonMemory parallelism:self.argonParallelism iterations:self.iterations];
            newKdfParams = foo.kdfParameters;
        }
        else if ( self.kdfAlgorithm == kKdfAlgorithmArgon2id ) {
            Argon2idKdfCipher* foo = [[Argon2idKdfCipher alloc] initWithMemory:self.argonMemory parallelism:self.argonParallelism iterations:self.iterations];
            newKdfParams = foo.kdfParameters;
        }
        else if ( self.kdfAlgorithm == kKdfAlgorithmAes256 ) {
            AesKdfCipher* foo = [[AesKdfCipher alloc] initWithIterations:self.iterations];
            newKdfParams = foo.kdfParameters;
        }
        else {
            slog(@"WARNWARN: Unknown KDF");
            return;
        }
        
        model.meta.kdfParameters = newKdfParams;
    }
    else {
        model.meta.kdfIterations = self.iterations;
    }
    
    model.meta.cipherUuid = [EncryptionSettingsViewModel getEncryptionCipherUuid:self.encryptionAlgorithm];
    model.meta.innerRandomStreamId = [EncryptionSettingsViewModel getInnerStreamId:self.innerStreamAlgorithm];
    model.meta.compressionFlags = self.compression ? kGzipCompressionFlag : kNoCompressionFlag;
}

- (BOOL)isStrongboxDefaultEncryptionSettings {
    EncryptionSettingsViewModel *defaults = [EncryptionSettingsViewModel defaultsForFormat:self.format];
    
    return ![self isEncryptionParamsDifferentFrom:defaults];
}

- (NSString *)debugString {
    if ( self.kdfAlgorithm == kKdfAlgorithmArgon2d || self.kdfAlgorithm == kKdfAlgorithmArgon2d ) {
        return [NSString stringWithFormat:@"%@/%@ %@ (I%llu/P%u)/%@/%@/%@/%@", [self formatAndVersion], self.kdf, friendlyMemorySizeString(self.argonMemory), self.iterations, self.argonParallelism, self.encryption, self.innerStreamCipher, self.compressionString, self.generator];
    }
    else {
        return [NSString stringWithFormat:@"%@/%@ (I%llu)/%@/%@/%@/%@", [self formatAndVersion], self.kdf, self.iterations, self.encryption, self.innerStreamCipher, self.compressionString, self.generator];
    }
}

@end
