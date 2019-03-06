//
//  PasswordGenerator.m
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PasswordGenerator.h"

@implementation PasswordGenerator

static NSString* const kAllSymbols = @"+-=_@#$%^&;:,.<>/~\\[](){}?!|*";
static NSString* const kAllUppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString* const kAllLowercase = @"abcdefghijklmnopqrstuvwxyz";
static NSString* const kAllDigits = @"0123456789";
static NSString* const kDifficultToRead = @"0125lIOSZ;:,.[](){}!|";

+ (NSString *)generatePassword:(PasswordGenerationParameters*)parameters {
    if(parameters.algorithm == kBasic) {
        return [PasswordGenerator generateBasicPassword:parameters];
    }
    if(parameters.algorithm == kXkcd) {
        if(parameters.xKcdWordList == kXcdGoogle) {
            return [PasswordGenerator generateXkcdPassword:parameters];
        }
        else {
            return [PasswordGenerator generateDicewareStylePassword:parameters.wordSeparator
                                                           wordList:parameters.xKcdWordList
                                                          wordCount:parameters.xkcdWordCount];
        }
    }
    else {
        NSLog(@"Ruh roh... don't know how to generate this kind of password.");
        return @"Ruh roh...";
    }
}

+ (NSString *)generateBasicPassword:(PasswordGenerationParameters*)parameters {
    NSMutableString *characterPool = [[NSMutableString alloc] init];
    
    if(parameters.useDigits) {
        [characterPool appendString:kAllDigits];
    }
    
    if(parameters.useUpper) {
        [characterPool appendString:kAllUppercase];
    }
    
    if(parameters.useLower) {
        [characterPool appendString:kAllLowercase];
    }
    
    if(parameters.useSymbols) {
        [characterPool appendString:kAllSymbols];
    }
    
    NSString *pool = characterPool;
    
    if(parameters.easyReadOnly) {
        NSCharacterSet *trim = [NSCharacterSet characterSetWithCharactersInString:kDifficultToRead];
        pool = [[characterPool componentsSeparatedByCharactersInSet:trim] componentsJoinedByString:@""];
    }
    
    if(![pool length]) {
        return @"";
    }
    
    NSUInteger len = parameters.minimumLength + arc4random_uniform((parameters.maximumLength - parameters.minimumLength) + 1);
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    
    for (int i = 0; i < len; i++) {
        uint32_t index = arc4random_uniform((u_int32_t)pool.length);
        [randomString appendFormat:@"%C", [pool characterAtIndex:index]];
    }
    
    return randomString;
}

+ (NSArray *)xkcdGoogleWordList
{
    static NSArray *_wordList;
    static dispatch_once_t onceToken;
   
    dispatch_once(&onceToken, ^{
        NSString* fileRoot = [[NSBundle mainBundle] pathForResource:@"google-10000-english-usa-no-swears-medium" ofType:@"txt"];
        NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:nil];
        _wordList = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)effLargeWordList
{
    static NSDictionary<NSNumber*, NSString*>* _wordList;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _wordList = [PasswordGenerator loadDicewareWordList:@"eff_large_wordlist"];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)effShortWordList1
{
    static NSDictionary<NSNumber*, NSString*>* _wordList;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _wordList = [PasswordGenerator loadDicewareWordList:@"eff_short_wordlist_1"];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)effShortWordList2
{
    static NSDictionary<NSNumber*, NSString*>* _wordList;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _wordList = [PasswordGenerator loadDicewareWordList:@"eff_short_wordlist_2_0"];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)dicewareWordList
{
    static NSDictionary<NSNumber*, NSString*>* _wordList;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _wordList = [PasswordGenerator loadDicewareWordList:@"diceware.wordlist"];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)bealeWordList
{
    static NSDictionary<NSNumber*, NSString*>* _wordList;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _wordList = [PasswordGenerator loadDicewareWordList:@"beale.wordlist"];
    });
    
    return _wordList;
}

+ (NSDictionary<NSNumber*, NSString*>*)loadDicewareWordList:(NSString*)file {
    NSString* fileRoot = [[NSBundle mainBundle] pathForResource:file ofType:@"txt"];
    NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:nil];
    NSArray* lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableDictionary<NSNumber*, NSString*>* foo = [NSMutableDictionary dictionary];
    
    for (NSString* line in lines) {
        NSArray* numberAndString = [line componentsSeparatedByString:@"\t"];
        if(numberAndString.count == 2) { // Skip any empty or weird lines
            [foo setObject:numberAndString[1] forKey:[NSNumber numberWithInteger:[numberAndString[0] integerValue]]];
        }
    }
    
    return [foo copy];
}

+ (NSString*)generateXkcdPassword:(PasswordGenerationParameters*)parameters {
    NSMutableString *randomString = [NSMutableString string];
    
    for(int i=0;i<parameters.xkcdWordCount;i++) {
        NSUInteger index = arc4random_uniform((u_int32_t)PasswordGenerator.xkcdGoogleWordList.count);
    
        [randomString appendString:[[PasswordGenerator.xkcdGoogleWordList objectAtIndex:index] capitalizedString]];
    }
    
    return randomString;
}

+ (NSString*)generateDicewareStylePassword:(NSString*)wordSeparator
                                  wordList:(WordList)xKcdWordList
                                 wordCount:(int)wordCount {
    NSDictionary<NSNumber*, NSString*>* wordList = [PasswordGenerator getWordList:xKcdWordList];

    int diceRolls =  [PasswordGenerator getDiceRollsForList:xKcdWordList];
    
    return wordList[@(11111)];
}

+ (int)getDiceRollsForList:(WordList)wordList {
    return 5; // TODO
}

+ (NSDictionary<NSNumber*, NSString*>* )getWordList:(WordList)xKcdWordList {
    NSDictionary<NSNumber*, NSString*>* wordList = PasswordGenerator.effLargeWordList;
    
    if(xKcdWordList == kEffLarge) {
        wordList = PasswordGenerator.effLargeWordList;
    }
    else if(xKcdWordList == kOriginal) {
        wordList = PasswordGenerator.dicewareWordList;
    }
    else if(xKcdWordList == kBeale) {
        wordList = PasswordGenerator.bealeWordList;
    }
    else if(xKcdWordList == kEffShort) {
        wordList = PasswordGenerator.effShortWordList1;
    }
    else if(xKcdWordList == kEffShortUniqueTriplet) {
        wordList = PasswordGenerator.effShortWordList2;
    }
    
    return wordList;
}

@end
