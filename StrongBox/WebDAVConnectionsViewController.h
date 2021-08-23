//
//  WebDAVConnectionsViewController.h
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectWebDAVConnectionCompletionBlock)(WebDAVSessionConfiguration* connection);

@interface WebDAVConnectionsViewController : UITableViewController

+ (instancetype)instantiateFromStoryboard;
- (void)presentFromViewController:(UIViewController*)viewController;

@property BOOL selectMode;
@property (nullable) NSString* initialSelected;

@property (copy) SelectWebDAVConnectionCompletionBlock onSelected;

@end

NS_ASSUME_NONNULL_END
