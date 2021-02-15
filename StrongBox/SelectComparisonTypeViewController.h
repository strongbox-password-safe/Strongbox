//
//  SelectComparisonTypeViewController.h
//  Strongbox
//
//  Created by Strongbox on 02/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectComparisonTypeViewController : UIViewController

@property Model* firstDatabase;
@property Model* secondDatabase;
@property (nonatomic, copy) void (^onDone)(BOOL mergeRequested, Model*_Nullable first, Model*_Nullable second);

@end

NS_ASSUME_NONNULL_END
