//
//  PasswordStrength.h
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordStrength : NSObject

+ (instancetype)withEntropy:(double)entropy 
           guessesPerSecond:(NSUInteger)guessesPerSecond
             characterCount:(NSUInteger)characterCount 
         showCharacterCount:(BOOL)showCharacterCount;

@property double entropy;
@property (readonly) NSString* category;
@property (readonly) NSString* summaryString;

@end

NS_ASSUME_NONNULL_END
