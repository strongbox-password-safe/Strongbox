//
//  DatabasePropertiesController.h
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseModel.h"
#import "MacDatabasePreferences.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseSettingsTabViewController : NSTabViewController

typedef NS_ENUM(NSUInteger, DatabaseSettingsInitialTab) {
    kDatabaseSettingsInitialTabGeneral,
    kDatabaseSettingsInitialTabSideBar,
    kDatabaseSettingsInitialTabTouchId,
    kDatabaseSettingsInitialTabAutoFill,
    kDatabaseSettingsInitialTabAudit,
    kDatabaseSettingsInitialTabEncryption,
    kDatabaseSettingsInitialTabAdvanced,
};

+ (instancetype)fromStoryboard;
- (void)setModel:(ViewModel*)model initialTab:(DatabaseSettingsInitialTab)initialTab;

@end

NS_ASSUME_NONNULL_END
