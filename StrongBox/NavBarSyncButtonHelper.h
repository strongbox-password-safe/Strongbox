//
//  NavBarSyncButtonHelper.h
//  Strongbox
//
//  Created by Strongbox on 15/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface NavBarSyncButtonHelper : NSObject

+ (UIButton*)createSyncButton:(id)target action:(SEL)action;
+ (BOOL)bindSyncToobarButton:(Model*)model button:(UIButton*)button; 

@end

NS_ASSUME_NONNULL_END
