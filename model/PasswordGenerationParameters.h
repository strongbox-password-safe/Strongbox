//
//  PasswordGenerationParameters.h
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kBasic,
    kXkcd
} PasswordGenerationAlgorithm;

typedef enum {
    kXcdGoogle,
    kOriginal,
    kBeale,
    kEffLarge,
    kEffShort,
    kEffShortUniqueTriplet
} WordList;

@interface PasswordGenerationParameters : NSObject

- (instancetype _Nullable)initWithDefaults;

@property (nonatomic) PasswordGenerationAlgorithm algorithm;
@property (nonatomic) BOOL useLower;
@property (nonatomic) BOOL useUpper;
@property (nonatomic) BOOL useDigits;
@property (nonatomic) BOOL useSymbols;
@property (nonatomic) BOOL easyReadOnly;
@property (nonatomic) int minimumLength;
@property (nonatomic) int maximumLength;

@property (nonatomic) int xkcdWordCount;
@property (nonatomic) NSString* wordSeparator;
@property (nonatomic) WordList xKcdWordList;

@end
