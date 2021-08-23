//
//  SFTPConfigurationVC.h
//  MacBox
//
//  Created by Strongbox on 04/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SFTPSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFTPConfigurationVC : NSViewController

+ (instancetype)newConfigurationVC;

@property (nonatomic, copy) void (^onDone)(BOOL success, SFTPSessionConfiguration* _Nullable configuration);
@property (nullable) SFTPSessionConfiguration* initialConfiguration;

@end

NS_ASSUME_NONNULL_END
