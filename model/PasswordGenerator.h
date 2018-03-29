//
//  PasswordGenerator.h
//  Strongbox
//
//  Created by Mark on 29/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationParameters.h"

@interface PasswordGenerator : NSObject

+ (NSString *)generatePassword:(PasswordGenerationParameters*)parameters;

@end
