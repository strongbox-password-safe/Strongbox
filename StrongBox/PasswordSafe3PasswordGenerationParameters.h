//
//  PasswordSafe3PasswordGenerationParameters.h
//  Strongbox
//
//  Created by Mark on 13/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PasswordSafe3PasswordGenerationParameters : NSObject

@property (nonatomic) BOOL useLowercase;
@property (nonatomic) BOOL useUppercase;
@property (nonatomic) BOOL useDigits;
@property (nonatomic) BOOL useSymbols;
@property (nonatomic) BOOL useHexDigitsOnly;
@property (nonatomic) BOOL makePronounceable;
@property (nonatomic) BOOL useEasyVision;

@property (nonatomic) NSUInteger minimumLength;
@property (nonatomic) NSUInteger minimumLowercase;
@property (nonatomic) NSUInteger minimumUppercase;
@property (nonatomic) NSUInteger minimumDigits;
@property (nonatomic) NSUInteger minimumSymbols;

@end
