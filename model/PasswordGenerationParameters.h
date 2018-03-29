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
} PasswordGenerationAlgorithm;

@interface PasswordGenerationParameters : NSObject

//- (instancetype _Nullable)init;
- (instancetype _Nullable)initWithDefaults;

@property (nonatomic) PasswordGenerationAlgorithm algorithm;
@property (nonatomic) BOOL useLower;
@property (nonatomic) BOOL useUpper;
@property (nonatomic) BOOL useDigits;
@property (nonatomic) BOOL useSymbols;
@property (nonatomic) BOOL easyReadOnly;
@property (nonatomic) int minimumLength;
@property (nonatomic) int maximumLength;

@end
