//
//  PasswordGenerationConfig.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WordList.h"

NS_ASSUME_NONNULL_BEGIN

//typedef enum {
//    kBasic,
//    kXkcd


typedef NS_ENUM (NSInteger, PasswordGenerationAlgo) {
    kPasswordGenerationAlgorithmBasic,
    kPasswordGenerationAlgorithmDiceware,
};

typedef NS_ENUM (NSInteger, PasswordGenerationCharacterPool) {
    kPasswordGenerationCharacterPoolUpper,
    kPasswordGenerationCharacterPoolLower,
    kPasswordGenerationCharacterPoolNumeric,
    kPasswordGenerationCharacterPoolSymbols,
    kPasswordGenerationCharacterPoolLatin1Supplement,
    kPasswordGenerationCharacterPoolEmojis,
};

typedef NS_ENUM (NSInteger, PasswordGenerationWordCasing) {
    kPasswordGenerationWordCasingNoChange,
    kPasswordGenerationWordCasingUpper,
    kPasswordGenerationWordCasingLower,
    kPasswordGenerationWordCasingTitle,
    kPasswordGenerationWordCasingRandom,
};

typedef NS_ENUM (NSInteger, PasswordGenerationHackerifyLevel) {
    kPasswordGenerationHackerifyLevelNone,
    kPasswordGenerationHackerifyLevelBasicSome,
    kPasswordGenerationHackerifyLevelBasicAll,
    kPasswordGenerationHackerifyLevelProSome,
    kPasswordGenerationHackerifyLevelProAll,
};

typedef NS_ENUM (NSInteger, PasswordGenerationSaltConfig) {
    kPasswordGenerationSaltConfigNone,
    kPasswordGenerationSaltConfigPrefix,
    kPasswordGenerationSaltConfigSprinkle,
    kPasswordGenerationSaltConfigSuffix,
};

@interface PasswordGenerationConfig : NSObject

+ (instancetype)defaults;
+ (NSDictionary<NSString*, WordList*>*)wordListsMap;

+ (NSString*)getCasingStringForCasing:(PasswordGenerationWordCasing)casing;
+ (NSString*)characterPoolToPoolString:(PasswordGenerationCharacterPool)pool;
+ (NSString*)getHackerifyLevel:(PasswordGenerationHackerifyLevel)level;
+ (NSString*)getSaltLevel:(PasswordGenerationSaltConfig)salt;

@property PasswordGenerationAlgo algorithm;

@property NSInteger basicLength;
@property NSArray<NSNumber*> *useCharacterGroups;
@property BOOL easyReadCharactersOnly;
@property BOOL nonAmbiguousOnly;
@property BOOL pickFromEveryGroup;

@property NSInteger wordCount;
@property NSArray<NSString*>* wordLists;
@property NSString* wordSeparator;
@property PasswordGenerationWordCasing wordCasing;
@property PasswordGenerationHackerifyLevel hackerify;
@property PasswordGenerationSaltConfig saltConfig;



@property BOOL dicewareAddNumber;
@property BOOL dicewareAddUpper;
@property BOOL dicewareAddLower;
@property BOOL dicewareAddSymbols;
@property BOOL dicewareAddLatin1Supplement;

@property NSString* basicExcludedCharacters;

@end

NS_ASSUME_NONNULL_END
