//
//  DatabaseModelConfig.h
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModelConfig : NSObject

+ (instancetype)defaults;
+ (instancetype)withPasswordConfig:(PasswordGenerationConfig*)passwordConfig;
+ (instancetype)withPasswordConfig:(PasswordGenerationConfig*)passwordConfig sanityCheckInnerStream:(BOOL)sanityCheckInnerStream;

@property (readonly) PasswordGenerationConfig *passwordGeneration;
@property (readonly) BOOL sanityCheckInnerStream;

@end

NS_ASSUME_NONNULL_END
