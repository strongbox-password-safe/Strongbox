//
//  WelcomeUseICloudViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 17/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface WelcomeUseICloudViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL addExisting, SafeMetaData* _Nullable databaseToOpen);
@property BOOL addExisting;

@end

NS_ASSUME_NONNULL_END
