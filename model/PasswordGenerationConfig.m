//
//  PasswordGenerationConfig.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationConfig.h"

@interface PasswordGenerationConfig ()

@property NSSet<NSNumber*>* characterPools;
@property NSSet<NSString*>* dicewareLists;

@end

@implementation PasswordGenerationConfig

static NSString* const kWordListSecureDrop = @"securedrop.wordlist.utf8";
static NSString* const kWordListEffLarge = @"eff_large_wordlist.utf8";
static NSString* const kWordListBeale = @"beale.wordlist.utf8";
static NSString* const kWordListCatalan = @"catalan-diceware.wordlist.utf8";
static NSString* const kWordListDiceware = @"diceware.wordlist.utf8";
static NSString* const kWordListDutch = @"dutch-diceware.wordlist.utf8";
static NSString* const kWordListEffShort1 = @"eff_short_wordlist_1.utf8";
static NSString* const kWordListEffShort2 = @"eff_short_wordlist_2_0.utf8";
static NSString* const kWordListFrench = @"french-diceware.wordlist.utf8";
static NSString* const kWordListGerman = @"german-diceware.wordlist.utf8";
static NSString* const kWordListGoogleUsNoSwears = @"google-10000-english-usa-no-swears-medium";
static NSString* const kWordListItalian = @"italian-diceware.wordlist.utf8";
static NSString* const kWordListJapanese = @"japanese-diceware.wordlist.utf8";
static NSString* const kWordListPolish = @"polish-diceware.wordlist.utf8";
static NSString* const kWordListSwedish = @"swedish-diceware.wordlist.utf8";

const static NSDictionary<NSString*, NSString*> *wordLists;

+ (void)initialize {
    if(self == [PasswordGenerationConfig class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            wordLists = @{
                          kWordListSecureDrop : @"SecureDrop",
                          kWordListEffLarge : @"EFF Large",
                          kWordListBeale : @"Beale",
                          kWordListCatalan : @"Catalan",
                          kWordListDiceware : @"Diceware (Arnold G. Reinhold's Original)",
                          kWordListDutch : @"Dutch",
                          kWordListEffShort1 : @"EFF Short (v1.0)",
                          kWordListEffShort2 : @"EFF Short (v2.0 - More memorable, unique prefix)",
                          kWordListFrench : @"French",
                          kWordListGerman : @"German",
                          kWordListGoogleUsNoSwears : @"Google (U.S. English, No Swears)",
                          kWordListItalian : @"Italian",
                          kWordListJapanese : @"Japanese",
                          kWordListPolish : @"Polish",
                          kWordListSwedish : @"Swedish",
                         };
        });
    }
}

+ (instancetype)defaults {
    PasswordGenerationConfig *ret = [[PasswordGenerationConfig alloc] init];
    
    ret.algorithm = kPasswordGenerationAlgorithmBasic;
    
    ret.basicLength = 16;
    ret.useCharacterGroups = @[@(kPasswordGenerationCharacterPoolLower),
                               @(kPasswordGenerationCharacterPoolUpper),
                               @(kPasswordGenerationCharacterPoolNumeric),
                               @(kPasswordGenerationCharacterPoolSymbols)];
    
    ret.easyReadCharactersOnly = YES;
    ret.nonAmbiguousOnly = YES;
    ret.pickFromEveryGroup = YES;
    
    ret.wordCount = 5;
    ret.wordLists = @[kWordListEffLarge];
    ret.wordSeparator = @"-";
    ret.wordCasing = kPasswordGenerationWordCasingTitle;
    ret.hackerify = kPasswordGenerationHackerifyLevelNone;

    return ret;
}

+ (NSDictionary<NSString*, NSString*>*)wordLists {
    return wordLists.copy;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.dicewareLists = [NSSet set];
        self.characterPools = [NSSet set];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInteger:self.algorithm forKey:@"algorithm"];
    [encoder encodeInteger:self.basicLength forKey:@"basicLength"];
    [encoder encodeObject:self.useCharacterGroups forKey:@"useCharacterGroups"];
    [encoder encodeBool:self.easyReadCharactersOnly forKey:@"easyReadCharactersOnly"];
    [encoder encodeBool:self.nonAmbiguousOnly forKey:@"nonAmbiguousOnly"];
    [encoder encodeBool:self.pickFromEveryGroup forKey:@"pickFromEveryGroup"];
    [encoder encodeInteger:self.wordCount forKey:@"wordCount"];
    [encoder encodeObject:self.wordLists forKey:@"wordLists"];
    [encoder encodeObject:self.wordSeparator forKey:@"wordSeparator"];
    [encoder encodeInteger:self.wordCasing forKey:@"wordCasing"];
    [encoder encodeInteger:self.hackerify forKey:@"hackerifyLevel"];
    [encoder encodeInteger:self.saltConfig forKey:@"saltConfig"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.algorithm = [decoder decodeIntegerForKey:@"algorithm"];
        self.basicLength = [decoder decodeIntegerForKey:@"basicLength"];
        self.useCharacterGroups = [decoder decodeObjectForKey:@"useCharacterGroups"];
        self.easyReadCharactersOnly = [decoder decodeBoolForKey:@"easyReadCharactersOnly"];
        self.nonAmbiguousOnly = [decoder decodeBoolForKey:@"nonAmbiguousOnly"];
        self.pickFromEveryGroup = [decoder decodeBoolForKey:@"pickFromEveryGroup"];
        self.wordCount = [decoder decodeIntegerForKey:@"wordCount"];
        self.wordLists = [decoder decodeObjectForKey:@"wordLists"];
        self.wordSeparator = [decoder decodeObjectForKey:@"wordSeparator"];
        
        if([decoder containsValueForKey:@"wordCasing"]) {
            self.wordCasing = [decoder decodeIntegerForKey:@"wordCasing"];
        }
        if([decoder containsValueForKey:@"hackerifyLevel"]) {
            self.hackerify = [decoder decodeIntegerForKey:@"hackerifyLevel"];
        }
        if([decoder containsValueForKey:@"saltConfig"]) {
            self.saltConfig = [decoder decodeIntegerForKey:@"saltConfig"];
        }
    }
    
    return self;
}

+ (NSString*)getCasingStringForCasing:(PasswordGenerationWordCasing)casing {
    switch (casing) {
        case kPasswordGenerationWordCasingNoChange:
            return @"Do Not Change";
            break;
        case kPasswordGenerationWordCasingLower:
            return @"Lowercase";
            break;
        case kPasswordGenerationWordCasingUpper:
            return @"Uppercase";
            break;
        case kPasswordGenerationWordCasingTitle:
            return @"Title Case";
            break;
        case kPasswordGenerationWordCasingRandom:
            return @"Random";
            break;
        default:
            return @"Unknown";
            break;
    }
}

+ (NSString*)characterPoolToPoolString:(PasswordGenerationCharacterPool)pool {
    switch (pool) {
        case kPasswordGenerationCharacterPoolLower:
            return @"Lowercase";
            break;
        case kPasswordGenerationCharacterPoolUpper:
            return @"Uppercase";
            break;
        case kPasswordGenerationCharacterPoolNumeric:
            return @"Numeric";
            break;
        case kPasswordGenerationCharacterPoolSymbols:
            return @"Symbols";
            break;
        default:
            return @"Unknown";
            break;
    }
}

+ (NSString*)getHackerifyLevel:(PasswordGenerationHackerifyLevel)level {
    switch (level) {
        case kPasswordGenerationHackerifyLevelNone:
            return @"None";
            break;
        case kPasswordGenerationHackerifyLevelBasicSome:
            return @"Basic (Some Words)";
            break;
        case kPasswordGenerationHackerifyLevelBasicAll:
            return @"Basic (All Words)";
            break;
        case kPasswordGenerationHackerifyLevelProSome:
            return @"Pro (Some Words)";
            break;
        case kPasswordGenerationHackerifyLevelProAll:
            return @"Pro (All Words)";
            break;
    }
}

+ (NSString*)getSaltLevel:(PasswordGenerationSaltConfig)salt {
    switch (salt) {
        case kPasswordGenerationSaltConfigNone:
            return @"None";
            break;
        case kPasswordGenerationSaltConfigPrefix:
            return @"Prefix";
            break;
        case kPasswordGenerationSaltConfigSprinkle:
            return @"Sprinkle";
            break;
        case kPasswordGenerationSaltConfigSuffix:
            return @"Suffix";
            break;
    }
}

- (NSArray<NSString *> *)wordLists {
    return self.dicewareLists.allObjects;
}

- (void)setWordLists:(NSArray<NSString *> *)wordLists {
    self.dicewareLists = [NSSet setWithArray:wordLists];
}

- (NSArray<NSNumber *> *)useCharacterGroups {
    return self.characterPools.allObjects;
}

- (void)setUseCharacterGroups:(NSArray<NSNumber *> *)useCharacterGroups {
    self.characterPools = [NSSet setWithArray:useCharacterGroups];
}

@end
