//
//  WebDAVConfigurationViewController.h
//  Strongbox
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVConfigurationViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL success, WebDAVSessionConfiguration*_Nullable configuration);
@property (nullable) WebDAVSessionConfiguration* initialConfiguration;

@end

NS_ASSUME_NONNULL_END
