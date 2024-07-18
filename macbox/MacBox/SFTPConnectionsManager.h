//
//  SFTPConnectionsManager.h
//  MacBox
//
//  Created by Strongbox on 05/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SFTPSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectSFTPConnectionCompletionBlock)(SFTPSessionConfiguration* connection);

@interface SFTPConnectionsManager : NSViewController

+ (instancetype)instantiateFromStoryboard;

@property BOOL manageMode;

@property (copy) SelectSFTPConnectionCompletionBlock onSelected;

@end

NS_ASSUME_NONNULL_END
