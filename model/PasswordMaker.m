//
//  PasswordMaker.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PasswordMaker.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "Settings.h"

static NSString* const kAllSymbols = @"+-=_@#$%^&;:,.<>/~\\[](){}?!|*'\"";
static NSString* const kAllUppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString* const kAllLowercase = @"abcdefghijklmnopqrstuvwxyz";
static NSString* const kAllDigits = @"0123456789";
static NSString* const kDifficultToRead = @"0125lIOSZ;:,.[](){}!|";
static NSString* const kAmbiguous = @"{}[]()/\\'\"`~,;:.<>";

@interface PasswordMaker ()

//@property NSString* allEmojis;
//@property NSString* allExtendedAscii;

@property NSMutableDictionary<NSString*, NSArray<NSString*>*> *wordListsCache;
@property NSSet<NSString*>* allWordsCacheKey;
@property NSArray<NSString*>* allWordsCache;

@property NSArray<NSString*> *firstNamesCache;
@property NSArray<NSString*> *surnamesCache;

@end

@implementation PasswordMaker

const static NSDictionary<NSString*, NSString*> *l33tMap;
const static NSDictionary<NSString*, NSString*> *l3ssl33tMap;

+ (void)initialize {
    if(self == [PasswordMaker class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            l33tMap = @{
                            @"A" : @"4",
                            @"B" : @"|3",
                            @"C" : @"(",
                            @"D" : @"|)",
                            @"E" : @"3",
                            @"F" : @"|=",
                            @"G" : @"6",
                            @"H" : @"|-|",
                            @"I" : @"|",
                            @"J" : @"9",
                            @"K" : @"|<",
                            @"L" : @"1",
                            @"M" : @"|v|",
                            @"N" : @"|/|",
                            @"O" : @"0",
                            @"P" : @"|*",
                            @"Q" : @"0,",
                            @"R" : @"|2",
                            @"S" : @"5",
                            @"T" : @"7",
                            @"U" : @"|_|",
                            @"V" : @"|/",
                            @"W" : @"|/|/",
                            @"X" : @"><",
                            @"Y" : @"`/",
                            @"Z" : @"2",};
            
            l3ssl33tMap = @{
                            @"A" : @"4",
                            @"E" : @"3",
                            @"G" : @"6",
                            @"I" : @"|",
                            @"J" : @"9",
                            @"L" : @"1",
                            @"O" : @"0",
                            @"S" : @"5",
                            @"T" : @"7",
                            @"Z" : @"2",};
        });
    }
}
                      
+ (instancetype)sharedInstance {
    static PasswordMaker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PasswordMaker alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.wordListsCache = @{}.mutableCopy;
    }
    
    return self;
}

//static NSString *stringFromUnicodeCharacter(uint32_t character) {
//    uint32_t bytes = htonl(character); // Convert the character to a known ordering
//    return [[NSString alloc] initWithBytes:&bytes length:sizeof(uint32_t) encoding:NSUTF32StringEncoding];
//}

- (void)promptWithSuggestions:(UIViewController *)viewController usernames:(BOOL)usernames action:(void (^)(NSString * _Nonnull))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = NSLocalizedString(@"select_generated_field_title", @"Select your preferred generated field title.");
        NSString* message = NSLocalizedString(@"select_generated_field_message", @"Select your preferred generated field message.");
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        
        PasswordGenerationConfig* config = Settings.sharedInstance.passwordGenerationConfig;
        NSMutableArray* suggestions = [NSMutableArray arrayWithCapacity:3];
        
        if(usernames) {
            [suggestions addObject:[self generateUsername]];
            [suggestions addObject:[self generateUsername]];
            [suggestions addObject:[self generateUsername]];
        }
        else {
            [suggestions addObject:[self generateForConfigOrDefault:config]];
            [suggestions addObject:[self generateForConfigOrDefault:config]];
            config.algorithm = config.algorithm == kBasic ? kXkcd : kBasic; // Alternate method
            [suggestions addObject:[self generateForConfigOrDefault:config]];
        }
        
        UIAlertAction *firstSuggestion = [UIAlertAction actionWithTitle:suggestions[0]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(suggestions[0]); }];

        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:suggestions[1]
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) { action(suggestions[1]); }];

        UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:suggestions[2]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) { action(suggestions[2]); }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *a) { }];
            
        [alertController addAction:firstSuggestion];
        [alertController addAction:secondAction];
        [alertController addAction:thirdAction];
        [alertController addAction:cancelAction];
            
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (NSString*)generateUsername {
    if(!self.firstNamesCache) {
        self.firstNamesCache = [self loadWordsForList:@"first.names.us"];
        self.surnamesCache = [self loadWordsForList:@"surnames.us"];
    }
    
    NSInteger findex = arc4random_uniform((u_int32_t)self.firstNamesCache.count);
    NSInteger sindex = arc4random_uniform((u_int32_t)self.surnamesCache.count);
    
    return [NSString stringWithFormat:@"%@.%@", self.firstNamesCache[findex], self.surnamesCache[sindex]];
}

- (NSString *)generateForConfigOrDefault:(PasswordGenerationConfig *)config {
    NSString* pw = [self generateForConfig:config];
    return pw ? pw : [self generateWithDefaultConfig];
}

- (NSString*)generateWithDefaultConfig {
    PasswordGenerationConfig* defaults = [PasswordGenerationConfig defaults];
    return [self generateForConfig:defaults];
}

- (NSString *)generateForConfig:(PasswordGenerationConfig *)config {
    if(config.algorithm == kPasswordGenerationAlgorithmDiceware) {
        return [self generateDicewareForConfig:config];
    }
    else {
        return [self generateBasicForConfig:config];
    }
}

- (NSString *)generateDicewareForConfig:(PasswordGenerationConfig *)config {
    NSSet<NSString*>* currentWordListsCacheKey = [NSSet setWithArray:config.wordLists];
    if(self.allWordsCache && [currentWordListsCacheKey isEqual:self.allWordsCacheKey]) {
        //NSLog(@"All Words Cache Hit! Yay");
    }
    else {
        NSLog(@"All Words Cache Miss! Boo");
        self.allWordsCacheKey = currentWordListsCacheKey;
        

        NSArray<NSString*>* all = [config.wordLists flatMap:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self getWordsForList:obj];
        }];

        NSLog(@"Diceware Total Words: %lu", (unsigned long)all.count);
        self.allWordsCache = [[NSSet setWithArray:all] allObjects];
        NSLog(@"Diceware Total Unique Words: %lu", (unsigned long)self.allWordsCache.count);
    }
    NSArray<NSString*>* allWords = self.allWordsCache;
    
    if(allWords.count < 128) { // Bare minimum
        NSLog(@"Not enough words in word list(s) to generate a reasonable passphrase");
        return nil;
    }
    
    NSMutableArray<NSString*>* words = @[].mutableCopy;
    for(int i=0;i<config.wordCount;i++) {
        NSInteger index = arc4random_uniform((u_int32_t)allWords.count);
        [words addObject:allWords[index]];
    }
    
    // Perform Casing...
    
    NSArray<NSString*>* cased = [words map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [self changeWordCasing:config.wordCasing word:obj];
    }];
    
    // Perform Hackerification
    
    if(config.hackerify != kPasswordGenerationHackerifyLevelNone) {
        cased = [cased map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self hackerify:obj level:config.hackerify];
        }];
    }
    
    NSString* passphrase = [cased componentsJoinedByString:config.wordSeparator];
    
    // Add Salt?
    
    if (config.saltConfig != kPasswordGenerationSaltConfigNone) {
        return [self addSalt:passphrase config:config];
    }
    
    return passphrase;
}

- (NSString*)addSalt:(NSString*)passphrase config:(PasswordGenerationConfig*)config {
    PasswordGenerationConfig *saltConfig = [[PasswordGenerationConfig alloc] init];
    saltConfig.basicLength = arc4random_uniform(4) + 1;
    saltConfig.useCharacterGroups = @[@(kPasswordGenerationCharacterPoolLower),
                                      @(kPasswordGenerationCharacterPoolUpper),
                                      @(kPasswordGenerationCharacterPoolSymbols),
                                      @(kPasswordGenerationCharacterPoolNumeric)];
    
    saltConfig.easyReadCharactersOnly = YES;
    saltConfig.nonAmbiguousOnly = YES;
    
    NSString *salt = [self generateBasicForConfig:saltConfig];
    
    if (config.saltConfig == kPasswordGenerationSaltConfigPrefix) {
        return [salt stringByAppendingFormat:@"%@%@", config.wordSeparator, passphrase];
    }
    else if (config.saltConfig == kPasswordGenerationSaltConfigSuffix) {
        return [passphrase stringByAppendingFormat:@"%@%@", config.wordSeparator, salt];
    }
    else {
        for(int i=0;i<salt.length;i++) {
            NSString* chr = [salt substringWithRange:NSMakeRange(i, 1)];
            int index = arc4random_uniform((uint32_t)passphrase.length);
            passphrase = [passphrase stringByReplacingCharactersInRange:NSMakeRange(index, 0) withString:chr];
        }
        
        return passphrase;
    }
}

- (NSString*)hackerify:(NSString*)word level:(PasswordGenerationHackerifyLevel)level {
    BOOL all = level == kPasswordGenerationHackerifyLevelProAll || level == kPasswordGenerationHackerifyLevelBasicAll;
    
    if(!all && arc4random_uniform(10) < 6) { // Only do 40% of words if we're not doing all
        return word;
    }
    
    BOOL pro = level == kPasswordGenerationHackerifyLevelProSome || level == kPasswordGenerationHackerifyLevelProAll;
    const NSDictionary* map = pro ? l33tMap : l3ssl33tMap;
    
    NSMutableString *hackerified = [NSMutableString string];
    for(int i=0;i<word.length;i++) {
        NSString* character = [word substringWithRange:NSMakeRange(i, 1)];
        NSString* replace = map[character] ? map[character] : map[character.uppercaseString];
        [hackerified appendString:replace ? replace : character];
    }
    
    return hackerified.copy;
}

- (NSString*)changeWordCasing:(PasswordGenerationWordCasing)casing word:(NSString*)word {
    switch (casing) {
        case kPasswordGenerationWordCasingNoChange:
            return word;
            break;
        case kPasswordGenerationWordCasingLower:
            return word.lowercaseString;
            break;
        case kPasswordGenerationWordCasingUpper:
            return word.uppercaseString;
            break;
        case kPasswordGenerationWordCasingTitle:
            return word.localizedCapitalizedString;
            break;
        case kPasswordGenerationWordCasingRandom:
            return [self randomiseCase:word];
            break;
        default:
            return word;
            break;
    }
}

- (NSString*)randomiseCase:(NSString*)word {
    uint32_t lettersToRandomize = (uint32_t)word.length / 2; // 50%
    
    NSMutableString* ret = [NSMutableString stringWithString:word];
    for(int i=0;i<lettersToRandomize;i++) {
        BOOL upper = (BOOL)arc4random_uniform(2);
        uint32_t indexToRandomize = (uint32_t)arc4random_uniform((uint32_t)word.length);
        
        NSString* current = [ret substringWithRange:NSMakeRange(indexToRandomize, 1)];
        NSString* replace = upper ? current.uppercaseString : current.lowercaseString;
        [ret replaceCharactersInRange:NSMakeRange(indexToRandomize, 1) withString:replace];
    }
    
    return ret.copy;
}

- (NSArray<NSString*>*)getWordsForList:(NSString*)wordList {
    if(!self.wordListsCache[wordList]) {
        self.wordListsCache[wordList] = [self loadWordsForList:wordList];
    }
    
    return self.wordListsCache[wordList];
}

- (NSArray<NSString*>*)loadWordsForList:(NSString*)wordList {
    NSString* fileRoot = [[NSBundle mainBundle] pathForResource:wordList ofType:@"txt"];
    NSLog(@"%@ - fileRoot = [%@]", wordList, fileRoot);
    if(fileRoot == nil) {
        NSLog(@"WARNWARN: Could not load wordlist: %@", wordList);
        return @[];
    }
    
    NSError* error;
    NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:&error];
    NSLog(@"Loaded File Contents: %lu bytes - %@", (unsigned long)fileContents.length, error);
    if(!fileContents) {
        NSLog(@"WARNWARN: Could not load wordlist: %@ - %@", wordList, error);
        return @[];
    }
    
    NSArray<NSString*>* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSLog(@"%lu lines", (unsigned long)lines.count);
    
    NSArray<NSString*>* trimmed = [lines map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return trim(obj);
    }];
    
    NSArray<NSString*> *nonEmpty = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length != 0;
    }];
    
    NSLog(@"%@ - %lu cleaned lines", wordList, (unsigned long)nonEmpty.count);
    
    return nonEmpty;
}

- (NSString *)generateBasicForConfig:(PasswordGenerationConfig *)config {
    NSMutableArray<NSString*>* pools = @[].mutableCopy;
    
    for (NSNumber* group in config.useCharacterGroups) {
        [pools addObject:[self getCharacterPool:(PasswordGenerationCharacterPool)group.integerValue]];
    }
    
    NSString* allCharacters = [pools componentsJoinedByString:@""];
    
    if(config.easyReadCharactersOnly) {
        NSCharacterSet *trim = [NSCharacterSet characterSetWithCharactersInString:kDifficultToRead];
        allCharacters = [[allCharacters componentsSeparatedByCharactersInSet:trim] componentsJoinedByString:@""];
    }

    if(config.nonAmbiguousOnly) {
        NSCharacterSet *trim = [NSCharacterSet characterSetWithCharactersInString:kAmbiguous];
        allCharacters = [[allCharacters componentsSeparatedByCharactersInSet:trim] componentsJoinedByString:@""];
    }

    // Empty Set?
    
    if(![allCharacters length]) {
        NSLog(@"WARN: Could not generate password using config. Empty Character Pool.");
        return nil;
    }
    
    // Take one from each group... is it possible?
    
    if(config.pickFromEveryGroup && ![self containsCharactersFromEveryGroup:allCharacters config:config]) {
        NSLog(@"WARN: Could not generate password using config. Not possible to pick from every group.");
        return nil;
    }

    NSString *ret;
    do {
        NSMutableString *mut = [NSMutableString string];
        for(int i=0;i<config.basicLength;i++) {
            NSInteger index = arc4random_uniform((u_int32_t)allCharacters.length);
            NSString* character = [allCharacters substringWithRange:NSMakeRange(index, 1)];
            [mut appendString:character];
        }
        ret = [mut copy];
//        NSLog(@"Checking: [%@]-%lu", ret, (unsigned long)ret.length);
    } while(config.pickFromEveryGroup && ![self containsCharactersFromEveryGroup:ret config:config]);
    
    return ret;
}

- (BOOL)containsCharactersFromEveryGroup:(NSString*)ret config:(PasswordGenerationConfig*)config {
    for (NSNumber* group in config.useCharacterGroups) {
        NSString* pool = [self getCharacterPool:(PasswordGenerationCharacterPool)group.integerValue];
        NSCharacterSet* poolCharSet = [NSCharacterSet characterSetWithCharactersInString:pool];
        NSRange range = [ret rangeOfCharacterFromSet:poolCharSet];
        
        if(range.location == NSNotFound) {
            //NSLog(@"Does not contain characters from group [%@].", group);
            return NO;
        }
    }
    
    return YES;
}

- (NSString*)getCharacterPool:(PasswordGenerationCharacterPool)pool {
    switch (pool) {
        case kPasswordGenerationCharacterPoolLower:
            return kAllLowercase;
            break;
        case kPasswordGenerationCharacterPoolUpper:
            return kAllUppercase;
            break;
        case kPasswordGenerationCharacterPoolNumeric:
            return kAllDigits;
            break;
        case kPasswordGenerationCharacterPoolSymbols:
            return kAllSymbols;
            break;
//        case kPasswordGenerationCharacterPoolEmoji:
//            return self.allEmojis;
//            break;
//        case kPasswordGenerationCharacterPoolExtendedAscii:
//            return self.allExtendedAscii;
//            break;
        default:
            return @"";
            break;
    }
}

@end
