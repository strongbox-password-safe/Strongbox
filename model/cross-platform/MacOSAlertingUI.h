//
//  MacOSAlertingUI.h
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AlertingUI.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacOSAlertingUI : NSObject<AlertingUI>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
