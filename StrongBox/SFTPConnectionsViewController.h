//
//  SFTPConnectionsViewControllerTableViewController.h
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFTPSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectSFTPConnectionCompletionBlock)(SFTPSessionConfiguration* connection);

@interface SFTPConnectionsViewController : UITableViewController

+ (instancetype)instantiateFromStoryboard;
- (void)presentFromViewController:(UIViewController*)viewController;

@property BOOL selectMode;
@property (nullable) NSString* initialSelected;

@property (copy) SelectSFTPConnectionCompletionBlock onSelected;

@end

NS_ASSUME_NONNULL_END
