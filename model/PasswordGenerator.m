//
//  PasswordGenerator.m
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PasswordGenerator.h"

@implementation PasswordGenerator

static NSString* kAllSymbols = @"+-=_@#$%^&;:,.<>/~\\[](){}?!|*";
static NSString* kAllUppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString* kAllLowercase = @"abcdefghijklmnopqrstuvwxyz";
static NSString* kAllDigits = @"0123456789";
static NSString* kDifficultToRead = @"0125lIOSZ;:,.[](){}!|";

+ (NSString *)generatePassword:(PasswordGenerationParameters*)parameters {
    if(parameters.algorithm == kBasic) {
        return [PasswordGenerator generateBasicPassword:parameters];
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
    
    NSUInteger len = parameters.minimumLength + arc4random_uniform(parameters.maximumLength - parameters.minimumLength);
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    
    for (int i = 0; i < len; i++) {
        [randomString appendFormat:@"%C", [pool characterAtIndex:arc4random_uniform((u_int32_t)pool.length)]];
    }
    
    return randomString;
}

@end
