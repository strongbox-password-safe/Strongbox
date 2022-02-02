//
//  CrossPlatform.m
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "CrossPlatform.h"

#if TARGET_OS_IPHONE

#import "AppPreferences.h"
#import "SyncManager.h"
#import "iOSSpinnerUI.h"
#import "IOSAlertingUI.h"

#else

#import "Settings.h"
#import "MacSyncManager.h"
#import "macOSSpinnerUI.h"
#import "MacOSAlertingUI.h"

#endif

@implementation CrossPlatformDependencies

+ (instancetype)defaults {
    static CrossPlatformDependencies *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
#if TARGET_OS_IPHONE
        sharedInstance = [[CrossPlatformDependencies alloc] initWithApplicationPreferences:AppPreferences.sharedInstance
                                                                            syncManagement:SyncManager.sharedInstance
                                                                                 spinnerUi:iOSSpinnerUI.sharedInstance
                                                                                alertingUi:IOSAlertingUI.sharedInstance];

#else
    sharedInstance = [[CrossPlatformDependencies alloc] initWithApplicationPreferences:Settings.sharedInstance
                                                                        syncManagement:MacSyncManager.sharedInstance
                                                                             spinnerUi:macOSSpinnerUI.sharedInstance
                                                                            alertingUi:MacOSAlertingUI.sharedInstance];
#endif
    });
    
    return sharedInstance;
}

- (instancetype)initWithApplicationPreferences:(id<ApplicationPreferences>)applicationPreferences
                                syncManagement:(id<SyncManagement>)syncManagement
                                     spinnerUi:(id<SpinnerUI>)spinnerUi
                                    alertingUi:(id<AlertingUI>)alertingUi {
    self = [super init];
    
    if (self) {
        _applicationPreferences = applicationPreferences;
        _syncManagement = syncManagement;
        _spinnerUi = spinnerUi;
        _alertingUi = alertingUi;
    }
    
    return self;
}

@end
