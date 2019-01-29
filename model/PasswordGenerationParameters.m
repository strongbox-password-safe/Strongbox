//
//  PasswordGenerationParameters.m
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationParameters.h"

@implementation PasswordGenerationParameters

- (instancetype _Nullable)initWithDefaults {
    if(self = [self init]) {
        self.algorithm = kBasic;
        self.useLower = YES;
        self.useUpper = YES;
        self.useDigits = YES;
        self.useSymbols = YES;
        self.easyReadOnly = YES;
        self.minimumLength = 14;
        self.maximumLength = 24;
        self.xkcdWordCount = 4;
        
        self.wordSeparator = @"";
        self.xKcdWordList = kXcdGoogle;
        
        return self;
    }
    
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInteger:self.algorithm forKey:@"algorithm"];
    [encoder encodeBool:self.useLower forKey:@"useLower"];
    [encoder encodeBool:self.useUpper forKey:@"useUpper"];
    [encoder encodeBool:self.useDigits forKey:@"useDigits"];
    [encoder encodeBool:self.useSymbols forKey:@"useSymbols"];
    [encoder encodeBool:self.easyReadOnly forKey:@"easyReadOnly"];
    [encoder encodeInteger:self.minimumLength forKey:@"minimumLength"];
    [encoder encodeInteger:self.maximumLength forKey:@"maximumLength"];
    [encoder encodeInteger:self.xkcdWordCount forKey:@"xkcdWordCount"];
    
    [encoder encodeInteger:self.xKcdWordList forKey:@"wordList"];
    [encoder encodeObject:self.wordSeparator forKey:@"wordSeparator"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.algorithm = (int)[decoder decodeIntegerForKey:@"algorithm"];
        self.useLower = [decoder decodeBoolForKey:@"useLower"];
        self.useUpper = [decoder decodeBoolForKey:@"useUpper"];
        self.useDigits = [decoder decodeBoolForKey:@"useDigits"];
        self.useSymbols = [decoder decodeBoolForKey:@"useSymbols"];
        self.easyReadOnly = [decoder decodeBoolForKey:@"easyReadOnly"];
        self.minimumLength = (int)[decoder decodeIntegerForKey:@"minimumLength"];
        self.maximumLength = (int)[decoder decodeIntegerForKey:@"maximumLength"];
        self.xkcdWordCount = (int)[decoder decodeIntegerForKey:@"xkcdWordCount"];
    
        if([decoder containsValueForKey:@"wordList"]) {
            self.xKcdWordList = (int)[decoder decodeIntegerForKey:@"wordList"];
        }

        if([decoder containsValueForKey:@"wordSeparator"]) {
            self.wordSeparator = [decoder decodeObjectForKey:@"wordSeparator"];
        }
    }

    return self;
}

@end
