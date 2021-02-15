//
//  PreviewItemViewController.h
//  Strongbox
//
//  Created by Strongbox on 24/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface PreviewItemViewController : UIViewController

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)forItem:(Node *)item andModel:(Model *)model;

- (instancetype)initForItem:(Node*)item andModel:(Model*)model;

@end

NS_ASSUME_NONNULL_END
