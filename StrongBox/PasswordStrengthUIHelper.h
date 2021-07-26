//
//  PasswordStrengthUIHelper.h
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PasswordStrengthConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordStrengthUIHelper : NSObject

+ (void)bindStrengthUI:(NSString *)password config:(PasswordStrengthConfig *)config emptyPwHideSummary:(BOOL)emptyPwHideSummary label:(UILabel *)label progress:(UIProgressView *)progress;

@end

NS_ASSUME_NONNULL_END
