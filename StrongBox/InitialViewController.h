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

- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL;
- (void)showQuickLaunchView;
- (void)showSafesListView;
- (BOOL)isInQuickLaunchViewMode;
- (void)beginOpenSafeSequence:(SafeMetaData*)safe completion:(void (^)(Model* model))completion;
- (nullable SafeMetaData* )getPrimarySafe;
- (void)checkICloudAvailability;

@end

NS_ASSUME_NONNULL_END
