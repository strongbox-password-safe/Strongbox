//
//  CrossPlatform.h
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

//#ifndef CrossPlatform_h
//#define CrossPlatform_h

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///
#import <Foundation/Foundation.h>

#import "ApplicationPreferences.h"
#import "SyncManagement.h"
#import "SpinnerUI.h"
#import "AlertingUI.h"
#import "SBLog.h"



NS_ASSUME_NONNULL_BEGIN

@interface CrossPlatformDependencies : NSObject

+ (instancetype)defaults;

@property (readonly) id<ApplicationPreferences> applicationPreferences;
@property (readonly) id<SyncManagement> syncManagement;
@property (readonly) id<SpinnerUI> spinnerUi;
@property (readonly) id<AlertingUI> alertingUi;

@end

NS_ASSUME_NONNULL_END


