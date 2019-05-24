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

// Must be done after Privacy/Lock Screen is down, so we queue it up and execute on viewDidAppear or onPrivacyDismissed

- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace;
- (void)import:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace;

- (void)showQuickLaunchView;
- (void)showSafesListView;

- (void)appResignActive;
- (void)appBecameActive;

- (BOOL)isInQuickLaunchViewMode;
- (nullable SafeMetaData* )getPrimarySafe;
- (void)checkICloudAvailability;

@end

NS_ASSUME_NONNULL_END
