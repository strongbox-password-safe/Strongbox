//
//  WelcomeMasterPasswordViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface WelcomeMasterPasswordViewController : UIViewController

@property NSString* name;
@property (nonatomic, copy) void (^onDone)(BOOL addExisting, DatabasePreferences* _Nullable databaseToOpen);

@end

NS_ASSUME_NONNULL_END
