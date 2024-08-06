//
//  PasswordMaker.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PasswordMaker.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

static NSString* const kAllSymbols = @"+-=_@#$%^&;:,.<>/~\\[](){}?!|*'\"";
static NSString* const kAllUppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString* const kAllLowercase = @"abcdefghijklmnopqrstuvwxyz";
static NSString* const kAllDigits = @"0123456789";
static NSString* const kDifficultToRead = @"0125lIOSZ;:,.[](){}!|";
static NSString* const kAmbiguous = @"{}[]()/\\'\"`~,;:.<>";
static NSString* const kLatin1Supplement = 
                @"\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7"
                "\u00A8\u00A9\u00AA\u00AB\u00AC\u00AE\u00AF"
                "\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7"
                "\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF"
                "\u00C0\u00C1\u00C2\u00C3\u00C4\u00C5\u00C6\u00C7"
                "\u00C8\u00C9\u00CA\u00CB\u00CC\u00CD\u00CE\u00CF"
                "\u00D0\u00D1\u00D2\u00D3\u00D4\u00D5\u00D6\u00D7"
                "\u00D8\u00D9\u00DA\u00DB\u00DC\u00DD\u00DE\u00DF"
                "\u00E0\u00E1\u00E2\u00E3\u00E4\u00E5\u00E6\u00E7"
                "\u00E8\u00E9\u00EA\u00EB\u00EC\u00ED\u00EE\u00EF"
                "\u00F0\u00F1\u00F2\u00F3\u00F4\u00F5\u00F6\u00F7"
                "\u00F8\u00F9\u00FA\u00FB\u00FC\u00FD\u00FE\u00FF";

static NSString* const kEmojis = @"😀😃😄😁😆😅";

@interface PasswordMaker ()

@property NSMutableDictionary<NSString*, NSArray<NSString*>*> *wordListsCache;
@property NSSet<NSString*>* allWordsCacheKey;
@property NSArray<NSString*>* allWordsCache;

@property NSArray<NSString*> *firstNamesCache;
@property NSArray<NSString*> *surnamesCache;

@property NSSet<NSString*>* commonPasswordsSetCache;

@end

@implementation PasswordMaker

const static NSDictionary<NSString*, NSString*> *l33tMap;
const static NSDictionary<NSString*, NSString*> *l3ssl33tMap;
const static NSArray<NSString*> *kEmailDomains;

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
            
            kEmailDomains = @[
                 @"aol.com",
                 @"att.net",
                 @"comcast.net",
                 @"facebook.com",
                 @"gmail.com",
                 @"gmx.com",
                 @"googlemail.com",
                 @"google.com",
                 @"hotmail.com",
                 @"hotmail.co.uk",
                 @"mac.com",
                 @"me.com",
                 @"mail.com",
                 @"msn.com",
                 @"live.com",
                 @"sbcglobal.net",
                 @"verizon.net",
                 @"yahoo.com",
                 @"yahoo.co.uk"];
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

#if TARGET_OS_IPHONE
    
- (void)promptWithUsernameSuggestions:(UIViewController *)viewController
                               config:(PasswordGenerationConfig *)config
                               action:(void (^)(NSString * _Nonnull))action {
    [self promptWithSuggestions:viewController usernamesOnly:YES config:config action:action];
}

- (void)promptWithSuggestions:(UIViewController *)viewController
                       config:(PasswordGenerationConfig *)config
                       action:(void (^)(NSString * _Nonnull))action {
    [self promptWithSuggestions:viewController usernamesOnly:NO config:config action:action];
}

- (void)promptWithSuggestions:(UIViewController *)viewController
                usernamesOnly:(BOOL)usernamesOnly
                       config:(PasswordGenerationConfig *)config
                       action:(void (^)(NSString * _Nonnull))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = NSLocalizedString(@"select_generated_field_title", @"Select your preferred generated field title.");
        NSString* message = NSLocalizedString(@"select_generated_field_message", @"Select your preferred generated field message.");
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        NSMutableArray* suggestions = [NSMutableArray arrayWithCapacity:3];
        
        if(usernamesOnly) {
            [suggestions addObject:[self generateUsername].lowercaseString];
            [suggestions addObject:[self generateName]];
            [suggestions addObject:[self getFirstName]];
            [suggestions addObject:[self generateEmail]];
            [suggestions addObject:[self generateRandomWord]];
        }
        else {
            config.algorithm = config.algorithm == kPasswordGenerationAlgorithmBasic ? kPasswordGenerationAlgorithmDiceware : kPasswordGenerationAlgorithmBasic; 
            [suggestions addObject:[self generateForConfigOrDefault:config]];
            [suggestions addObject:[self generateUsername].lowercaseString];

            uint32_t randomInt = arc4random();
            [suggestions addObject:@(randomInt).stringValue];
            
            [suggestions addObject:[self generateEmail]];
            [suggestions addObject:[self generateRandomWord]];
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
        
        UIAlertAction *fourthAction = [UIAlertAction actionWithTitle:suggestions[3]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) { action(suggestions[3]); }];
        
        UIAlertAction *fifthAction = [UIAlertAction actionWithTitle:suggestions[4]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) { action(suggestions[4]); }];

        NSString* loc = NSLocalizedString(@"password_generation_regenerate_ellipsis", @"Regenerate...");
        
        UIAlertAction *regenAction = [UIAlertAction actionWithTitle:loc
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) {
            [self promptWithSuggestions:viewController usernamesOnly:usernamesOnly config:config action:action];
        }];
        [regenAction setValue:UIColor.systemGreenColor forKey:@"titleTextColor"];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *a) { }];
            
        [alertController addAction:firstSuggestion];
        [alertController addAction:secondAction];
        [alertController addAction:thirdAction];
        [alertController addAction:fourthAction];
        [alertController addAction:fifthAction];
        [alertController addAction:regenAction];

        [alertController addAction:cancelAction];
            
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

#endif

- (BOOL)isCommonPassword:(NSString *)password {
    if(!self.commonPasswordsSetCache) {
        NSMutableArray<NSString*>* common = [self getWordsForList:@"10-million-password-list-top-10000"].mutableCopy;
        [common addObjectsFromArray:[self getWordsForList:@"eff_large_wordlist.utf8"]];
        
        self.commonPasswordsSetCache = [NSSet setWithArray:common];
    }
    
    return [self.commonPasswordsSetCache containsObject:password.lowercaseString]; 
}

- (NSString*)generateName {
    NSString* firstName = [self getFirstName];

    NSInteger sindex = arc4random_uniform((u_int32_t)self.surnamesCache.count);

    return [NSString stringWithFormat:@"%@ %@", firstName, self.surnamesCache[sindex]];
}

- (NSString*)generateUsername {
    NSString* firstName = [self getFirstName];

    NSInteger sindex = arc4random_uniform((u_int32_t)self.surnamesCache.count);
    return [NSString stringWithFormat:@"%@.%@", firstName, self.surnamesCache[sindex]];
}

- (NSString*)getFirstName {
    if(!self.firstNamesCache) {
        self.firstNamesCache = [self loadWordsForList:@"first.names.us"];
        self.surnamesCache = [self loadWordsForList:@"surnames.us"];
    }

    NSInteger findex = arc4random_uniform((u_int32_t)self.firstNamesCache.count);
    return self.firstNamesCache[findex];
}

- (NSString*)getEmailDomain {
    uint32_t index = arc4random_uniform((uint32_t)kEmailDomains.count);
    return kEmailDomains[index];
}

- (NSString*)generateEmail {
    NSString* userNumber = @(arc4random_uniform(1000)).stringValue;
    NSString* user = [self getFirstName].lowercaseString;
    NSString* mailProviderDomain = [self getEmailDomain];
    
    return [NSString stringWithFormat:@"%@%@@%@", user, userNumber, mailProviderDomain];
}

- (NSString*)generateRandomWord {
    PasswordGenerationConfig *config = PasswordGenerationConfig.defaults;
    
    config.wordCount = 1;
    config.algorithm = kPasswordGenerationAlgorithmDiceware;
    
    return [self generateDicewareForConfig:config].lowercaseString;
}

- (NSString *)generateForConfigOrDefault:(PasswordGenerationConfig *)config {
    NSString* pw = [self generateForConfig:config];
    return pw ? pw : [self generateWithDefaultConfig];
}

- (NSString*)generateAlternateForConfig:(PasswordGenerationConfig *)config {
    if(config.algorithm == kPasswordGenerationAlgorithmDiceware) {
        return [self generateBasicForConfig:config];
    }
    else {
        return [self generateDicewareForConfig:config];
    }
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
        
    }
    else {
        slog(@"All Words Cache Miss! Boo");
        self.allWordsCacheKey = currentWordListsCacheKey;
        

        NSArray<NSString*>* all = [config.wordLists flatMap:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self getWordsForList:obj];
        }];

        slog(@"Diceware Total Words: %lu", (unsigned long)all.count);
        self.allWordsCache = [[NSSet setWithArray:all] allObjects];
        slog(@"Diceware Total Unique Words: %lu", (unsigned long)self.allWordsCache.count);
    }
    NSArray<NSString*>* allWords = self.allWordsCache;
    
    if(allWords.count < 128) { 
        slog(@"Not enough words in word list(s) to generate a reasonable passphrase");
        return nil;
    }
    
    NSMutableArray<NSString*>* words = @[].mutableCopy;
    for(int i=0;i<config.wordCount;i++) {
        NSInteger index = arc4random_uniform((u_int32_t)allWords.count);
        [words addObject:allWords[index]];
    }
    
    
    
    NSArray<NSString*>* cased = [words map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [self changeWordCasing:config.wordCasing word:obj];
    }];
    
    
    
    if(config.hackerify != kPasswordGenerationHackerifyLevelNone) {
        cased = [cased map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self hackerify:obj level:config.hackerify];
        }];
    }
    
    NSString* passphrase = [cased componentsJoinedByString:config.wordSeparator];
    
    
    
    if (config.saltConfig != kPasswordGenerationSaltConfigNone) {
        passphrase = [self addSalt:passphrase config:config];
    }
    
    

    if (config.dicewareAddLower ) {
        passphrase = [self dicewareSprinkleRandomFromPool:kPasswordGenerationCharacterPoolLower passphrase:passphrase];
    }
    if (config.dicewareAddUpper ) {
        passphrase = [self dicewareSprinkleRandomFromPool:kPasswordGenerationCharacterPoolUpper passphrase:passphrase];
    }
    if (config.dicewareAddNumber ) {
        passphrase = [self dicewareSprinkleRandomFromPool:kPasswordGenerationCharacterPoolNumeric passphrase:passphrase];
    }
    if (config.dicewareAddSymbols ) {
        passphrase = [self dicewareSprinkleRandomFromPool:kPasswordGenerationCharacterPoolSymbols passphrase:passphrase];
    }
    if (config.dicewareAddLatin1Supplement ) {
        passphrase = [self dicewareSprinkleRandomFromPool:kPasswordGenerationCharacterPoolLatin1Supplement passphrase:passphrase];
    }

    return passphrase;
}

- (NSString*)getRandomCharacterFromPool:(PasswordGenerationCharacterPool)pool {
    NSString* chars = [self getCharacterPool:pool];
    
    NSInteger index = arc4random_uniform((u_int32_t)chars.length);
    
    return [chars substringWithRange:NSMakeRange(index, 1)];
}

- (NSString*)dicewareSprinkleRandomFromPool:(PasswordGenerationCharacterPool)pool passphrase:(NSString*)passphrase {
    NSString* character = [self getRandomCharacterFromPool:pool];
    
    int index = arc4random_uniform((uint32_t)passphrase.length);
    
    return [passphrase stringByReplacingCharactersInRange:NSMakeRange(index, 0) withString:character];
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
    
    if(!all && arc4random_uniform(10) < 6) { 
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
    uint32_t lettersToRandomize = (uint32_t)word.length / 2; 
    
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

    if(fileRoot == nil) {
        slog(@"WARNWARN: Could not load wordlist: %@", wordList);
        return @[];
    }
    
    NSError* error;
    NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:&error];

    if(!fileContents) {
        slog(@"WARNWARN: Could not load wordlist: %@ - %@", wordList, error);
        return @[];
    }
    
    NSArray<NSString*>* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    
    NSArray<NSString*>* trimmed = [lines map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return trim(obj);
    }];
    
    NSArray<NSString*> *nonEmpty = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length != 0;
    }];
    

    
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

    if ( config.basicExcludedCharacters.length ) {
        NSCharacterSet *trim = [NSCharacterSet characterSetWithCharactersInString:config.basicExcludedCharacters];
        allCharacters = [[allCharacters componentsSeparatedByCharactersInSet:trim] componentsJoinedByString:@""];
    }
    
    
    
    if(![allCharacters length]) {
        slog(@"WARN: Could not generate password using config. Empty Character Pool.");
        return nil;
    }
    
    
    
    if(config.pickFromEveryGroup) {
        if ( ![self containsCharactersFromEveryGroup:allCharacters config:config] ) {
            slog(@"WARN: Could not generate password using config. Not possible to pick from every group.");
            return nil;
        }
        
        if ( config.basicLength < config.useCharacterGroups.count ) {
            slog(@"WARN: Could not generate password using config. Not possible to pick from every group because the length is too short.");
            return nil;
        }
    }
    
    NSString *ret;
    int iterationCount = 0;
    const int kMaxIterations = 1024;
    
    do {
        NSMutableString *mut = [NSMutableString string];
        for(int i=0;i<config.basicLength;i++) {
            NSInteger index = arc4random_uniform((u_int32_t)allCharacters.length);
            NSString* character = [allCharacters substringWithRange:NSMakeRange(index, 1)];
            [mut appendString:character];
        }
        ret = [mut copy];

        iterationCount++;
    } while(iterationCount < kMaxIterations && config.pickFromEveryGroup && ![self containsCharactersFromEveryGroup:ret config:config]);
    
    if ( iterationCount >= kMaxIterations ) {
        slog(@"WARN: Hit max iterations trying to create a password to match constraints... bailing");
        return nil;
    }
    
    return ret;
}

- (BOOL)containsCharactersFromEveryGroup:(NSString*)ret config:(PasswordGenerationConfig*)config {
    for (NSNumber* group in config.useCharacterGroups) {
        NSString* pool = [self getCharacterPool:(PasswordGenerationCharacterPool)group.integerValue];
        NSCharacterSet* poolCharSet = [NSCharacterSet characterSetWithCharactersInString:pool];
        NSRange range = [ret rangeOfCharacterFromSet:poolCharSet];
        
        if(range.location == NSNotFound) {
            
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
        case kPasswordGenerationCharacterPoolLatin1Supplement:
            return kLatin1Supplement;
            break;
        case kPasswordGenerationCharacterPoolEmojis:
            return kEmojis;
            break;
        default:
            return @"";
            break;
    }
}

@end
