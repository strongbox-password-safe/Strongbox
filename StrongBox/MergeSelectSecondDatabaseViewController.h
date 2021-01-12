//
//  MergeSelectSecondDatabaseViewController.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface MergeSelectSecondDatabaseViewController : UIViewController

@property Model* firstDatabase;
@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
