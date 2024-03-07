//
//  EncryptionSettingsModel.h
//  Strongbox
//
//  Created by Strongbox on 11/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, KdfAlgorithm) {
    kKdfAlgorithmUnknown,
    kKdfAlgorithmArgon2d,
    kKdfAlgorithmArgon2id,
    kKdfAlgorithmAes256,
    kKdfAlgorithmSha256,
};

typedef NS_ENUM (NSUInteger, EncryptionAlgorithm) {
    kEncryptionAlgorithmUnknown,
    kEncryptionAlgorithmTwoFish256,
    kEncryptionAlgorithmChaCha20,
    kEncryptionAlgorithmAes256,
};

typedef NS_ENUM (NSUInteger, InnerStreamAlgorithm) {
    kInnerStreamAlgorithmUnknown,
    kInnerStreamAlgorithmPlainText,
    kInnerStreamAlgorithmSalsa20,
    kInnerStreamAlgorithmChaCha20,
};


@interface EncryptionSettingsViewModel : NSObject

+ (instancetype _Nullable)fromDatabaseModel:(DatabaseModel*)databaseModel;
+ (instancetype)defaultsForFormat:(DatabaseFormat)format;

- (instancetype)clone;


@property DatabaseFormat format;

@property KdfAlgorithm kdfAlgorithm;
@property uint64_t argonMemory;
@property uint64_t iterations;
@property uint32_t argonParallelism;
@property EncryptionAlgorithm encryptionAlgorithm;
@property BOOL compression;
@property InnerStreamAlgorithm innerStreamAlgorithm;



@property (readonly) NSString* formatAndVersion;
@property (readonly) NSString* kdf;
@property (readonly) NSString* encryption;
@property (readonly) NSString* compressionString;
@property (readonly) NSString* innerStreamCipher;
@property (readonly) NSString* debugString;

@property (readonly) BOOL shouldUpgradeToV4;
@property (readonly) BOOL shouldReduceArgon2Memory;
@property (readonly) BOOL shouldShowCompressionSwitch;
@property (readonly) BOOL shouldShowArgon2Fields;
@property (readonly) BOOL shouldShowInnerStreamEncryption;
@property (readonly) BOOL formatIsEditable;
@property (readonly) BOOL kdfIsEditable;
@property (readonly) BOOL encryptionIsEditable;

@property (readonly) CGFloat minKdfIterations;
@property (readonly) CGFloat maxKdfIterations;

@property (readonly) BOOL isStrongboxDefaultEncryptionSettings;

+ (NSString*)getAlternativeFormatString:(DatabaseFormat)format;
+ (NSString *)kdfStringForKdf:(KdfAlgorithm)algo;
+ (NSString *)encryptionStringForAlgo:(EncryptionAlgorithm)algo;
+ (NSString *)compressionStringForCompression:(BOOL)compressed;



- (void)calibrateFor1Second;
- (void)applyToDatabaseModel:(DatabaseModel*)model;
- (BOOL)isDifferentFrom:(EncryptionSettingsViewModel*)other;
- (BOOL)isEncryptionParamsDifferentFrom:(EncryptionSettingsViewModel*)other;

@end

NS_ASSUME_NONNULL_END
