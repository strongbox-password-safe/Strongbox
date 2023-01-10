//
//  DatabasesManagerVC.h
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabasesListViewForceRefreshNotification;
extern NSString* const kDatabasesCollectionLockStateChangedNotification;
extern NSString* const kUpdateNotificationDatabasePreferenceChanged;

@interface DatabasesManagerVC : NSViewController

@end

NS_ASSUME_NONNULL_END
