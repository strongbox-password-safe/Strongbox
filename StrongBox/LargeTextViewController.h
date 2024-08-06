//
//  LargeTextViewController.h
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LargeTextViewController : UIViewController

+ (instancetype)fromStoryboard;

@property NSString* string;
@property NSString* subtext;
@property BOOL colorize;
@property BOOL hideLargeTextGrid; 

@end

NS_ASSUME_NONNULL_END
