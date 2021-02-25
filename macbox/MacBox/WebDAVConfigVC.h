//
//  WebDAVConfigVC.h
//  MacBox
//
//  Created by Strongbox on 17/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVConfigVC : NSViewController

+ (instancetype)newConfigurationVC;

@property (nonatomic, copy) void (^onDone)(BOOL success, WebDAVSessionConfiguration* _Nullable configuration);

@end

NS_ASSUME_NONNULL_END
