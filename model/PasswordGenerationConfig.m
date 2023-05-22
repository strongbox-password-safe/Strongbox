//
//  PasswordGenerationConfig.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
static NSString* const kWordListNorwegian = @"norwegian-diceware.wordlist.utf8";
static NSString* const kWordListFinnish = @"finnish-diceware.wordlist.utf8";
static NSString* const kWordListIcelandic = @"icelandic-diceware.wordlist.utf8";
static NSString* const kWordListOrchardSt = @"orchard-street-medium";

static NSString* const kWordListPtBr = @"ptbr-diceware.wordlist.utf8";

static NSString* const kWordListFandomGameOfThrones = @"gameofthrones_8k_2018.utf8";
static NSString* const kWordListFandomHarryPotter = @"harrypotter_8k_2018.utf8";
static NSString* const kWordListFandomStarTrek = @"star_trek_8k_2018.utf8";
static NSString* const kWordListFandomStarWars = @"starwars_8k_2018.utf8";

const static NSDictionary<NSString*, WordList*> *wordListsMap;

+ (void)initialize {
    if(self == [PasswordGenerationConfig class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSArray<WordList*>* wls = @[
                [WordList named:NSLocalizedString(@"pwgen_wordlist_securedrop", @"SecureDrop") withKey:kWordListSecureDrop withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_eff_large", @"EFF Large") withKey:kWordListEffLarge withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_beale", @"Beale") withKey:kWordListBeale withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_catalan", @"Catalan") withKey:kWordListCatalan withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_diceware", @"Diceware (Arnold G. Reinhold's Original)") withKey:kWordListDiceware withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_dutch", @"Dutch") withKey:kWordListDutch withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_eff_short_1", @"EFF Short (v1.0)") withKey:kWordListEffShort1 withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_eff_short_2", @"EFF Short (v2.0 - More memorable, unique prefix)") withKey:kWordListEffShort2 withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_french", @"French") withKey:kWordListFrench withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_german", @"German") withKey:kWordListGerman withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_google", @"Google (U.S. English, No Swears)") withKey:kWordListGoogleUsNoSwears withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_italian", @"Italian") withKey:kWordListItalian withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_japanese", @"Japanese") withKey:kWordListJapanese withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_polish", @"Polish") withKey:kWordListPolish withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_swedish", @"Swedish") withKey:kWordListSwedish withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_norwegian", @"Norwegian") withKey:kWordListNorwegian withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_finnish", @"Finnish") withKey:kWordListFinnish withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_icelandic", @"Icelandic") withKey:kWordListIcelandic withCategory:kWordListCategoryLanguages],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_gameofthrones", @"Game of Thrones (EFF Fandom)") withKey:kWordListFandomGameOfThrones withCategory:kWordListCategoryFandom],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_harrypotter", @"Harry Potter (EFF Fandom)") withKey:kWordListFandomHarryPotter withCategory:kWordListCategoryFandom],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_star_trek", @"Star Trek (EFF Fandom)") withKey:kWordListFandomStarTrek withCategory:kWordListCategoryFandom],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_starwars", @"Star Wars (EFF Fandom)") withKey:kWordListFandomStarWars withCategory:kWordListCategoryFandom],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_orchard_st", @"Orchard Street (Medium)") withKey:kWordListOrchardSt withCategory:kWordListCategoryStandard],
                [WordList named:NSLocalizedString(@"pwgen_wordlist_pt_br", @"Portuguese (Brazilian)") withKey:kWordListPtBr withCategory:kWordListCategoryLanguages],
            ];
            
            NSMutableDictionary<NSString*, WordList*>* wld = NSMutableDictionary.dictionary;

            for (WordList* w in wls) {
               wld[w.key] = w;
            }
            
            wordListsMap = wld.copy;
        });
    }
}

+ (instancetype)defaults {
    PasswordGenerationConfig *ret = [[PasswordGenerationConfig alloc] init];
    
    ret.algorithm = kPasswordGenerationAlgorithmBasic;
    
    ret.basicLength = 22;
    ret.basicExcludedCharacters = @"";
    ret.useCharacterGroups = @[@(kPasswordGenerationCharacterPoolLower),
                               @(kPasswordGenerationCharacterPoolUpper),
                               @(kPasswordGenerationCharacterPoolNumeric),
                               @(kPasswordGenerationCharacterPoolSymbols)];
    
    ret.easyReadCharactersOnly = YES;
    ret.nonAmbiguousOnly = YES;
    ret.pickFromEveryGroup = YES;
    
    ret.wordCount = 6;
    ret.wordLists = @[kWordListEffLarge];
    ret.wordSeparator = @"-";
    ret.wordCasing = kPasswordGenerationWordCasingTitle;
    ret.hackerify = kPasswordGenerationHackerifyLevelNone;
    
    return ret;
}

+ (NSDictionary<NSString *,WordList *> *)wordListsMap {
    return wordListsMap.copy;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.dicewareLists = [NSSet set];
        self.characterPools = [NSSet set];
        self.basicExcludedCharacters = @"";
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
    
    [encoder encodeInteger:self.dicewareAddNumber forKey:@"dicewareAddNumber"];
    [encoder encodeInteger:self.dicewareAddUpper forKey:@"dicewareAddUpper"];
    [encoder encodeInteger:self.dicewareAddLower forKey:@"dicewareAddLower"];
    [encoder encodeInteger:self.dicewareAddSymbols forKey:@"dicewareAddSymbols"];
    [encoder encodeInteger:self.dicewareAddLatin1Supplement forKey:@"dicewareAddLatin1Supplement"];
    [encoder encodeObject:self.basicExcludedCharacters forKey:@"basicExcludedCharacters"];

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
        
        if ( [decoder containsValueForKey:@"dicewareAddNumber" ]) {
            self.dicewareAddNumber = [decoder decodeIntegerForKey:@"dicewareAddNumber"];
        }

        if ( [decoder containsValueForKey:@"dicewareAddUpper" ]) {
            self.dicewareAddUpper = [decoder decodeIntegerForKey:@"dicewareAddUpper"];
        }

        if ( [decoder containsValueForKey:@"dicewareAddLower" ]) {
            self.dicewareAddLower = [decoder decodeIntegerForKey:@"dicewareAddLower"];
        }

        if ( [decoder containsValueForKey:@"dicewareAddSymbols" ]) {
            self.dicewareAddSymbols = [decoder decodeIntegerForKey:@"dicewareAddSymbols"];
        }

        if ( [decoder containsValueForKey:@"dicewareAddLatin1Supplement" ]) {
            self.dicewareAddLatin1Supplement = [decoder decodeIntegerForKey:@"dicewareAddLatin1Supplement"];
        }

        if ( [decoder containsValueForKey:@"basicExcludedCharacters" ]) {
            self.basicExcludedCharacters = [decoder decodeObjectForKey:@"basicExcludedCharacters"];
        }
        else {
            self.basicExcludedCharacters = @"";
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
        case kPasswordGenerationCharacterPoolLatin1Supplement:
            return NSLocalizedString(@"pwgen_casing_latin1_supplement", @"Latin-1 Supplement");
            break;
        case kPasswordGenerationCharacterPoolEmojis:
            return NSLocalizedString(@"pwgen_casing_emojis", @"Emojis");
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
