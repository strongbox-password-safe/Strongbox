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
                          kWordListSecureDrop : NSLocalizedString(@"pwgen_wordlist_securedrop", @"SecureDrop"),
                          kWordListEffLarge : NSLocalizedString(@"pwgen_wordlist_eff_large", @"EFF Large"),
                          kWordListBeale : NSLocalizedString(@"pwgen_wordlist_beale", @"Beale"),
                          kWordListCatalan : NSLocalizedString(@"pwgen_wordlist_catalan", @"Catalan"),
                          kWordListDiceware : NSLocalizedString(@"pwgen_wordlist_diceware", @"Diceware (Arnold G. Reinhold's Original)"),
                          kWordListDutch : NSLocalizedString(@"pwgen_wordlist_dutch", @"Dutch"),
                          kWordListEffShort1 : NSLocalizedString(@"pwgen_wordlist_eff_short_1", @"EFF Short (v1.0)"),
                          kWordListEffShort2 : NSLocalizedString(@"pwgen_wordlist_eff_short_2", @"EFF Short (v2.0 - More memorable, unique prefix)"),
                          kWordListFrench : NSLocalizedString(@"pwgen_wordlist_french", @"French"),
                          kWordListGerman : NSLocalizedString(@"pwgen_wordlist_german", @"German"),
                          kWordListGoogleUsNoSwears : NSLocalizedString(@"pwgen_wordlist_google", @"Google (U.S. English, No Swears)"),
                          kWordListItalian : NSLocalizedString(@"pwgen_wordlist_italian", @"Italian"),
                          kWordListJapanese : NSLocalizedString(@"pwgen_wordlist_japanese", @"Japanese"),
                          kWordListPolish : NSLocalizedString(@"pwgen_wordlist_polish", @"Polish"),
                          kWordListSwedish : NSLocalizedString(@"pwgen_wordlist_swedish", @"Swedish"),
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
            return NSLocalizedString(@"pwgen_casing_do_not_change", @"Do Not Change");
            break;
        case kPasswordGenerationWordCasingLower:
            return NSLocalizedString(@"pwgen_casing_lowercase", @"Lowercase");
            break;
        case kPasswordGenerationWordCasingUpper:
            return NSLocalizedString(@"pwgen_casing_uppercase", @"Uppercase");
            break;
        case kPasswordGenerationWordCasingTitle:
            return NSLocalizedString(@"pwgen_casing_title_case", @"Title Case");
            break;
        case kPasswordGenerationWordCasingRandom:
            return NSLocalizedString(@"pwgen_casing_random", @"Random");
            break;
        default:
            return @"Unknown";
            break;
    }
}

+ (NSString*)characterPoolToPoolString:(PasswordGenerationCharacterPool)pool {
    switch (pool) {
        case kPasswordGenerationCharacterPoolLower:
            return NSLocalizedString(@"pwgen_casing_lowercase", @"Lowercase");
            break;
        case kPasswordGenerationCharacterPoolUpper:
            return NSLocalizedString(@"pwgen_casing_uppercase", @"Uppercase");
            break;
        case kPasswordGenerationCharacterPoolNumeric:
            return NSLocalizedString(@"pwgen_casing_numeric", @"Numeric");
            break;
        case kPasswordGenerationCharacterPoolSymbols:
            return NSLocalizedString(@"pwgen_casing_symbols", @"Symbols");
            break;
        default:
            return @"Unknown";
            break;
    }
}

+ (NSString*)getHackerifyLevel:(PasswordGenerationHackerifyLevel)level {
    switch (level) {
        case kPasswordGenerationHackerifyLevelNone:
            return NSLocalizedString(@"pwgen_hacker_level_none", @"None");
            break;
        case kPasswordGenerationHackerifyLevelBasicSome:
            return NSLocalizedString(@"pwgen_hacker_level_basic_some", @"Basic (Some Words)");
            break;
        case kPasswordGenerationHackerifyLevelBasicAll:
            return NSLocalizedString(@"pwgen_hacker_level_basic_all", @"Basic (All Words)");
            break;
        case kPasswordGenerationHackerifyLevelProSome:
            return NSLocalizedString(@"pwgen_hacker_level_pro_some", @"Pro (Some Words)");
            break;
        case kPasswordGenerationHackerifyLevelProAll:
            return NSLocalizedString(@"pwgen_hacker_level_pro_all", @"Pro (All Words)");
            break;
    }
}

+ (NSString*)getSaltLevel:(PasswordGenerationSaltConfig)salt {
    switch (salt) {
        case kPasswordGenerationSaltConfigNone:
            return NSLocalizedString(@"pwgen_salt_mode_none", @"None");
            break;
        case kPasswordGenerationSaltConfigPrefix:
            return NSLocalizedString(@"pwgen_salt_mode_prefix", @"Prefix");
            break;
        case kPasswordGenerationSaltConfigSprinkle:
            return NSLocalizedString(@"pwgen_salt_mode_sprinkle", @"Sprinkle");
            break;
        case kPasswordGenerationSaltConfigSuffix:
            return NSLocalizedString(@"pwgen_salt_mode_suffix", @"Suffix");
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
