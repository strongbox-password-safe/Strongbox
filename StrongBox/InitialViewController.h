//
//  InitialViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 06/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"
#import "SafeStorageProvider.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface InitialViewController : UITabBarController

- (void)importFromManualUiUrl:(NSURL *)importURL;

- (void)enqueueImport:(NSURL *)importURL canOpenInPlace:(BOOL)openInPlace; // Used when opened from iOS Files or another App... Must be done after Privacy/Lock Screen is down, so we queue it up and execute on viewDidAppear...

- (void)import:(NSURL *)importURL canOpenInPlace:(BOOL)openInPlace;

- (void)showQuickLaunchView;
- (void)showSafesListView;

- (void)appResignActive;
- (void)appBecameActive;

- (BOOL)isInQuickLaunchViewMode;
- (nullable SafeMetaData* )getPrimarySafe;
- (void)checkICloudAvailability;

@end

NS_ASSUME_NONNULL_END
