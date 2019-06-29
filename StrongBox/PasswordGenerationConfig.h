//
//  PasswordGenerationConfig.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kPasswordGenerationAlgorithmBasic,
    kPasswordGenerationAlgorithmDiceware,
} PasswordGenerationAlgo;

typedef enum {
    kPasswordGenerationCharacterPoolUpper,
    kPasswordGenerationCharacterPoolLower,
    kPasswordGenerationCharacterPoolNumeric,
    kPasswordGenerationCharacterPoolSymbols,
//    kPasswordGenerationCharacterPoolEmoji,
//    kPasswordGenerationCharacterPoolExtendedAscii,
} PasswordGenerationCharacterPool;

@interface PasswordGenerationConfig : NSObject

+ (instancetype)defaults;

@property PasswordGenerationAlgo algorithm;

@property NSInteger basicLength;
@property NSArray<NSNumber*> *useCharacterGroups;
@property BOOL easyReadCharactersOnly;
@property BOOL nonAmbiguousOnly;
@property BOOL pickFromEveryGroup;

@property NSInteger wordCount;
@property BOOL wordLists;
@property NSString* wordSeparator;
@property BOOL casing;
@property BOOL hackerify;
@property BOOL addSalt;

@end

NS_ASSUME_NONNULL_END
