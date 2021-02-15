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

@property (nonatomic, copy) void (^onDone)(BOOL success);
@property (nullable) SFTPSessionConfiguration* configuration;

@end

NS_ASSUME_NONNULL_END
