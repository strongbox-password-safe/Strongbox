//
//  ColoredStringHelper.m
//  Strongbox
//
//  Created by Mark on 02/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ColoredStringHelper.h"
#import "Utils.h"

typedef NS_ENUM (unsigned int, CharacterType) {
    kUnknown,
    kCharacterTypeNumber,
    kCharacterTypeUpperLetter,
    kCharacterTypeLowerLetter,
    kCharacterTypeSymbol,
};

typedef struct _Palette {
    COLOR_PTR numberColor;
    COLOR_PTR symbolColor;
    COLOR_PTR upperLetterColor;
    COLOR_PTR lowerLetterColor;
} Palette;

static Palette light;
static Palette dark;
static Palette lightColorBlind;
static Palette darkColorBlind;
static COLOR_PTR defaultNonColorizedColor;

@implementation ColoredStringHelper

+ (void)initialize {
    if (self == [ColoredStringHelper class]) {
        
        
        
        
        lightColorBlind.numberColor = ColorFromRGB(0xCC79A7); 
        lightColorBlind.symbolColor = ColorFromRGB(0x0072B2); 
        lightColorBlind.upperLetterColor = ColorFromRGB(0x009E63); 
        lightColorBlind.lowerLetterColor = ColorFromRGB(0x000000); 

        darkColorBlind.numberColor = ColorFromRGB(0xD55E00); 
        darkColorBlind.symbolColor = ColorFromRGB(0x56B4E9); 
        darkColorBlind.upperLetterColor = ColorFromRGB(0xF0E442); 
        darkColorBlind.lowerLetterColor = ColorFromRGB(0x009E63); 

#if TARGET_OS_IPHONE
        light.numberColor = UIColor.systemBlueColor;
        light.symbolColor = UIColor.systemPinkColor;
        light.upperLetterColor = UIColor.systemGreenColor;
    
        dark.numberColor = UIColor.systemBlueColor;
        dark.symbolColor = UIColor.systemYellowColor;
        dark.upperLetterColor = UIColor.systemGreenColor;
        
        dark.lowerLetterColor = UIColor.labelColor;
        light.lowerLetterColor = UIColor.labelColor;
#else
        dark.numberColor = NSColor.systemBlueColor;
        dark.symbolColor = NSColor.systemYellowColor;
        dark.upperLetterColor = NSColor.systemGreenColor;
        dark.lowerLetterColor = NSColor.labelColor;

        light.numberColor = NSColor.systemBlueColor;
        light.symbolColor = NSColor.systemPinkColor;
        light.upperLetterColor = NSColor.systemGreenColor;
        light.lowerLetterColor = NSColor.labelColor;
#endif
        

#if TARGET_OS_IPHONE
        defaultNonColorizedColor = UIColor.labelColor;
#else
        defaultNonColorizedColor = NSColor.labelColor;
#endif
    }
}

+ (NSAttributedString *)getColorizedAttributedString:(NSString *)password
                                            colorize:(BOOL)colorize
                                            darkMode:(BOOL)darkMode
                                          colorBlind:(BOOL)colorBlind
                                                font:(FONT_PTR)font {
    NSMutableAttributedString* ret = [[NSMutableAttributedString alloc] initWithString:@""];
  
    Palette *palette = darkMode ? (colorBlind ? &darkColorBlind : &dark )  : (colorBlind ? &lightColorBlind : &light);
    
    [ret beginEditing];
  
    NSArray<NSString*>* characters = [ColoredStringHelper getStringCharacters:password];
    for (NSString* character in characters) {
        CharacterType type = [ColoredStringHelper getCharacterType:character];
        
        NSDictionary *attrs = [ColoredStringHelper getAttributesForCharacterType:type
                                                                        colorize:colorize
                                                                         palette:palette
                                                                            font:font];
    
        NSAttributedString *attr = [[NSAttributedString alloc] initWithString:character
                                                                   attributes:attrs];
        
        [ret appendAttributedString:attr];
    }
    
    [ret endEditing];
    
    return ret.copy;
}

+ (COLOR_PTR)getColorForCharacter:(NSString*)character darkMode:(BOOL)darkMode colorBlind:(BOOL)colorBlind {
    CharacterType type = [ColoredStringHelper getCharacterType:character];
    
    Palette *palette = darkMode ? (colorBlind ? &darkColorBlind : &dark )  : (colorBlind ? &lightColorBlind : &light);
    
    return [ColoredStringHelper getColorForCharacterType:type palette:palette];
}

+ (NSDictionary*)getAttributesForCharacterType:(CharacterType)type
                                      colorize:(BOOL)colorize
                                       palette:(Palette*)palette
                                          font:(FONT_PTR)font {
    NSMutableDictionary* ret = [NSMutableDictionary dictionaryWithDictionary:@{
        NSForegroundColorAttributeName : colorize ? [ColoredStringHelper getColorForCharacterType:type palette:palette] : defaultNonColorizedColor
    }];
    
    if (colorize) {
        ret[NSKernAttributeName] = @(1.4); 
    }
    
    if ( font ) {
        ret[NSFontAttributeName] = font;
    }
    
    return ret;
}

+ (COLOR_PTR)getColorForCharacterType:(CharacterType)type palette:(Palette*)palette {
    if (type == kCharacterTypeNumber) {
        return palette->numberColor;
    }
    else if (type == kCharacterTypeSymbol) {
        return palette->symbolColor;
    }
    else if (type == kCharacterTypeUpperLetter) {
        return palette->upperLetterColor;
    }
    else {
        return palette->lowerLetterColor;
    }
}

+ (CharacterType)getCharacterType:(NSString*)character {
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:character];

    if ([NSCharacterSet.decimalDigitCharacterSet isSupersetOfSet:inStringSet]) {
        return kCharacterTypeNumber;
    }
    else if ([NSCharacterSet.lowercaseLetterCharacterSet isSupersetOfSet:inStringSet]) {
        return kCharacterTypeLowerLetter;
    }
    else if ([NSCharacterSet.uppercaseLetterCharacterSet isSupersetOfSet:inStringSet]) {
        return kCharacterTypeUpperLetter;
    }

    else {
        return kCharacterTypeSymbol;
    }
}

+ (NSArray<NSString*>*)getStringCharacters:(NSString*)composite {
    
    
    if (!composite.length) {
        return @[];
    }
    
    NSMutableArray *chars = [NSMutableArray array];

    [composite enumerateSubstringsInRange:NSMakeRange(0, composite.length)
                                  options:NSStringEnumerationByComposedCharacterSequences
                               usingBlock: ^(NSString *inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
        [chars addObject: inSubstring];
    }];



    return chars.copy;
}

@end
