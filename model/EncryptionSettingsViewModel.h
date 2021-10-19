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

typedef enum : NSUInteger {
    kKdfAlgorithmUnknown,
    kKdfAlgorithmArgon2d,
    kKdfAlgorithmArgon2id,
    kKdfAlgorithmAes256,
    kKdfAlgorithmSha256,
} KdfAlgorithm;

typedef enum : NSUInteger {
    kEncryptionAlgorithmUnknown,
    kEncryptionAlgorithmTwoFish256,
    kEncryptionAlgorithmChaCha20,
    kEncryptionAlgorithmAes256,
} EncryptionAlgorithm;

typedef enum : NSUInteger {
    kInnerStreamAlgorithmUnknown,
    kInnerStreamAlgorithmPlainText,
    kInnerStreamAlgorithmSalsa20,
    kInnerStreamAlgorithmChaCha20,
} InnerStreamAlgorithm;


@interface EncryptionSettingsViewModel : NSObject

+ (instancetype _Nullable)fromDatabaseModel:(DatabaseModel*)databaseModel;
- (instancetype)clone;

@property DatabaseFormat format;
@property (nullable) NSString* subVersion;
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

@property (readonly) BOOL shouldUpgradeToV4;
@property (readonly) BOOL shouldReduceArgon2Memory;
@property (readonly) BOOL shouldShowCompressionSwitch;
@property (readonly) BOOL shouldShowArgon2Fields;
@property (readonly) BOOL shouldShowInnerStreamEncryption;
@property (readonly) BOOL formatIsEditable;
@property (readonly) BOOL kdfIsEditable;
@property (readonly) BOOL encryptionIsEditable;
@property (readonly) BOOL compressionIsEditable;

@property (readonly) CGFloat minKdfIterations;
@property (readonly) CGFloat maxKdfIterations;

+ (NSString*)getAlternativeFormatString:(DatabaseFormat)format;
+ (NSString *)kdfStringForKdf:(KdfAlgorithm)algo;
+ (NSString *)encryptionStringForAlgo:(EncryptionAlgorithm)algo;
+ (NSString *)compressionStringForCompression:(BOOL)compressed;



- (void)calibrateFor1Second;
- (void)applyToDatabaseModel:(DatabaseModel*)model;
- (BOOL)isDifferentFrom:(EncryptionSettingsViewModel*)other;

@end

NS_ASSUME_NONNULL_END
