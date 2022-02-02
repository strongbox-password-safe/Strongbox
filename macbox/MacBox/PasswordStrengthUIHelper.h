//
//  PasswordStrengthUIHelper.h
//  MacBox
//
//  Created by Strongbox on 02/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PasswordStrengthUIHelper : NSObject

+ (void)bindPasswordStrength:(NSString*)pw
               labelStrength:(NSTextField*)labelStrength
                    progress:(NSProgressIndicator*)progress;

+ (void)bindPasswordStrength:(NSString*)pw
               labelStrength:(NSTextField*)labelStrength
                    progress:(NSProgressIndicator*)progress
                    colorize:(BOOL)colorize;

@end

NS_ASSUME_NONNULL_END
