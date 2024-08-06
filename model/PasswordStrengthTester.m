//
//  PasswordStrengthTester.m
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//
#import "PasswordStrengthTester.h"
#import "zxcvbn.h"

typedef NS_ENUM (NSInteger, PasswordStrengthCharacterPool) {
    kPasswordStrengthCharacterPoolLower, // abcdefghijklmnopqrstuvwxyz (26)
    kPasswordStrengthCharacterPoolUpper, // ABCDEFGHIJKLMNOPQRSTUVWXYZ (26)
    kPasswordStrengthCharacterPoolNumeric, // 0123456789 (10)
    kPasswordStrengthCharacterPoolSymbol, // !@#$%^&*()`~-_=+[{]}\|;:'",<.>/? (32)
    kPasswordStrengthCharacterPoolSpace, // ' ' (1)
    kPasswordStrengthCharacterPoolWeirdExtendedAscii, 
};

@implementation PasswordStrengthTester

const static NSCharacterSet *kSymbolCharacterSet;

+ (void)initialize {
    if (self == [PasswordStrengthTester class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kSymbolCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"!@#$%^&*()`~-_=+[{]}\\|;:'\",<.>/?"];
        });
        
    }
}

+ (PasswordStrength *)getStrength:(NSString *)password config:(PasswordStrengthConfig*)config {
    if ( password.length == 0 ) {
        return [PasswordStrength withEntropy:0.0f guessesPerSecond:config.adversaryGuessesPerSecond characterCount:password.length showCharacterCount:YES];
    }

    double entropy;

    if ( config.algorithm == kPasswordStrengthAlgorithmBasic ) {
        entropy = [PasswordStrengthTester getSimpleStrength:password];
    }
    else {
        entropy = [PasswordStrengthTester getZxcvbnStrength:password];
    }

    return [PasswordStrength withEntropy:entropy guessesPerSecond:config.adversaryGuessesPerSecond characterCount:password.length showCharacterCount:YES];
}

+ (double)getZxcvbnStrength:(NSString *)password {
    if ( password.length == 0 ) {
        return 0.0f;
    }


    const char* cString = [password cStringUsingEncoding:NSUTF8StringEncoding];
    
    if ( cString ) {
        double entropyBits = ZxcvbnMatch(cString, nil, nil);

    
    
    
    

        return entropyBits;
    }
    
    slog(@"WARNWARN: Could not convert password to cString");
    
    return 0.0f;
}

+ (double)getSimpleStrength:(NSString *)password {
    if ( password.length == 0 ) {
        return 0.0f;
    }

    return [PasswordStrengthTester getSimplePasswordEntropy:password];
}

+ (double)getSimplePasswordEntropy:(NSString*)password {
    double entropyBits = [PasswordStrengthTester getEntropyBits:password];
    
    return entropyBits;
}

+ (double)getEntropyBits:(NSString*)password {
    NSSet<NSString*>* chars = [PasswordStrengthTester decomposeIntoMinimalCharacterSet:password];
    NSMutableSet<NSNumber*>* pools = NSMutableSet.set;
    
    for (NSString* character in chars) {
        NSUInteger len = [character length];
        if ( len != 1) {
            continue;
        }
        unichar buffer[len+1];
        [character getCharacters:buffer range:NSMakeRange(0, len)];

        if ( [PasswordStrengthTester isLowerAlpha:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolLower)];
        }
        else if ( [PasswordStrengthTester isUpperAlpha:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolUpper)];
        }
        else if ( [PasswordStrengthTester isNumeric:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolNumeric)];
        }
        else if ( [PasswordStrengthTester isSymbol:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolSymbol)];
        }
        else if ( [PasswordStrengthTester isSpace:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolSpace)];
        }
        else if ( [PasswordStrengthTester isWeirdExtendedAscii:buffer[0]] ) {
            [pools addObject:@(kPasswordStrengthCharacterPoolWeirdExtendedAscii)];
        }
    }
        
    int poolSize = 0;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolLower)] ) poolSize += 26;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolUpper)] ) poolSize += 26;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolNumeric)] ) poolSize += 10;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolSymbol)] ) poolSize += 32;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolSpace)] ) poolSize += 1;
    if ( [pools containsObject:@(kPasswordStrengthCharacterPoolWeirdExtendedAscii)] ) poolSize += 128;



    
    
    
    return log2( pow( poolSize, password.length ));
}

+ (BOOL)isLowerAlpha:(unichar)character {
    return ( character >= 'a' && character <= 'z' );
}

+ (BOOL)isUpperAlpha:(unichar)character {
    return ( character >= 'A' && character <= 'Z' );
}

+ (BOOL)isNumeric:(unichar)character {
    return ( character >= '0' && character <= '9' );
}

+ (BOOL)isSymbol:(unichar)character {
    return [kSymbolCharacterSet characterIsMember:character];
}

+ (BOOL)isSpace:(unichar)character {
    return character == ' ';
}

+ (BOOL)isWeirdExtendedAscii:(unichar)character {
    return ( character >= 128 && character <= 255 );
}
           
+ (NSSet<NSString*>*)decomposeIntoMinimalCharacterSet:(NSString*)string {
    

    NSMutableSet<NSString*> *chars = NSMutableSet.set;

    [string enumerateSubstringsInRange:NSMakeRange(0, [string length])
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
        [chars addObject:inSubstring];
    }];

    return chars.copy;
}

@end
