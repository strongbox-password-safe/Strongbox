//
//  SFTPSessionConfigurationViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFTPSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFTPSessionConfigurationViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL success, SFTPSessionConfiguration*_Nullable configuration);
@property (nullable) SFTPSessionConfiguration* initialConfiguration;

@end

NS_ASSUME_NONNULL_END
