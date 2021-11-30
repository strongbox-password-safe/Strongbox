//
//  SpinnerUI.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpinnerUI.h"

NS_ASSUME_NONNULL_BEGIN

@interface iOSSpinnerUI : NSObject<SpinnerUI>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
