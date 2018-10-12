//
//  InitialViewController.h
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface InitialTabViewController : UITabBarController

- (void)showQuickLaunchView;
- (void)showSafesListView;
- (BOOL)isInQuickLaunchViewMode;
- (SafeMetaData*)getPrimarySafe;
- (BOOL)isUnsupportedAutoFillProvider:(StorageProvider)storageProvider;

@end

NS_ASSUME_NONNULL_END
