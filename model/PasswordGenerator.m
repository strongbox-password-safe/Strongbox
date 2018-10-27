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
        return [PasswordGenerator generateXkcdPassword:parameters];
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
        [randomString appendFormat:@"%C", [pool characterAtIndex:arc4random_uniform((u_int32_t)pool.length)]];
    }
    
    return randomString;
}

+ (NSArray *)wordList
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

+ (NSString*)generateXkcdPassword:(PasswordGenerationParameters*)parameters {
    NSMutableString *randomString = [NSMutableString string];
    
    for(int i=0;i<parameters.xkcdWordCount;i++) {
        NSUInteger index = arc4random_uniform((u_int32_t)PasswordGenerator.wordList.count);
    
        [randomString appendString:[[PasswordGenerator.wordList objectAtIndex:index] capitalizedString]];
    }
    
    return randomString;
}

@end
