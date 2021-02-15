//
//  GettingStartedInitialViewController.h
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface GettingStartedInitialViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL addExisting, SafeMetaData* _Nullable databaseToOpen);

@end

NS_ASSUME_NONNULL_END
