//
//  PasswordMaker.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PasswordMaker.h"
#import "PasswordGenerator.h"

static NSString* const kAllSymbols = @"+-=_@#$%^&;:,.<>/~\\[](){}?!|*";
static NSString* const kAllUppercase = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString* const kAllLowercase = @"abcdefghijklmnopqrstuvwxyz";
static NSString* const kAllDigits = @"0123456789";
static NSString* const kDifficultToRead = @"0125lIOSZ;:,.[](){}!|";
static NSString* const kAmbiguous = @"{}[]()/\\'\"`~,;:.<>";

@interface PasswordMaker ()

//@property NSString* allEmojis;
//@property NSString* allExtendedAscii;

@end

@implementation PasswordMaker

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
//        // TODO: Right?
//        NSMutableString* mut = [NSMutableString string];
//        for (int i=0x1F300;i<0x1F3F0;i++) {
//            [mut appendString:stringFromUnicodeCharacter(i)];
//        }
//
//        self.allEmojis = mut.copy;
////        NSLog(@"%@", self.allEmojis);
//
//
//        //
//        NSMutableString* sbHighAnsi = [NSMutableString string];
//
//        // [U+0080, U+009F] are C1 control characters,
//        // U+00A0 is non-breaking space
//        for(int ch = 0x00A1; ch <= 0x00AC;++ch) {
//            [sbHighAnsi appendString:stringFromUnicodeCharacter(ch)];
//        }
//
//        // U+00AD is soft hyphen (format character)
//
//        for(int ch = 0x00AE; ch <= 0x00FF;++ch) {
//            [sbHighAnsi appendString:stringFromUnicodeCharacter(ch)];
//        }
//
//        [sbHighAnsi appendString:@"\u00FF"];
//        self.allExtendedAscii = [sbHighAnsi copy];
    }
    
    return self;
}

static NSString *stringFromUnicodeCharacter(uint32_t character) {
    uint32_t bytes = htonl(character); // Convert the character to a known ordering
    return [[NSString alloc] initWithBytes:&bytes length:sizeof(uint32_t) encoding:NSUTF32StringEncoding];
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
    return @"1234";
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
            NSLog(@"Does not contain characters from group [%@].", group);
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
