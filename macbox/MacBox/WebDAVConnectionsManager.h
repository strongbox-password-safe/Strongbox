//
//  WebDAVConnectionsManager.h
//  MacBox
//
//  Created by Strongbox on 06/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectWebDAVConnectionCompletionBlock)(WebDAVSessionConfiguration* connection);

@interface WebDAVConnectionsManager : NSViewController

+ (instancetype)instantiateFromStoryboard;

@property (copy) SelectWebDAVConnectionCompletionBlock onSelected;
@property BOOL manageMode;

@end

NS_ASSUME_NONNULL_END
