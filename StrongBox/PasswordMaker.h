//
//  PasswordMaker.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordMaker : NSObject

+ (instancetype)sharedInstance;

- (NSString*)generateForConfig:(PasswordGenerationConfig*)config;

@end

NS_ASSUME_NONNULL_END
