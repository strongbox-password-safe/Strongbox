//
//  DatabasesManagerVC.h
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseModel.h"
#import "MacDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabasesListViewForceRefreshNotification;
extern NSString* const kUpdateNotificationDatabasePreferenceChanged;

@interface DatabasesManagerVC : NSViewController

- (void)beginAddDatabaseSequence:(BOOL)createMode
                        newModel:(DatabaseModel* _Nullable)newModel
          existingDatabaseToCopy:(MacDatabasePreferences* _Nullable)existingDatabaseToCopy;

@end

NS_ASSUME_NONNULL_END
